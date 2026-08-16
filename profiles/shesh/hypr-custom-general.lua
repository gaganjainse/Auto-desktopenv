-- profiles/shesh/hypr-custom-general.lua
-- Copy/symlink to ~/.config/hypr/custom/general.lua OR append its content.
-- MSI Sword 16 HX B14VEKG: 1920x1200 @ 144Hz internal panel (eDP-1).
-- SEE: docs/SHESH/04_DEVICE_PROFILE.md
--
-- All hl.config() calls use the single-table style (the only form the hl API
-- accepts). The old two-argument style, e.g. hl.config("monitor", "..."), errors
-- with "argument must be a table".

-- Force the internal panel to its native 144 Hz mode. If 144 isn't advertised,
-- replace with hl.monitor({ output = "eDP-1", mode = "highrr,auto" }) for auto-high-refresh.
hl.monitor({ output = "eDP-1", mode = "1920x1200@144", position = "0x0" })

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
