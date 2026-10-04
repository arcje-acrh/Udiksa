-- General look: gaps, borders, layouts.
-- https://wiki.hypr.land/Configuring/Basics/Variables/#general
local colors = require("conf.colors")  -- the theme's colours (written by rice-theme)

hl.config({
    general = {
        gaps_in  = 5,  -- gap between windows (px)
        -- outer gaps: all 10 (user: a 4 px gap under the notch was too small). The Quickshell notch
        -- already reserves 30 px above the windows, so the notch-to-window gap is this top value.
        gaps_out = { top = 10, right = 10, bottom = 10, left = 10 },  -- gap between windows and the screen edge (px)

        border_size = 2,  -- window border width (px)

        col = {
            active_border   = { colors = colors.active_border, angle = colors.active_angle },  -- focused window's border (a gradient from the theme)
            inactive_border = colors.inactive_border,                                          -- other windows' border
        },

        resize_on_border = true, -- drag window edges/gaps to resize
        allow_tearing    = false,  -- off: no screen tearing in games

        layout = "dwindle",  -- tiling style: a new window splits the focused one
    },

    dwindle = {
        preserve_split = true,  -- keep the split direction when windows close
    },

    master = {
        new_status = "master",  -- new windows become the master (master layout only)
    },

    scrolling = {
        fullscreen_on_one_column = true,  -- a lone column fills the screen (scrolling layout)
    },

    -- window groups = tabs (Super+G makes one, Super+Tab steps through it; binds.lua). The tab strip is flat
    -- like the notch: square-ish, Iosevka, the theme's accent for the shown tab (colours: colors.lua).
    group = {
        col = {
            border_active          = colors.group_active or colors.active_border[1],   -- selected tab's border
            border_inactive        = colors.group_inactive or colors.inactive_border,  -- other tabs' border
            border_locked_active   = colors.group_locked or colors.active_border[2],   -- selected tab's border when the group is locked
            border_locked_inactive = colors.group_inactive or colors.inactive_border,  -- other tabs' border when locked
        },
        groupbar = {
            font_family         = "Iosevka Nerd Font",                      -- tab strip font
            font_size           = 11,                                       -- tab strip text size
            font_weight_active  = "bold",                                   -- the selected tab's text is bold
            height              = 16,                                       -- tab strip height (px)
            gradients           = true,                                     -- fade effect on the tabs
            rounding            = 2,                                        -- tab corner radius
            gradient_rounding   = 2,                                        -- tab fade corner radius
            indicator_height    = 0,                                        -- no extra indicator line under the title
            gaps_in             = 4,                                        -- gap between tabs
            gaps_out            = 2,                                        -- gap around the tab strip
            keep_upper_gap      = false,                                    -- no extra gap above the tab gradient
            text_color          = colors.tab_text or "rgba(ffffffff)",      -- text on the selected tab
            text_color_inactive = colors.tab_text_dim or "rgba(aaaaaaff)",  -- text on the other tabs
            col = {
                active          = colors.tab_active or colors.active_border[1],    -- selected tab
                inactive        = colors.tab_inactive or colors.inactive_border,   -- other tabs
                locked_active   = colors.group_locked or colors.active_border[2],  -- selected tab, group locked
                locked_inactive = colors.tab_inactive or colors.inactive_border,   -- other tabs, group locked
            },
        },
    },
})
