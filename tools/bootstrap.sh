#!/usr/bin/env bash
#
# shesh-desktop Bootstrap — generic, idempotent, with skip flags
# One-command installer for CachyOS/Arch + Hyprland (illogical-impulse look + CachyOS performance)
# Usage:
#   bash <(curl -s https://raw.githubusercontent.com/gaganjainse/shesh-desktop/main/tools/bootstrap.sh)
#   bash <(curl -s ...) -- --skip-ai --skip-nvidia --dry-run --device msi-sword-cachyos
#
# Flags:
#   --skip-ai       Skip AI stack (Ollama, models, Newelle)
#   --skip-nvidia   Skip NVIDIA/MUX setup
#   --skip-zram     Skip ZRAM config
#   --skip-power    Skip power management
#   --dry-run       Don't execute, only print what would be done
#   --device NAME   Device profile (e.g., msi-sword-cachyos, generic)
#   --help          Show help

set -euo pipefail

# Source common lib if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/lib/common.sh" ]]; then
    source "$SCRIPT_DIR/lib/common.sh"
else
    # Fallback colors/logging if common.sh not found
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
    log_info() { echo -e "${BLUE}[BOOT]${NC} $*"; }
    log_ok() { echo -e "${GREEN}[OK]${NC}   $*"; }
    log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
    log_error() { echo -e "${RED}[ERROR]${NC} $*"; }
fi

# Defaults
SKIP_AI=0
SKIP_NVIDIA=0
SKIP_ZRAM=0
SKIP_POWER=0
DRY_RUN=0
DEVICE="auto"

usage() {
    cat <<USAGE
shesh-desktop Bootstrap — generic installer

Usage:
  $0 [options]

Options:
  --skip-ai       Skip AI stack (Ollama, Newelle, models)
  --skip-nvidia   Skip NVIDIA/MUX setup
  --skip-zram     Skip ZRAM config
  --skip-power    Skip power management
  --dry-run       Don't execute, only print what would be done
  --device NAME   Device profile (auto, msi-sword-cachyos, generic)
  --help          Show this help

Examples:
  $0 --skip-ai --dry-run
  $0 --device msi-sword-cachyos --skip-nvidia
  bash <(curl -s https://raw.githubusercontent.com/gaganjainse/shesh-desktop/main/tools/bootstrap.sh) -- --skip-ai

Device profiles:
  - msi-sword-cachyos: MSI Sword 16 HX B14VEKG-210IN — 1920x1200@144, RTX 4050 6GB, 16GB DDR5
  - generic: Generic Arch/CachyOS — no device-specific tweaks

Idempotent: safe to re-run, skips already done steps.
USAGE
}

# Parse args
while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip-ai)
            SKIP_AI=1
            shift
            ;;
        --skip-nvidia)
            SKIP_NVIDIA=1
            shift
            ;;
        --skip-zram)
            SKIP_ZRAM=1
            shift
            ;;
        --skip-power)
            SKIP_POWER=1
            shift
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        --device)
            DEVICE="$2"
            shift 2
            ;;
        --help | -h)
            usage
            exit 0
            ;;
        *)
            log_warn "Unknown arg $1 — ignoring"
            shift
            ;;
    esac
done

# Auto-detect device if auto
if [[ "$DEVICE" == "auto" ]]; then
    if grep -qi "Sword 16 HX" /sys/class/dmi/id/product_name 2>/dev/null || grep -qi "B14VEKG" /sys/class/dmi/id/product_name 2>/dev/null; then
        DEVICE="msi-sword-cachyos"
    else
        DEVICE="generic"
    fi
fi

