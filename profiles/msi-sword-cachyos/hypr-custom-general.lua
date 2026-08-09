-- profiles/msi-sword-cachyos/hypr-custom-general.lua
-- Copy/symlink to ~/.config/hypr/custom/general.lua OR append its content.
-- MSI Sword 16 HX B14VEKG: 1920x1200 @ 144Hz internal panel (eDP-1).
-- SEE: docs/SESHA/04_DEVICE_PROFILE.md

-- Force the internal panel to its native 144 Hz mode. If 144 isn't advertised,
-- replace with `hl.config("monitor", [[eDP-1,highrr,auto,1]])` for auto-high-refresh.
hl.config("monitor", [[eDP-1,1920x1200@144,0x0,1]])

-- Default to the iGPU driving the compositor (better battery); dGPU via prime-run.
-- Do NOT set AQ_DRM_DEVICES unless needed — Hyprland picks the correct GPU by default.

-- Visuals: crisp at FHD+ with modest blur cost on the Intel iGPU.
hl.config("decoration:rounding", 10)
hl.config("decoration:blur:enabled", true)
hl.config("decoration:blur:size", 8)
hl.config("decoration:blur:passes", 3)
hl.config("decoration:shadow:enabled", true)
