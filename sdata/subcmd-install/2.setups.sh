# This script is meant to be sourced.
# It's not for directly running.

# Use the audited local installer revision supplied with this PR.

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

# Detect an AUR helper. Prefer an already installed helper; install paru only
# when no helper is present. Empty helpers are never expanded as commands.
detect_aur_helper() {
  local h
  for h in paru shelly yay; do
    if command_exists "$h"; then printf '%s' "$h"; return 0; fi
  done
  printf ''
}

if [[ -z "${AUR_HELPER:-}" ]]; then
  AUR_HELPER="$(detect_aur_helper)"
  if [[ -z "$AUR_HELPER" ]] && command_exists pacman; then
    log_info "No AUR helper found; installing paru for scripting stability"
    v sudo pacman -S --noconfirm --needed paru
    AUR_HELPER=paru
  fi
fi
readonly AUR_HELPER="${AUR_HELPER:-}"
if [[ -z "$AUR_HELPER" ]]; then
  log_warning "No AUR helper available; AUR package installs will be skipped"
fi

aur_install() {
  if [[ -z "$AUR_HELPER" ]]; then
    log_warning "Skipping AUR install (no helper): $*"
    return 0
  fi
  v "$AUR_HELPER" -S --noconfirm --needed "$@"
}

detect_bootloader() {
  if [[ -d /boot/loader/entries ]]; then printf 'systemd-boot'; return 0; fi
  if [[ -f /etc/default/limine ]] || [[ -f /boot/limine.conf ]] || [[ -f /boot/EFI/limine.conf ]]; then
    printf 'limine'; return 0
  fi
  if [[ -f /etc/default/grub ]] || command_exists grub-mkconfig; then printf 'grub'; return 0; fi
  printf 'unknown'
}

detect_limine_config() {
  local c
  for c in /etc/default/limine /boot/limine.conf /boot/EFI/limine.conf; do
    if [[ -f "$c" ]]; then printf '%s' "$c"; return 0; fi
  done
  return 1
}

BIN_DIR="${XDG_BIN_HOME:-$HOME/.local/bin}"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"

function prepare_systemd_user_service(){
  if [[ ! -e "/usr/lib/systemd/user/ydotool.service" ]]; then
    x sudo ln -s /usr/lib/systemd/{system,user}/ydotool.service
  fi
}

#####################################################################################
# Python packages are installed into the managed virtual environment by upstream.
showfun install-python-packages
v install-python-packages

function setup_user_group(){
  if [[ -z "$(getent group i2c)" ]] && [[ "${OS_GROUP_ID:-unknown}" != "fedora" ]]; then
    x sudo groupadd i2c
  fi

  if [[ "${OS_GROUP_ID:-unknown}" == "fedora" ]]; then
    x sudo usermod -aG video,input "$(whoami)"
  else
    x sudo usermod -aG video,i2c,input "$(whoami)"
  fi
}

showfun setup_user_group
v setup_user_group

