-- Game mode (notch power panel > Game mode, or `qs ipc call modes game`): turns off everything that costs GPU time on
-- every frame -- animations, blur, shadows, see-through and dimmed windows, gaps, rounding. Not a module of
-- hyprland.lua's list: Modes.qml applies it live (hyprctl eval dofile), and hyprland.lua runs it again after a reload
-- while $XDG_RUNTIME_DIR/udiksa-gamemode exists (gone at logout). Turning game mode off = a normal reload.
hl.config({
    animations = { enabled = false },  -- no animations
    decoration = {
        rounding         = 0,                    -- square corners
        active_opacity   = 1.0,                  -- solid windows
        inactive_opacity = 1.0,                  -- solid windows
        dim_inactive     = false,                -- no dimming
        blur             = { enabled = false },  -- no blur
        shadow           = { enabled = false },  -- no shadows
    },
    general = {
        gaps_in     = 0,  -- no gaps between windows
        gaps_out    = 0,  -- no gaps to the screen edge
        border_size = 1,  -- thin border
    },
})
