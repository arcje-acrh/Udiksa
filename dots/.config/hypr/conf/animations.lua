-- Animations. https://wiki.hypr.land/Configuring/Advanced-and-Cool/Animations/

hl.config({
    animations = { enabled = true },  -- master switch (game mode turns it off)
})

-- curves
hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1}    } })                  -- fast start, long smooth stop
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1}    } })                  -- slow start and end
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}       } })                  -- constant speed
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1}    } })                  -- nearly constant speed, soft finish
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}     } })                  -- very fast start
hl.curve("easy",           { type = "spring", mass = 1, stiffness = 238.1191, dampening = 24.21279333 })  -- a spring (slight bounce) instead of a curve

-- windows: springy pop-in, quick fade-out
hl.animation({ leaf = "global",        enabled = true, speed = 10,   bezier = "default" })                            -- default for everything not listed
hl.animation({ leaf = "border",        enabled = true, speed = 5.39, bezier = "easeOutQuint" })                       -- border colour changes
hl.animation({ leaf = "windows",       enabled = true, speed = 4.79, spring = "easy" })                               -- moving and resizing windows
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 4.1,  spring = "easy",         style = "popin 82%" })  -- a window opening
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 1.6,  bezier = "quick",        style = "popin 82%" })  -- a window closing
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 1.73, bezier = "almostLinear" })                       -- fade in
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 1.46, bezier = "almostLinear" })                       -- fade out
hl.animation({ leaf = "fade",          enabled = true, speed = 3.03, bezier = "quick" })                              -- opacity changes

-- layer surfaces (bars, launcher, notifications)
hl.animation({ leaf = "layers",        enabled = true, speed = 3.81, bezier = "easeOutQuint" })                  -- all shell surfaces (notch, launcher)
hl.animation({ leaf = "layersIn",      enabled = true, speed = 4,    bezier = "easeOutQuint", style = "fade" })  -- a shell surface appearing
hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.5,  bezier = "linear",       style = "fade" })  -- a shell surface leaving
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 1.79, bezier = "almostLinear" })                  -- fade in of shell surfaces
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })                  -- fade out of shell surfaces

-- workspaces: slide (matches the 3-finger swipe gesture)
hl.animation({ leaf = "workspaces",    enabled = true, speed = 3.2,  bezier = "easeOutQuint", style = "slide" })  -- switching workspace
hl.animation({ leaf = "workspacesIn",  enabled = true, speed = 3.2,  bezier = "easeOutQuint", style = "slide" })  -- the incoming workspace
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 3.2,  bezier = "easeOutQuint", style = "slide" })  -- the outgoing workspace

hl.animation({ leaf = "zoomFactor",    enabled = true, speed = 7,    bezier = "quick" })  -- screen zoom
