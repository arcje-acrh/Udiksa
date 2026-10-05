-- Window decoration: rounding, opacity, shadow, blur, dimming.
-- https://wiki.hypr.land/Configuring/Basics/Variables/#decoration
local colors = require("conf.colors")  -- the theme's colours (written by udiksa theme)

hl.config({
    decoration = {
        rounding       = 8,   -- fairly tight corners
        rounding_power = 2,   -- 2 = circular; higher = squircle

        -- Transparency for ALL windows (browsers, GTK apps, ...). Fullscreen
        -- (video, games) is forced opaque. Apps that make their own
        -- transparency (kitty) or must stay solid are handled in rules.lua.
        active_opacity     = 0.94,  -- focused window (1.0 = solid)
        inactive_opacity   = 0.88,  -- unfocused windows
        fullscreen_opacity = 1.0,   -- fullscreen windows are solid

        -- gently dim unfocused windows for depth
        dim_inactive = true,  -- darken unfocused windows
        dim_strength = 0.07,  -- how much (0 - 1)

        -- dark shadow hugging the border: tight range, strong black
        shadow = {
            enabled        = true,  -- window shadows on
            range          = 10,    -- shadow size (px)
            render_power   = 3,     -- how fast the shadow fades out (higher = tighter)
            color          = "rgba(000000ff)",              -- solid black (the design; was the theme's shadow colour)
            color_inactive = colors.shadow_inactive,  -- shadow of unfocused windows (from the theme)
        },

        blur = {
            enabled  = true,  -- blur what is behind see-through windows
            size     = 7,     -- blur radius per pass
            passes   = 3,     -- more passes = smoother, but more GPU work
            vibrancy = 0.17,  -- colour boost of the blur
            noise    = 0.02,  -- film grain that hides banding
        },
    },
})
