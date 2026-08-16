-- profiles/shesh/hypr-custom-general.lua
-- Copy/symlink to ~/.config/hypr/custom/general.lua OR append its content.
-- MSI Sword 16 HX B14VEKG: 1920x1200 @ 144Hz internal panel (eDP-1).
-- SEE: docs/SHESH/04_DEVICE_PROFILE.md
--
-- All hl.config() calls use the single-table style (the only form the hl API
-- accepts). The old two-argument style, e.g. hl.config("monitor", "..."), errors
-- with "argument must be a table".

-- Force the internal panel to its native mode. The panel does not always
-- advertise 144Hz over EDID on this muxed MSI, so let Hyprland pick the
-- preferred mode rather than hardcoding a rate that may not exist — forcing
-- 1920x1200@144 when the panel only reports 1920x1200 blanks the screen.
hl.monitor({ output = "eDP-1", mode = "preferred", position = "auto" })

-- Default to the iGPU driving the compositor (better battery); dGPU via prime-run.
-- Do NOT set AQ_DRM_DEVICES unless needed — Hyprland picks the correct GPU by default.

-- Visuals: crisp at FHD+ with modest blur cost on the Intel iGPU.
hl.config({
    decoration = {
        rounding = 10,
        blur = {
            enabled = true,
            size = 8,
            passes = 3
        },
        shadow = {
            enabled = true
        }
    }
})
