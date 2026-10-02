-- Shake to find (like macOS / KDE): the pointer grows while you shake the mouse, then shrinks back.
-- Plugin hypr-dynamic-cursors, built + loaded by hyprpm (autostart.lua; the rice installs it, "Update system" rebuilds
-- it after a Hyprland update). Without the plugin this file does nothing. On / off: Settings > Themes > Pointer
-- (local/settings.lua, loaded later, then sets shake.enabled).
if hl.plugin and hl.plugin.dynamic_cursors then
    hl.config({ plugin = { dynamic_cursors = {
        enabled = true,
        mode = "none",               -- no tilting / rotating / stretching: only shake to find
        shake = {
            enabled   = true,
            threshold = 4.0,         -- how soon a shake counts (lower = sooner)
            base      = 1.0,         -- starts at the normal size (user: "too sudden") ...
            speed     = 2.5,         -- ... and grows smoothly while shaking on (x per second)
            influence = 0.5,         -- a harder shake grows a little faster
            limit     = 3.0,         -- never bigger than 3x
            timeout   = 800,         -- ms it stays big after the shake ends
        },
        hyprcursor = {
            enabled    = true,       -- big = drawn again from the theme's vector pointer, so it stays sharp and its
            resolution = 100,        -- thin edge stays thin (default -1 = size x base = 25 px, blurry when magnified)
            nearest    = 0,
        },
    } } })
end
