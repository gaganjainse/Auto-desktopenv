#!/usr/bin/env bash
# tools/automation/shesh-power.sh — SYSTEM-side AC/battery profile switch.
# Invoked by udev (99-shesh-power.rules) as root via systemd-run.
# Does ONLY the system-level action (powerprofilesctl). The user-facing visual
# tweaks (hyprctl blur/shadow) are applied by the Shesh shell service
# (Shesh.qml applyPowerVisuals) in the user session — root has no session to
# talk to hyprctl/notify-send, so those must NOT run here.
set -euo pipefail
state="${1:-}"
case "$state" in
  ac) powerprofilesctl set performance ;;
  battery) powerprofilesctl set power-saver ;;
  *) echo "usage: $0 <ac|battery>" >&2; exit 2 ;;
esac
