# This script is meant to be sourced.
# It's not for directly running.

die() {
  printf "${STY_RED}FATAL: %s${STY_RST}\n" "$*"
  exit 1
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

require_cmd() {
  local c
  for c in "$@"; do
    command_exists "$c" || die "Required command missing: $c"
  done
}

detect_bootloader() {
  if [[ -d /boot/loader/entries ]]; then
    printf 'systemd-boot'
    return 0
  fi

  if [[ -f /etc/default/limine ]] || [[ -f /boot/limine.conf ]] || [[ -f /boot/EFI/limine.conf ]]; then
    printf 'limine'
    return 0
  fi

  if [[ -f /etc/default/grub ]] || command_exists grub-mkconfig; then
    printf 'grub'
    return 0
  fi

  printf 'unknown'
}

detect_limine_config() {
  local c
  for c in /etc/default/limine /boot/limine.conf /boot/EFI/limine.conf; do
    [[ -f "$c" ]] && { printf '%s' "$c"; return 0; }
  done
  return 1
}

BIN_DIR="${XDG_BIN_HOME:-$HOME/.local/bin}"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"

require_cmd pacman sed grep awk lspci mkinitcpio

function prepare_systemd_user_service(){
  if [[ ! -e "/usr/lib/systemd/user/ydotool.service" ]]; then
    x sudo ln -s /usr/lib/systemd/{system,user}/ydotool.service
  fi
}

function setup_user_group(){
  if [[ -z $(getent group i2c) ]] && [[ "${OS_GROUP_ID:-unknown}" != "fedora" ]]; then
    # On Fedora this is not needed. Tested with desktop computer with NVIDIA video card.
    x sudo groupadd i2c
  fi

  if [[ "${OS_GROUP_ID:-unknown}" == "fedora" ]]; then
    x sudo usermod -aG video,input "$(whoami)"
  else
    x sudo usermod -aG video,i2c,input "$(whoami)"
  fi
}
#####################################################################################
# These python packages are installed using uv into the venv (virtual environment). Once the folder of the venv gets deleted, they are all gone cleanly. So it's considered as setups, not dependencies.
showfun install-python-packages
v install-python-packages

showfun setup_user_group
v setup_user_group

if command_exists systemctl; then
  # For Fedora, uinput is required for the virtual keyboard to function, and udev rules enable input group users to utilize it.
  if [[ "${OS_GROUP_ID:-}" == "fedora" ]]; then
    v bash -c "echo uinput | sudo tee /etc/modules-load.d/uinput.conf"
    v bash -c 'echo SUBSYSTEM==\"misc\", KERNEL==\"uinput\", MODE=\"0660\", GROUP=\"input\" | sudo tee /etc/udev/rules.d/99-uinput.rules'
  else
    v bash -c "echo i2c-dev | sudo tee /etc/modules-load.d/i2c-dev.conf"
  fi
  # TODO: find a proper way for enable Nix installed ydotool. When running `systemctl --user enable ydotool, it errors "Failed to enable unit: Unit ydotool.service does not exist".
  if [[ ! "${INSTALL_VIA_NIX:-false}" == true ]]; then
    if [[ "${OS_GROUP_ID:-}" == "fedora" ]]; then
      v prepare_systemd_user_service
    fi
    # When ${DBUS_SESSION_BUS_ADDRESS:-} and $XDG_RUNTIME_DIR are empty, it commonly means that the current user has been logged in with `su - user` or `ssh user@hostname`. In such case `systemctl --user enable <service>` is not usable. It should be `sudo systemctl --machine=$(whoami)@.host --user enable <service>` instead.
    if [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
      v systemctl --user enable ydotool --now
    else
      v sudo systemctl --machine=$(whoami)@.host --user enable ydotool --now
    fi
  fi
  v sudo systemctl enable bluetooth --now
elif command_exists openrc; then
  v bash -c "echo 'modules=i2c-dev' | sudo tee -a /etc/conf.d/modules"
  v sudo rc-update add modules boot
  v sudo rc-update add ydotool default
  v sudo rc-update add bluetooth default

  x sudo rc-service ydotool start
  x sudo rc-service bluetooth start
else
  printf "${STY_RED}"
  printf "====================INIT SYSTEM NOT FOUND====================\n"
  printf "${STY_RST}"
  pause
fi

if [[ "${OS_GROUP_ID:-unknown}" == "gentoo" ]]; then
  v sudo chown -R $(whoami):$(whoami) ~/.local/
fi

#####################################################################################
# MSI MUX Switcher
showfun setup_mux_switcher
v setup_mux_switcher

function setup_mux_switcher(){
  local mux_dir="${REPO_ROOT}/tools/mux-switcher"
  local mux_bin="${BIN_DIR}/msi-mux-switcher"
  local py_script="${mux_dir}/msi-mux-switcher.py"

  if [[ ! -f "$py_script" ]]; then
    printf "${STY_YELLOW}[$0]: msi-mux-switcher Python tool not found at $py_script${STY_RST}\n"
    return 0
  fi

  if [[ -f /sys/class/dmi/id/product_name ]] && \
     grep -qi "MSI" /sys/class/dmi/id/sys_vendor 2>/dev/null; then
    printf "${STY_CYAN}[$0]: MSI laptop detected, setting up MUX switcher${STY_RST}\n"
    v mkdir -p "${BIN_DIR}"
    v ln -sf "${py_script}" "$mux_bin"
    v chmod +x "$mux_bin"
    printf "${STY_GREEN}[$0]: MUX switcher installed at $mux_bin${STY_RST}\n"
    printf "  Run: sudo msi-mux-switcher status\n"
    printf "  Run: sudo msi-mux-switcher hybrid\n"
    printf "  Run: sudo msi-mux-switcher dgpu\n"
    printf "  Run: sudo msi-mux-switcher igpu\n"
  else
    printf "${STY_YELLOW}[$0]: Not an MSI laptop, skipping MUX switcher${STY_RST}\n"
  fi
}

#####################################################################################
# Smart Organizer
if [[ ! "${SKIP_SMART_ORGANIZER:-}" == true ]]; then
  showfun setup_smart_organizer
  v setup_smart_organizer
fi

function setup_smart_organizer(){
  local organizer_dir="${REPO_ROOT}/tools/smart-organizer"
  local organizer_bin="${BIN_DIR}/smart-organizer"

  if [[ ! -d "$organizer_dir" ]]; then
    printf "${STY_YELLOW}[$0]: smart-organizer not found at $organizer_dir${STY_RST}\n"
    return 0
  fi

  printf "${STY_CYAN}[$0]: Setting up Smart Organizer${STY_RST}\n"
  v mkdir -p "${BIN_DIR}"
  v ln -sf "${organizer_dir}/smart-organizer.sh" "$organizer_bin"
  v chmod +x "$organizer_bin"

  local backup_dir="${REPO_ROOT}/tools/backup"
  local maintenance_dir="${REPO_ROOT}/tools/maintenance"
  if [[ -f "${backup_dir}/backup.sh" ]]; then
    v ln -sf "${backup_dir}/backup.sh" "${BIN_DIR}/backup.sh"
    v chmod +x "${BIN_DIR}/backup.sh"
  fi
  if [[ -f "${maintenance_dir}/maintenance.sh" ]]; then
    v ln -sf "${maintenance_dir}/maintenance.sh" "${BIN_DIR}/maintenance.sh"
    v chmod +x "${BIN_DIR}/maintenance.sh"
  fi

  # Install default configuration
  v mkdir -p "${CONFIG_DIR}/smart-organizer"
  if [[ ! -f "${CONFIG_DIR}/smart-organizer/smart-organizer.conf" ]]; then
    v cp "${organizer_dir}/smart-organizer.conf" "${CONFIG_DIR}/smart-organizer/smart-organizer.conf"
    printf "${STY_GREEN}[$0]: Default config installed to ${CONFIG_DIR}/smart-organizer/smart-organizer.conf${STY_RST}\n"
  fi

  # Install systemd user service for watch mode
  v mkdir -p "${CONFIG_DIR}/systemd/user"
  v bash -c "cat > '${CONFIG_DIR}/systemd/user/smart-organizer.service' << 'EOFSERVICE'
[Unit]
Description=Smart Organizer Watch Service
After=network.target

[Service]
Type=simple
ExecStart=%h/.local/bin/smart-organizer --watch
Restart=on-failure
RestartSec=10

[Install]
WantedBy=default.target
EOFSERVICE"

  # Install systemd user timer for periodic runs
  v bash -c "cat > '${CONFIG_DIR}/systemd/user/smart-organizer-timer.service' << 'EOFSERVICE'
[Unit]
Description=Smart Organizer Oneshot
After=network.target

[Service]
Type=oneshot
ExecStart=%h/.local/bin/smart-organizer --once
EOFSERVICE"

  v bash -c "cat > '${CONFIG_DIR}/systemd/user/smart-organizer.timer' << 'EOFSERVICE'
[Unit]
Description=Smart Organizer Timer
Requires=smart-organizer-timer.service

[Timer]
OnBootSec=15min
OnUnitActiveSec=1h
AccuracySec=1min
Persistent=true

[Install]
WantedBy=timers.target
EOFSERVICE"

   v systemctl --user daemon-reload
  v systemctl --user enable --now smart-organizer.service || true
  v systemctl --user enable --now smart-organizer.timer || true

  # Install backup timer
  local backup_dir="${REPO_ROOT}/tools/backup"
  if [[ -d "$backup_dir" ]]; then
    v bash -c "cat > '${CONFIG_DIR}/systemd/user/backup.service' << 'EOFSERVICE'
[Unit]
Description=Backup Script Oneshot
After=network.target

[Service]
Type=oneshot
ExecStart=%h/.local/bin/backup.sh --dry-run
EOFSERVICE"

    v bash -c "cat > '${CONFIG_DIR}/systemd/user/backup.timer' << 'EOFSERVICE'
[Unit]
Description=Backup Timer
Requires=backup.service

[Timer]
OnCalendar=weekly
AccuracySec=1h
Persistent=true

[Install]
WantedBy=timers.target
EOFSERVICE"

  v systemctl --user enable --now backup.timer || true
  fi

  # Install maintenance timer
  local maintenance_dir="${REPO_ROOT}/tools/maintenance"
  if [[ -d "$maintenance_dir" ]]; then
    v bash -c "cat > '${CONFIG_DIR}/systemd/user/maintenance.service' << 'EOFSERVICE'
[Unit]
Description=Maintenance Script Oneshot
After=network.target

[Service]
Type=oneshot
ExecStart=%h/.local/bin/maintenance.sh --auto
EOFSERVICE"

    v bash -c "cat > '${CONFIG_DIR}/systemd/user/maintenance.timer' << 'EOFSERVICE'
[Unit]
Description=Maintenance Timer
Requires=maintenance.service

[Timer]
OnCalendar=weekly
AccuracySec=1h
Persistent=true

[Install]
WantedBy=timers.target
EOFSERVICE"

  v systemctl --user enable --now maintenance.timer || true
  fi

  v systemctl --user daemon-reload

  printf "${STY_GREEN}[$0]: Smart Organizer installed successfully!${STY_RST}\n"
  printf "  Run: smart-organizer --dry-run\n"
  printf "  Run: smart-organizer --clean system\n"
  printf "  Watch service: systemctl --user status smart-organizer\n"
  printf "  Timer service: systemctl --user list-timers | grep smart-organizer\n"
  printf "  Backup timer: systemctl --user list-timers | grep backup\n"
  printf "  Maintenance timer: systemctl --user list-timers | grep maintenance\n"
}

#####################################################################################
# NVIDIA + MUX Setup for CachyOS
showfun setup_nvidia_mux
v setup_nvidia_mux

function setup_nvidia_mux(){
  if [[ "${OS_GROUP_ID:-unknown}" != "arch" ]] && [[ "${OS_GROUP_ID:-unknown}" != "cachyos" ]]; then
    printf "${STY_YELLOW}[$0]: Not Arch/CachyOS, skipping NVIDIA setup${STY_RST}\n"
    return 0
  fi

  if ! lspci | grep -qi "nvidia"; then
    printf "${STY_YELLOW}[$0]: No NVIDIA GPU detected, skipping NVIDIA setup${STY_RST}\n"
    return 0
  fi

  printf "${STY_CYAN}[$0]: Setting up NVIDIA drivers + MUX support${STY_RST}\n"

  # Install NVIDIA DKMS drivers
  printf "  Installing NVIDIA packages...\n"
  local kernel_headers_pkgs=()
  while IFS= read -r pkg; do
    [[ -n "$pkg" ]] && kernel_headers_pkgs+=("${pkg}-headers")
  done < <(pacman -Q 2>/dev/null | awk '/^linux-/{print $1}' | grep -vE '-headers$' || true)

  v sudo pacman -S --noconfirm --needed \
    nvidia-dkms "${kernel_headers_pkgs[@]}" nvidia-utils lib32-nvidia-utils \
    nvidia-prime

  # Configure mkinitcpio for hybrid graphics
  printf "  Configuring mkinitcpio for Intel + NVIDIA hybrid...\n"
  NEEDS_INITRAMFS_REBUILD=0
  if [[ -f /etc/mkinitcpio.conf ]]; then
    if ! grep -q "^MODULES=(i915 nvidia" /etc/mkinitcpio.conf; then
      v sudo sed -i 's/^MODULES=(/MODULES=(i915 nvidia nvidia_modeset nvidia_uvm nvidia_drm /' /etc/mkinitcpio.conf
      NEEDS_INITRAMFS_REBUILD=1
    fi
  fi

  # Configure bootloader kernel parameters (detect bootloader first)
  printf "  Configuring boot parameters for NVIDIA...\n"
  BOOTLOADER="$(detect_bootloader)"

  case "$BOOTLOADER" in
    systemd-boot)
      local entry_file
      while IFS= read -r entry_file; do
        if [[ -n "$entry_file" ]] && ! grep -q "nvidia-drm.modeset=1" "$entry_file"; then
          v sudo sed -i 's|^\(options .*\)|\1 nvidia-drm.modeset=1 nvidia.NVreg_PreserveVideoMemoryAllocations=1|' "$entry_file"
        fi
      done < <(find /boot/loader/entries -maxdepth 1 -name '*.conf' 2>/dev/null)
      NEEDS_INITRAMFS_REBUILD=0
      ;;
    limine)
      local limine_cfg=""
      limine_cfg="$(detect_limine_config)" || true

      if [[ -n "$limine_cfg" ]] && ! grep -q "nvidia-drm.modeset=1" "$limine_cfg"; then
        if grep -Eq '^KERNEL_CMDLINE\[default\]=' "$limine_cfg"; then
          v sudo sed -i 's|^\(KERNEL_CMDLINE\[default\]=.*\)"|\1 nvidia-drm.modeset=1 nvidia.NVreg_PreserveVideoMemoryAllocations=1"|' "$limine_cfg"
          NEEDS_INITRAMFS_REBUILD=1
        elif grep -Eq '^kernel_cmdline[[:space:]]*=' "$limine_cfg"; then
          v sudo sed -i 's|^\(kernel_cmdline[[:space:]]*=.*\)|\1 nvidia-drm.modeset=1 nvidia.NVreg_PreserveVideoMemoryAllocations=1|' "$limine_cfg"
        else
          printf "  WARNING: Could not recognize Limine cmdline format in $limine_cfg\n"
        fi
      fi
      ;;
    grub)
      if [[ -f /etc/default/grub ]] && ! grep -q "nvidia-drm.modeset=1" /etc/default/grub; then
        if grep -Eq '^GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub; then
          v sudo sed -i 's|^\(GRUB_CMDLINE_LINUX_DEFAULT=.*\)"|\1 nvidia-drm.modeset=1 nvidia.NVreg_PreserveVideoMemoryAllocations=1"|' /etc/default/grub
        elif grep -Eq '^GRUB_CMDLINE_LINUX=' /etc/default/grub; then
          v sudo sed -i 's|^\(GRUB_CMDLINE_LINUX=.*\)"|\1 nvidia-drm.modeset=1 nvidia.NVreg_PreserveVideoMemoryAllocations=1"|' /etc/default/grub
        fi
      fi
      if command_exists grub-mkconfig; then
        if [[ -d /boot/grub ]]; then
          v sudo grub-mkconfig -o /boot/grub/grub.cfg
        elif [[ -d /boot/efi/EFI/grub ]]; then
          v sudo grub-mkconfig -o /boot/efi/EFI/grub/grub.cfg
        fi
      fi
      NEEDS_INITRAMFS_REBUILD=0
      ;;
    *)
      printf "  WARNING: unknown bootloader, skipping boot parameter configuration\n"
      NEEDS_INITRAMFS_REBUILD=0
      ;;
  esac

  if [[ "$NEEDS_INITRAMFS_REBUILD" -eq 1 ]]; then
    if command_exists limine-mkinitcpio; then
      v sudo limine-mkinitcpio
    else
      v sudo mkinitcpio -P
    fi
  fi

  # Create udev rules for stable GPU device paths
  printf "  Creating udev rules for stable GPU paths...\n"
  local igpu_pci
  local dgpu_pci
  igpu_pci=$(lspci -D -d ::0300 | grep -i "intel" | head -n1 | awk '{print $1}' || true)
  dgpu_pci=$(lspci -D -d ::0300 | grep -i "nvidia" | head -n1 | awk '{print $1}' || true)

  if [[ -n "$igpu_pci" ]]; then
    v sudo tee /etc/udev/rules.d/igpu-device-path.rules << 'EOF'
