#!/usr/bin/env bash
#
# smart-organizer/lib/config.sh
# Configuration, classification rules, and path mappings
#

# =============================================================================
# File type classification rules
# =============================================================================

# Extension to category mapping
declare -A EXT_CATEGORIES=(
    # Documents
    [pdf]="documents"
    [doc]="documents"
    [docx]="documents"
    [txt]="documents"
    [rtf]="documents"
    [odt]="documents"
    [md]="documents"
    [epub]="documents"
    [mobi]="documents"
    [xls]="documents"
    [xlsx]="documents"
    [ppt]="documents"
    [pptx]="documents"
    [csv]="documents"
    [json]="documents"
    [xml]="documents"
    [yaml]="documents"
    [yml]="documents"
    [tex]="documents"

    # Images
    [jpg]="images"
    [jpeg]="images"
    [png]="images"
    [gif]="images"
    [bmp]="images"
    [svg]="images"
    [webp]="images"
    [ico]="images"
    [tiff]="images"
    [tif]="images"
    [heic]="images"
    [raw]="images"
    [arw]="images"
    [cr2]="images"
    [nef]="images"
    [dng]="images"

    # Videos
    [mp4]="videos"
    [mkv]="videos"
    [avi]="videos"
    [mov]="videos"
    [wmv]="videos"
    [flv]="videos"
    [webm]="videos"
    [m4v]="videos"
    [mpg]="videos"
    [mpeg]="videos"
    [3gp]="videos"
    [vob]="videos"

    # Audio
    [mp3]="music"
    [wav]="music"
    [flac]="music"
    [aac]="music"
    [ogg]="music"
    [wma]="music"
    [m4a]="music"
    [opus]="music"
    [alac]="music"
    [aiff]="music"
    [mid]="music"
    [midi]="music"

    # Archives
    [zip]="archives"
    [rar]="archives"
    [7z]="archives"
    [tar]="archives"
    [gz]="archives"
    [bz2]="archives"
    [xz]="archives"
    [tgz]="archives"
    [tbz2]="archives"
    [zst]="archives"
    [lz]="archives"
    [lzma]="archives"
    [cab]="archives"
    [iso]="archives"
    [img]="archives"
    [dmg]="archives"
    [pkg]="archives"
    [deb]="archives"
    [rpm]="archives"

    # Code/Development
    [py]="code"
    [js]="code"
    [ts]="code"
    [jsx]="code"
    [tsx]="code"
    [c]="code"
    [cpp]="code"
    [h]="code"
    [hpp]="code"
    [java]="code"
 [kt]="code"
    [rs]="code"
    [go]="code"
    [rb]="code"
    [php]="code"
    [swift]="code"
    [m]="code"
    [sh]="code"
    [bash]="code"
    [zsh]="code"
    [fish]="code"
    [ps1]="code"
    [sql]="code"
    [html]="code"
    [css]="code"
    [scss]="code"
    [less]="code"
    [vue]="code"
    [svelte]="code"
    [lua]="code"
    [r]="code"
    [asm]="code"
    [dart]="code"
    [ex]="code"
    [exs]="code"
    [hs]="code"
    [ml]="code"
    [scala]="code"
    [clj]="code"
    [lisp]="code"
    [el]="code"
    [vim]="code"
    [nvim]="code"
    [lock]="code"
    [toml]="code"
    [ini]="code"
    [cfg]="code"
    [conf]="code"

    # Executables/Installers
    [exe]="installers"
    [msi]="installers"
    [appimage]="installers"
    [flatpak]="installers"
    [snap]="installers"
    [deb]="installers"
    [rpm]="installers"
    [pkg]="installers"
    [dmg]="installers"
    [run]="installers"
    [bin]="installers"
    [app]="installers"

    # Fonts
    [ttf]="fonts"
    [otf]="fonts"
    [woff]="fonts"
    [woff2]="fonts"

    # Data
    [db]="data"
    [sqlite]="data"
    [sqlite3]="data"
    [parquet]="data"
    [csv]="data"
    [pkl]="data"
    [pickle]="data"
    [h5]="data"
    [hdf5]="data"
    [npy]="data"
    [npz]="data"
)

# Path-based classification rules (checked before extension)
declare -A PATH_RULES=(
    ["*/Downloads/*"]="downloads"
    ["*/Documents/*"]="documents"
    ["*/Pictures/*"]="images"
    ["*/Videos/*"]="videos"
    ["*/Music/*"]="music"
    ["*/Desktop/*"]="desktop"
    ["*/.cache/*"]="cache"
    ["*/.config/*"]="config"
    ["*/.local/share/*"]="local_share"
    ["*/tmp/*"]="temp"
    ["*/temp/*"]="temp"
    ["*/Archives/*"]="archives"
    ["*/archive/*"]="archives"
    ["*/Models/*"]="models"
    ["*/Datasets/*"]="datasets"
    ["*/Workspace/*"]="workspace"
    ["*/Projects/*"]="projects"
    ["*/AI/*"]="ai"
    ["*/venv/*"]="venv"
    ["*/.venv/*"]="venv"
    ["*/node_modules/*"]="node_modules"
    ["*/.git/*"]="git"
    ["*/backup/*"]="backups"
    ["*/Backup/*"]="backups"
)

