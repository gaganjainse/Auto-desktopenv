#!/usr/bin/env bash
# setup-ollama-auth.sh — put an API-key reverse proxy in front of local Ollama.
# Idempotent; safe to re-run. The raw Ollama port stays loopback-only.
set -euo pipefail

CONF="${XDG_CONFIG_HOME:-$HOME/.config}/shesh/ollama"
KEYFILE="$CONF/api.key"
ENVFILE="$CONF/env"
CADDYFILE="$CONF/Caddyfile"
UNIT="$HOME/.config/systemd/user/shesh-ollama-auth.service"
PROXY_ADDR="http://127.0.0.1:11435"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

die() { echo "[ollama-auth] FATAL: $*" >&2; exit 1; }
info() { echo "[ollama-auth] $*"; }

[[ $EUID -eq 0 ]] && die "run as your normal user (sudo used where needed)"
command -v sudo >/dev/null || die "sudo required"

mkdir -p "$CONF"
chmod 700 "$CONF"

# 1. API key (generate once, 0600)
if [[ ! -f "$KEYFILE" ]]; then
    umask 177
    (head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n') > "$KEYFILE"
    info "generated API key at $KEYFILE"
fi
chmod 600 "$KEYFILE"
KEY="$(cat "$KEYFILE")"
[[ -n "$KEY" ]] || die "empty API key"

# 2. Env file for MCP units + caddy (0600)
umask 177
cat > "$ENVFILE" <<ENV
OLLAMA_URL=$PROXY_ADDR
OLLAMA_API_KEY=$KEY
ENV
chmod 600 "$ENVFILE"
info "env file written (OLLAMA_URL=$PROXY_ADDR)"

# 3. Caddyfile (no secret — key via EnvironmentFile)
install -Dm644 "$HERE/Caddyfile" "$CADDYFILE"
info "Caddyfile installed"

# 4. systemd user unit for the proxy
mkdir -p "$(dirname "$UNIT")"
cat > "$UNIT" <<UNIT
[Unit]
Description=Shesh Ollama auth proxy (API key)
After=network-online.target

[Service]
ExecStart=/usr/bin/caddy run --config %h/.config/shesh/ollama/Caddyfile
EnvironmentFile=-%h/.config/shesh/ollama/env
Restart=on-failure
RestartSec=3

[Install]
WantedBy=default.target
UNIT
info "systemd user unit written"

# 5. Force raw Ollama to loopback (system drop-in, needs sudo)
if command -v ollama >/dev/null 2>&1; then
    sudo mkdir -p /etc/systemd/system/ollama.service.d
    sudo install -Dm644 "$HERE/ollama-localhost.conf" \
        /etc/systemd/system/ollama.service.d/shesh-localhost.conf
    sudo systemctl daemon-reload
    sudo systemctl restart ollama.service 2>/dev/null \
        || info "ollama not running yet — drop-in takes effect on next start"
    info "ollama loopback drop-in installed"
else
    info "ollama not installed — loopback drop-in skipped (re-run after ollama install)"
fi

# 6. Enable the proxy
systemctl --user daemon-reload
systemctl --user enable --now shesh-ollama-auth.service 2>/dev/null \
    && info "proxy enabled (127.0.0.1:11435, key required)" \
    || info "no user bus — proxy unit installed, not enabled"

echo "[ollama-auth] done. Ollama is now:"
echo "  raw API:  127.0.0.1:11434 (loopback only, NO key — never exposed)"
echo "  proxy:    127.0.0.1:11435 (requires X-API-Key: <key>)"
echo "  key file: $KEYFILE"
echo "  env file: $ENVFILE  (MCP units pick this up via EnvironmentFile)"
