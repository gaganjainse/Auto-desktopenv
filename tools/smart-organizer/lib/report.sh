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
    local total_saved=$((BYTES_DELETED + BYTES_HARDLINKED))
    echo "Total space affected: $(human_readable_size $total_saved)"
    echo ""
}
