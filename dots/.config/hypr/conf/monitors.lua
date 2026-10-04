-- Monitors (the design ships no fixed screen): every screen at its preferred mode, placed automatically, with
-- Hyprland's automatic scale. Your own screen setup (resolution, refresh, scale, position, mirror) is made in
-- Settings > Display and saved in ~/.config/hypr/local/monitors.lua, which overrides this (personal layer).
-- https://wiki.hypr.land/Configuring/Basics/Monitors/
hl.monitor({
    output   = "",           -- "" = every screen
    mode     = "preferred",  -- the screen's own best resolution and refresh rate
    position = "auto",       -- placed side by side automatically
    scale    = "auto",       -- Hyprland picks the scale from the screen's density
})
