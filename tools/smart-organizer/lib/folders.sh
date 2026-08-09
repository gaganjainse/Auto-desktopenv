#!/usr/bin/env bash
#
# smart-organizer/lib/folders.sh
# Folder operations: create, move, merge, split, dedupe
#

# =============================================================================
# Folder creation
# =============================================================================

create_folders() {
    local base_dir="${1:-$HOME}"

    log_info "Creating organized folder structure in: $base_dir"

    # Standard directories
    local standard_dirs=(
        "Downloads"
        "Documents"
        "Pictures"
        "Videos"
        "Music"
        "Desktop"
        "Temp"
        "Archives"
        "Backups"
        "Workspace"
        "Projects"
        "AI"
        "Models"
        "Datasets"
        "bin"
    )

    for dir in "${standard_dirs[@]}"; do
        local path="${base_dir}/${dir}"
        if [[ ! -d "$path" ]]; then
            mkdir -p "$path"
            log_info "Created: $path"
        fi
    done

    # AI/ML subdirectories
    mkdir -p "$base_dir/Models"/{ollama,huggingface,checkpoints,embeddings}
    mkdir -p "$base_dir/Datasets"/{raw,processed,experiments,external}

    # Workspace subdirectories
    mkdir -p "$base_dir/Workspace"/{personal,work,archived}

    # Downloads subdirectories
    mkdir -p "$base_dir/Downloads"/{Installers,Archives,Temp}

    log_ok "Folder structure created"
}

# =============================================================================
# Folder merge
# =============================================================================

merge_folders() {
    local src="$1"
    local dest="$2"

    if [[ ! -d "$src" ]]; then
        log_error "Source folder does not exist: $src"
        return 1
    fi

    if [[ ! -d "$dest" ]]; then
        log_error "Destination folder does not exist: $dest"
        return 1
    fi

    log_info "Merging: $src -> $dest"

    if is_dry_run; then
        log_action_dry "Would merge $src into $dest"
        return 0
    fi

    # Move contents with duplicate handling
    find "$src" -mindepth 1 -maxdepth 1 -print0 2>/dev/null | \
    while IFS= read -r -d '' item; do
        local basename
        basename=$(basename "$item")
        local dest_path="${dest}/${basename}"

        if [[ -e "$dest_path" ]]; then
            # Handle duplicates
            if [[ -d "$item" ]] && [[ -d "$dest_path" ]]; then
                # Recursively merge directories
                merge_folders "$item" "$dest_path"
            elif [[ -f "$item" ]] && [[ -f "$dest_path" ]]; then
                # Check if files are identical
                if diff -q "$item" "$dest_path" >/dev/null 2>&1; then
                    safe_delete "$item" "duplicate file"
                else
                    # Rename and move
                    local counter=1
                    local base="${dest_path%.*}"
                    local ext="${dest_path##*.}"
                    while [[ -e "${base}_${counter}.${ext}" ]]; do
                        ((counter++))
                    done
                    mv "$item" "${base}_${counter}.${ext}"
                fi
            else
                # Type mismatch, just move with suffix
                local counter=1
                while [[ -e "${dest_path}_${counter}" ]]; do
                    ((counter++))
                done
                mv "$item" "${dest_path}_${counter}"
            fi
        else
            mv "$item" "$dest_path"
        fi
    done

    # Remove empty source directory
    if is_empty_dir "$src"; then
        safe_delete "$src" "empty folder after merge"
    fi

    log_ok "Merge completed"
}

# =============================================================================
# Folder split
# =============================================================================

split_folder() {
    local folder="$1"
    local max_files="${2:-50}"

    if [[ ! -d "$folder" ]]; then
        log_error "Folder does not exist: $folder"
        return 1
    fi

    log_info "Splitting folder: $folder (max $max_files files per subfolder)"

    if is_dry_run; then
        log_action_dry "Would split $folder into subfolders of max $max_files files"
        return 0
    fi

    local counter=1
    local current_subfolder=""
    local file_count=0

    find "$folder" -maxdepth 1 -type f -print0 2>/dev/null | \
    sort -z | \
    while IFS= read -r -d '' file; do
        if [[ "$file_count" -eq 0 ]] || [[ "$file_count" -ge "$max_files" ]]; then
            current_subfolder="${folder}/part_${counter}"
            mkdir -p "$current_subfolder"
            file_count=0
            counter=$((counter + 1))
        fi

        mv "$file" "$current_subfolder/"
        file_count=$((file_count + 1))
    done

    log_ok "Split completed: created $((counter - 1)) subfolders"
}

# =============================================================================
# Deduplication
# =============================================================================

dedupe_folders() {
    local base_dir="${1:-$HOME}"

    log_info "Deduplicating folders in: $base_dir"

    # Find duplicate files across the system (exclude first occurrence)
    local duplicates
    duplicates=$(find_duplicates "$base_dir" "" false)

    if [[ -n "$duplicates" ]]; then
        log_info "Found duplicates, cleaning up..."
        echo "$duplicates" | while read -r filepath; do
            # Keep the first occurrence, delete duplicates
            safe_delete "$filepath" "duplicate file"
        done
    fi

    log_ok "Deduplication completed"
}

# =============================================================================
# Hard-link deduplication
# =============================================================================

dedupe_hardlink() {
    local base_dir="${1:-$HOME}"

    log_info "Hard-link deduplication in: $base_dir"

    # Find duplicate files (include first occurrence for linking)
    local duplicates
    duplicates=$(find_duplicates "$base_dir" "" true)

    if [[ -z "$duplicates" ]]; then
        log_info "No duplicates found"
        return 0
    fi

    # Group by hash and hard-link duplicates to first file
    local current_hash=""
    local first_file=""

    echo "$duplicates" | while read -r hash filepath; do
        if [[ -z "$first_file" ]]; then
            first_file="$filepath"
            current_hash="$hash"
        elif [[ "$hash" == "$current_hash" ]]; then
            # Replace duplicate with hard link to first file
            if is_dry_run; then
                log_action_dry "Would hard-link: $filepath -> $first_file"
            else
                local size
                size=$(file_size_mb "$filepath")
                ln -f "$first_file" "$filepath" 2>/dev/null || true
                increment_hardlinked "$((size * 1024 * 1024))"
                log_action "Hard-linked: $filepath -> $first_file"
            fi
        else
            # New group
            first_file="$filepath"
            current_hash="$hash"
        fi
    done

    log_ok "Hard-link deduplication completed"
}

# =============================================================================
# Main folder operations runner
# =============================================================================

run_folder_ops() {
    local targets=("$@")

    log_info "=== Running folder operations ==="

    for target in "${targets[@]}"; do
        if [[ "$target" == "system" ]]; then
            # Systemwide folder operations
            create_folders "$HOME"
            dedupe_folders "$HOME"
            continue
        fi

        if [[ ! -d "$target" ]]; then
            continue
        fi

        log_info "Processing folder: $target"

        # Create standard subdirectories if target is a home-like directory
        if [[ "$target" == "$HOME" ]]; then
            create_folders "$target"
        fi

        # Find and handle merge candidates
        local merge_candidates
        merge_candidates=$(find_merge_candidates "$target")
        if [[ -n "$merge_candidates" ]]; then
            log_info "Found merge candidates: $merge_candidates"
            # Would need user confirmation in interactive mode
        fi

        # Find and handle split candidates
        local split_candidates
        split_candidates=$(find_split_candidates "$target")
        if [[ -n "$split_candidates" ]]; then
            log_info "Found split candidates: $split_candidates"
            # Would need user confirmation in interactive mode
        fi

        # Deduplicate
        dedupe_folders "$target"
    done
}
