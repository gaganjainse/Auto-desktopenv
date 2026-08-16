#!/usr/bin/env bash
# apply-profile.sh — apply a shesh-desktop device profile (idempotent).
#
# Applies the parts of profiles/<device>/ that the end-4 installer does NOT
# already do. mkinitcpio (hybrid GPU modules) and zram/power-profiles are
# handled by `setup install` itself (setup_nvidia_mux / setup_power_management),
# so they are intentionally NOT re-applied here — one source of truth each.
#
# This script applies:
#   sysctl-99-shesh.conf        -> /etc/sysctl.d/99-shesh.conf        + sysctl load
#   udev-60-ioschedulers.rules  -> /etc/udev/rules.d/60-ioschedulers.rules + udev reload
#   hypr-custom-general.lua     -> ~/.config/hypr/custom/general.lua (append, idempotent)
#
# Usage:
#   bash tools/apply-profile.sh [--device shesh|generic|auto] [--dry-run]
set -euo pipefail

GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
ok()  { echo -e "${GREEN}[OK]${NC}   $*"; }
info(){ echo -e "${BLUE}[..]${NC}   $*"; }
warn(){ echo -e "${YELLOW}[!!]${NC}   $*"; }
die() { echo -e "${RED}[FATAL]${NC} $*" >&2; exit 1; }

DEVICE="auto"; DRY=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --device) DEVICE="$2"; shift 2;;
    --dry-run) DRY=1; shift;;
    -h|--help) sed -n '2,18p' "$0"; exit 0;;
    *) shift;;
  esac
done

if [[ "$DEVICE" == "auto" ]]; then
  if grep -qi "Sword 16 HX\|B14VEKG" /sys/class/dmi/id/product_name 2>/dev/null; then
    DEVICE="shesh"
  else
    DEVICE="generic"
  fi
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE_DIR="$SCRIPT_DIR/profiles/$DEVICE"

run() { if [[ $DRY -eq 1 ]]; then info "[dry-run] $*"; else "$@"; fi; }

[[ $EUID -eq 0 ]] && die "run as your normal user (sudo used where needed)"
[[ -d "$PROFILE_DIR" ]] || { warn "no profile at $PROFILE_DIR — nothing to apply"; exit 0; }

info "== Applying device profile: $DEVICE =="

# 1. sysctl
if [[ -f "$PROFILE_DIR/sysctl-99-shesh.conf" ]]; then
  info "sysctl tuning -> /etc/sysctl.d/99-shesh.conf"
  if [[ $DRY -eq 0 ]]; then
    sudo install -Dm644 "$PROFILE_DIR/sysctl-99-shesh.conf" /etc/sysctl.d/99-shesh.conf
    sudo sysctl --system >/dev/null 2>&1 || warn "sysctl --system returned nonzero (a key may be unloadable) — file is still in place"
    ok "sysctl applied (swappiness, dirty ratio, cake/BBR, inotify)"
  fi
fi

# 2. udev (NVMe kyber scheduler)
if [[ -f "$PROFILE_DIR/udev-60-ioschedulers.rules" ]]; then
  info "udev rule -> /etc/udev/rules.d/60-ioschedulers.rules"
  if [[ $DRY -eq 0 ]]; then
    sudo install -Dm644 "$PROFILE_DIR/udev-60-ioschedulers.rules" /etc/udev/rules.d/60-ioschedulers.rules
    sudo udevadm control --reload 2>/dev/null || warn "udevadm reload returned nonzero"
    ok "udev rule applied (NVMe kyber)"
  fi
fi

# 3. Hyprland custom lua (monitor 144Hz + visuals) — append idempotently
if [[ -f "$PROFILE_DIR/hypr-custom-general.lua" ]]; then
  target="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/custom/general.lua"
  info "Hyprland overrides -> $target"
  if [[ $DRY -eq 0 ]]; then
    mkdir -p "$(dirname "$target")"
    if grep -q "managed-by=shesh-desktop-profile" "$target" 2>/dev/null; then
      info "general.lua already has the shesh profile block — skipping"
    else
      {
        echo ""
        echo "-- managed-by=shesh-desktop-profile (device: $DEVICE) — regenerate with tools/apply-profile.sh"
        cat "$PROFILE_DIR/hypr-custom-general.lua"
      } >> "$target"
      ok "Hyprland 144Hz + visuals block appended"
    fi
  fi
fi

info "== Profile applied. mkinitcpio (hybrid GPU) + zram are handled by 'setup install'. =="
ok "Done — device: $DEVICE"
