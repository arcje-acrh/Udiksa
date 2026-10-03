-- Input. https://wiki.hypr.land/Configuring/Basics/Variables/#input

hl.config({
    input = {
        kb_layout  = "us",
        kb_variant = "",
        kb_model   = "",
        kb_options = "",
        kb_rules   = "",

        repeat_rate  = 35,
        repeat_delay = 300,

        follow_mouse = 1,
        sensitivity  = 0, -- -1.0 - 1.0, 0 = no modification

        touchpad = {
            natural_scroll = true,
        },
    },
})

-- 3-finger horizontal swipe switches workspace
hl.gesture({
    fingers   = 3,
    direction = "horizontal",
    action    = "workspace",
})
