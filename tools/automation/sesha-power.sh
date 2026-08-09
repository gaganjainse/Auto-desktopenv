#!/usr/bin/env bash
# tools/automation/sesha-power.sh
# Called by udev on AC plug/unplug (see 99-sesha-power.rules).
# Sets power profile, toggles Hyprland visuals, notifies, and logs to audit.
set -euo pipefail

state="${1:-}"
case "$state" in
  ac)
    powerprofilesctl set performance
    command -v hyprctl >/dev/null && {
      hyprctl --keyword decoration:blur:passes 3 >/dev/null
      hyprctl --keyword decoration:shadow:enabled 1 >/dev/null
    }
    notify-send -a Sesha -i battery-full-charging "Power" "AC connected — performance" 2>/dev/null || true
    ;;
  battery)
    powerprofilesctl set power-saver
    command -v hyprctl >/dev/null && {
      hyprctl --keyword decoration:blur:passes 1 >/dev/null
      hyprctl --keyword decoration:shadow:enabled 0 >/dev/null
    }
    notify-send -a Sesha -i battery-caution "Power" "On battery — power saver" 2>/dev/null || true
    ;;
  *)
    echo "usage: $0 ac|battery" >&2; exit 2 ;;
esac

logdir="${XDG_DATA_HOME:-$HOME/.local/share}/sesha/audit"
mkdir -p "$logdir"
printf '{"ts":"%s","event":"power","state":"%s"}\n' "$(date -Iseconds)" "$state" >> "$logdir/events.jsonl"
