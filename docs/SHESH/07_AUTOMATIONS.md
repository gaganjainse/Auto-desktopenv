# 07 — Automations Catalog

> Every set-and-forget job in the Shesh ecosystem. The rule: **if it can be done safely on a timer
> or event, it is automated; if it's destructive, it asks first; every action is logged.** All units
> are canonical files under `tools/<tool>/units/`, installed (not here-doc-generated) by setup.

---

## 1. The automation surface at a glance

| Automation | Trigger | Mechanism | Asks? |
|---|---|---|---|
| Real-time file organizing | file create in Downloads/Desk/Inbox | `sm-watcher` → classifier | only low-conf |
| Deep file sweep | Sun 03:00 | `smart-organizer-daily.timer` | dry first week |
| Local backup | daily 04:00 (plugged in) | `backup.timer` + restic | no |
| Backup integrity verify | Sun 05:00 | `backup-verify.service` | no |
| System maintenance | Sun 02:30 | `maintenance.timer` | no |
| System **update notification** | daily 12:00 | `update-check.timer` | **yes (never auto `-Syu`)** |
| Power/GPU profile on AC change | udev power_supply event | udev → `systemd-run` | no |
| Disk-usage alert | daily | `disk-alert.timer` | only if >80% |
| Wallpaper rotation | boot + hourly (optional) | `wallpaper.timer` + `swww` | no |
| Battery/SMART health report | 1st of month | `health-report.timer` | no |
| ZRAM / sysctl | boot | `sysctl.d`, `zram-generator` | n/a |
| NVIDIA suspend/resume | sleep/wake | `nvidia-suspend/resume` units | n/a |
| hyprlock auto-lock | 5 min idle | `hypridle` | n/a |
| Clipboard history | always | cliphist + wl-paste (upstream) | n/a |
| Font cache after font install | pacman hook | package hook | n/a |
| Shesh morning briefing | 08:00 | Newelle scheduled task / cron skill | no |

---

## 2. Power profile auto-switch (AC/battery)

`/etc/udev/rules.d/99-shesh-power.rules`:
```udev
# On AC plug/unplug, delegate to a transient systemd unit (never run long scripts in udev)
SUBSYSTEM=="power_supply", ATTR{online}=="1", \
  RUN+="/usr/bin/systemd-run --no-block --unit=shesh-on-ac /usr/local/bin/shesh-power.sh ac"
SUBSYSTEM=="power_supply", ATTR{online}=="0", \
  RUN+="/usr/bin/systemd-run --no-block --unit=shesh-on-bat /usr/local/bin/shesh-power.sh battery"
```
`/usr/local/bin/shesh-power.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail
state="$1"
case "$state" in
  ac)
    powerprofilesctl set performance
    hyprctl --keyword decoration:blur:passes 3 >/dev/null
    hyprctl --keyword decoration:shadow:enabled 1 >/dev/null
    notify-send -a Shesh "Power" "AC connected — performance mode" -i battery-full-charging
    ;;
  battery)
    powerprofilesctl set power-saver
    hyprctl --keyword decoration:blur:passes 1 >/dev/null
    hyprctl --keyword decoration:shadow:enabled 0 >/dev/null
    notify-send -a Shesh "Power" "On battery — power saver" -i battery-caution
    ;;
esac
# log to audit
echo "{\"ts\":\"$(date -Iseconds)\",\"event\":\"power\",\"state\":\"$state\"}" \
  >> "${XDG_DATA_HOME:-$HOME/.local/share}/shesh/audit/events.jsonl"
```
```bash
sudo install -m755 shesh-power.sh /usr/local/bin/shesh-power.sh
sudo udevadm control --reload-rules
```
> Note: dGPU MUX switching needs a reboot; don't try it on udev. The script only changes the power
> profile and visual effects. GPU offload is per-app via `prime-run`.

---

## 3. Updates — notification, NEVER auto

Arch/CachyOS is rolling; blind `pacman -Syu` on a timer can break NVIDIA/Hyprland. So we only **notify**:

`~/.local/bin/shesh-update-check`:
```bash
#!/usr/bin/env bash
set -euo pipefail
checkupdates 2>/dev/null | wc -l | read -r n
if (( n > 0 )); then
  notify-send -a Shesh -u normal "Updates available" "$n packages. Run: pacman -Syu (review first)"
fi
# Also check AUR if paru/yay present
for h in paru yay; do command -v "$h" >/dev/null && "$h" -Qua 2>/dev/null | wc -l | read -r an; done
```
`units/shesh-update-check.timer`:
```ini
[Unit]
Description=Shesh update check (notify only)
[Timer]
OnCalendar=daily
Persistent=true
[Install]
WantedBy=timers.target
```
Pair with a pacman hook that reminds you to run `mkinitcpio -P` after kernel/nvidia updates if the
package didn't.

