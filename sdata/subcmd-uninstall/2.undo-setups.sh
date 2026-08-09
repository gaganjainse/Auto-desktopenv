#!/usr/bin/env bash
# sdata/subcmd-uninstall/2.undo-setups.sh
# Reverses the system changes made by sdata/subcmd-install/2.setups.sh.
# Sourced by 0.run.sh. Safe to re-run. Conservative: it never removes packages
# without asking and never edits the bootloader automatically.
# See docs/SHESHA/02_ROADMAP.md (Phase 2) and 01_AUDIT.md (HIGH-06).

undo_nvidia_mux() {
  printf "${STY_CYAN}[$0]: Undoing NVIDIA/MUX setup${STY_RST}\n"

  # 1. Remove nvidia-run wrapper
  if [[ -e /usr/local/bin/nvidia-run ]]; then
    v sudo rm -f /usr/local/bin/nvidia-run
  fi

  # 2. Remove our udev GPU path rules
  v sudo rm -f /etc/udev/rules.d/igpu-device-path.rules \
               /etc/udev/rules.d/dgpu-device-path.rules
  v sudo udevadm control --reload-rules 2>/dev/null || true

  # 3. Remove the modules we prepended to mkinitcpio.conf.
  if [[ -f /etc/mkinitcpio.conf ]]; then
    v sudo sed -i -E \
      's/\b(i915|nvidia|nvidia_modeset|nvidia_uvm|nvidia_drm)\b//g; s/[[:space:]]+/ /g; s/MODULES=\( /MODULES=(/; s/ \)/)/' \
      /etc/mkinitcpio.conf
    v sudo mkinitcpio -P
  fi

  # 4. Remove Hyprland mode configs we generated
  v rm -rf "${HOME}/.config/hypr/config/modes"

  printf "${STY_YELLOW}[$0]: BOOTLOADER: nvidia_drm.modeset=1 and nvidia.NVreg_PreserveVideoMemoryAllocations=1\n"
  printf "       were added to your bootloader. Remove them manually from systemd-boot/grub/limine\n"
  printf "       and rebuild the boot config; then reboot.${STY_RST}\n"
}

undo_ai_stack() {
  printf "${STY_CYAN}[$0]: Undoing AI stack${STY_RST}\n"

  # Stop/disable user units we created (only if systemctl --user works)
  if command_exists systemctl && [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
    for u in shesha-system-control-mcp.service shesha-smart-organizer-mcp.service \
             shesha-hyprland-control-mcp.service; do
      v systemctl --user disable --now "$u" 2>/dev/null || true
      v rm -f "${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/$u"
    done
    v systemctl --user daemon-reload
  fi

  # Remove installed MCP launcher symlinks
  v rm -f "${XDG_BIN_HOME:-$HOME/.local/bin}"/shesha-*-mcp
  v rm -f "${XDG_BIN_HOME:-$HOME/.local/bin}"/sm-watcher

  # Remove the Shesha venv (state, not config)
  v rm -rf "${XDG_STATE_HOME:-$HOME/.local/state}/sesha"

  # Disable (do NOT uninstall) Ollama — it may be used by other things.
  if command_exists systemctl; then
    v sudo systemctl disable --now ollama.service 2>/dev/null || true
  fi
  printf "${STY_YELLOW}[$0]: Ollama and Newelle packages were left installed; remove with your package manager if desired.${STY_RST}\n"
}

undo_smart_organizer() {
  printf "${STY_CYAN}[$0]: Undoing smart-organizer / backup / maintenance timers${STY_RST}\n"
  if command_exists systemctl && [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
    for u in smart-organizer.service smart-organizer-watch.service smart-organizer.timer \
             smart-organizer-timer.service backup.service backup.timer \
             maintenance.service maintenance.timer; do
      v systemctl --user disable --now "$u" 2>/dev/null || true
      v rm -f "${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/$u"
    done
    v systemctl --user daemon-reload
  fi
  v rm -f "${XDG_BIN_HOME:-$HOME/.local/bin}"/smart-organizer \
          "${XDG_BIN_HOME:-$HOME/.local/bin}"/backup.sh \
          "${XDG_BIN_HOME:-$HOME/.local/bin}"/maintenance.sh \
          "${XDG_BIN_HOME:-$HOME/.local/bin}"/msi-mux-switcher
}

undo_power_management() {
  printf "${STY_CYAN}[$0]: Undoing power management${STY_RST}\n"
  if command_exists systemctl; then
    v sudo systemctl disable --now power-profiles-daemon.service 2>/dev/null || true
    v sudo systemctl disable --now systemd-zram-setup@zram0.service 2>/dev/null || true
  fi
  # Only remove zram-generator.conf if we are the ones who wrote it. We tag our
  # managed file; if it has our marker, remove it. (Conservative otherwise.)
  if [[ -f /etc/systemd/zram-generator.conf ]] && \
     grep -q "# managed-by=auto-desktopenv" /etc/systemd/zram-generator.conf 2>/dev/null; then
    v sudo rm -f /etc/systemd/zram-generator.conf
  fi
}

# Run all reversals.
undo_smart_organizer
undo_power_management
undo_nvidia_mux
undo_ai_stack
