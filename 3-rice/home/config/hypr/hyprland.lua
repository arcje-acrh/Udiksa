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
local modules = {
    "env", "monitors", "input", "binds", "autostart",
    "general", "decoration", "animations", "misc", "rules",
}

local errors = {}
for _, name in ipairs(modules) do
    local ok, err = pcall(require, "conf." .. name)
    if not ok then
        errors[#errors + 1] = "conf." .. name .. ": " .. tostring(err)
    end
end

-- PERSONAL LAYER: ~/.config/hypr/local/*.lua (not in the Udiksa repo: .gitignore). Loaded last, so it overrides the
-- design above on this machine only. Written by Settings (settings.lua: look / input / your startup apps + binds,
-- monitors.lua: your screens) or by hand / a device add-on (device.lua, env.lua). Missing files are simply skipped.
local localdir = os.getenv("HOME") .. "/.config/hypr/local/"
for _, name in ipairs({ "env", "device", "monitors", "settings" }) do
    local path = localdir .. name .. ".lua"
    local f = io.open(path, "r")
    if f then
        f:close()
        local ok, err = pcall(dofile, path)
        if not ok then errors[#errors + 1] = "local/" .. name .. ": " .. tostring(err) end
    end
end
if #errors > 0 then
    error("failed to load config modules:\n" .. table.concat(errors, "\n"), 0)
end