---

## 4. Backup (real, verified, no `--dry-run`)

Use **restic** to an external/NAS repo (`~/Backups/external` mounted). Fix BUG-02: the unit's
`ExecStart` must not have `--dry-run`.

`units/backup.service` (excerpt):
```ini
[Service]
Type=oneshot
ExecStart=%h/.local/bin/shesh-backup
```
`~/.local/bin/shesh-backup`:
```bash
#!/usr/bin/env bash
set -euo pipefail
REPO="${BACKUP_REPO:-$HOME/Backups/external}"
[ -d "$REPO" ] || { notify-send -a Shesh "Backup skipped" "$REPO not mounted"; exit 0; }
restic -r "$REPO" backup "$HOME/Documents" "$HOME/Notes" "$HOME/Projects/personal" \
  --exclude-file="$HOME/.config/shesh/restic-excludes" \
  --one-file-system
restic -r "$REPO" forget --keep-daily 7 --keep-weekly 4 --keep-monthly 12 --prune
restic -r "$REPO" check --read-data-subset=5%   # verify a slice each run
```
`restic-excludes` skips `AI/`, `.cache/`, `Downloads/`, `node_modules/`, `target/`, `__pycache__/`,
`.venv/`, `*.gguf`, `*.safetensors`. The job runs only on AC + when the repo is mounted.

---

## 5. Maintenance

`maintenance.timer` → Sun 02:30, runs:
- `journalctl --vacuum-time=14d`
- remove `~/.cache/thumbnails` older than 30d
- `paccache -rk2` (keep last 2 cached packages) if installed
- `uv cache prune`
- clear `Downloads/*` older than 30d (trash, not rm)
- `fc-cache` only if fonts changed
- append a maintenance event to the Shesh audit log

Guard every destructive action with a 7-day "new install" dry-run window (config flag).

---

## 6. Disk, health, and battery reports

- **Disk alert:** `df -h` → if `$HOME` >80%, critical notification; at 90%, Shesh verbally warns.
- **SMART:** monthly `smartctl -H` on NVMe; `nvme smart-log` for Gen4 drive.
- **Battery:** `upower -i` / `/sys/class/power_supply/BAT0/cycle_count` + `capacity`; alert when
  design capacity drops below 80% (battery wear).
- **Thermals:** `sensors` weekly; log CPU/GPU peaks; suggest cleaning fans if sustained >90 °C.

---

## 7. Wallpaper / theming

- `swww-daemon` for smooth wallpaper transitions (works at 144 Hz).
- `wallpaper.timer` picks randomly from `~/Media/Wallpapers` every hour (optional; you may prefer static).
- `matugen`/`kde-material-you-colors` regenerates the Material You palette from the new wallpaper and
  applies it to Hyprland/Quickshell/GTK/Kitty (this is already how end-4 theming works — don't fight it).
- Optional: time-based light/dark (sunset/sunrise via `wl-gammactl`/`hyprsunset`).

---

## 8. Session & window automations (Hyprland)

- **Workspace per activity** via window rules: code→ws1, browser→ws2, chat→ws3, media→ws4, etc.
- **Pinned floating:** Newelle (floating, top-right), Shesh overlay, screenshots UI.
- **Auto-start:** `quickshell`, `swww-daemon`, `hypridle`, `easyeffects`, `udiskie`, `nm-applet`
  (or the Quickshell equivalents already shipped by end-4).
- **Idle lock:** 5 min → `hyprlock`; 10 min → screen off; 30 min on battery → suspend.
- **Night light:** `hyprsunset` from sunset to sunrise (4500K).

---

## 9. Conventions for every new automation

1. One job = one canonical `.service` + `.timer` under `tools/<tool>/units/`.
2. Installed via `install -Dm644`, never generated with here-docs.
3. `TimeoutStartSec=15`, `TimeoutStopSec=10` (CachyOS 260628 user-service defaults).
4. `IOSchedulingClass=idle` and `CPUQuota` for background jobs so the desktop stays smooth at 144 Hz.
5. Every job appends one JSON line to `~/.local/share/shesh/audit/events.jsonl`.
6. Destructive actions default to **notify/ask** for the first 7 days and after any failure.
7. No network calls except explicit, local-only services (Ollama, restic repo).
