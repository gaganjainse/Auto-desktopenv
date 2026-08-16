#!/usr/bin/env bash
# shesh-desktop Bootstrap — ONE command installs everything.
#
#   bash <(curl -s https://raw.githubusercontent.com/gaganjainse/shesh-desktop/main/tools/bootstrap.sh)
#   bash <(curl -s .../bootstrap.sh) -- --skip-ai --device shesh
#
# What it does (idempotent; safe to re-run):
#   1. Preflight (not root, sudo present, network, Arch/CachyOS check)
#   2. System update + base tooling (pacman)
#   3. Clone shesh-desktop to ~/Workspace/shesh-desktop (recurse submodules)
#   4. Run `./setup install --force` — end-4 dots + Hyprland + Quickshell +
#      NVIDIA/MUX + power/zram + Ollama/models/Newelle (the desktop's own AI bits)
#   5. Apply the device profile (sysctl/udev/144Hz) via tools/apply-profile.sh
#   6. Install the Shesh MCP stack (shesh-core + memory/orchestrator/harness/…) +
#      MCP client configs + systemd units via the ecosystem installer
#   7. Verification + reboot note
#
# Flags:
#   --skip-ai       skip Ollama/models/voice + the ecosystem MCP stack
#   --skip-nvidia   skip NVIDIA/MUX setup
#   --skip-power    skip power management (incl. zram)
#   --skip-stack    skip the Shesh MCP stack entirely (it is optional)
#   --dry-run       print every step, run nothing
#   --device NAME   shesh | generic | auto (default auto-detect)
#   --help
#
# Headless / no-DE installs (no TTY for sudo):
#   BOOTSTRAP_SUDO_PASSWORD='yourpass' bash tools/bootstrap.sh
#     -> uses an askpass helper so ./setup, makepkg and yay authenticate without a TTY.
#   Or pre-set SUDO_ASKPASS to your own askpass program.
#
# Overriding the MCP-stack installer (default upstream path currently 404s):
#   SHESH_STACK_URL=https://.../install-shesh-stack.sh SHESH_STACK_SHA256=... bash tools/bootstrap.sh
#   If the download or SHA check fails, the stack step is SKIPPED (warning), not fatal.
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log_info(){ echo -e "${BLUE}[BOOT]${NC} $*"; }
log_ok()  { echo -e "${GREEN}[OK]${NC}   $*"; }
log_warn(){ echo -e "${YELLOW}[WARN]${NC} $*"; }
log_err() { echo -e "${RED}[FATAL]${NC} $*" >&2; }

SKIP_AI=0; SKIP_NVIDIA=0; SKIP_POWER=0; SKIP_STACK=0; DRY=0; DEVICE="auto"

usage() {
  cat <<'EOF'
shesh-desktop Bootstrap — one command installs the whole desktop + Shesh stack.

  --skip-ai       skip Ollama/models/voice + the ecosystem MCP stack
  --skip-nvidia   skip NVIDIA/MUX setup
  --skip-power    skip power management (incl. zram)
  --skip-stack    skip the Shesh MCP stack entirely (it is optional)
  --dry-run       print every step, run nothing
  --device NAME   shesh | generic | auto (default auto-detect)
  --help
EOF
}

# allow the `bash <(curl ...) -- <flags>` invocation form
[[ "${1:-}" == "--" ]] && shift

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-ai) SKIP_AI=1; shift;;
    --skip-nvidia) SKIP_NVIDIA=1; shift;;
    --skip-power) SKIP_POWER=1; shift;;
    --skip-stack) SKIP_STACK=1; shift;;
    --dry-run) DRY=1; shift;;
    --device) DEVICE="$2"; shift 2;;
    --help|-h) usage; exit 0;;
    *) log_warn "unknown arg $1 — ignoring"; shift;;
  esac
done

if [[ "$DEVICE" == "auto" ]]; then
  if grep -qiE "Sword 16 HX|B14VEKG" /sys/class/dmi/id/product_name 2>/dev/null; then
    DEVICE="shesh"
  else
    DEVICE="generic"
  fi
fi

INSTALL_DIR="${HOME}/Workspace/shesh-desktop"
# Shesh MCP-stack installer. Overridable via SHESH_STACK_URL if the pinned path
# changes. NOTE: the default upstream path currently 404s, so the stack step
# degrades to a warning (skip) instead of aborting the whole bootstrap.
ECO_URL="${SHESH_STACK_URL:-https://raw.githubusercontent.com/gaganjainse/shesh-ecosystem/main/tools/install-shesh-stack.sh}"
# Pinned SHA256 of install-shesh-stack.sh. Override with SHESH_STACK_SHA256.
# A mismatch (or a failed download) skips the stack rather than failing hard.
ECO_SHA256="${SHESH_STACK_SHA256:-1ccefd55c22cc981990da46215008940118f41d219549c4045097b0f0f47af8a}"

