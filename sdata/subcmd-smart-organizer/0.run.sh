#!/usr/bin/env bash
cd "$(dirname "$0")/../.."
REPO_ROOT="$(pwd)"
source ./sdata/lib/environment-variables.sh
source ./sdata/lib/functions.sh

prevent_sudo_or_root
set -e

printf "${STY_CYAN}[$0]: Smart Organizer Setup${STY_RST}\n"
pause

# Install smart-organizer
SMART_ORGANIZER_DIR="${REPO_ROOT}/tools/smart-organizer"
SMART_ORGANIZER_BIN="${XDG_BIN_HOME}/smart-organizer"

if [[ ! -d "$SMART_ORGANIZER_DIR" ]]; then
    printf "${STY_RED}smart-organizer directory not found at $SMART_ORGANIZER_DIR${STY_RST}\n"
    exit 1
fi

# Create symlink to bin
v mkdir -p "$XDG_BIN_HOME"
v ln -sf "${SMART_ORGANIZER_DIR}/smart-organizer.sh" "$SMART_ORGANIZER_BIN"

# Install systemd user service for watch mode
v mkdir -p "${XDG_CONFIG_HOME}/systemd/user"

cat > "${XDG_CONFIG_HOME}/systemd/user/smart-organizer.service" << 'SERVICEEOF'
[Unit]
Description=Smart Organizer Watch Service
After=network.target

[Service]
Type=simple
ExecStart=%h/.local/bin/smart-organizer --watch
Restart=on-failure
RestartSec=10

[Install]
WantedBy=default.target
SERVICEEOF

v systemctl --user daemon-reload
v systemctl --user enable --now smart-organizer.service || true

printf "${STY_GREEN}Smart Organizer installed successfully!${STY_RST}\n"
printf "  Run: smart-organizer --dry-run\n"
printf "  Run: smart-organizer --clean system\n"
printf "  Service: systemctl --user status smart-organizer\n"
