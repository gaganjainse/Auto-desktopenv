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

# Detect an AUR helper. CachyOS 260628 ships Shelly; paru is preferred for
# scripting (stable pacman-compatible flags) and is installed if missing.
# Caches result in AUR_HELPER; never expands empty into a command call.
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
    v sudo pacman -S --noconfirm --needed paru && AUR_HELPER=paru
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

function prepare_systemd_user_service(){
  if [[ ! -e "/usr/lib/systemd/user/ydotool.service" ]]; then
    x sudo ln -s /usr/lib/systemd/{system,user}/ydotool.service
  fi
}


#####################################################################################
# These python packages are installed using uv into the venv (virtual environment). Once the folder of the venv gets deleted, they are all gone cleanly. So it's considered as setups, not dependencies.
showfun install-python-packages
v install-python-packages

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
function setup_mux_switcher(){
  local mux_dir="${REPO_ROOT}/tools/mux-switcher"
  local mux_bin="${BIN_DIR}/msi-mux-switcher"
  local py_script="${mux_dir}/msi-mux-switcher.py"

  if [[ ! -f "$py_script" ]]; then
    printf "${STY_YELLOW}[$0]: msi-mux-switcher Python tool not found at $py_script${STY_RST}\n"
    return 0
  fi

  if grep -qi "MSI" /sys/class/dmi/id/sys_vendor 2>/dev/null || \
     grep -qi "MSI" /sys/class/dmi/id/product_name 2>/dev/null; then
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

showfun setup_mux_switcher
v setup_mux_switcher



#####################################################################################
# Smart Organizer
if [[ ! "${SKIP_SMART_ORGANIZER:-}" == true ]]; then
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

  # Install systemd user timer for periodic runs
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

   v systemctl --user daemon-reload
  v systemctl --user enable --now smart-organizer.service || true
  v systemctl --user enable --now smart-organizer.timer || true

  # Install backup timer
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

  v systemctl --user enable --now backup.timer || true
  fi

  # Install maintenance timer
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

showfun setup_smart_organizer
  v setup_smart_organizer
fi



#####################################################################################
# NVIDIA + MUX Setup for CachyOS
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
  done < <(pacman -Q 2>/dev/null | awk '/^linux-/{print $1}' | grep -vE '^(linux-firmware|linux-api-headers|linux-docs|linux-source|linux-tools|linux-headers)' | sed 's/-headers$//' || true)

  v sudo pacman -S --noconfirm --needed \
    nvidia-dkms "${kernel_headers_pkgs[@]}" nvidia-utils lib32-nvidia-utils \
    nvidia-prime

  # Configure mkinitcpio for hybrid graphics
  printf "  Configuring mkinitcpio for Intel + NVIDIA hybrid...\n"
  NEEDS_INITRAMFS_REBUILD=0
  if [[ -f /etc/mkinitcpio.conf ]]; then
    v sudo sed -i -E 's/\b(i915|nvidia|nvidia_modeset|nvidia_uvm|nvidia_drm)\b//g; s/^MODULES=\(/MODULES=(i915 nvidia nvidia_modeset nvidia_uvm nvidia_drm /' /etc/mkinitcpio.conf
    NEEDS_INITRAMFS_REBUILD=1
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
      ;;
    *)
      printf "  WARNING: unknown bootloader, skipping boot parameter configuration\n"
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
  printf "  Run: sudo msi-mux-switcher status\n"
}

showfun setup_nvidia_mux
v setup_nvidia_mux