preflight() {
    echo ""
    log_info "========================================"
    log_info " shesh-desktop Bootstrap"
    log_info " Device: $DEVICE"
    log_info " Flags: skip-ai=$SKIP_AI skip-nvidia=$SKIP_NVIDIA skip-zram=$SKIP_ZRAM skip-power=$SKIP_POWER dry-run=$DRY_RUN"
    log_info "========================================"
    echo ""

    if [[ $EUID -eq 0 ]]; then
        log_error "Do NOT run this as root. Run as normal user with sudo available."
        exit 1
    fi

    if ! command -v sudo >/dev/null 2>&1; then
        log_error "sudo is required but not found."
        exit 1
    fi

    if ! ping -c 1 archlinux.org >/dev/null 2>&1; then
        log_error "No network connectivity."
        exit 1
    fi
    log_ok "Network reachable"
    log_info "OS: $(grep -oP '^NAME=\K.*' /etc/os-release 2>/dev/null | tr -d '\"' || echo Unknown)"
    log_info "Target user: $(whoami)"
    log_info "Device profile: $DEVICE — 1920x1200@144 RTX 4050 6GB 16GB DDR5 (if msi-sword-cachyos)"
}

install_prerequisites() {
    log_info "=== Installing Prerequisites ==="
    if [[ "$DRY_RUN" == "1" ]]; then
        log_info "[dry-run] Would update system and install prerequisites"
        return 0
    fi
    sudo pacman -Syu --noconfirm
    sudo pacman -S --noconfirm --needed git curl wget base-devel
    log_ok "Prerequisites installed"
}

clone_repo() {
    log_info "=== Cloning Repository ==="
    local repo_url="https://github.com/gaganjainse/shesh-desktop.git"
    local install_dir="${HOME}/Workspace/shesh-desktop"
    mkdir -p "${HOME}/Workspace"
    if [[ -d "${install_dir}/.git" ]]; then
        log_info "Repository exists, pulling latest..."
        if ! git -C "${install_dir}" pull --ff-only; then
            log_warn "pull failed — continuing with existing checkout"
        else
            git -C "${install_dir}" submodule update --init --recursive
            log_warn "git pull --ff-only failed for ${install_dir} (local changes or offline?) — continuing with the existing checkout"
        fi
    else
        log_info "Cloning repository (with submodules)..."
        git clone --recurse-submodules "${repo_url}" "${install_dir}"
    fi
    log_ok "Repository ready at ${install_dir}"
}

run_installer() {
    log_info "=== Running Main Installer ==="
    local install_dir="${HOME}/Workspace/shesh-desktop"
    if [[ ! -f "${install_dir}/setup" ]]; then
        log_error "Installer not found at ${install_dir}/setup"
        exit 1
    fi
    cd "${install_dir}"
    local args=("install" "--device" "$DEVICE")
    [[ "$SKIP_AI" == "1" ]] && args+=("--skip-ai")
    [[ "$SKIP_NVIDIA" == "1" ]] && args+=("--skip-nvidia")
    [[ "$SKIP_ZRAM" == "1" ]] && args+=("--skip-zram")
    [[ "$SKIP_POWER" == "1" ]] && args+=("--skip-power")
    [[ "$DRY_RUN" == "1" ]] && args+=("--dry-run")
    log_info "Running: ./setup ${args[*]}"
    if [[ "$DRY_RUN" == "1" ]]; then
        echo "[dry-run] Would run: ./setup ${args[*]}"
    else
        ./setup "${args[@]}"
    fi
}

main() {
    preflight
    install_prerequisites
    clone_repo
    run_installer
    echo ""
    log_ok "========================================"
    log_ok " Bootstrap Complete — Device: $DEVICE"
    log_ok "========================================"
    log_info "Reboot and select Hyprland at login."
    log_info "After reboot:"
    log_info "  - Test MUX: sudo msi-mux-switcher status"
    log_info "  - Test GPU: prime-run glxinfo | grep NVIDIA || nvidia-run glxinfo"
    log_info "  - Test AI: ollama run qwen2.5:3b (if not --skip-ai)"
    log_info "  - Test organizer: smart-organizer --dry-run"
    echo ""
}

main "$@"
