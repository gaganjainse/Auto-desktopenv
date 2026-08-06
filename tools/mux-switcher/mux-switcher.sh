#!/usr/bin/env bash
#
# mux-switcher - MSI Laptop GPU MUX Switch Control
# For: MSI Sword 16 HX B14VEKG and similar MSI laptops
#
# This script switches between hybrid and dGPU-only modes on MSI laptops
# with hardware MUX switch support.
#
# Usage:
#   sudo mux-switcher.sh [OPTIONS]
#
# Options:
#   status              Show current MUX mode
#   hybrid              Switch to hybrid mode (iGPU + dGPU)
#  dgpu                 Switch to dGPU-only mode
#   restart             Restart display manager
#   --help              Show this help
#
# Note: Requires root privileges and MSI laptop with MUX switch.
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[MUX]${NC} $*"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}   $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# =============================================================================
# Detection
# =============================================================================

is_msi_laptop() {
    [[ -f /sys/class/dmi/id/product_name ]] && \
    grep -qi "MSI" /sys/class/dmi/id/sys_vendor 2>/dev/null
}

get_mux_status() {
    if command -v msi-gpu-switcher >/dev/null 2>&1; then
        msi-gpu-switcher status 2>/dev/null || echo "unknown"
    elif [[ -f /sys/kernel/debug/vgaswitcheroo/switch ]]; then
        cat /sys/kernel/debug/vgaswitcheroo/switch 2>/dev/null || echo "unknown"
    else
        echo "unknown"
    fi
}

# =============================================================================
# Mode switching
# =============================================================================

switch_to_hybrid() {
    log_info "Switching to hybrid mode..."

    if command -v msi-gpu-switcher >/dev/null 2>&1; then
        msi-gpu-switcher hybrid 2>/dev/null || true
    else
        log_warn "msi-gpu-switcher not found. Trying direct ACPI..."
        # Direct ACPI call for MSI laptops
        echo 1 > /sys/kernel/debug/vgaswitcheroo/switch 2>/dev/null || \
        log_error "Failed to switch to hybrid mode"
    fi

    log_ok "Switched to hybrid mode. Restart display manager to apply."
}

switch_to_dgpu() {
    log_info "Switching to dGPU-only mode..."

    if command -v msi-gpu-switcher >/dev/null 2>&1; then
        msi-gpu-switcher dgpu 2>/dev/null || true
    else
        log_warn "msi-gpu-switcher not found. Trying direct ACPI..."
        echo 2 > /sys/kernel/debug/vgaswitcheroo/switch 2>/dev/null || \
        log_error "Failed to switch to dGPU mode"
    fi

    log_ok "Switched to dGPU-only mode. Restart display manager to apply."
}

restart_display_manager() {
    log_info "Restarting display manager..."

    if systemctl is-active --quiet gdm; then
        sudo systemctl restart gdm
    elif systemctl is-active --quiet sddm; then
        sudo systemctl restart sddm
    elif systemctl is-active --quiet lightdm; then
        sudo systemctl restart lightdm
    elif systemctl is-active --quiet ly; then
        sudo systemctl restart ly
    else
        log_warn "No known display manager found. Please restart manually."
    fi
}

# =============================================================================
# Main
# =============================================================================

show_help() {
    cat << 'EOF'
mux-switcher - MSI Laptop GPU MUX Switch Control

USAGE:
    sudo mux-switcher.sh [OPTIONS]

OPTIONS:
    status              Show current MUX mode
    hybrid              Switch to hybrid mode (iGPU + dGPU)
    dgpu                Switch to dGPU-only mode
    restart             Restart display manager
    --help              Show this help

EXAMPLES:
    sudo mux-switcher.sh status
    sudo mux-switcher.sh hybrid
    sudo mux-switcher.sh dgpu
    sudo mux-switcher.sh restart
EOF
}

main() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)."
        exit 1
    fi

    case "${1:-}" in
        status)
            echo "Current MUX status:"
            get_mux_status
            ;;
        hybrid)
            switch_to_hybrid
            ;;
        dgpu)
            switch_to_dgpu
            ;;
        restart)
            restart_display_manager
            ;;
        --help|-h|help)
            show_help
            ;;
        *)
            log_error "Unknown option: ${1:-}"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
