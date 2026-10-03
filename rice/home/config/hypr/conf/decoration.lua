-- Window decoration: rounding, opacity, shadow, blur, dimming.
-- https://wiki.hypr.land/Configuring/Basics/Variables/#decoration
local colors = require("conf.colors")

hl.config({
    decoration = {
        rounding       = 8,   -- fairly tight corners
        rounding_power = 2,   -- 2 = circular; higher = squircle

        -- Transparency for ALL windows (browsers, GTK apps, ...). Fullscreen
        -- (video, games) is forced opaque. Apps that make their own
        -- transparency (kitty) or must stay solid are handled in rules.lua.
        active_opacity     = 0.94,
        inactive_opacity   = 0.88,
        fullscreen_opacity = 1.0,

        -- gently dim unfocused windows for depth
        dim_inactive = true,
        dim_strength = 0.07,

        -- dark shadow hugging the border: tight range, strong black
        shadow = {
            enabled        = true,
            range          = 10,
            render_power   = 3,
            color          = "rgba(000000ff)",              -- solid black (the design; was the theme's shadow colour)
            color_inactive = colors.shadow_inactive,
        },

        blur = {
            enabled  = true,
            size     = 7,
            passes   = 3,
            vibrancy = 0.17,
            noise    = 0.02,
        },
    },
})
