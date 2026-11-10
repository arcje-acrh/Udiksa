-- Monitors (the design ships no fixed screen): every screen at its preferred mode, placed automatically, with
-- Hyprland's automatic scale. Your own screen setup (resolution, refresh, scale, position, mirror) is made in
-- Settings > Display and saved in ~/.config/hypr/local/monitors.lua, which overrides this (personal layer).
-- https://wiki.hypr.land/Configuring/Basics/Monitors/
hl.monitor({
    output   = "",           -- "" = every screen
    mode     = "preferred",  -- the screen's own best resolution and refresh rate
    position = "auto",       -- placed side by side automatically
    scale    = "auto",       -- Hyprland picks the scale from the screen's density
})

-- Screens coming and going (logic: ~/.local/lib/udiksa/display; Hyprland's own stand-in FALLBACK output and our
-- UDIKSA-WAKE are not screens):
--  plugged in: a safe mode if it hangs off the second GPU (garbled otherwise, e.g. a 1366x768 TV on the NVIDIA HDMI
--              port), "only the other screen" honoured, and the current wallpaper (awww leaves new screens black)
--  unplugged:  if no screen is left switched on, the laptop's own comes back -- never a black screen
--  any change (also scale / resolution): the shell's size is re-checked (~/.local/lib/udiksa/shell --ensure) and X11
--              apps' dpi follows the main screen (~/.local/lib/udiksa/xdpi)
local udiksa = os.getenv("HOME") .. "/.local/bin/udiksa "
local function screen(m) return not (m and m.name and (m.name == "FALLBACK" or m.name == "UDIKSA-WAKE")) end
hl.on("monitor.added", function(m) if screen(m) then hl.exec_cmd(udiksa .. "display added") end end)
hl.on("monitor.removed", function(m) if screen(m) then hl.exec_cmd(udiksa .. "display removed") end end)
hl.on("monitor.layout_changed", function() hl.exec_cmd(udiksa .. "shell --ensure"); hl.exec_cmd(udiksa .. "xdpi") end)
