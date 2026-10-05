-- Hyprland configuration (Lua) — entry point.
-- The real settings live in small modules under ~/.config/hypr/conf/:
--
--   colors     palette (matugen target)        general      gaps / borders / layouts
--   programs   default apps                    decoration   rounding / blur / shadow
--   monitors   any screen: preferred mode      animations   curves + animations
--                                             misc         background, vfr, ...
--   env        environment variables           rules        window / layer rules
--   input      keyboard / touchpad / gestures  binds        keybindings
--   autostart  things started at login
--
-- Docs: https://wiki.hypr.land/Configuring/Start/

-- Load order matters a little: binds come early so a broken cosmetic module
-- can never leave the session without keyboard shortcuts. Each module is
-- loaded under pcall; any failures are reported together at the end (Hyprland
-- shows Lua errors in its error bar / `hyprctl configerrors`).
local modules = {  -- the config modules below, loaded in this order
    "env", "monitors", "input", "binds", "autostart",
    "general", "decoration", "animations", "misc", "rules", "cursor",
}

local errors = {}  -- failures are collected here and shown together at the end
for _, name in ipairs(modules) do
    local ok, err = pcall(require, "conf." .. name)  -- load one module; a broken one cannot stop the others
    if not ok then
        errors[#errors + 1] = "conf." .. name .. ": " .. tostring(err)
    end
end

-- PERSONAL LAYER: ~/.config/hypr/local/*.lua (not in the Udiksa repo: .gitignore). Loaded last, so it overrides the
-- design above on this machine only. Written by Settings (settings.lua: look / input / your startup apps + binds,
-- monitors.lua: your screens) or by hand / a device add-on (device.lua, env.lua). Missing files are simply skipped.
local localdir = os.getenv("HOME") .. "/.config/hypr/local/"
for _, name in ipairs({ "env", "device", "monitors", "settings" }) do  -- personal overrides, loaded after the design
    local path = localdir .. name .. ".lua"
    local f = io.open(path, "r")  -- skip files that do not exist
    if f then
        f:close()
        local ok, err = pcall(dofile, path)  -- run the file; remember any error
        if not ok then errors[#errors + 1] = "local/" .. name .. ": " .. tostring(err) end
    end
end
-- The built-in panel's refresh rate is switched live (60 Hz on battery, higher on the charger: ~/.local/bin/udiksa panel-hz),
-- which saves the mode it set here. Re-applied last, so a reload (every theme switch) keeps the rate the panel is
-- running at: a reload that picked another rate would change the display mode, and the screen blanks for a moment.
do
    local f = io.open(os.getenv("HOME") .. "/.local/state/rice/panel-mode", "r")  -- the refresh rate udiksa panel-hz last set
    if f then
        local out, mode = (f:read("*l") or ""):match("^(%S+)%s+(%S+)$")
        f:close()
        if out then hl.monitor({ output = out, mode = mode }) end  -- set it again so a reload does not change the display mode
    end
end
-- game mode stays on through reloads (theme switch, Settings) until it is turned off (conf/gamemode.lua)
do
    local f = io.open((os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/udiksa-gamemode", "r")  -- this file exists while game mode is on
    if f then
        f:close()
        local ok, err = pcall(dofile, os.getenv("HOME") .. "/.config/hypr/conf/gamemode.lua")  -- apply game mode again after a reload
        if not ok then errors[#errors + 1] = "conf/gamemode.lua: " .. tostring(err) end
    end
end
if #errors > 0 then  -- show every failure in Hyprland's error bar
    error("failed to load config modules:\n" .. table.concat(errors, "\n"), 0)
end