KERNEL=="card*", KERNELS=="__IGPU_PCI__", SUBSYSTEM=="drm", SUBSYSTEMS=="pci", SYMLINK+="dri/igpu"
EOF
    v sudo sed -i "s|__IGPU_PCI__|${igpu_pci}|g" /etc/udev/rules.d/igpu-device-path.rules
  fi

  if [[ -n "$dgpu_pci" ]]; then
    v sudo tee /etc/udev/rules.d/dgpu-device-path.rules << 'EOF'
KERNEL=="card*", KERNELS=="__DGPU_PCI__", SUBSYSTEM=="drm", SUBSYSTEMS=="pci", SYMLINK+="dri/dgpu"
EOF
    v sudo sed -i "s|__DGPU_PCI__|${dgpu_pci}|g" /etc/udev/rules.d/dgpu-device-path.rules
  fi

  v sudo udevadm control --reload-rules
  v sudo udevadm trigger

  # Create Hyprland mode-specific configs
  printf "  Creating Hyprland GPU mode configs...\n"
  v mkdir -p "${HOME}/.config/hypr/config/modes"

  v bash -c "cat > '${HOME}/.config/hypr/config/modes/hybrid.lua' << 'EOFCONFIG'
-- Hybrid mode: Intel iGPU primary, NVIDIA offload
env = AQ_DRM_DEVICES, /dev/dri/igpu:/dev/dri/dgpu
env = LIBVA_DRIVER_NAME, nvidia
env = __GLX_VENDOR_LIBRARY_NAME, nvidia
EOFCONFIG"

  v bash -c "cat > '${HOME}/.config/hypr/config/modes/dgpu.lua' << 'EOFCONFIG'
