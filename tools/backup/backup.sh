#!/usr/bin/env bash
#
# shesh-desktop Backup Script
# Automated backup of critical files
#
# Features:
#   - SSH keys backup
#   - Dotfiles backup
#   - Documents backup
#   - Incremental backups with rsync
#   - Encryption support
#   - External drive detection
#
# Usage:
#   backup.sh [OPTIONS] [DESTINATION]
#
# Options:
#   --dry-run    Show what would be done
#   --encrypt    Encrypt backup with GPG
#   --help       Show help
#
# Examples:
#   backup.sh /media/backup
#   backup.sh --encrypt ~/Backups
#   backup.sh --dry-run /media/backup
#

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

DRY_RUN=false
ENCRYPT=false

log_info() { echo -e "${BLUE}[BACKUP]${NC} $*"; }
log_ok() { echo -e "${GREEN}[OK]${NC}   $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

usage() {
    cat <<'EOF'
backup.sh - Automated backup script

USAGE:
    backup.sh [OPTIONS] [DESTINATION]

OPTIONS:
    --dry-run    Show what would be done without making changes
    --encrypt    Encrypt backup with GPG
    --help       Show this help

ARGUMENTS:
    DESTINATION  Backup destination directory

EXAMPLES:
    backup.sh /media/backup
    backup.sh --encrypt ~/Backups
    backup.sh --dry-run /media/backup
EOF
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --encrypt)
            ENCRYPT=true
            shift
            ;;
        --help | -h)
            usage
            exit 0
            ;;
        -*)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
        *)
            DEST="$1"
            shift
            ;;
    esac
done

if [[ -z "${DEST:-}" ]]; then
    DEST="${HOME}/Backups/$(date +%Y%m%d-%H%M%S)"
fi

log_info "Backup destination: $DEST"

if $DRY_RUN; then
    log_info "Running in DRY-RUN mode"
fi

# Create backup directory
if ! $DRY_RUN; then
    mkdir -p "$DEST"
fi

# Backup items
backup_item() {
    local src="$1"
    local dest="$2"
    local label="${3:-$src}"

    if [[ ! -e "$src" ]]; then
        log_warn "$label not found: $src"
        return 0
    fi

    log_info "Backing up: $label"

    if $DRY_RUN; then
        log_info "[DRY-RUN] Would backup $src -> $dest"
        return 0
    fi

    if [[ -d "$src" ]]; then
        mkdir -p "$(dirname "$dest")"
        rsync -a --delete "$src/" "$dest/" 2>/dev/null || cp -r "$src" "$dest"
    elif [[ -f "$src" ]]; then
        mkdir -p "$(dirname "$dest")"
        cp -p "$src" "$dest"
    fi

    log_ok "$label backed up"
}

# 1. SSH keys (critical)
backup_item "$HOME/.ssh" "$DEST/ssh" "SSH keys"

# 2. GPG keys (critical)
backup_item "$HOME/.gnupg" "$DEST/gnupg" "GPG keys"

# 3. Important configs
backup_item "$HOME/.config/git" "$DEST/config/git" "Git config"
backup_item "$HOME/.config/fish" "$DEST/config/fish" "Fish config"
backup_item "$HOME/.config/hypr" "$DEST/config/hypr" "Hyprland config"
backup_item "$HOME/.config/nvim" "$DEST/config/nvim" "Neovim config"

# 4. Documents
backup_item "$HOME/Documents" "$DEST/Documents" "Documents"

# 5. Pictures
backup_item "$HOME/Pictures" "$DEST/Pictures" "Pictures"

# 6. Projects (only critical ones)
if [[ -d "$HOME/Workspace" ]]; then
    backup_item "$HOME/Workspace/shesh-kernel" "$DEST/Workspace/shesh-kernel" "shesh-kernel"
fi

# 7. Package lists
log_info "Backing up package lists..."
if ! $DRY_RUN; then
    mkdir -p "$DEST/package-lists"
    if command -v pacman >/dev/null 2>&1; then
        pacman -Qqe >"$DEST/package-lists/pacman.txt" || echo "WARN: pacman -Qqe failed; pacman.txt incomplete" >&2
        pacman -Qqm >"$DEST/package-lists/aur.txt" || echo "WARN: pacman -Qqm failed; aur.txt incomplete" >&2
    fi
    log_ok "Package lists backed up"
fi

# 8. Create backup manifest
if ! $DRY_RUN; then
    cat >"$DEST/backup-manifest.txt" <<EOF
Backup created: $(date)
Host: $(hostname)
User: $(whoami)
OS: $(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d= -f2 | tr -d '"' || echo "Unknown")
Backup size: $(du -sh "$DEST" | cut -f1)
EOF
    log_ok "Backup manifest created"
fi

# 9. Encryption (optional)
if $ENCRYPT && ! $DRY_RUN; then
    log_info "Encrypting backup with GPG..."
    tar -czf - -C "$(dirname "$DEST")" "$(basename "$DEST")" |
        gpg --symmetric --cipher-algo AES256 -o "${DEST}.tar.gz.gpg"
    log_ok "Backup encrypted: ${DEST}.tar.gz.gpg"
fi

echo ""
log_ok "Backup completed: $DEST"
log_info "Backup size: $(du -sh "$DEST" 2>/dev/null | cut -f1 || echo 'unknown')"
echo ""