run() { if [[ $DRY -eq 1 ]]; then log_info "[dry-run] $*"; else "$@"; fi; }

preflight() {
  log_info "=== Preflight ==="
  log_info "device=$DEVICE skip-ai=$SKIP_AI skip-nvidia=$SKIP_NVIDIA skip-power=$SKIP_POWER dry-run=$DRY"
  [[ $EUID -eq 0 ]] && { log_err "do NOT run as root — run as your normal user (sudo will be used)"; exit 1; }
  command -v sudo >/dev/null 2>&1 || { log_err "sudo is required"; exit 1; }
  curl -s -o /dev/null -m 8 https://archlinux.org/ || { log_err "no network (https://archlinux.org unreachable)"; exit 1; }
  if ! grep -qiE 'arch|cachyos' /etc/os-release; then
    log_warn "not Arch/CachyOS detected — continuing, but some steps assume pacman"
  fi
  log_ok "preflight passed ($(whoami)@$(hostname))"
}

install_prerequisites() {
  log_info "=== System update + base tooling ==="
  run sudo pacman -Syu --noconfirm
  run sudo pacman -S --noconfirm --needed git curl wget base-devel
  log_ok "prerequisites ready"
}

clone_desktop() {
  log_info "=== Clone shesh-desktop ==="
  if [[ -d "$INSTALL_DIR/.git" ]]; then
    run git -C "$INSTALL_DIR" pull --ff-only && run git -C "$INSTALL_DIR" submodule update --init --recursive
  else
    run mkdir -p "$(dirname "$INSTALL_DIR")"
    run git clone --recurse-submodules "https://github.com/gaganjainse/shesh-desktop.git" "$INSTALL_DIR"
  fi
  log_ok "shesh-desktop ready at $INSTALL_DIR"
}

run_setup() {
  log_info "=== end-4 dots + Hyprland + hardware setup (non-interactive) ==="
  if [[ $DRY -eq 0 && ! -f "$INSTALL_DIR/setup" ]]; then
    log_err "setup not found at $INSTALL_DIR/setup"; exit 1
  fi
  local env_prefix=()
  [[ $SKIP_NVIDIA -eq 1 ]] && env_prefix+=(SKIP_NVIDIA_SETUP=true)
  [[ $SKIP_AI -eq 1 ]]     && env_prefix+=(SKIP_AI_STACK=true)
  [[ $SKIP_POWER -eq 1 ]]  && env_prefix+=(SKIP_POWER_SETUP=true)
  if [[ $DRY -eq 1 ]]; then
    log_info "[dry-run] (cd $INSTALL_DIR && env ${env_prefix[*]} ./setup install --force)"
  else
    (cd "$INSTALL_DIR" && env "${env_prefix[@]}" ./setup install --force)
  fi
  log_ok "desktop setup done"
}

apply_profile() {
  log_info "=== Device profile ($DEVICE) ==="
  local prof="$INSTALL_DIR/tools/apply-profile.sh"
  if [[ $DRY -eq 1 ]]; then
    log_info "[dry-run] bash $prof --device $DEVICE"
    return 0
  fi
  [[ -f "$prof" ]] || { log_warn "apply-profile.sh missing — skipping (profile is optional tuning)"; return 0; }
  bash "$prof" --device "$DEVICE"
  log_ok "device profile applied"
}