-- dGPU mode: NVIDIA direct via MUX
env = AQ_DRM_DEVICES, /dev/dri/dgpu
env = LIBVA_DRIVER_NAME, nvidia
env = __GLX_VENDOR_LIBRARY_NAME, nvidia
env = GBM_BACKEND, nvidia-drm
EOFCONFIG"

  v bash -c "cat > '${HOME}/.config/hypr/config/modes/igpu.lua' << 'EOFCONFIG'
-- iGPU mode: Intel only, NVIDIA powered off
env = AQ_DRM_DEVICES, /dev/dri/igpu
env = LIBVA_DRIVER_NAME, iHD
env = __GLX_VENDOR_LIBRARY_NAME, mesa
EOFCONFIG"

  # Create nvidia-run wrapper script
  printf "  Creating nvidia-run wrapper...\n"
  v sudo tee /usr/local/bin/nvidia-run << 'EOFSCRIPT'
#!/bin/bash
export __NV_PRIME_RENDER_OFFLOAD=1
export __GLX_VENDOR_LIBRARY_NAME=nvidia
export __VK_LAYER_NV_optimus=NVIDIA_only
export GBM_BACKEND=nvidia-drm
export LIBVA_DRIVER_NAME=nvidia
export WLR_NO_HARDWARE_CURSORS=1
exec "$@"
EOFSCRIPT
  v sudo chmod +x /usr/local/bin/nvidia-run

  printf "${STY_GREEN}[$0]: NVIDIA + MUX setup completed${STY_RST}\n"
  printf "  Reboot required for changes to take effect\n"
  printf "  Run: sudo msi-gpu-switcher status\n"
}

