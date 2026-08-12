#!/usr/bin/env bash
#
# shesh-desktop Maintenance Script
# Daily/weekly system maintenance automation
#
# Features:
#   - System update
#   - Package cache cleanup
#   - Orphan removal
#   - Journal cleanup
#   - Disk space report
#   - SMART health check
#   - Service health check
#
# Usage:
#   maintenance.sh [OPTIONS]
#
# Options:
#   --dry-run    Show what would be done
#   --auto       Run without prompts
#   --help       Show help
#

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

DRY_RUN=false
AUTO_MODE=false

log_info() { echo -e "${BLUE}[MAINT]${NC} $*"; }
log_ok() { echo -e "${GREEN}[OK]${NC}   $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

usage() {
    cat <<'EOF'
maintenance.sh - System maintenance automation

USAGE:
    maintenance.sh [OPTIONS]

OPTIONS:
    --dry-run    Show what would be done without making changes
    --auto       Run without prompts
    --help       Show this help
EOF
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --auto)
            AUTO_MODE=true
            shift
            ;;
        --help | -h)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

if [[ $EUID -eq 0 ]]; then
    log_error "Do not run as root. Run as normal user with sudo available."
    exit 1
fi

if ! command -v sudo >/dev/null 2>&1; then
    log_error "sudo is required but not found."
    exit 1
fi

echo ""
log_info "========================================"
log_info " System Maintenance"
log_info "========================================"
echo ""

if ! $DRY_RUN && ! $AUTO_MODE; then
    # Interactive by default: system changes require consent.
    printf 'Proceed with system maintenance (update, cache clean, orphans, journal)? [y/N] '
    read -r answer
    case "${answer,,}" in
        y | yes) ;;
        *)
            log_info "Aborted by user. Use --auto for non-interactive/cron runs."
            exit 0
            ;;
    esac
fi

# 1. System update
log_info "1. Checking for system updates..."
if command -v pacman >/dev/null 2>&1; then
    if $DRY_RUN; then
        log_info "[DRY-RUN] Would run: sudo pacman -Syu"
    else
        sudo pacman -Syu --noconfirm
    fi
    log_ok "System updated"
else
    log_warn "Not an Arch-based system, skipping system update"
fi

# 2. Clean package cache
log_info "2. Cleaning package cache..."
if command -v pacman >/dev/null 2>&1; then
    if $DRY_RUN; then
        log_info "[DRY-RUN] Would run: sudo pacman -Sc --noconfirm"
    else
        sudo pacman -Sc --noconfirm || log_warn "pacman cache clean failed (db locked or nothing to clean); continuing"
    fi
    log_ok "Package cache cleaned"
fi

if command -v yay >/dev/null 2>&1; then
    if $DRY_RUN; then
        log_info "[DRY-RUN] Would run: yay -Sc --noconfirm"
    else
        yay -Sc --noconfirm || log_warn "yay cache clean failed; continuing"
    fi
    log_ok "AUR cache cleaned"
fi

# 3. Remove orphans
log_info "3. Removing orphan packages..."
if command -v pacman >/dev/null 2>&1; then
    # pacman -Qtdq exits 1 when there are NO orphans — that is a normal
    # state, captured explicitly instead of being blanket-swallowed.
    if ! orphans=$(pacman -Qtdq 2>/dev/null); then
        orphans=""
    fi
    if [[ -n "$orphans" ]]; then
        if $DRY_RUN; then
            log_info "[DRY-RUN] Would remove orphans: $(echo "$orphans" | wc -l) packages"
        else
            echo "$orphans" | sudo pacman -Rns --noconfirm - || log_warn "orphan removal failed mid-transaction; rerun to finish"
        fi
        log_ok "Orphans removed"
    else
        log_info "No orphans found"
    fi
fi

# 4. Clean journal
log_info "4. Cleaning system journal..."
if command -v journalctl >/dev/null 2>&1; then
    if $DRY_RUN; then
        log_info "[DRY-RUN] Would run: sudo journalctl --vacuum-time=7d"
    else
        sudo journalctl --vacuum-time=7d || log_warn "journal vacuum failed (permissions or journal in use); continuing"
    fi
    log_ok "Journal cleaned"
fi

# 5. Disk space report
log_info "5. Disk space report:"
df -h /home | awk 'NR==1 {print} NR==2 {print "  Home: "$4" available"}'

# 6. SMART health check
log_info "6. Checking disk health..."
if command -v smartctl >/dev/null 2>&1; then
    disk=$(df /home | awk 'NR==2 {print $1}' | sed 's/[0-9]//g')
    if [[ -n "$disk" ]]; then
        sudo smartctl -H "$disk" 2>/dev/null | grep -E "PASSED|FAILED|SMART" || log_warn "SMART check not available"
    fi
else
    log_warn "smartctl not installed, skipping disk health check"
fi

# 7. Service health check
log_info "7. Checking critical services..."
services=(bluetooth NetworkManager systemd-timesyncd)
for svc in "${services[@]}"; do
    if systemctl is-active --quiet "$svc" 2>/dev/null; then
        log_ok "$svc is running"
    else
        log_warn "$svc is not running"
    fi
done

# 8. Memory usage
log_info "8. Memory usage:"
free -h | awk 'NR==1 {print} NR==2 {print "  RAM: "$3" / "$2" used"}'

# 9. Temperature (if available)
log_info "9. Temperature:"
if command -v sensors >/dev/null 2>&1; then
    sensors 2>/dev/null | grep -E "Core|Package|temp1" | head -5 || log_warn "Temperature sensors not available"
else
    log_warn "lm_sensors not installed"
fi

echo ""
log_ok "Maintenance completed"
log_info "Run with --auto for non-interactive mode"
echo ""
