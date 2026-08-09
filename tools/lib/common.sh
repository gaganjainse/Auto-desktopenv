#!/usr/bin/env bash
# tools/lib/common.sh — canonical shared helpers for every tool under tools/.
# Source this at the top of each tool script:
#   source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../lib/common.sh"
#
# License: GPL-3.0 (same as the repo)

# Avoid double-sourcing.
[[ -n "${__SESHA_COMMON_SH_LOADED:-}" ]] && return 0
__SESHA_COMMON_SH_LOADED=1

# ── Colors (respect NO_COLOR and non-TTY) ──────────────────────────────────────
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  _C_RESET='\033[0m'; _C_RED='\033[0;31m'; _C_GREEN='\033[0;32m'
  _C_YELLOW='\033[1;33m'; _C_BLUE='\033[0;34m'; _C_CYAN='\033[0;36m'
  _C_BOLD='\033[1m'; _C_DIM='\033[2m'
else
  _C_RESET=; _C_RED=; _C_GREEN=; _C_YELLOW=; _C_BLUE=; _C_CYAN=; _C_BOLD=; _C_DIM=
fi

# ── Logging (prefix = calling script) ─────────────────────────────────────────
# Override LOG_PREFIX in the caller if you want a fixed tag.
_LOG_TAG="${LOG_TAG:-$(basename "${BASH_SOURCE[1]:-$0}")}"

log_info()    { printf "%b[%s]%b %s\n" "$_C_BLUE"   "$_LOG_TAG" "$_C_RESET" "$*"; }
log_ok()      { printf "%b[%s]%b %s\n" "$_C_GREEN"  "$_LOG_TAG" "$_C_RESET" "$*"; }
log_warn()    { printf "%b[%s]%b %s\n" "$_C_YELLOW" "$_LOG_TAG" "$_C_RESET" "$*" >&2; }
log_error()   { printf "%b[%s]%b %s\n" "$_C_RED"    "$_LOG_TAG" "$_C_RESET" "$*" >&2; }
log_step()    { printf "\n%b==> %s%b\n" "$_C_BOLD" "$*" "$_C_RESET"; }
die()         { log_error "$@"; exit 1; }

# ── Small utilities ───────────────────────────────────────────────────────────
command_exists() { command -v "$1" >/dev/null 2>&1; }

require_cmds() {
  local missing=() c
  for c in "$@"; do command_exists "$c" || missing+=("$c"); done
  (( ${#missing[@]} )) && die "Missing required commands: ${missing[*]}"
}

# Portable realpath fallback.
abspath() {
  local p="$1"
  if command_exists realpath; then realpath -s "$p"; else
    (cd "$(dirname "$p")" 2>/dev/null && printf "%s/%s" "$PWD" "$(basename "$p")")
  fi
}

# Run a command, echoing it first (dry-run aware).
# Usage: run <cmd...> ; respects DRY_RUN=1
run() {
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    printf "%b[dry-run]%b %s\n" "$_C_DIM" "$_C_RESET" "$*" >&2
    return 0
  fi
  log_info "+ $*"
  "$@"
}

# Append a JSON line to the Sesha audit log.
sesha_audit() {
  # usage: sesha_audit <event> [key=value ...]
  local event="$1"; shift || return 0
  local logdir="${XDG_DATA_HOME:-$HOME/.local/share}/sesha/audit"
  mkdir -p "$logdir"
  local ts; ts="$(date -Iseconds)"
  local kv="" k v
  for kv in "$@"; do
    k="${kv%%=*}"; v="${kv#*=}"
    # escape quotes/backslashes in value
    v="${v//\\/\\\\}"; v="${v//\"/\\\"}"
    printf ', "%s": "%s"' "$k" "$v"
  done
  printf '{"ts":"%s", "event":"%s"%s}\n' "$ts" "$event" "$kv" >> "$logdir/events.jsonl"
}
