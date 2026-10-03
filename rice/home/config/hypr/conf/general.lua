-- General look: gaps, borders, layouts.
-- https://wiki.hypr.land/Configuring/Basics/Variables/#general
local colors = require("conf.colors")

hl.config({
    general = {
        gaps_in  = 5,
        -- outer gaps: all 10 (user: a 4 px gap under the notch was too small). The Quickshell notch
        -- already reserves 30 px above the windows, so the notch-to-window gap is this top value.
        gaps_out = { top = 10, right = 10, bottom = 10, left = 10 },

        border_size = 2,

        col = {
            active_border   = { colors = colors.active_border, angle = colors.active_angle },
            inactive_border = colors.inactive_border,
        },

        resize_on_border = true, -- drag window edges/gaps to resize
        allow_tearing    = false,

        layout = "dwindle",
    },

    dwindle = {
        preserve_split = true,
    },

    master = {
        new_status = "master",
    },

    scrolling = {
        fullscreen_on_one_column = true,
    },

    -- window groups = tabs (Super+G makes one, Super+Tab steps through it; binds.lua). The tab strip is flat
    -- like the notch: square-ish, Iosevka, the theme's accent for the shown tab (colours: colors.lua).
    group = {
        col = {
            border_active          = colors.group_active or colors.active_border[1],
            border_inactive        = colors.group_inactive or colors.inactive_border,
            border_locked_active   = colors.group_locked or colors.active_border[2],
            border_locked_inactive = colors.group_inactive or colors.inactive_border,
        },
        groupbar = {
            font_family         = "Iosevka Nerd Font",
            font_size           = 11,
            font_weight_active  = "bold",
            height              = 16,
            gradients           = true,
            rounding            = 2,
            gradient_rounding   = 2,
            indicator_height    = 0,
            gaps_in             = 4,
            gaps_out            = 2,
            keep_upper_gap      = false,
            text_color          = colors.tab_text or "rgba(ffffffff)",
            text_color_inactive = colors.tab_text_dim or "rgba(aaaaaaff)",
            col = {
                active          = colors.tab_active or colors.active_border[1],
                inactive        = colors.tab_inactive or colors.inactive_border,
                locked_active   = colors.group_locked or colors.active_border[2],
                locked_inactive = colors.tab_inactive or colors.inactive_border,
            },
        },
    },
})
