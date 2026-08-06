#!/usr/bin/env bash
#
# smart-organizer/lib/organize.sh
# File organization runner
#

promote_downloads() {
    log_info "Promoting old files from Downloads subfolders to main libraries..."

    local promotion_age="${DOWNLOADS_PROMOTION_AGE:-30}"

    # Promote from ~/Documents/Downloads to ~/Documents
    if [[ -d "$HOME/Documents/Downloads" ]]; then
        find "$HOME/Documents/Downloads" -maxdepth 1 -type f -atime +"$promotion_age" -print0 2>/dev/null | \
        while IFS= read -r -d '' file; do
            local filename
            filename=$(basename "$file")
            local dest="$HOME/Documents/$filename"
            safe_move "$file" "$dest"
        done
    fi

    # Promote from ~/Pictures/Downloads to ~/Pictures
    if [[ -d "$HOME/Pictures/Downloads" ]]; then
        find "$HOME/Pictures/Downloads" -maxdepth 1 -type f -atime +"$promotion_age" -print0 2>/dev/null | \
        while IFS= read -r -d '' file; do
            local filename
            filename=$(basename "$file")
            local dest="$HOME/Pictures/$filename"
            safe_move "$file" "$dest"
        done
    fi

    # Promote from ~/Videos/Downloads to ~/Videos
    if [[ -d "$HOME/Videos/Downloads" ]]; then
        find "$HOME/Videos/Downloads" -maxdepth 1 -type f -atime +"$promotion_age" -print0 2>/dev/null | \
        while IFS= read -r -d '' file; do
            local filename
            filename=$(basename "$file")
            local dest="$HOME/Videos/$filename"
            safe_move "$file" "$dest"
        done
    fi

    # Promote from ~/Music/Downloads to ~/Music
    if [[ -d "$HOME/Music/Downloads" ]]; then
        find "$HOME/Music/Downloads" -maxdepth 1 -type f -atime +"$promotion_age" -print0 2>/dev/null | \
        while IFS= read -r -d '' file; do
            local filename
            filename=$(basename "$file")
            local dest="$HOME/Music/$filename"
            safe_move "$file" "$dest"
        done
    fi

    # Clean up empty Downloads subdirectories after promotion
    for subdir in Documents Pictures Videos Music; do
        if [[ -d "$HOME/$subdir/Downloads" ]] && is_empty_dir "$HOME/$subdir/Downloads"; then
            safe_delete "$HOME/$subdir/Downloads" "empty downloads subdirectory after promotion"
        fi
    done

    log_ok "Downloads promotion completed"
}

run_organize() {
    local targets=("$@")

    log_info "=== Running organize mode ==="

    for target in "${targets[@]}"; do
        if [[ "$target" == "system" ]]; then
            # Systemwide organization
            organize_downloads "$HOME/Downloads"
            organize_documents "$HOME/Documents"
            organize_pictures "$HOME/Pictures"
            organize_videos "$HOME/Videos"
            organize_music "$HOME/Music"
            promote_downloads
            continue
        fi

        if [[ ! -d "$target" ]]; then
            continue
        fi

        log_info "Organizing target: $target"

        # Determine what type of directory this is
        case "$target" in
            *[Dd]ownload*)
                organize_downloads "$target"
                organize_downloads_subs "$target"
                ;;
            *[Dd]ocument*)
                organize_documents "$target"
                ;;
            *[Pp]icture*|*[Pp]hoto*)
                organize_pictures "$target"
                ;;
            *[Vv]ideo*)
                organize_videos "$target"
                ;;
            *[Mm]usic*|*[Aa]udio*)
                organize_music "$target"
                ;;
            *)
                # Generic organization
                organize_media "$target"
                ;;
        esac
    done

    log_ok "Organization completed"
}
