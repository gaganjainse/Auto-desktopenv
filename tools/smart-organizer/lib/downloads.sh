#!/usr/bin/env bash
#
# smart-organizer/lib/downloads.sh
# Downloads folder organization
#

# =============================================================================
# Downloads organization
# =============================================================================

organize_downloads() {
    local target="${1:-$HOME/Downloads}"

    if [[ ! -d "$target" ]]; then
        return 0
    fi

    log_info "Organizing downloads: $target"

    # Skip files that are still downloading (modified in last 60 seconds)
    find "$target" -maxdepth 1 -type f -mmin -60 -print0 2>/dev/null | \
    while IFS= read -r -d '' file; do
        log_info "Skipping active download: $(basename "$file")"
    done

    # Organize files
    find "$target" -maxdepth 1 -type f -mmin +60 -print0 2>/dev/null | \
    while IFS= read -r -d '' file; do
        if is_protected "$file"; then
            continue
        fi

        local filename
        filename=$(basename "$file")
        local ext="${filename##*.}"
        ext="${ext,,}"

        # Skip partial downloads
        case "$ext" in
            part|crdownload|tmp| downloading)
                continue
                ;;
        esac

        # Skip protected patterns
        case "$filename" in
            ssh-backup.tar.gz|*.iso|*.img)
                log_info "Skipping protected file: $filename"
                continue
                ;;
        esac

        # Get category
        local category
        category=$(get_file_category "$file")

        # Determine destination
        local dest_dir
        case "$category" in
            images) dest_dir="$HOME/Pictures/Downloads" ;;
            videos) dest_dir="$HOME/Videos/Downloads" ;;
            music) dest_dir="$HOME/Music/Downloads" ;;
            documents) dest_dir="$HOME/Documents/Downloads" ;;
            archives) dest_dir="$HOME/Archives" ;;
            installers) dest_dir="$HOME/Downloads/Installers" ;;
            code) dest_dir="$HOME/Workspace/Snippets" ;;
            *)
                # Check for app-specific installers
                case "$filename" in
                    *installer*|*setup*|*install*)
                        dest_dir="$HOME/Downloads/Installers"
                        ;;
                    *)
                        dest_dir="$HOME/Downloads"
                        ;;
                esac
                ;;
        esac

        # Move file
        mkdir -p "$dest_dir"
        safe_move "$file" "${dest_dir}/${filename}"
    done

    # Clean up empty directories
    find "$target" -mindepth 1 -maxdepth 1 -type d -empty -print0 2>/dev/null | \
    while IFS= read -r -d '' dir; do
        safe_delete "$dir" "empty downloads subdirectory"
    done
}

# =============================================================================
# Downloads subdirectories
# =============================================================================

organize_downloads_subs() {
    local target="${1:-$HOME/Downloads}"

    if [[ ! -d "$target" ]]; then
        return 0
    fi

    log_info "Organizing downloads subdirectories: $target"

    # Process subdirectories
    find "$target" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null | \
    while IFS= read -r -d '' dir; do
        local dirname
        dirname=$(basename "$dir")

        # Skip special directories
        case "$dirname" in
            Installers|Archives|Temp|Screenshots)
                continue
                ;;
        esac

        # Check if directory contains mostly one type of file
        local file_count
        file_count=$(find "$dir" -type f | wc -l)

        if [[ "$file_count" -eq 0 ]]; then
            safe_delete "$dir" "empty downloads subdirectory"
            continue
        fi

        # Count file types
        local images=0 videos=0 audio=0 docs=0 archives=0 other=0
        find "$dir" -type f -print0 2>/dev/null | \
        while IFS= read -r -d '' file; do
            local category
            category=$(get_file_category "$file")
            case "$category" in
                images) images=$((images + 1)) ;;
                videos) videos=$((videos + 1)) ;;
                music) audio=$((audio + 1)) ;;
                documents) docs=$((docs + 1)) ;;
                archives) archives=$((archives + 1)) ;;
                *) other=$((other + 1)) ;;
            esac
        done

        # Determine dominant type
        local max_type="other"
        local max_count=0
        for type in images videos audio docs archives other; do
            local count
            count=$(eval echo \$$type)
            if [[ "$count" -gt "$max_count" ]]; then
                max_count=$count
                max_type="$type"
            fi
        done

        # Move to appropriate location if dominant type > 80%
        if [[ "$file_count" -gt 0 ]] && [[ $((max_count * 100 / file_count)) -gt 80 ]]; then
            local dest_dir
            case "$max_type" in
                images) dest_dir="$HOME/Pictures/Downloads" ;;
                videos) dest_dir="$HOME/Videos/Downloads" ;;
                music) dest_dir="$HOME/Music/Downloads" ;;
                documents) dest_dir="$HOME/Documents/Downloads" ;;
                archives) dest_dir="$HOME/Archives" ;;
                *) dest_dir="" ;;
            esac

            if [[ -n "$dest_dir" ]]; then
                mkdir -p "$dest_dir"
                safe_move "$dir" "${dest_dir}/${dirname}"
            fi
        fi
    done
}
