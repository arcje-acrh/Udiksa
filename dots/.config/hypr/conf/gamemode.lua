-- Game mode (notch power panel > Game mode, or `qs ipc call modes game`): turns off everything that costs GPU time on
-- every frame -- animations, blur, shadows, see-through and dimmed windows, gaps, rounding. Not a module of
-- hyprland.lua's list: Modes.qml applies it live (hyprctl eval dofile), and hyprland.lua runs it again after a reload
-- while $XDG_RUNTIME_DIR/udiksa-gamemode exists (gone at logout). Turning game mode off = a normal reload.
hl.config({
    animations = { enabled = false },
    decoration = {
        rounding         = 0,
        active_opacity   = 1.0,
        inactive_opacity = 1.0,
        dim_inactive     = false,
        blur             = { enabled = false },
        shadow           = { enabled = false },
    },
    general = {
        gaps_in     = 0,
        gaps_out    = 0,
        border_size = 1,
    },
})
