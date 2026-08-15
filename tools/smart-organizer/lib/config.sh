#!/usr/bin/env bash
#
# smart-organizer/lib/config.sh
# Configuration, classification rules, path mappings, and file operations
#

# =============================================================================
# Recovery directory
# =============================================================================

RECOVERY_DIR="${HOME}/.local/share/smart-organizer/recovery"
# consumed by lib/report.sh (sourced-lib consumption is invisible to SC2034)
# shellcheck disable=SC2034
RECOVERY_MANIFEST="${RECOVERY_DIR}/.manifest"

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
    [pages]="documents"
    [numbers]="documents"
    [key]="documents"
    [odp]="documents"
    [ods]="documents"
    [log]="documents"
    [msg]="documents"
    [rst]="documents"
    [adoc]="documents"
    [org]="documents"
    [text]="documents"
    [wiki]="documents"

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
    [heif]="images"
    [raw]="images"
    [arw]="images"
    [cr2]="images"
    [nef]="images"
    [dng]="images"
    [orf]="images"
    [raf]="images"
    [rw2]="images"
    [pef]="images"
    [srw]="images"
    [jxl]="images"
    [qoi]="images"
    [psd]="images"
    [ai]="images"
    [eps]="images"
    [avif]="images"
    [jfif]="images"
    [pbm]="images"
    [pgm]="images"
    [ppm]="images"
    [pnm]="images"
    [xbm]="images"
    [xpm]="images"
    [tga]="images"
    [exr]="images"
    [hdr]="images"
    [ico]="images"

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
    [m2ts]="videos"
    [mts]="videos"
    [ts]="videos"
    [mxf]="videos"
    [ogv]="videos"
    [ogm]="videos"
    [divx]="videos"
    [xvid]="videos"
    [rm]="videos"
    [rmvb]="videos"
    [asf]="videos"
    [f4v]="videos"
    [swf]="videos"
    [yuv]="videos"

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
    [aif]="music"
    [mid]="music"
    [midi]="music"
    [ape]="music"
    [wv]="music"
    [dsf]="music"
    [dff]="music"
    [mka]="music"
    [mod]="music"
    [it]="music"
    [s3m]="music"
    [xm]="music"
    [spc]="music"
    [nsf]="music"
    [gym]="music"
    [sid]="music"
    [ay]="music"
    [gbs]="music"
    [hes]="music"
    [kss]="music"
    [sap]="music"
    [vgm]="music"
    [vgz]="music"

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
    [arj]="archives"
    [lzh]="archives"
    [lha]="archives"
    [zoo]="archives"
    [ace]="archives"
    [arc]="archives"
    [pak]="archives"
    [pk3]="archives"
    [pk4]="archives"
    [bz]="archives"
    [tbz]="archives"
    [cpio]="archives"
    [shar]="archives"
    [lbr]="archives"
    [mar]="archives"
    [sbx]="archives"
    [sea]="archives"
    [sit]="archives"
    [sitx]="archives"
    [zap]="archives"
    [gz]="archives"

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
    [kts]="code"
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
    [zig]="code"
    [nim]="code"
    [cob]="code"
    [cbl]="code"
    [pas]="code"
    [pp]="code"
    [d]="code"
    [erl]="code"
    [hrl]="code"
    [ex]="code"
    [exs]="code"
    [lhs]="code"
    [cl]="code"
    [elisp]="code"
    [rkt]="code"
    [ss]="code"
    [scm]="code"
    [tcl]="code"
    [tk]="code"
    [pl]="code"
    [pm]="code"
    [t]="code"
    [pod]="code"
    [bat]="code"
    [cmd]="code"
    [psm1]="code"
    [psd1]="code"
    [nix]="code"
    [dhall]="code"
    [jsonc]="code"
    [hjson]="code"
    [yuck]="code"

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
    [apk]="installers"
    [xap]="installers"
    [appx]="installers"
    [appxbundle]="installers"
    [msix]="installers"
    [msixbundle]="installers"
    [nupkg]="installers"

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
    [mat]="data"
    [feather]="data"
    [arrow]="data"
    [avro]="data"
    [orc]="data"
    [dat]="data"
    [bin]="data"
    [pcap]="data"
    [pcapng]="data"
    [cap]="data"
    [bloom]="data"
    [idx]="data"
    [dta]="data"
    [sav]="data"
    [zsav]="data"
    [por]="data"
    [sas7bdat]="data"
    [xpt]="data"
    [dbf]="data"
    [mdb]="data"
    [accdb]="data"
    [sql]="data"
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
# Project-based directory detection
# =============================================================================

