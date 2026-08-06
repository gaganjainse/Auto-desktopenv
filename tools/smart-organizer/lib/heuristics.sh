#!/usr/bin/env bash
#
# smart-organizer/lib/heuristics.sh
# Heuristic scoring and classification logic
#

# =============================================================================
# Heuristic scoring
# =============================================================================

# Score a file for organization priority (higher = more important to organize)
# Factors:
#   - File age (older = more likely to be clutter)
#   - File size (larger = more important)
#   - File type (archives, installers = more likely to be temporary)
#   - Path context (Downloads = more likely to be temporary)

score_file() {
    local filepath="$1"
    local score=0

    # Get file info
    local age_days
    age_days=$(file_age_days "$filepath")
    local size_mb
    size_mb=$(file_size_mb "$filepath")
    local category
    category=$(get_file_category "$filepath")

    # Age factor: older files get higher score (more likely to be stale)
    if [[ "$age_days" -gt 90 ]]; then
        score=$((score + 30))
    elif [[ "$age_days" -gt 30 ]]; then
        score=$((score + 20))
    elif [[ "$age_days" -gt 7 ]]; then
        score=$((score + 10))
    fi

    # Size factor: larger files are more important to organize
    if [[ "$size_mb" -gt 1000 ]]; then
        score=$((score + 30))
    elif [[ "$size_mb" -gt 100 ]]; then
        score=$((score + 20))
    elif [[ "$size_mb" -gt 10 ]]; then
        score=$((score + 10))
    fi

    # Category factor
    case "$category" in
        archives|installers|temp|cache)
            score=$((score + 20))
            ;;
        documents|images|videos|music)
            score=$((score + 15))
            ;;
        code|data|models)
            score=$((score + 10))
            ;;
        unknown)
            score=$((score + 5))
            ;;
    esac

    # Path factor
    case "$filepath" in
        */Downloads/*)
            score=$((score + 10))
            ;;
        */temp/*|*/tmp/*)
            score=$((score + 15))
            ;;
        */.cache/*)
            score=$((score + 20))
            ;;
    esac

    echo "$score"
}

# =============================================================================
# Decision engine
# =============================================================================

# Decide what to do with a file
# Returns: move|delete|archive|keep|unknown
decide_action() {
    local filepath="$1"
    local category
    category=$(get_file_category "$filepath")
    local age_days
    age_days=$(file_age_days "$filepath")
    local size_mb
    size_mb=$(file_size_mb "$filepath")

    # Protected files are never touched
    if is_protected "$filepath"; then
        echo "keep"
        return 0
    fi

    # Hidden files are usually config/state, keep them
    if is_hidden "$filepath"; then
        echo "keep"
        return 0
    fi

    # Symlinks are preserved
    if is_symlink "$filepath"; then
        echo "keep"
        return 0
    fi

    # Category-based decisions
    case "$category" in
        cache)
            if [[ "$age_days" -gt 30 ]]; then
                echo "delete"
            else
                echo "keep"
            fi
            ;;
        temp)
            if [[ "$age_days" -gt 7 ]]; then
                echo "delete"
            else
                echo "keep"
            fi
            ;;
        archives)
            # Old archives might be safe to delete if they've been extracted
            if [[ "$age_days" -gt 90 ]]; then
                echo "archive"
            else
                echo "move"
            fi
            ;;
        installers)
            # Old installers for apps that are already installed
            if [[ "$age_days" -gt 90 ]]; then
                echo "delete"
            else
                echo "move"
            fi
            ;;
        documents|images|videos|music|code|data)
            echo "move"
            ;;
        unknown)
            # For unknown files, use scoring
            local score
            score=$(score_file "$filepath")
            if [[ "$score" -gt 50 ]]; then
                echo "delete"
            elif [[ "$score" -gt 30 ]]; then
                echo "archive"
            else
                echo "keep"
            fi
            ;;
        *)
            echo "keep"
            ;;
    esac
}

# =============================================================================
# Folder merge/split heuristics
# =============================================================================

# Find folders that are candidates for merging
# Candidates: folders with same name pattern, or similar content
find_merge_candidates() {
    local dir="$1"
    local threshold="${2:-0.8}"

    if [[ ! -d "$dir" ]]; then
        return 0
    fi

    # Find folders with similar names
    find "$dir" -maxdepth 2 -type d -print0 2>/dev/null | \
    xargs -0 -I{} basename {} | sort | uniq -d
}

# Find folders that are candidates for splitting
# Candidates: folders with too many files, or mixed content types
find_split_candidates() {
    local dir="$1"
    local max_files="${2:-50}"

    if [[ ! -d "$dir" ]]; then
        return 0
    fi

    find "$dir" -maxdepth 1 -type d -print0 2>/dev/null | \
    while IFS= read -r -d '' folder; do
        local count
        count=$(find "$folder" -type f | wc -l)
        if [[ "$count" -gt "$max_files" ]]; then
            echo "$folder ($count files)"
        fi
    done
}

# =============================================================================
# Content-based classification
# =============================================================================

classify_by_content() {
    local filepath="$1"

    # Try to detect file type using file command
    if command -v file >/dev/null 2>&1; then
        local mime_type
        mime_type=$(file -b --mime-type "$filepath" 2>/dev/null || echo "unknown")

        case "$mime_type" in
            text/*)
                if [[ "$filepath" == *.py || "$filepath" == *.js || "$filepath" == *.sh ]]; then
                    echo "code"
                else
                    echo "documents"
                fi
                ;;
            image/*) echo "images" ;;
            video/*) echo "videos" ;;
            audio/*) echo "music" ;;
            application/zip|application/x-rar|application/x-7z-compressed)
                echo "archives"
                ;;
            application/pdf) echo "documents" ;;
            application/octet-stream)
                # Check extension as fallback
                local ext="${filepath##*.}"
                ext="${ext,,}"
                echo "${EXT_CATEGORIES[$ext]:-unknown}"
                ;;
            *) echo "unknown" ;;
        esac
    else
        echo "unknown"
    fi
}
