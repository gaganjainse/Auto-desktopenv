#!/usr/bin/env bash
#
# smart-organizer/lib/content.sh
# Content-based file classification using file command
#

classify_by_content() {
    local filepath="$1"
    local filename
    filename=$(basename "$filepath")
    local ext="${filename##*.}"
    ext="${ext,,}"

    # Only use content-based classification for unknown or ambiguous extensions
    if [[ -n "${EXT_CATEGORIES[$ext]+x}" ]]; then
        return 1
    fi

    # Check if file command is available
    if ! command -v file >/dev/null 2>&1; then
        return 1
    fi

    # Get MIME type
    local mime_type
    mime_type=$(file -b --mime-type "$filepath" 2>/dev/null || echo "unknown")

    case "$mime_type" in
        text/*)
            # Try to detect code files by content
            if head -n 5 "$filepath" 2>/dev/null | grep -qE '^(#!/|# |// |/*|import |from |require |package |using |namespace )'; then
                echo "code"
                return 0
            fi
            echo "documents"
            return 0
            ;;
        image/*) echo "images" ; return 0 ;;
        video/*) echo "videos" ; return 0 ;;
        audio/*) echo "music" ; return 0 ;;
        application/zip|application/x-rar|application/x-7z-compressed|application/x-tar|application/gzip|application/x-bzip2|application/x-xz)
            echo "archives"
            return 0
            ;;
        application/pdf) echo "documents" ; return 0 ;;
        application/octet-stream)
            # Check for executables
            if head -c 4 "$filepath" 2>/dev/null | grep -qE '^(MZ|PK|\x7fELF)'; then
                echo "installers"
                return 0
            fi
            ;;
        *) ;;
    esac

    return 1
}
