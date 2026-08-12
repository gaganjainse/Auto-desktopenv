#!/usr/bin/env bash
# tools/automation/shesh-power.sh
# Called by udev on AC plug/unplug (see 99-shesh-power.rules).
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
        # Best-effort UI sugar: no notification daemon on headless/server
        # sessions — absence of notify-send is a normal condition, not a failure.
        if command -v notify-send >/dev/null 2>&1; then
            notify-send -a Shesh -i battery-full-charging "Power" "AC connected — performance"
        fi
        ;;
    battery)
        powerprofilesctl set power-saver
        command -v hyprctl >/dev/null && {
            hyprctl --keyword decoration:blur:passes 1 >/dev/null
            hyprctl --keyword decoration:shadow:enabled 0 >/dev/null
        }
        if command -v notify-send >/dev/null 2>&1; then
            notify-send -a Shesh -i battery-caution "Power" "On battery — power saver"
        fi
        ;;
    *)
        echo "usage: $0 ac|battery" >&2
        exit 2
        ;;
esac

logdir="${XDG_DATA_HOME:-$HOME/.local/share}/shesh/audit"
mkdir -p "$logdir"
printf '{"ts":"%s","event":"power","state":"%s"}\n' "$(date -Iseconds)" "$state" >>"$logdir/events.jsonl"
