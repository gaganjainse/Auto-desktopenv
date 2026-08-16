#!/usr/bin/env bash
# shesh-desktop Bootstrap — safe, staged installer for Arch/CachyOS.
#
# The bootstrap is deliberately self-contained until the repository is cloned.
# Hardware/NVIDIA tuning is opt-in because it mutates initramfs/bootloader state.
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log_info(){ echo -e "${BLUE}[BOOT]${NC} $*"; }
log_ok(){ echo -e "${GREEN}[OK]${NC}   $*"; }
log_warn(){ echo -e "${YELLOW}[WARN]${NC} $*"; }
log_err(){ echo -e "${RED}[FATAL]${NC} $*" >&2; }

SKIP_AI=0; SKIP_NVIDIA=1; SKIP_POWER=0; SKIP_STACK=0; DRY=0; DEVICE='auto'
ENABLE_HARDWARE=0
INSTALL_DIR="${HOME}/Workspace/shesh-desktop"
ECO_DIR="${HOME}/Workspace/shesh-ecosystem"
ECO_SHA256="${SHESH_STACK_SHA256:-640f3b7e40347744dca9c9cf12c52b2dd85945fb96247e5e6a08414577c485da}"
REPO_URL="${SHESH_DESKTOP_REPO_URL:-https://github.com/gaganjainse/shesh-desktop.git}"

usage(){
  cat <<'EOF'
shesh-desktop Bootstrap

  --enable-hardware   enable MSI/NVIDIA/initramfs/bootloader tuning (opt-in)
  --skip-ai           skip CUDA/Ollama/Newelle/model work
  --skip-power        skip power management/zram
  --skip-stack        skip the Shesh MCP ecosystem stack
  --dry-run           print actions without executing them
  --device NAME       shesh | generic | auto (default: auto)
  --help

Safe default: hardware/NVIDIA tuning is NOT applied during the first install.
After the first plain-Hyprland boot is verified, rerun with --enable-hardware.
EOF
}

[[ "${1:-}" == '--' ]] && shift
while [[ $# -gt 0 ]]; do
  case "$1" in
    --enable-hardware) ENABLE_HARDWARE=1; SKIP_NVIDIA=0; shift;;
    --skip-ai) SKIP_AI=1; shift;;
    --skip-power) SKIP_POWER=1; shift;;
    --skip-stack) SKIP_STACK=1; shift;;
    --dry-run) DRY=1; shift;;
    --device) [[ $# -ge 2 ]] || { log_err '--device requires a value'; exit 2; }; DEVICE="$2"; shift 2;;
    --help|-h) usage; exit 0;;
    *) log_err "unknown argument: $1"; exit 2;;
  esac
done

run(){
  if (( DRY )); then log_info "[dry-run] $*"; else "$@"; fi
}

preflight(){
  log_info '=== Preflight ==='
  [[ $EUID -ne 0 ]] || { log_err 'run as the normal user, not root'; exit 1; }
  command -v sudo >/dev/null 2>&1 || { log_err 'sudo is required'; exit 1; }
  command -v curl >/dev/null 2>&1 || { log_err 'curl is required'; exit 1; }
  command -v git >/dev/null 2>&1 || { log_err 'git is required'; exit 1; }
  curl -fsS --connect-timeout 8 --max-time 15 https://archlinux.org/ >/dev/null || { log_err 'network check failed'; exit 1; }
  grep -qiE '(^ID=.?cachyos|^ID=arch|^ID_LIKE=.*arch)' /etc/os-release || { log_err 'CachyOS/Arch is required'; exit 1; }
  log_ok "preflight passed ($(whoami)@$(hostname))"
}

install_prereqs(){
  log_info '=== System update + base tooling ==='
  run sudo pacman -Syu --noconfirm
  run sudo pacman -S --needed --noconfirm git curl wget base-devel python
}

clone_desktop(){
  log_info '=== Clone shesh-desktop ==='
  if [[ -d "$INSTALL_DIR/.git" ]]; then
    run git -C "$INSTALL_DIR" fetch --prune origin
    run git -C "$INSTALL_DIR" checkout main
    run git -C "$INSTALL_DIR" pull --ff-only
    run git -C "$INSTALL_DIR" submodule update --init --recursive
  else
    run mkdir -p "$(dirname "$INSTALL_DIR")"
    run git clone --recurse-submodules "$REPO_URL" "$INSTALL_DIR"
  fi
}

