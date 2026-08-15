#!/usr/bin/env bash
# update-mirror.sh — self-hosted local pacman mirror (roadmap P2)
#
# CachyOS is rolling: resilience means updates keep working when upstream
# is slow or down, and repeated downloads are cached (efficiency). This
# maintains a local mirror directory:
#   - fetches packages with `pacman -Sw --cachedir <dir>` (or rsync from
#     another mirror when MIRROR_RSYNC is set)
#   - rebuilds the local repo DB with `repo-add`
#   - prunes old versions keeping KEEP_VERSIONS per package
# The mirror can then be used as the first entry in /etc/pacman.conf
# (Server = file://$MIRROR_DIR).
#
# Everything is dry-run safe: `--dry-run` prints exactly what would run
# without touching anything.
#
# Usage:
#   update-mirror.sh sync [--dry-run]     # fetch + repo-add + prune
#   update-mirror.sh prune [--dry-run]    # prune only (keep KEEP_VERSIONS)
#   update-mirror.sh status               # size / count / last sync
#   update-mirror.sh help
set -euo pipefail

MIRROR_DIR="${MIRROR_DIR:-$HOME/.cache/shesh/pacman-mirror}"
KEEP_VERSIONS="${KEEP_VERSIONS:-2}"
REPO_NAME="${REPO_NAME:-shesh}"
MIRROR_RSYNC="${MIRROR_RSYNC:-}"      # e.g. rsync://mirror.example.com/archlinux
SYNC_MARKER="$MIRROR_DIR/.last-sync"
DRY_RUN=false

log() { echo "[mirror] $*"; }

usage() { sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }

maybe_run() {
  if [ "$DRY_RUN" = true ]; then
    log "dry-run: $*"
    return 0
  fi
  "$@"
}

cmd_available() { command -v "$1" >/dev/null 2>&1; }

do_fetch() {
  mkdir -p "$MIRROR_DIR"
  if [ -n "$MIRROR_RSYNC" ]; then
    if ! cmd_available rsync; then
      echo "error: rsync not installed (needed for MIRROR_RSYNC)" >&2
      exit 1
    fi
    maybe_run rsync -a --delete "$MIRROR_RSYNC/" "$MIRROR_DIR/"
  else
    if ! cmd_available pacman; then
      echo "error: pacman not installed — set MIRROR_RSYNC or run on the target machine" >&2
      exit 1
    fi
    # Sync the package cache into the mirror dir (network only for what's new).
    maybe_run pacman -Sw --noconfirm --cachedir "$MIRROR_DIR" "$@"
  fi
}

do_repo_add() {
  if ! cmd_available repo-add; then
    echo "error: repo-add not installed (pacman package 'pacman-contrib' or 'archlinux-keyring')" >&2
    exit 1
  fi
  local db="$MIRROR_DIR/$REPO_NAME.db.tar.zst"
  # repo-add needs an explicit file list; glob is fine (all in one dir).
  # shellcheck disable=SC2086
  # An empty mirror is a valid state; any other failure must be visible.
  if ! maybe_run repo-add -q "$db" "$MIRROR_DIR"/*.pkg.tar.* 2>&1; then
    if compgen -G "$MIRROR_DIR/*.pkg.tar.*" >/dev/null; then
      log "warning: repo-add failed with packages present"
    fi
  fi
  [ "$DRY_RUN" = true ] && log "dry-run: repo-add $db <packages>"
}

prune_candidates() {
  # Print paths that should be removed: for each package stem keep the
  # KEEP_VERSIONS newest archives. Pure read — no side effects.
  local dir="$1" stem f
  for f in "$dir"/*.pkg.tar.*; do
    [ -e "$f" ] || continue
    stem=$(basename "$f")
    # strip -<ver>-<rel>-<arch>.pkg.tar.* -> name
    name=${stem%%-[0-9]*}
    printf '%s %s\n' "$name" "$stem"
  done | sort -u -k1,1 -k2,2r | awk -v keep="$KEEP_VERSIONS" '
    {
      if ($1 == prev) { count++; if (count > keep) print $2 }
      else { prev = $1; count = 1 }
    }'
}

do_prune() {
  local cand
  if [ ! -d "$MIRROR_DIR" ]; then
    log "mirror dir absent — nothing to prune"
    return 0
  fi
  while IFS= read -r cand; do
    [ -n "$cand" ] || continue
    if [ "$DRY_RUN" = true ]; then
      log "dry-run: rm $MIRROR_DIR/$cand"
    else
      rm -f "$MIRROR_DIR/$cand"
      log "removed $cand"
    fi
  done < <(prune_candidates "$MIRROR_DIR")
}

do_status() {
  if [ ! -d "$MIRROR_DIR" ]; then
    echo "mirror: not initialized ($MIRROR_DIR)"
    exit 0
  fi
  local count size
  count=$(find "$MIRROR_DIR" -name "*.pkg.tar.*" 2>/dev/null | wc -l)
  size=$(du -sh "$MIRROR_DIR" 2>/dev/null | cut -f1)
  echo "mirror dir: $MIRROR_DIR"
  echo "packages: $count   size: $size   keep: $KEEP_VERSIONS"
  if [ -f "$SYNC_MARKER" ]; then
    echo "last sync: $(cat "$SYNC_MARKER")"
  else
    echo "last sync: never"
  fi
}

case "${1:-help}" in
  sync)
    [ "$#" -gt 0 ] && shift
    case "${1:-}" in --dry-run) DRY_RUN=true; [ "$#" -gt 0 ] && shift ;; esac
    do_fetch "$@"
    do_repo_add
    do_prune
    if [ "$DRY_RUN" = false ]; then
      date -u +%Y-%m-%dT%H:%M:%SZ > "$SYNC_MARKER"
      log "sync complete"
    fi
    ;;
  prune)
    [ "$#" -gt 0 ] && shift
    case "${1:-}" in --dry-run) DRY_RUN=true ;; esac
    do_prune
    ;;
  status) do_status ;;
  help|-h|--help) usage 0 ;;
  *) usage 1 ;;
esac