#####################################################################################
# AI/ML Stack Setup
showfun setup_ai_stack
v setup_ai_stack

function setup_ai_stack(){
  if [[ "${OS_GROUP_ID:-unknown}" != "arch" ]] && [[ "${OS_GROUP_ID:-unknown}" != "cachyos" ]]; then
    printf "${STY_YELLOW}[$0]: Not Arch/CachyOS, skipping AI stack setup${STY_RST}\n"
    return 0
  fi

  printf "${STY_CYAN}[$0]: Setting up AI/ML stack${STY_RST}\n"

  # Install CUDA + Ollama
  printf "  Installing CUDA toolkit and Ollama...\n"
  v sudo pacman -S --noconfirm --needed \
    cuda cudnn ollama ollama-cuda python python-pip

  # Enable Ollama service
  printf "  Enabling Ollama service...\n"
  v sudo systemctl enable --now ollama.service

  # Add user to video/render groups
  printf "  Adding user to video/render groups...\n"
  v sudo usermod -aG video,render "$(whoami)"

  # Install Python packages
  printf "  Installing Python AI packages...\n"
  v pip install --user torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128 || true
  v pip install --user transformers datasets accelerate huggingface-hub chromadb langchain || true

  printf "${STY_GREEN}[$0]: AI/ML stack installed${STY_RST}\n"
  printf "  Run: ollama pull qwen2.5:7b\n"
  printf "  Run: python -c \"import torch; print(torch.cuda.is_available())\"\n"
}

#####################################################################################
# Power Management Setup
showfun setup_power_management
v setup_power_management

function setup_power_management(){
  printf "${STY_CYAN}[$0]: Setting up power management${STY_RST}\n"

  # Install power-profiles-daemon
  v sudo pacman -S --noconfirm --needed power-profiles-daemon || true

  # Enable service
  v sudo systemctl enable --now power-profiles-daemon.service || true

  # Set balanced profile by default
  v powerprofilesctl set balanced || true

  # ZRAM configuration for 16GB RAM
  printf "  Configuring ZRAM for 16GB RAM...\n"
  if [[ -f /etc/systemd/system/systemd-zram-setup@.service ]]; then
    v sudo systemctl enable --now systemd-zram-setup@zram0.service || true
  fi

  printf "${STY_GREEN}[$0]: Power management configured${STY_RST}\n"
}
