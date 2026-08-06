#!/usr/bin/env bash
#
# smart-organizer/lib/media.sh
# Pictures, Videos, Music, Documents organization
#

# =============================================================================
# Media organization
# =============================================================================

organize_media() {
    local target="$1"

    if [[ ! -d "$target" ]]; then
        return 0
    fi

    log_info "Organizing media in: $target"

    # Process files in target directory (non-recursive for top-level)
    find "$target" -maxdepth 1 -type f -print0 2>/dev/null | \
    while IFS= read -r -d '' file; do
        organize_file "$file"
    done

    # Recursively process subdirectories (but not hidden or protected)
    find "$target" -mindepth 1 -maxdepth 3 -type d -print0 2>/dev/null | \
    while IFS= read -r -d '' dir; do
        if is_protected "$dir" || is_exempt "$dir" || is_hidden "$dir"; then
            continue
        fi
        organize_media "$dir"
    done
}

organize_file() {
    local filepath="$1"

    if is_protected "$filepath"; then
        return 0
    fi

    if is_hidden "$filepath"; then
        return 0
    fi

    if is_symlink "$filepath"; then
        return 0
    fi

    local category
    category=$(get_file_category "$filepath")

    case "$category" in
        images|videos|music|documents|code|archives|data|installers|fonts)
            local target_dir
            target_dir=$(get_category_dir "$category")
            if [[ -n "$target_dir" ]]; then
                local dest="${target_dir}/$(basename "$filepath")"
                safe_move "$filepath" "$dest"
            fi
            ;;
        *)
            # Unknown files stay where they are
            ;;
    esac
}

# =============================================================================
# Pictures organization
# =============================================================================

organize_pictures() {
    local target="${1:-$HOME/Pictures}"

    if [[ ! -d "$target" ]]; then
        return 0
    fi

    log_info "Organizing pictures: $target"

    # Create standard subdirectories
    mkdir -p "$target"/{Screenshots,Wallpapers,Edited,Downloads}

    find "$target" -maxdepth 1 -type f \( \
        -iname "*.jpg" -o \
        -iname "*.jpeg" -o \
        -iname "*.png" -o \
        -iname "*.gif" -o \
        -iname "*.webp" -o \
        -iname "*.bmp" -o \
        -iname "*.svg" \
    \) -print0 2>/dev/null | \
    while IFS= read -r -d '' file; do
        local filename
        filename=$(basename "$file")

        # Heuristic: screenshots usually have "screenshot" in name
        if [[ "$filename" =~ [Ss]creenshot ]]; then
            safe_move "$file" "$target/Screenshots/$filename"
        # Heuristic: wallpapers usually have "wallpaper" in name or are in wallpaper folders
        elif [[ "$filename" =~ [Ww]allpaper ]]; then
            safe_move "$file" "$target/Wallpapers/$filename"
        else
            safe_move "$file" "$target/Downloads/$filename"
        fi
    done
}

# =============================================================================
# Videos organization
# =============================================================================

organize_videos() {
    local target="${1:-$HOME/Videos}"

    if [[ ! -d "$target" ]]; then
        return 0
    fi

    log_info "Organizing videos: $target"

    mkdir -p "$target"/{Movies,Shows,Recordings,Clips}

    find "$target" -maxdepth 1 -type f \( \
        -iname "*.mp4" -o \
        -iname "*.mkv" -o \
        -iname "*.avi" -o \
        -iname "*.mov" -o \
        -iname "*.webm" -o \
        -iname "*.m4v" \
    \) -print0 2>/dev/null | \
    while IFS= read -r -d '' file; do
        local filename
        filename=$(basename "$file")

        if [[ "$filename" =~ [Ss]creen ]]; then
            safe_move "$file" "$target/Recordings/$filename"
        elif [[ "$filename" =~ [Cc]lip ]]; then
            safe_move "$file" "$target/Clips/$filename"
        elif [[ "$filename" =~ [Ss]how|[Ss]eries|[Ee]pisode ]]; then
            safe_move "$file" "$target/Shows/$filename"
        else
            safe_move "$file" "$target/Movies/$filename"
        fi
    done
}

# =============================================================================
# Music organization
# =============================================================================

organize_music() {
    local target="${1:-$HOME/Music}"

    if [[ ! -d "$target" ]]; then
        return 0
    fi

    log_info "Organizing music: $target"

    mkdir -p "$target"/{Albums,Singles,Playlists,Audiobooks}

    find "$target" -maxdepth 1 -type f \( \
        -iname "*.mp3" -o \
        -iname "*.flac" -o \
        -iname "*.wav" -o \
        -iname "*.aac" -o \
        -iname "*.ogg" -o \
        -iname "*.m4a" -o \
        -iname "*.opus" \
    \) -print0 2>/dev/null | \
    while IFS= read -r -d '' file; do
        local filename
        filename=$(basename "$file")

        if [[ "$filename" =~ [Aa]udiobook ]]; then
            safe_move "$file" "$target/Audiobooks/$filename"
        elif [[ "$filename" =~ [Pp]laylist ]]; then
            safe_move "$file" "$target/Playlists/$filename"
        else
            safe_move "$file" "$target/Singles/$filename"
        fi
    done
}

# =============================================================================
# Documents organization
# =============================================================================

organize_documents() {
    local target="${1:-$HOME/Documents}"

    if [[ ! -d "$target" ]]; then
        return 0
    fi

    log_info "Organizing documents: $target"

    mkdir -p "$target"/{PDFs,Word,Excel,PowerPoint,Text,Images,Archives,Other}

    find "$target" -maxdepth 1 -type f -print0 2>/dev/null | \
    while IFS= read -r -d '' file; do
        local filename
        filename=$(basename "$file")
        local ext="${filename##*.}"
        ext="${ext,,}"

        case "$ext" in
            pdf) safe_move "$file" "$target/PDFs/$filename" ;;
            doc|docx) safe_move "$file" "$target/Word/$filename" ;;
            xls|xlsx|csv) safe_move "$file" "$target/Excel/$filename" ;;
            ppt|pptx) safe_move "$file" "$target/PowerPoint/$filename" ;;
            txt|md|rtf|odt) safe_move "$file" "$target/Text/$filename" ;;
            jpg|jpeg|png|gif|webp|svg|bmp)
                safe_move "$file" "$target/Images/$filename"
                ;;
            zip|rar|7z|tar|gz|bz2|xz)
                safe_move "$file" "$target/Archives/$filename"
                ;;
            *) safe_move "$file" "$target/Other/$filename" ;;
        esac
    done
}
