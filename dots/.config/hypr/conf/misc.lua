-- Misc. https://wiki.hypr.land/Configuring/Basics/Variables/#misc
-- (variable frame rate is `debug:vfr` in this version and is already on by
-- default: only redraws when something changes, which saves battery.)
local colors = require("conf.colors")  -- the theme's colours (written by udiksa theme)

hl.config({
    misc = {
        force_default_wallpaper = 0,    -- no anime-mascot wallpapers
        disable_hyprland_logo   = true,  -- no Hyprland logo on an empty desktop
        background_color        = colors.background, -- plain colour until a wallpaper is set

        -- wake the screen from DPMS-off on any key / mouse move
        key_press_enables_dpms  = true,  -- any key wakes the screen
        mouse_move_enables_dpms = true,  -- moving the mouse wakes it
    },
})

-- X11 apps (XWayland, e.g. OnlyOffice) are drawn at the screen's real resolution instead of being stretched to the
-- 1.25 scale (that made them blurry / pixelated). Such apps size their own UI instead (OnlyOffice: --force-scale=1.25
-- in ~/.local/share/applications/onlyoffice-desktopeditors.desktop).
hl.config({
    xwayland = { force_zero_scaling = true },  -- XWayland apps are drawn at the real resolution (sharp)
})
