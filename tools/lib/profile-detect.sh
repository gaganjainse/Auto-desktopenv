#!/usr/bin/env bash
# profile-detect.sh — Automatic device profile detection for shesh-desktop
#
# This library provides automatic device profile detection based on system
# hardware (DMI/SMBIOS information). It supports:
#   - Automatic detection via DMI/SMBIOS
#   - Manual override via --device flag
#   - Fallback to generic profile
#   - Extensible profile database
#
# Usage: source this file, then call detect_profile

# Profile database: maps DMI product_name patterns to profile names
# Format: "regex_pattern:profile_name"
# First match wins (order matters - more specific first)
PROFILE_DATABASE=(
    "Sword 16 HX.*B14VEKG:shesh"
    "Sword 16 HX:shesh"
    # Add more patterns here as needed:
    # "ThinkPad T14.*Gen.*:thinkpad-t14"
    # "MacBookPro.*:macbook"
)

# Read DMI product name
get_dmi_product_name() {
    cat /sys/class/dmi/id/product_name 2>/dev/null || echo ""
}

# Read DMI product version
get_dmi_product_version() {
    cat /sys/class/dmi/id/product_version 2>/dev/null || echo ""
}

# Read board name
get_dmi_board_name() {
    cat /sys/class/dmi/id/board_name 2>/dev/null || echo ""
}

# Read BIOS vendor
get_dmi_bios_vendor() {
    cat /sys/class/dmi/id/bios_vendor 2>/dev/null || echo ""
}

# Detect profile based on DMI info
detect_profile() {
    local product_name board_name
    product_name="$(get_dmi_product_name)"
    board_name="$(get_dmi_board_name)"

    # Try to match against profile database
    for entry in "${PROFILE_DATABASE[@]}"; do
        local pattern="${entry%%:*}"
        local profile="${entry##*:}"

        if [[ -n "$product_name" ]] && [[ "$product_name" =~ $pattern ]]; then
            echo "$profile"
            return 0
        fi
        if [[ -n "$board_name" ]] && [[ "$board_name" =~ $pattern ]]; then
            echo "$profile"
            return 0
        fi
    done

    # No match found
    echo "generic"
    return 1
}

# Get profile directory path
get_profile_dir() {
    local profile="$1"
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    echo "$script_dir/profiles/$profile"
}

# Check if profile exists
profile_exists() {
    local profile="$1"
    local profile_dir
    profile_dir="$(get_profile_dir "$profile")"
    [[ -d "$profile_dir" ]]
}

# List available profiles
list_profiles() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    if [[ -d "$script_dir/profiles" ]]; then
        for dir in "$script_dir/profiles"/*/; do
            basename "$dir"
        done
    fi
}

# Export functions for use by other scripts
export -f detect_profile
export -f get_profile_dir
export -f profile_exists
export -f list_profiles
export -f get_dmi_product_name
export -f get_dmi_product_version
export -f get_dmi_board_name
export -f get_dmi_bios_vendor

# If run directly, show detected profile
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Detected profile: $(detect_profile)"
    echo "Available profiles: $(list_profiles | tr '\n' ' ')"
    echo "DMI Product: $(get_dmi_product_name)"
    echo "DMI Board: $(get_dmi_board_name)"
fi