#####################################################################################
# AI/ML Stack Setup
function setup_ai_stack() {
  [[ "${OS_GROUP_ID}" != "arch" ]] && {
    log_warning "AI stack setup is CachyOS/Arch only — skipping"
    return 0
  }

  command_exists nvidia-smi || {
    log_warning "No NVIDIA GPU detected — skipping AI stack"
    return 0
  }

  # ── 1. Check CUDA version (faster-whisper requires CUDA 12+) ──────────────
  local cuda_ver
  cuda_ver=$(nvcc --version 2>/dev/null | grep -oP 'release \K[0-9]+' || echo "0")
  if (( cuda_ver < 12 )); then
    log_warning "CUDA < 12 detected. Installing cuda + cudnn..."
    v sudo pacman -S --noconfirm --needed cuda cudnn
  fi

  # ── 2. Install Ollama (target: v0.32.6+) ──────────────────────────────────
  if ! command_exists ollama; then
    v sudo pacman -S --noconfirm --needed ollama
  fi

  local ollama_ver ollama_maj ollama_min
  ollama_ver=$(ollama --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -n1 || echo "0.0")
  IFS=. read -r ollama_maj ollama_min <<<"$ollama_ver"
  if (( ollama_maj < 0 || (ollama_maj == 0 && ollama_min < 32) )); then
    log_warning "Ollama < 0.32 detected (have $ollama_ver) — agent mode not available"
    log_warning "Update via: sudo pacman -Syu ollama"
  fi
  v sudo systemctl enable --now ollama.service

  # ── 3. Install Newelle 1.4.5 (native, NOT Flatpak) ────────────────────────
  # Flatpak Newelle is sandbox-limited; native install is required for:
  # - MCP server connections to localhost
  # - Wake word access to microphone
  # - File permission system access outside ~/.var/
  if ! command_exists newelle; then
    aur_install newelle
  else
    log_info "Newelle already installed — verify it is >=1.4.5"
    log_info "Check: newelle --version"
  fi

  # ── 4. Python venv for MCP servers + STT + TTS ────────────────────────────
  local venv="${XDG_STATE_HOME:-$HOME/.local/state}/shesh/.venv"
  v uv venv "$venv"

  # Install all pinned dependencies
  v uv pip install --python "$venv/bin/python" \
    "faster-whisper>=1.2.0"  \
    "piper-tts"              \
    "chromadb>=1.5.9"        \
    "mcp[cli]>=1.0"          \
    "fastmcp>=0.1"           \
    "tomli-w>=1.0"           \
    "pydantic>=2.0"          \
    "httpx>=0.27"

  # ── 5. Build Rust sm-watcher binary ───────────────────────────────────────
  if command_exists cargo; then
    local watcher_dir="${REPO_ROOT}/tools/smart-organizer/watcher-rs"
    if [[ -d "$watcher_dir" ]]; then
      log_info "Building Rust smart-organizer watcher..."
      (cd "$watcher_dir" && cargo build --release) && \
        v install -Dm755 "${watcher_dir}/target/release/sm-watcher" "${BIN_DIR}/sm-watcher"
      log_success "sm-watcher binary installed to ${BIN_DIR}/sm-watcher"
    fi
  else
    log_warning "cargo not found — sm-watcher will use Python watchfiles fallback"
    v uv pip install --python "$venv/bin/python" "watchfiles>=0.24"
  fi

  # ── 6. Pull ONLY 6GB VRAM-safe Ollama models ─────────────────────────────
  log_header "Pulling Ollama models (RTX 4050, 6GB VRAM)"
  log_info "Primary brain:    phi4-mini    (~3.2GB Q4)"
  log_info "Code assistant:   qwen2.5-coder:3b (~2.8GB Q4)"
  log_info "Embeddings/RAG:   nomic-embed-text (<0.5GB)"
  log_info "Vision/screenshots: moondream2  (~2.5GB)"
  log_warning "NOT pulling: qwen3:14b, llava:13b, mistral:7b — overflow 6GB VRAM"

  v ollama pull phi4-mini
  v ollama pull qwen2.5-coder:3b
  v ollama pull nomic-embed-text
  v ollama pull moondream2

  # ── 7 & 8. Install MCP servers that ACTUALLY EXIST (no dead units) ────────
  local mcp_dir="${REPO_ROOT}/tools/shesh/mcp_servers"
  local unit_dest="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
  local mcp_server installed=()
  shopt -s nullglob
  for mcp_file in "${mcp_dir}"/*.py; do
    mcp_server="$(basename "${mcp_file}" .py)"
    v install -Dm755 "${mcp_file}" "${BIN_DIR}/shesh-${mcp_server//_/-}-mcp"
    cat > "${unit_dest}/shesh-${mcp_server//_/-}-mcp.service" << EOF
[Unit]
Description=Shesh MCP Server: ${mcp_server}
After=graphical-session.target

[Service]
Type=simple
ExecStart=${venv}/bin/python ${BIN_DIR}/shesh-${mcp_server//_/-}-mcp
Restart=on-failure
RestartSec=5s
TimeoutStartSec=15
TimeoutStopSec=10

[Install]
WantedBy=graphical-session.target
EOF
    installed+=("${mcp_server}")
  done
  shopt -u nullglob
  if (( ${#installed[@]} == 0 )); then
    log_warning "No MCP servers found in ${mcp_dir}"
  fi

  v systemctl --user daemon-reload
  for mcp_server in "${installed[@]}"; do
    v systemctl --user enable --now "shesh-${mcp_server//_/-}-mcp.service"
  done
  log_success "AI stack (Newelle 1.4.5 + Ollama v0.32.6+ + MCP servers: ${installed[*]}) installed"
  log_info   "Launch Newelle → Settings → Models → Add Ollama → phi4-mini"
  log_info   "Settings → MCP → Add server → path: shesh-system-control-mcp"
}

showfun setup_ai_stack
v setup_ai_stack



#####################################################################################
# Power Management Setup
function setup_power_management(){
  if [[ "${OS_GROUP_ID:-unknown}" != "arch" ]]; then
    printf "${STY_YELLOW}[$0]: Not Arch/CachyOS, skipping power management${STY_RST}\n"
    return 0
  fi
  printf "${STY_CYAN}[$0]: Setting up power management${STY_RST}\n"

  v sudo pacman -S --noconfirm --needed power-profiles-daemon
  v sudo systemctl enable --now power-profiles-daemon.service
  v powerprofilesctl set balanced || true

  # ZRAM: size = half of RAM, zstd, capped at 16G. Idempotent.
  local mem_kb mem_gb zram_gb
  mem_kb=$(awk '/MemTotal/{print $2}' /proc/meminfo)
  mem_gb=$(( mem_kb / 1024 / 1024 ))
  zram_gb=$(( mem_gb / 2 )); (( zram_gb > 16 )) && zram_gb=16
  printf "  Detected %sGB RAM — configuring %sGB zram0 (zstd)\n" "$mem_gb" "$zram_gb"
  v sudo install -Dm644 /dev/stdin /etc/systemd/zram-generator.conf << EOFZRAM
# managed-by=auto-desktopenv
[zram0]
zram-size = ${zram_gb} GiB
compression-algorithm = zstd
EOFZRAM
  v sudo systemctl daemon-reload
  v sudo systemctl enable --now systemd-zram-setup@zram0.service || true

  printf "${STY_GREEN}[$0]: Power management configured${STY_RST}\n"
}

showfun setup_power_management
v setup_power_management