detect_project_name() {
    local filename="$1"
    local name="${filename%.*}"

    # Pattern: ProjectName_... or ProjectName-... or ProjectName....
    if [[ "$name" =~ ^([A-Za-z][A-Za-z0-9_.-]+)[-_] ]]; then
        echo "${BASH_REMATCH[1]}"
        return 0
    fi

    # Pattern: ..._ProjectName or ...-ProjectName
    if [[ "$name" =~ [_\-]([A-Za-z][A-Za-z0-9_.-]+)$ ]]; then
        echo "${BASH_REMATCH[1]}"
        return 0
    fi

    # Pattern: [ProjectName] ...
    if [[ "$name" =~ \[([A-Za-z][A-Za-z0-9_.-]+)\] ]]; then
        echo "${BASH_REMATCH[1]}"
        return 0
    fi

    return 1
}

get_project_dest() {
    local filepath="$1"
    local filename
    filename="$(basename "$filepath")"
    local project_name

    project_name=$(detect_project_name "$filename")
    if [[ -n "$project_name" ]]; then
        echo "${HOME}/Projects/${project_name}"
        return 0
    fi

    return 1
}

detect_dynamic_dir() {
    local filename="$1"
    local name="${filename%.*}"

    # Pattern: Prefix_... or Prefix-...
    if [[ "$name" =~ ^([A-Za-z][A-Za-z0-9_-]+)[-_] ]]; then
        echo "${BASH_REMATCH[1]}"
        return 0
    fi

    # Pattern: ..._Suffix or ...-Suffix
    if [[ "$name" =~ [_\-]([A-Za-z][A-Za-z0-9_-]+)$ ]]; then
        echo "${BASH_REMATCH[1]}"
        return 0
    fi

    # Pattern: [Category]...
    if [[ "$name" =~ \[([A-Za-z][A-Za-z0-9_-]+)\] ]]; then
        echo "${BASH_REMATCH[1]}"
        return 0
    fi

    return 1
}

get_dynamic_dest() {
    local filepath="$1"
    local dirname

    dirname=$(detect_dynamic_dir "$(basename "$filepath")")
    if [[ -n "$dirname" ]]; then
        echo "${HOME}/${dirname}"
        return 0
    fi

    return 1
}

get_file_destination() {
    local filepath="$1"
    local filename
    filename="$(basename "$filepath")"
    local ext="${filename##*.}"
    ext="${ext,,}"

    # First, check if this looks like a project file
    local project_dest
    project_dest=$(get_project_dest "$filepath")
    if [[ $? -eq 0 ]] && [[ -n "$project_dest" ]]; then
        echo "$project_dest"
        return 0
    fi

    # Then check for dynamic directory creation
    local dynamic_dest
    dynamic_dest=$(get_dynamic_dest "$filepath")
    if [[ $? -eq 0 ]] && [[ -n "$dynamic_dest" ]]; then
        echo "$dynamic_dest"
        return 0
    fi

    # Otherwise, use category-based routing
    local category
    category=$(get_file_category "$filepath")
    if [[ $? -eq 0 ]] && [[ -n "$category" ]]; then
        get_category_dir "$category"
        return $?
    fi

    return 1
}

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
    local filename
    filename="$(basename "$filepath")"
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
        # pattern is a glob BY DESIGN (do not quote RHS)
        # shellcheck disable=SC2053
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
    local filename
    filename="$(basename "$filepath")"
    for pattern in "${PROTECTED_PATTERNS[@]}"; do
        # shellcheck disable=SC2053
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

    # Confirmation prompt for actual deletions
    if [[ "${CONFIRM_DELETE:-true}" == "true" ]]; then
        echo -n "Delete ${target}? (y/N): "
        read -r confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            log_info "Skipped deletion: $target"
            return 0
        fi
    fi

    # Move to recovery directory instead of permanent delete
    local recovery_dir="${HOME}/.local/share/smart-organizer/recovery"
    mkdir -p "$recovery_dir"

    local recovery_name

    recovery_name="$(date +%Y%m%d-%H%M%S)-$(basename "$target")"
    local size
    size=$(file_size_mb "$target")
    mv "$target" "${recovery_dir}/${recovery_name}"
    
    # Write to manifest for recovery tracking
    local manifest_file="${recovery_dir}/.manifest"
    echo "${recovery_name}:${target}" >> "$manifest_file"
    
    increment_deleted "$((size * 1024 * 1024))"
    log_action_dry "Recovered: $target -> ${recovery_name} (reason: $reason)"
}
