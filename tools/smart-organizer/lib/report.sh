#!/usr/bin/env bash
#
# smart-organizer/lib/report.sh
# Reporting and statistics
#

# Counters
FILES_MOVED=0
FILES_DELETED=0
FILES_HARDLINKED=0
BYTES_MOVED=0
BYTES_DELETED=0
BYTES_HARDLINKED=0

reset_counters() {
    FILES_MOVED=0
    FILES_DELETED=0
    FILES_HARDLINKED=0
    BYTES_MOVED=0
    BYTES_DELETED=0
    BYTES_HARDLINKED=0
}

increment_moved() {
    local size="${1:-0}"
    FILES_MOVED=$((FILES_MOVED + 1))
    BYTES_MOVED=$((BYTES_MOVED + size))
}

increment_deleted() {
    local size="${1:-0}"
    FILES_DELETED=$((FILES_DELETED + 1))
    BYTES_DELETED=$((BYTES_DELETED + size))
}

increment_hardlinked() {
    local size="${1:-0}"
    FILES_HARDLINKED=$((FILES_HARDLINKED + 1))
    BYTES_HARDLINKED=$((BYTES_HARDLINKED + size))
}

human_readable_size() {
    local bytes=$1
    if [[ $bytes -gt 1073741824 ]]; then
        echo "$(awk "BEGIN {printf \"%.2f GB\", $bytes/1073741824}")"
    elif [[ $bytes -gt 1048576 ]]; then
        echo "$(awk "BEGIN {printf \"%.2f MB\", $bytes/1048576}")"
    elif [[ $bytes -gt 1024 ]]; then
        echo "$(awk "BEGIN {printf \"%.2f KB\", $bytes/1024}")"
    else
        echo "${bytes} B"
    fi
}

print_report() {
    echo ""
    log_info "========================================"
    log_info " Smart Organizer Report"
    log_info "========================================"
    echo ""
    echo "Files moved:     $FILES_MOVED ($(human_readable_size $BYTES_MOVED))"
    echo "Files deleted:   $FILES_DELETED ($(human_readable_size $BYTES_DELETED))"
    echo "Files hard-linked: $FILES_HARDLINKED ($(human_readable_size $BYTES_HARDLINKED))"
    echo ""
    local total_saved
    total_saved=$((BYTES_DELETED + BYTES_HARDLINKED))
    echo "Total space affected: $(human_readable_size $total_saved)"
    echo ""
}

# =============================================================================
# Recovery functions
# =============================================================================

# RECOVERY_DIR / RECOVERY_MANIFEST come from lib/config.sh (canonical, sourced first)
list_recovery() {
    if [[ ! -d "$RECOVERY_DIR" ]]; then
        echo "Recovery directory does not exist."
        return 0
    fi

    local count=0
    echo "Recovery directory: $RECOVERY_DIR"
    echo ""
    for item in "$RECOVERY_DIR"/*; do
        if [[ -e "$item" ]] && [[ "$(basename "$item")" != ".manifest" ]]; then
            local name
            name=$(basename "$item")
            local date
            date=$(stat -c %y "$item" 2>/dev/null | cut -d'.' -f1 || echo "unknown")
            local size
            size=$(du -sh "$item" 2>/dev/null | cut -f1 || echo "unknown")
            local original=""
            if [[ -f "$RECOVERY_MANIFEST" ]]; then
                original=$(grep "^${name}:" "$RECOVERY_MANIFEST" 2>/dev/null | cut -d: -f2 || echo "")
            fi
            if [[ -n "$original" ]]; then
                echo "  $name -> $original ($size, $date)"
            else
                echo "  $name ($size, $date)"
            fi
            count=$((count + 1))
        fi
    done
    echo ""
    echo "Total items: $count"
}

restore_from_recovery() {
    local name="$1"
    local source="$RECOVERY_DIR/$name"
    local original_path=""

    if [[ ! -e "$source" ]]; then
        log_error "Item not found in recovery: $name"
        return 1
    fi

    # Look up original path from manifest
    if [[ -f "$RECOVERY_MANIFEST" ]]; then
        original_path=$(grep "^${name}:" "$RECOVERY_MANIFEST" 2>/dev/null | cut -d: -f2 || echo "")
    fi

    # Fallback: try to extract from name
    if [[ -z "$original_path" ]]; then
        local original_name="${name#*-*-}"
        original_path="$HOME/$original_name"
    fi

    if [[ -e "$original_path" ]]; then
        log_error "Cannot restore: $original_path already exists"
        return 1
    fi

    mkdir -p "$(dirname "$original_path")"
    mv "$source" "$original_path"
    log_ok "Restored: $name -> $original_path"
}

purge_recovery() {
    if [[ ! -d "$RECOVERY_DIR" ]]; then
        echo "Recovery directory does not exist."
        return 0
    fi

    local count=0
    for item in "$RECOVERY_DIR"/*; do
        if [[ -e "$item" ]] && [[ "$(basename "$item")" != ".manifest" ]]; then
            rm -rf "$item"
            count=$((count + 1))
        fi
    done

    # Remove manifest too
    if [[ -f "$RECOVERY_MANIFEST" ]]; then
        rm -f "$RECOVERY_MANIFEST"
    fi

    log_ok "Purged $count items from recovery directory"
}