install_stack() {
  log_info "=== Shesh MCP stack (shesh-core + services + MCP config + units) ==="
  local flags=(--no-sysupgrade)
  [[ $SKIP_AI -eq 1 ]] && flags+=(--skip-ai)
  if [[ $DRY -eq 1 ]]; then
    log_info "[dry-run] fetch $ECO_URL (sha256 pinned: ${ECO_SHA256:-(none)}) then: bash <installer> ${flags[*]}"
    return 0
  fi
  if [[ $SKIP_STACK -eq 1 ]]; then
    log_warn "skipping MCP stack (--skip-stack)"; return 0
  fi
  # SHA-pinned: fetch to a temp file, verify against the pinned digest, then run.
  # A missing file (404) or digest mismatch must NOT abort the bootstrap — it only
  # skips the OPTIONAL MCP stack, leaving the desktop itself fully installed.
  local tmp; tmp="$(mktemp)"
  if ! curl -fsSL "$ECO_URL" -o "$tmp" 2>/tmp/kilo/iss.err; then
    log_warn "could not download Shesh stack installer: $ECO_URL"
    log_warn "$(cat /tmp/kilo/iss.err 2>/dev/null | tr -d '\n')"
    log_warn "SKIPPING MCP stack — desktop is fully installed. Re-run later with SHESH_STACK_URL set."
    rm -f "$tmp" /tmp/kilo/iss.err
    return 0
  fi
  if [[ -n "$ECO_SHA256" ]]; then
    local got; got="$(sha256sum "$tmp" | cut -d' ' -f1)"
    if [[ "$got" != "$ECO_SHA256" ]]; then
      log_warn "install-shesh-stack.sh checksum mismatch"
      log_warn "  expected $ECO_SHA256"
      log_warn "  got      $got"
      log_warn "SKIPPING MCP stack to avoid running unverified code. Update the pin or set SHESH_STACK_SHA256."
      rm -f "$tmp" /tmp/kilo/iss.err
      return 0
    fi
    log_ok "install-shesh-stack.sh checksum verified"
  else
    log_warn "no SHA256 pin set (SHESH_STACK_SHA256) — running unverified installer from $ECO_URL"
  fi
  bash "$tmp" "${flags[@]}"
  local rc=$?
  rm -f "$tmp" /tmp/kilo/iss.err
  [[ $rc -eq 0 ]] && log_ok "Shesh stack installed" || log_warn "Shesh stack installer exited $rc"
}

verify() {
  log_info "=== Verification ==="
  if [[ $DRY -eq 1 ]]; then
    log_info "[dry-run] verification skipped"; return 0
  fi
  local fails=0
  command -v hyprctl >/dev/null 2>&1 && log_ok "hyprctl present" || { log_warn "hyprctl missing (expected until first Hyprland session)"; fails=$((fails+1)); }
  command -v ollama >/dev/null 2>&1 && log_ok "ollama present" || { [[ $SKIP_AI -eq 1 ]] && log_ok "ollama skipped (--skip-ai)" || { log_warn "ollama missing"; fails=$((fails+1)); }; }
  command -v shesh-audit-mcp >/dev/null 2>&1 && log_ok "shesh-audit-mcp present" || { [[ $SKIP_AI -eq 1 ]] && log_ok "MCP stack skipped (--skip-ai)" || { log_warn "shesh-audit-mcp missing (MCP stack may not have installed)"; fails=$((fails+1)); }; }
  [[ $fails -gt 0 ]] && { log_warn "$fails verification warning(s) — see above"; } || log_ok "verification clean"
}

setup_sudo() {
  # Optional non-interactive sudo for headless / no-DE installs (no TTY).
  # Provide BOOTSTRAP_SUDO_PASSWORD, or pre-set SUDO_ASKPASS yourself.
  # We drop a `sudo` wrapper + askpass helper on PATH so child processes
  # (./setup, makepkg, yay) also authenticate without a TTY.
  if [[ -n "${SUDO_ASKPASS:-}" ]]; then
    sudo() { command sudo -A "$@"; }
    export SUDO_ASKPASS
    log_info "using provided SUDO_ASKPASS for non-interactive sudo"
    return 0
  fi
  if [[ -n "${BOOTSTRAP_SUDO_PASSWORD:-}" ]]; then
    local dir; dir="$(mktemp -d "${XDG_RUNTIME_DIR:-/tmp}/shesh-sudo.XXXXXX")"
    local ap="$dir/askpass.sh"
    printf '#!/usr/bin/env bash\necho "%s"\n' "$BOOTSTRAP_SUDO_PASSWORD" > "$ap"
    chmod 700 "$ap"
    local sw="$dir/sudo"
    printf '#!/usr/bin/env bash\nexec /usr/bin/sudo -A "$@"\n' > "$sw"
    chmod 700 "$sw"
    SUDO_ASKPASS="$ap"
    export SUDO_ASKPASS PATH="$dir:$PATH"
    sudo() { command sudo -A "$@"; }
    log_info "headless sudo enabled (BOOTSTRAP_SUDO_PASSWORD)"
    return 0
  fi
  log_info "interactive sudo — run from a TTY, or set BOOTSTRAP_SUDO_PASSWORD for headless"
}

main() {
  setup_sudo
  preflight
  install_prerequisites
  clone_desktop
  run_setup
  apply_profile
  install_stack
  verify
  echo
  log_ok "=== Bootstrap complete (device: $DEVICE) ==="
  log_info "Reboot, pick Hyprland at the login screen, then:"
  log_info "  - Settings → Shesh → flip toggles (they rewrite ~/.config/shesh/mcp/*.json)"
  log_info "  - Verify: hyprctl monitors   (expect 1920x1200@144 on eDP-1)"
  log_info "  - Voice:  'Hey Shesh' (Newelle, local models)"
  echo
}

main "$@"