# =============================================================================
# Category to target directory mapping
# =============================================================================

get_category_dir() {
    local category="$1"
    local base="${2:-$HOME}"

    case "$category" in
        documents) echo "${base}/Documents" ;;
        images)    echo "${base}/Pictures" ;;
        videos)    echo "${base}/Videos" ;;
        music)     echo "${base}/Music" ;;
        archives)  echo "${base}/Archives" ;;
        code)      echo "${base}/Workspace" ;;
        installers) echo "${base}/Downloads/Installers" ;;
        fonts)     echo "${base}/.local/share/fonts" ;;
        data)      echo "${base}/Datasets" ;;
        cache)     echo "${base}/.cache" ;;
        config)    echo "${base}/.config" ;;
        temp)      echo "${base}/Temp" ;;
        desktop)   echo "${base}/Desktop" ;;
        downloads) echo "${base}/Downloads" ;;
        workspace) echo "${base}/Workspace" ;;
        projects)  echo "${base}/Projects" ;;
        ai)        echo "${base}/AI" ;;
        models)    echo "${base}/Models" ;;
        datasets)  echo "${base}/Datasets" ;;
        backups)   echo "${base}/Backups" ;;
        venv)      echo "${base}/.venv" ;;
        node_modules) echo "${base}/node_modules" ;;
        git)       return 1 ;; # Don't move .git
        local_share) return 1 ;; # Don't move .local/share
        *)         return 1 ;;
    esac
}

# =============================================================================
# Heuristic scoring
# =============================================================================

get_file_category() {
    local filepath="$1"
    local filename="$(basename "$filepath")"
    local ext="${filename##*.}"
    ext="${ext,,}" # lowercase

    # Special case: files already in Downloads should be classified by extension,
    # not locked to the "downloads" path category. This lets Downloads act as a
    # sorting buffer whose contents can be routed to Downloads subfolders or
    # promoted later by age-based rules.
    if [[ "$filepath" == */Downloads/* ]]; then
        if [[ -n "${EXT_CATEGORIES[$ext]+x}" ]]; then
            echo "${EXT_CATEGORIES[$ext]}"
            return 0
        fi
        echo "unknown"
        return 1
    fi

    # Check path-based rules first
    for pattern in "${!PATH_RULES[@]}"; do
        if [[ "$filepath" == $pattern ]]; then
            echo "${PATH_RULES[$pattern]}"
            return 0
        fi
    done

    # Check extension-based rules
    if [[ -n "${EXT_CATEGORIES[$ext]+x}" ]]; then
        echo "${EXT_CATEGORIES[$ext]}"
        return 0
    fi

    # Try content-based classification as fallback
    if [[ -f "$filepath" ]]; then
        local content_category
        content_category=$(classify_by_content "$filepath")
        if [[ -n "$content_category" ]]; then
            echo "$content_category"
            return 0
        fi
    fi

    # No match
    echo "unknown"
    return 1
}

is_protected() {
    local filepath="$1"
    local filename="$(basename "$filepath")"

    for pattern in "${PROTECTED_PATTERNS[@]}"; do
        if [[ "$filename" == $pattern ]]; then
            return 0
        fi
    done

    return 1
}

# =============================================================================
# File operations
# =============================================================================

safe_move() {
    local src="$1"
    local dest="$2"

    if [[ ! -e "$src" ]]; then
        return 1
    fi

    # Create destination directory if needed
    mkdir -p "$(dirname "$dest")"

    if is_dry_run; then
        log_action_dry "Would move: $src -> $dest"
        return 0
    fi

    # Handle existing destination
    if [[ -e "$dest" ]]; then
        local base="${dest%.*}"
        local ext="${dest##*.}"
        local counter=1
        while [[ -e "${base}_${counter}.${ext}" ]]; do
            ((counter++))
        done
        dest="${base}_${counter}.${ext}"
    fi

    local size
    size=$(file_size_mb "$src")
    mv "$src" "$dest"
    increment_moved "$((size * 1024 * 1024))"
    log_action_dry "Moved: $(basename "$src") -> $dest"
}

safe_delete() {
    local target="$1"
    local reason="$2"

    if [[ ! -e "$target" ]]; then
        return 1
    fi

    if is_dry_run; then
        log_action_dry "Would delete: $target (reason: $reason)"
        return 0
    fi

    # Move to trash instead of permanent delete
    local trash_dir="${HOME}/.local/share/Trash/files"
    mkdir -p "$trash_dir"

    local trash_name="$(date +%Y%m%d-%H%M%S)-$(basename "$target")"
    local size
    size=$(file_size_mb "$target")
    mv "$target" "${trash_dir}/${trash_name}"
    increment_deleted "$((size * 1024 * 1024))"
    log_action_dry "Trashed: $target -> ${trash_name} (reason: $reason)"
}
