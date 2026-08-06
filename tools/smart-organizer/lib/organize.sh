#!/usr/bin/env bash
#
# smart-organizer/lib/organize.sh
# File organization runner
#

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