resolve_device(){
  local detector="$INSTALL_DIR/tools/lib/profile-detect.sh"
  [[ -f "$detector" ]] || { log_err "profile detector missing: $detector"; exit 1; }
  # shellcheck source=/dev/null
  source "$detector"
  if [[ "$DEVICE" == 'auto' ]]; then DEVICE="$(detect_profile)"; fi
  profile_exists "$DEVICE" || { log_err "profile '$DEVICE' does not exist"; exit 1; }
  log_ok "device profile: $DEVICE"
}

run_setup(){
  log_info '=== end-4 dots + Hyprland base setup ==='
  local env_prefix=()
  (( SKIP_NVIDIA )) && env_prefix+=(SKIP_NVIDIA_SETUP=true)
  (( SKIP_AI )) && env_prefix+=(SKIP_AI_STACK=true)
  (( SKIP_POWER )) && env_prefix+=(SKIP_POWER_SETUP=true)
  (( ENABLE_HARDWARE )) && env_prefix+=(ENABLE_SHESH_HARDWARE_TUNING=true)
  if (( DRY )); then
    log_info "[dry-run] (cd $INSTALL_DIR && env ${env_prefix[*]:-} ./setup install --force)"
  else
    (cd "$INSTALL_DIR" && env "${env_prefix[@]}" ./setup install --force)
  fi
}

apply_profile(){
  log_info '=== Apply device profile ==='
  if (( DRY )); then
    log_info "[dry-run] bash $INSTALL_DIR/tools/apply-profile.sh --device $DEVICE"
  else
    bash "$INSTALL_DIR/tools/apply-profile.sh" --device "$DEVICE"
  fi
}

install_stack(){
  (( SKIP_STACK )) && { log_warn 'MCP stack skipped (--skip-stack)'; return 0; }
  log_info '=== Shesh MCP stack ==='

  if [[ -d "$ECO_DIR/.git" ]]; then
    run git -C "$ECO_DIR" fetch --prune origin
    run git -C "$ECO_DIR" checkout main
    run git -C "$ECO_DIR" pull --ff-only
  else
    run mkdir -p "$(dirname "$ECO_DIR")"
    run git clone --depth 1 https://github.com/gaganjainse/shesh-ecosystem.git "$ECO_DIR"
  fi
  [[ -f "$ECO_DIR/tools/install-shesh-stack.sh" ]] || { log_err 'ecosystem installer not found'; exit 1; }

  # Current ecosystem installer expects /tmp/kilo for per-step diagnostics.
  run mkdir -p /tmp/kilo

  local actual_sha
  actual_sha="$(sha256sum "$ECO_DIR/tools/install-shesh-stack.sh" | awk '{print $1}')"
  [[ "$actual_sha" == "$ECO_SHA256" ]] || {
    log_err 'ecosystem installer checksum mismatch'
    log_err "expected: $ECO_SHA256"
    log_err "actual:   $actual_sha"
    exit 1
  }
  log_ok 'ecosystem installer checksum verified'

  local flags=(--no-sysupgrade --src-dir "$ECO_DIR")
  (( SKIP_AI )) && flags+=(--skip-ai)
  if (( DRY )); then
    log_info "[dry-run] (cd $ECO_DIR && bash tools/install-shesh-stack.sh ${flags[*]})"
  elif (cd "$ECO_DIR" && bash tools/install-shesh-stack.sh "${flags[@]}"); then
    log_ok 'Shesh MCP stack installed'
  else
    log_err 'Shesh MCP stack installation failed; refusing to report a complete installation'
    return 1
  fi
}

verify(){
  (( DRY )) && return 0
  log_info '=== Verification ==='
  local failed=0
  command -v hyprctl >/dev/null 2>&1 || { log_warn 'hyprctl missing'; failed=1; }
  if (( ! SKIP_AI )); then
    command -v ollama >/dev/null 2>&1 || { log_warn 'ollama missing'; failed=1; }
  fi
  if (( ! SKIP_STACK )); then
    command -v shesh-audit-mcp >/dev/null 2>&1 || { log_warn 'shesh-audit-mcp missing'; failed=1; }
  fi
  if (( failed )); then log_err 'verification failed'; return 1; fi
  log_ok 'verification passed'
}

main(){
  preflight
  install_prereqs
  clone_desktop
  resolve_device
  run_setup
  apply_profile
  install_stack
  verify
  log_ok 'Bootstrap complete.'
  log_info 'Reboot and select plain Hyprland at SDDM — DO NOT select UWSM on first boot.'
  if (( ! ENABLE_HARDWARE )); then
    log_info 'Hardware/NVIDIA tuning was intentionally deferred. Verify the first boot before rerunning with --enable-hardware.'
  fi
}
main
