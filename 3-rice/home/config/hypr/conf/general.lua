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
})
