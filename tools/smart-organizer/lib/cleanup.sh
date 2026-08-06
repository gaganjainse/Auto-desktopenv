#!/usr/bin/env bash
#
# smart-organizer/lib/cleanup.sh
# Cache, trash, bloat cleanup
#

# =============================================================================
# Cache cleanup
# =============================================================================

cleanup_cache() {
    log_info "Cleaning cache directories..."

    local cache_dirs=(
        "$HOME/.cache"
        "$HOME/.config"
        "$HOME/.local/share"
    )

    for dir in "${cache_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            continue
        fi

        log_info "Scanning: $dir"

        # Find cache files older than threshold
        find "$dir" -type f -atime +${CACHE_MAX_AGE} -print0 2>/dev/null | \
        while IFS= read -r -d '' file; do
            if is_protected "$file"; then
                continue
            fi

            local size_mb
            size_mb=$(file_size_mb "$file")

            # Only delete files that are small enough (safely)
            if [[ "$size_mb" -lt 100 ]]; then
                safe_delete "$file" "old cache file"
            fi
        done
    done

    log_ok "Cache cleanup completed"
}

# =============================================================================
# Trash cleanup
# =============================================================================

cleanup_trash() {
    log_info "Cleaning trash directories..."

    for trash_dir in "${TRASH_DIRS[@]}"; do
        if [[ ! -d "$trash_dir" ]]; then
            continue
        fi

        log_info "Scanning trash: $trash_dir"

        find "$trash_dir" -type f -print0 2>/dev/null | \
        while IFS= read -r -d '' file; do
            if is_older_than "$file" ${TRASH_MAX_AGE}; then
                safe_delete "$file" "old trash file"
            fi
        done
    done

    log_ok "Trash cleanup completed"
}

# =============================================================================
# Bloat cleanup
# =============================================================================

cleanup_bloat() {
    log_info "Cleaning bloat..."

    # 1. Old log files
    cleanup_old_logs

    # 2. Old package caches
    cleanup_package_cache

    # 3. Old installer zips for installed apps
    cleanup_old_installers

    # 4. Thumbnail caches
    cleanup_thumbnails

    # 5. Browser caches
    cleanup_browser_cache

    # 6. Empty directories
    cleanup_empty_dirs

    log_ok "Bloat cleanup completed"
}

cleanup_old_logs() {
    log_info "Cleaning old logs..."

    local log_dirs=(
        "$HOME/.local/state"
        "$HOME/.cache"
        "$HOME/.config"
    )

    for dir in "${log_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            continue
        fi

        find "$dir" -type f \( -name "*.log" -o -name "*.old" \) -atime +30 -print0 2>/dev/null | \
        while IFS= read -r -d '' file; do
            if is_protected "$file"; then
                continue
            fi
            safe_delete "$file" "old log file"
        done
    done
}

cleanup_package_cache() {
    log_info "Cleaning package caches..."

    # pacman cache (only if on Arch-based system)
    if command -v pacman >/dev/null 2>&1; then
        if [[ -d /var/cache/pacman/pkg ]]; then
            sudo pacman -Sc --noconfirm 2>/dev/null || true
        fi
    fi

    # AUR helper cache
    if command -v yay >/dev/null 2>&1; then
        yay -Sc --noconfirm 2>/dev/null || true
    fi

    # pip cache
    if command -v pip >/dev/null 2>&1; then
        pip cache purge 2>/dev/null || true
    fi

    # npm cache
    if command -v npm >/dev/null 2>&1; then
        npm cache clean --force 2>/dev/null || true
    fi

    # cargo cache
    if [[ -d "$HOME/.cargo/registry/cache" ]]; then
        find "$HOME/.cargo/registry/cache" -type f -atime +30 -delete 2>/dev/null || true
    fi
}

cleanup_old_installers() {
    log_info "Cleaning old installers..."

    # Check for installer files in Downloads
    local installer_dirs=(
        "$HOME/Downloads"
        "$HOME/Downloads/Installers"
    )

    for dir in "${installer_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            continue
        fi

        find "$dir" -maxdepth 1 -type f \( \
            -name "*.deb" -o \
            -name "*.rpm" -o \
            -name "*.pkg.tar.zst" -o \
            -name "*.pkg.tar.xz" -o \
            -name "*.AppImage" -o \
            -name "*.exe" -o \
            -name "*.msi" -o \
            -name "*.dmg" -o \
            -name "*.run" \
        \) -atime +${OLD_INSTALLER_MAX_AGE} -print0 2>/dev/null | \
        while IFS= read -r -d '' file; do
            safe_delete "$file" "old installer"
        done
    done
}

cleanup_thumbnails() {
    log_info "Cleaning old thumbnails..."

    local thumb_dirs=(
        "$HOME/.cache/thumbnails"
        "$HOME/.cache/xfce4/thumbnails"
    )

    for dir in "${thumb_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            continue
        fi

        find "$dir" -type f -atime +30 -print0 2>/dev/null | \
        while IFS= read -r -d '' file; do
            safe_delete "$file" "old thumbnail"
        done
    done
}

cleanup_browser_cache() {
    log_info "Cleaning browser caches..."

    local browser_cache_dirs=(
        "$HOME/.cache/google-chrome"
        "$HOME/.cache/chromium"
        "$HOME/.cache/BraveSoftware"
        "$HOME/.cache/mozilla"
        "$HOME/.cache/msedge"
        "$HOME/.config/google-chrome"
        "$HOME/.config/chromium"
    )

    for dir in "${browser_cache_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            continue
        fi

        # Only clear Cache and Code Cache directories, not profiles
        find "$dir" -maxdepth 2 -type d \( -name "Cache" -o -name "Code Cache" -o -name "GPUCache" \) -print0 2>/dev/null | \
        while IFS= read -r -d '' cache_dir; do
            find "$cache_dir" -type f -atime +7 -print0 2>/dev/null | \
            while IFS= read -r -d '' file; do
                safe_delete "$file" "browser cache"
            done
        done
    done
}

cleanup_empty_dirs() {
    log_info "Cleaning empty directories..."

    local dirs=(
        "$HOME/Downloads"
        "$HOME/Documents"
        "$HOME/Pictures"
        "$HOME/Videos"
        "$HOME/Music"
        "$HOME/Desktop"
        "$HOME/Temp"
    )

    for dir in "${dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            continue
        fi

        find "$dir" -type d -empty -print0 2>/dev/null | \
        while IFS= read -r -d '' empty_dir; do
            if is_protected "$empty_dir"; then
                continue
            fi
            safe_delete "$empty_dir" "empty directory"
        done
    done
}

# =============================================================================
# Main cleanup runner
# =============================================================================

run_cleanup() {
    local targets=("$@")

    log_info "=== Running cleanup mode ==="

    # Check if systemwide cleanup requested
    for target in "${targets[@]}"; do
        if [[ "$target" == "system" ]]; then
            cleanup_cache
            cleanup_trash
            cleanup_bloat
            return 0
        fi
    done

    # Otherwise clean specific targets
    for target in "${targets[@]}"; do
        if [[ ! -d "$target" ]]; then
            continue
        fi

        log_info "Cleaning target: $target"

        # Clean cache subdirectories
        find "$target" -type d -name ".cache" -print0 2>/dev/null | \
        while IFS= read -r -d '' cache_dir; do
            cleanup_cache
        done

        # Clean trash
        cleanup_trash

        # Clean bloat
        cleanup_bloat
    done
}
