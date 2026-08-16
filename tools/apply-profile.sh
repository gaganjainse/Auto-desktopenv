#!/usr/bin/env bash
# apply-profile.sh — apply a shesh-desktop device profile (idempotent).
set -euo pipefail

GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
ok(){ echo -e "${GREEN}[OK]${NC} $*"; }
info(){ echo -e "${BLUE}[..]${NC} $*"; }
warn(){ echo -e "${YELLOW}[!!]${NC} $*"; }
die(){ echo -e "${RED}[FATAL]${NC} $*" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/profile-detect.sh"

DEVICE='auto'
DRY=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --device) [[ $# -ge 2 ]] || die '--device requires a value'; DEVICE="$2"; shift 2;;
    --dry-run) DRY=1; shift;;
    -h|--help) sed -n '1,18p' "$0"; exit 0;;
    *) die "unknown argument: $1";;
  esac
done

if [[ "$DEVICE" == 'auto' ]]; then DEVICE="$(detect_profile)"; fi
profile_exists "$DEVICE" || die "profile '$DEVICE' does not exist"

# The shesh profile contains machine-specific GPU/display assumptions and must
# never be manually forced onto another laptop.
if [[ "$DEVICE" == 'shesh' ]]; then
  product_name=''
  if [[ -r /sys/class/dmi/id/product_name ]]; then product_name="$(cat /sys/class/dmi/id/product_name)"; fi
  [[ "$product_name" =~ ^Sword[[:space:]]16[[:space:]]HX[[:space:]]B14VEKG ]] || die "shesh profile is only valid for MSI Sword 16 HX B14VEKG; detected: ${product_name:-unknown}"
fi

PROFILE_DIR="$(get_profile_dir "$DEVICE")"
run(){ if (( DRY )); then info "[dry-run] $*"; else "$@"; fi; }
(( EUID != 0 )) || die 'run as the normal user (sudo is used where needed)'

info "== Applying device profile: $DEVICE =="

if [[ -f "$PROFILE_DIR/sysctl-99-shesh.conf" ]]; then
  run sudo install -Dm644 "$PROFILE_DIR/sysctl-99-shesh.conf" /etc/sysctl.d/99-shesh.conf
  if ! sudo sysctl --system >/dev/null 2>&1; then
    warn 'sysctl --system reported a non-fatal key/application error; inspect systemd-sysctl output before continuing.'
  fi
  ok 'sysctl profile installed'
fi

if [[ -f "$PROFILE_DIR/udev-60-ioschedulers.rules" ]]; then
  run sudo install -Dm644 "$PROFILE_DIR/udev-60-ioschedulers.rules" /etc/udev/rules.d/60-ioschedulers.rules
  run sudo udevadm control --reload-rules
  run sudo udevadm trigger
  ok 'udev scheduler rules installed'
fi

if [[ -f "$PROFILE_DIR/hypr-custom-general.lua" ]]; then
  target="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/custom/general.lua"
  mkdir -p "$(dirname "$target")"
  if grep -q 'managed-by=shesh-desktop-profile' "$target" 2>/dev/null; then
    warn 'existing shesh profile block found; leaving it unchanged'
  else
    {
      printf '\n-- managed-by=shesh-desktop-profile (device: %s)\n' "$DEVICE"
      cat "$PROFILE_DIR/hypr-custom-general.lua"
    } >> "$target"
  fi
  ok 'Hyprland profile override installed'
fi

ok "Done — device: $DEVICE"
