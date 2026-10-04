-- Input. https://wiki.hypr.land/Configuring/Basics/Variables/#input

hl.config({
    input = {
        kb_layout  = "us",  -- keyboard layout (us = US English)
        kb_variant = "",    -- layout variant, empty = the default
        kb_model   = "",    -- keyboard model, empty = the default
        kb_options = "",    -- extra XKB options, e.g. "caps:escape"
        kb_rules   = "",    -- XKB rules, empty = the default

        repeat_rate  = 35,   -- repeats per second while a key is held
        repeat_delay = 300,  -- ms before a held key starts repeating

        follow_mouse = 1,  -- 1 = keyboard focus follows the mouse
        sensitivity  = 0, -- -1.0 - 1.0, 0 = no modification

        touchpad = {
            natural_scroll = true,  -- touchpad scrolls like a phone (content follows the fingers)
        },
    },
})

-- 3-finger horizontal swipe switches workspace
hl.gesture({
    fingers   = 3,             -- three fingers ...
    direction = "horizontal",  -- ... swiping sideways ...
    action    = "workspace",   -- ... switch workspace
})
