#!/usr/bin/env bash
# profile-detect.sh — automatic device profile detection for shesh-desktop.
#
# Only exact, hardware-specific matches may select the shesh profile.
# Unknown hardware always falls back to generic.
set -euo pipefail

PROFILE_DATABASE=(
    "Sword 16 HX B14VEKG:shesh"
)

get_dmi_product_name(){
    if [[ -r /sys/class/dmi/id/product_name ]]; then cat /sys/class/dmi/id/product_name; else printf ''; fi
}
get_dmi_board_name(){
    if [[ -r /sys/class/dmi/id/board_name ]]; then cat /sys/class/dmi/id/board_name; else printf ''; fi
}

detect_profile(){
    local product_name board_name entry pattern profile
    product_name="$(get_dmi_product_name)"
    board_name="$(get_dmi_board_name)"
    for entry in "${PROFILE_DATABASE[@]}"; do
        pattern="${entry%%:*}"
        profile="${entry##*:}"
        if [[ -n "$product_name" && "$product_name" =~ $pattern ]]; then
            printf '%s' "$profile"
            return 0
        fi
        if [[ -n "$board_name" && "$board_name" =~ $pattern ]]; then
            printf '%s' "$profile"
            return 0
        fi
    done
    printf 'generic'
    return 0
}

get_profile_dir(){
    local profile="$1"
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    printf '%s/profiles/%s' "$script_dir" "$profile"
}

profile_exists(){ [[ -d "$(get_profile_dir "$1")" ]]; }

list_profiles(){
    local script_dir dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    [[ -d "$script_dir/profiles" ]] || return 0
    for dir in "$script_dir/profiles"/*/; do basename "$dir"; done
}

export -f detect_profile get_profile_dir profile_exists list_profiles get_dmi_product_name get_dmi_board_name

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    printf 'Detected profile: %s\n' "$(detect_profile)"
    printf 'Available profiles: %s\n' "$(list_profiles | tr '\n' ' ')"
    printf 'DMI Product: %s\n' "$(get_dmi_product_name)"
    printf 'DMI Board: %s\n' "$(get_dmi_board_name)"
fi