if command_exists systemctl; then
  if [[ "${OS_GROUP_ID:-}" == "fedora" ]]; then
    v bash -c "echo uinput | sudo tee /etc/modules-load.d/uinput.conf"
    v bash -c 'echo SUBSYSTEM==\"misc\", KERNEL==\"uinput\", MODE=\"0660\", GROUP=\"input\" | sudo tee /etc/udev/rules.d/99-uinput.rules'
  else
    v bash -c "echo i2c-dev | sudo tee /etc/modules-load.d/i2c-dev.conf"
  fi
  if [[ ! "${INSTALL_VIA_NIX:-false}" == true ]]; then
    if [[ "${OS_GROUP_ID:-}" == "fedora" ]]; then
      v prepare_systemd_user_service
    fi
    if [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
      if ! systemctl --user enable ydotool --now; then
        log_error "Failed to enable ydotool user service"
        exit 1
      fi
    else
      if ! sudo systemctl --machine="$(whoami)@.host" --user enable ydotool --now; then
        log_error "Failed to enable ydotool through the user manager"
        exit 1
      fi
    fi
  fi
  if ! sudo systemctl enable bluetooth --now; then
    log_error "Failed to enable bluetooth.service"
    exit 1
  fi
elif command_exists openrc; then
  v bash -c "echo 'modules=i2c-dev' | sudo tee -a /etc/conf.d/modules"
  v sudo rc-update add modules boot
  v sudo rc-update add ydotool default
  v sudo rc-update add bluetooth default
  x sudo rc-service ydotool start
  x sudo rc-service bluetooth start
else
  die "No supported init system found"
fi

if [[ "${OS_GROUP_ID:-unknown}" == "gentoo" ]]; then
  v sudo chown -R "$(whoami):$(whoami)" ~/.local/
fi

#####################################################################################
# MSI MUX Switcher — model-specific helper, opt-in hardware phase.
function setup_mux_switcher(){
  local mux_dir="${REPO_ROOT}/tools/mux-switcher"
  local mux_bin="${BIN_DIR}/msi-mux-switcher"
  local py_script="${mux_dir}/msi-mux-switcher.py"

  if [[ ! -f "$py_script" ]]; then
    log_warning "msi-mux-switcher helper missing at $py_script"
    return 0
  fi

  local product_name=""
  if [[ -r /sys/class/dmi/id/product_name ]]; then
    product_name="$(cat /sys/class/dmi/id/product_name)"
  fi

  if [[ "$product_name" =~ ^Sword[[:space:]]16[[:space:]]HX[[:space:]]B14VEKG ]]; then
    log_info "MSI Sword 16 HX B14VEKG detected; installing model-specific MUX helper"
    v mkdir -p "${BIN_DIR}"
    v ln -sf "${py_script}" "$mux_bin"
    v chmod +x "$mux_bin"
    log_success "MUX helper installed at $mux_bin"
  else
    log_info "Model-specific MUX helper not applicable; detected product: ${product_name:-unknown}"
  fi
}

showfun setup_mux_switcher
v setup_mux_switcher

#####################################################################################
# Smart Organizer
if [[ ! "${SKIP_SMART_ORGANIZER:-}" == true ]]; then
  function setup_smart_organizer(){
    local organizer_dir="${REPO_ROOT}/tools/smart-organizer"
    local organizer_bin="${BIN_DIR}/smart-organizer"

    if [[ ! -d "$organizer_dir" ]]; then
      log_warning "smart-organizer not found at $organizer_dir"
      return 0
    fi

    log_info "Setting up Smart Organizer"
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

    v mkdir -p "${CONFIG_DIR}/smart-organizer"
    if [[ ! -f "${CONFIG_DIR}/smart-organizer/smart-organizer.conf" ]]; then
      v cp "${organizer_dir}/smart-organizer.conf" "${CONFIG_DIR}/smart-organizer/smart-organizer.conf"
    fi

    v mkdir -p "${CONFIG_DIR}/systemd/user"
    v bash -c "cat > '${CONFIG_DIR}/systemd/user/smart-organizer.service' << EOFSERVICE
[Unit]
Description=Smart Organizer Watch Service
After=network.target

[Service]
Type=simple
ExecStart=${BIN_DIR}/smart-organizer --watch
Restart=on-failure
RestartSec=10

[Install]
WantedBy=default.target
EOFSERVICE"

    v bash -c "cat > '${CONFIG_DIR}/systemd/user/smart-organizer-timer.service' << EOFSERVICE
[Unit]
Description=Smart Organizer Oneshot
After=network.target

[Service]
Type=oneshot
ExecStart=${BIN_DIR}/smart-organizer --once
EOFSERVICE"

    v bash -c "cat > '${CONFIG_DIR}/systemd/user/smart-organizer.timer' << EOFSERVICE
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

    if [[ -f "${BIN_DIR}/backup.sh" ]]; then
      v bash -c "cat > '${CONFIG_DIR}/systemd/user/backup.service' << EOFSERVICE
[Unit]
Description=Backup Script Oneshot
After=network.target

[Service]
Type=oneshot
ExecStart=${BIN_DIR}/backup.sh
EOFSERVICE"
      v bash -c "cat > '${CONFIG_DIR}/systemd/user/backup.timer' << EOFSERVICE
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
    fi

    if [[ -f "${BIN_DIR}/maintenance.sh" ]]; then
      v bash -c "cat > '${CONFIG_DIR}/systemd/user/maintenance.service' << EOFSERVICE
[Unit]
Description=Maintenance Script Oneshot
After=network.target

[Service]
Type=oneshot
ExecStart=${BIN_DIR}/maintenance.sh --auto
EOFSERVICE"
      v bash -c "cat > '${CONFIG_DIR}/systemd/user/maintenance.timer' << EOFSERVICE
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
    fi

    # A fresh TTY/no-DE install does not have a user D-Bus manager yet.
    # Install units now; enable them when a real user session exists.
    if [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" && -n "${XDG_RUNTIME_DIR:-}" ]]; then
      x systemctl --user daemon-reload
      x systemctl --user enable smart-organizer.service --now
      x systemctl --user enable smart-organizer.timer --now
      [[ ! -f "${BIN_DIR}/backup.sh" ]] || x systemctl --user enable backup.timer --now
      [[ ! -f "${BIN_DIR}/maintenance.sh" ]] || x systemctl --user enable maintenance.timer --now
    else
      log_info "No user session; Smart Organizer, backup, and maintenance units are installed but not enabled yet."
    fi
  }

  showfun setup_smart_organizer
  v setup_smart_organizer
fi

#####################################################################################
# NVIDIA + MUX Setup for CachyOS — opt-in because it mutates boot/initramfs state.
function setup_nvidia_mux(){
  if [[ "${ENABLE_SHESH_HARDWARE_TUNING:-false}" != "true" ]]; then
    log_info "Shesh hardware tuning deferred. Set ENABLE_SHESH_HARDWARE_TUNING=true only after plain Hyprland is verified."
    return 0
  fi
  if [[ "${SKIP_NVIDIA_SETUP:-}" == "true" ]]; then
    log_info "SKIP_NVIDIA_SETUP=true — skipping NVIDIA/MUX setup"
    return 0
  fi
  if [[ "${OS_GROUP_ID:-unknown}" != "arch" && "${OS_GROUP_ID:-unknown}" != "cachyos" ]]; then
    log_warning "Not Arch/CachyOS; skipping NVIDIA setup"
    return 0
  fi
  if ! command_exists lspci; then die "lspci is required for hardware detection"; fi
  if ! lspci | grep -qi "nvidia"; then
    log_info "No NVIDIA GPU detected; skipping NVIDIA setup"
    return 0
  fi

  log_info "Installing NVIDIA + MUX support for the detected system"
  local kernel_headers_pkgs=()
  while IFS= read -r pkg; do
    [[ -n "$pkg" ]] && kernel_headers_pkgs+=("${pkg}-headers")
  done < <(pacman -Q 2>/dev/null | awk '/^linux-/{print $1}' | grep -vE '^(linux-firmware|linux-api-headers|linux-docs|linux-source|linux-tools|linux-headers)' | sed 's/-headers$//')

  v sudo pacman -S --noconfirm --needed nvidia-dkms "${kernel_headers_pkgs[@]}" nvidia-utils lib32-nvidia-utils nvidia-prime

  printf "  Configuring mkinitcpio for Intel + NVIDIA hybrid...\n"
  local needs_initramfs_rebuild=0
  local nvidia_modules="i915 nvidia nvidia_modeset nvidia_uvm nvidia_drm"

  patch_mkinitcpio_modules(){
    local file="$1"
    sudo python3 - "$file" "$nvidia_modules" <<'PYEOF'
import pathlib, re, sys
path = pathlib.Path(sys.argv[1])
mods = sys.argv[2].split()
text = path.read_text()
def rewrite(match):
    inner = match.group(1)
    for mod in mods:
        inner = re.sub(r'\b' + re.escape(mod) + r'\b', '', inner)
    inner = ' '.join(mods) + (' ' + inner.strip() if inner.strip() else '')
    return 'MODULES=(' + inner + ')'
new = re.sub(r'^MODULES=\(([^)]*)\)', rewrite, text, flags=re.MULTILINE)
if new != text:
    path.write_text(new)
PYEOF
  }

  if [[ -f /etc/mkinitcpio.conf ]]; then
    v patch_mkinitcpio_modules /etc/mkinitcpio.conf
    needs_initramfs_rebuild=1
  fi
  if [[ -d /etc/mkinitcpio.conf.d ]]; then
    for dropin in /etc/mkinitcpio.conf.d/*.conf; do
      [[ -f "$dropin" ]] || continue
      if grep -q '^MODULES=' "$dropin"; then
        v patch_mkinitcpio_modules "$dropin"
        needs_initramfs_rebuild=1
      fi
    done
  fi

  if (( needs_initramfs_rebuild )); then
    if ! grep -rq 'i915' /etc/mkinitcpio.conf /etc/mkinitcpio.conf.d/ 2>/dev/null; then
      die "i915 was not present after mkinitcpio patch; refusing to rebuild initramfs"
    fi
  fi

  printf "  Configuring NVIDIA kernel parameters...\n"
  local bootloader="$(detect_bootloader)"
  case "$bootloader" in
    systemd-boot)
      local entry_file found_entry=0
      while IFS= read -r entry_file; do
        [[ -n "$entry_file" ]] || continue
        found_entry=1
        if ! grep -q 'nvidia_drm.modeset=1' "$entry_file"; then
          sudo sed -i 's|^\(options .*\)|\1 nvidia_drm.modeset=1 nvidia.NVreg_PreserveVideoMemoryAllocations=1|' "$entry_file"
        fi
      done < <(find /boot/loader/entries -maxdepth 1 -name '*.conf' -print 2>/dev/null)
      (( found_entry )) || die 'systemd-boot selected but no loader entry was found'
      ;;
    limine)
      local limine_cfg=""
      if ! limine_cfg="$(detect_limine_config)"; then limine_cfg=""; fi
      [[ -n "$limine_cfg" ]] || die 'Limine selected but no supported configuration file was found'
      local nv_params='nvidia-drm.modeset=1 nvidia.NVreg_PreserveVideoMemoryAllocations=1'
      if grep -q 'nvidia_drm.modeset=1' "$limine_cfg"; then
        log_info "Limine NVIDIA parameters already present in $limine_cfg"
      elif grep -Eq '^KERNEL_CMDLINE\[default\]=' "$limine_cfg"; then
        sudo sed -i "s|^\(KERNEL_CMDLINE\[default\]=.*\)\"|\1 ${nv_params}\"|" "$limine_cfg"
      elif grep -Eq '^[[:space:]]*kernel_cmdline[[:space:]]*=' "$limine_cfg"; then
        sudo python3 - "$limine_cfg" "$nv_params" <<'PYEOF'
import pathlib, re, sys
p = pathlib.Path(sys.argv[1]); params = sys.argv[2]
text = p.read_text()
def add(match):
    line = match.group(0).rstrip()
    return (line[:-1] + ' ' + params + '"') if line.endswith('"') else (line + ' ' + params)
p.write_text(re.sub(r'^[^\S\n]*kernel_cmdline[^\S\n]*=.*', add, text, flags=re.MULTILINE))
PYEOF
      elif grep -Eq '^[[:space:]]+cmdline[[:space:]]*:' "$limine_cfg"; then
        sudo python3 - "$limine_cfg" "$nv_params" <<'PYEOF'
import pathlib, re, sys
p = pathlib.Path(sys.argv[1]); params = sys.argv[2]
text = p.read_text()
p.write_text(re.sub(r'^[^\S\n]+cmdline[^\S\n]*:.*', lambda m: m.group(0).rstrip() + ' ' + params, text, flags=re.MULTILINE))
PYEOF
      else
        die "Unsupported Limine cmdline format in $limine_cfg"
      fi
      grep -q 'nvidia_drm.modeset=1' "$limine_cfg" || die "Limine NVIDIA parameter patch could not be verified"
      ;;
    grub)
      [[ -f /etc/default/grub ]] || die 'GRUB detected but /etc/default/grub is missing'
      if ! grep -q 'nvidia_drm.modeset=1' /etc/default/grub; then
        if grep -Eq '^GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub; then
          sudo sed -i 's|^\(GRUB_CMDLINE_LINUX_DEFAULT=.*\)\"|\1 nvidia_drm.modeset=1 nvidia.NVreg_PreserveVideoMemoryAllocations=1\"|' /etc/default/grub
        elif grep -Eq '^GRUB_CMDLINE_LINUX=' /etc/default/grub; then
          sudo sed -i 's|^\(GRUB_CMDLINE_LINUX=.*\)\"|\1 nvidia_drm.modeset=1 nvidia.NVreg_PreserveVideoMemoryAllocations=1\"|' /etc/default/grub
        else
          die 'GRUB configuration has no supported kernel command-line variable'
        fi
      fi
      if [[ -d /boot/grub ]]; then
        v sudo grub-mkconfig -o /boot/grub/grub.cfg
      elif [[ -d /boot/efi/EFI/grub ]]; then
        v sudo grub-mkconfig -o /boot/efi/EFI/grub/grub.cfg
      else
        die 'GRUB detected but no grub.cfg output directory found'
      fi
      ;;
    *) die 'Unsupported or unknown bootloader; refusing NVIDIA bootloader mutation';;
  esac

  if (( needs_initramfs_rebuild )); then
    if command_exists limine-mkinitcpio; then
      v sudo limine-mkinitcpio
    else
      v sudo mkinitcpio -P
    fi
  fi

  local igpu_pci="" dgpu_pci="" line
  if line="$(lspci -D -d ::0300 | grep -i 'intel' | head -n1)"; then igpu_pci="${line%% *}"; fi
  if line="$(lspci -D -d ::0300 | grep -i 'nvidia' | head -n1)"; then dgpu_pci="${line%% *}"; fi

  if [[ -n "$igpu_pci" ]]; then
    sudo tee /etc/udev/rules.d/igpu-device-path.rules >/dev/null <<EOF
KERNEL=="card*", KERNELS=="$igpu_pci", SUBSYSTEM=="drm", SUBSYSTEMS=="pci", SYMLINK+="dri/igpu"
EOF
  fi
  if [[ -n "$dgpu_pci" ]]; then
    sudo tee /etc/udev/rules.d/dgpu-device-path.rules >/dev/null <<EOF
KERNEL=="card*", KERNELS=="$dgpu_pci", SUBSYSTEM=="drm", SUBSYSTEMS=="pci", SYMLINK+="dri/dgpu"
EOF
  fi
  sudo udevadm control --reload-rules
  sudo udevadm trigger

  sudo tee /usr/local/bin/nvidia-run >/dev/null <<'EOFSCRIPT'
#!/bin/bash
set -euo pipefail
export __NV_PRIME_RENDER_OFFLOAD=1
export __GLX_VENDOR_LIBRARY_NAME=nvidia
export __VK_LAYER_NV_optimus=NVIDIA_only
export GBM_BACKEND=nvidia-drm
export LIBVA_DRIVER_NAME=nvidia
export WLR_NO_HARDWARE_CURSORS=1
exec "$@"
EOFSCRIPT
  sudo chmod +x /usr/local/bin/nvidia-run
  log_success 'NVIDIA + MUX setup completed; reboot required before testing.'
}

showfun setup_nvidia_mux
v setup_nvidia_mux

#####################################################################################
# AI/ML Stack Setup
function setup_ai_stack() {
  [[ "${SKIP_AI_STACK:-}" == "true" ]] && {
    log_info 'SKIP_AI_STACK=true — skipping AI stack'
    return 0
  }
  [[ "${OS_GROUP_ID:-unknown}" == 'arch' || "${OS_GROUP_ID:-unknown}" == 'cachyos' ]] || {
    log_warning 'AI stack is supported only on Arch/CachyOS; skipping'
    return 0
  }

  if ! command_exists nvidia-smi; then
    log_warning 'NVIDIA driver is not currently available (nvidia-smi missing); skipping CUDA/Ollama/Newelle AI setup.'
    log_warning 'After hardware tuning is deliberately enabled and verified, rerun the setup for the AI phase.'
    return 0
  fi

  local cuda_ver
  cuda_ver=$(nvcc --version 2>/dev/null | grep -oP 'release \K[0-9]+' || printf '0')
  if (( cuda_ver < 12 )); then
    v sudo pacman -S --noconfirm --needed cuda cudnn
  fi
  if ! command_exists ollama; then v sudo pacman -S --noconfirm --needed ollama; fi
  v sudo systemctl enable --now ollama.service

  if ! command_exists newelle; then
    aur_install newelle
  fi

  local venv="${XDG_STATE_HOME:-$HOME/.local/state}/shesh/.venv"
  v uv venv "$venv"
  v uv pip install --python "$venv/bin/python" \
    'faster-whisper>=1.2.0' 'piper-tts' 'chromadb>=1.5.9' 'mcp[cli]>=1.0' \
    'fastmcp>=0.1' 'tomli-w>=1.0' 'pydantic>=2.0' 'httpx>=0.27'

  if command_exists cargo; then
    local watcher_dir="${REPO_ROOT}/tools/smart-organizer/watcher-rs"
    if [[ -d "$watcher_dir" ]]; then
      (cd "$watcher_dir" && cargo build --release)
      v install -Dm755 "${watcher_dir}/target/release/sm-watcher" "${BIN_DIR}/sm-watcher"
    fi
  else
    v uv pip install --python "$venv/bin/python" 'watchfiles>=0.24'
  fi

  log_info 'Pulling 6GB-VRAM-safe models'
  v ollama pull phi4-mini
  v ollama pull qwen2.5-coder:3b
  v ollama pull nomic-embed-text
  v ollama pull moondream2
  log_success 'AI stack installed'
}
showfun setup_ai_stack
v setup_ai_stack

#####################################################################################
# Power Management Setup
function setup_power_management(){
  [[ "${SKIP_POWER_SETUP:-}" == "true" ]] && {
    log_info 'SKIP_POWER_SETUP=true — skipping power management'
    return 0
  }
  [[ "${OS_GROUP_ID:-unknown}" == 'arch' || "${OS_GROUP_ID:-unknown}" == 'cachyos' ]] || {
    log_warning 'Power management is supported only on Arch/CachyOS; skipping'
    return 0
  }

  v sudo pacman -S --noconfirm --needed power-profiles-daemon
  v sudo systemctl enable --now power-profiles-daemon.service
  if systemctl list-unit-files sddm.service >/dev/null 2>&1; then
    if ! sudo systemctl enable --now sddm; then
      log_error 'sddm.service is installed but could not be enabled'
      return 1
    fi
  fi
  if ! powerprofilesctl set balanced; then
    log_error 'Unable to select balanced power profile'
    return 1
  fi

  local mem_kb mem_gb zram_gb
  mem_kb=$(awk '/MemTotal/{print $2}' /proc/meminfo)
  mem_gb=$(( mem_kb / 1024 / 1024 ))
  zram_gb=$(( mem_gb / 2 ))
  (( zram_gb > 16 )) && zram_gb=16
  (( zram_gb < 1 )) && zram_gb=1

  sudo install -Dm644 /dev/stdin /etc/systemd/zram-generator.conf <<EOFZRAM
# managed-by=shesh-desktop
[zram0]
zram-size = ${zram_gb} GiB
compression-algorithm = zstd
EOFZRAM
  v sudo systemctl daemon-reload
  if ! sudo systemctl enable --now systemd-zram-setup@zram0.service; then
    log_error 'Failed to enable systemd-zram-setup@zram0.service'
    return 1
  fi
  log_success "Power management configured with ${zram_gb}GiB zram"
}
showfun setup_power_management
v setup_power_management
