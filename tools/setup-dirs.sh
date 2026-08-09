#!/usr/bin/env bash
# tools/setup-dirs.sh — Create the Shesha home layout. Idempotent.
# See docs/SHESHA/03_DISK_STRUCTURE.md for the full rationale.
#
# Usage: tools/setup-dirs.sh [--dry-run]
set -euo pipefail

DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/common.sh"

home="$HOME"

make_dir() {
  if (( DRY_RUN )); then
    log_info "[dry-run] mkdir -p $1"
  else
    mkdir -p "$1"
  fi
}

log_step "Creating Shesha directory structure under $home"

# Desktop (kept empty — staging only)
make_dir "$home/Desk"

# Downloads (transient, auto-organized)
make_dir "$home/Downloads"/{Archives,Installers,Torrents,Unsorted}

# Documents — Personal / Job separation is a hard boundary
make_dir "$home/Documents/Personal"/{Finance,Government-ID,Medical,Travel}
make_dir "$home/Documents/Job"
make_dir "$home/Documents/Reference"
make_dir "$home/Documents/Inbox"

# One Media root
make_dir "$home/Media"/{Images,Screenshots,Wallpapers,Music,Videos,Camera,Design}

# Projects — job vs personal vs labs vs forks
make_dir "$home/Projects"/{job,personal,labs,forks,_archive}

# AI assets (large, snapshot/backup excluded)
make_dir "$home/AI"/{Models,Datasets,Vectors,Weights-Cache,Sessions}

# Notes (git-backed vault)
make_dir "$home/Notes"/{Daily,Tech,Ideas,Meetings,Shesha}

# Vaults (encrypted) & backups
make_dir "$home/Vaults"/{Passwords,Keys}
make_dir "$home/Backups"/{external,nas,restic-repo}

# XDG
make_dir "$home/.local/share"
make_dir "$home/.local/state"
make_dir "$home/.config"
make_dir "$home/.cache"

# Disable CoW on big AI model/data dirs (btrfs) if chattr is available
if (( ! DRY_RUN )) && command_exists chattr; then
  chattr +C "$home/AI/Models" "$home/AI/Datasets" 2>/dev/null || \
    log_warn "chattr +C failed (not btrfs?); harmless"
fi

# Secrets locked down
(( ! DRY_RUN )) && chmod 700 "$home/Vaults" "$home/Vaults/Keys" 2>/dev/null || true

log_ok "Shesha directory structure created."
log_info "Next: review docs/SHESHA/03_DISK_STRUCTURE.md for XDG env, git identity, and backup policy."
