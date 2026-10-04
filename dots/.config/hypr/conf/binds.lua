-- Keybindings. https://wiki.hypr.land/Configuring/Basics/Binds/
local programs = require("conf.programs")

local mainMod = "SUPER"

-- apps / session
hl.bind(mainMod .. " + RETURN",        hl.dsp.exec_cmd(programs.terminal))
-- fallback that does NOT use the Super/Windows key (added 2026-09-25 when Super stopped working)
hl.bind("CTRL + ALT + T",              hl.dsp.exec_cmd(programs.terminal))
hl.bind(mainMod .. " + Q",             hl.dsp.window.close())
hl.bind(mainMod .. " + SHIFT + Q",     hl.dsp.exit())
hl.bind(mainMod .. " + E",             hl.dsp.exec_cmd(programs.fileManager))
hl.bind(mainMod .. " + R",             hl.dsp.exec_cmd(programs.menu))
-- Settings (full screen, ~/.config/quickshell/Settings.qml)
hl.bind(mainMod .. " + I",             hl.dsp.exec_cmd("qs ipc call settings toggle"))

-- window state / layout
hl.bind(mainMod .. " + V",             hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + F",             hl.dsp.window.fullscreen())
-- F9 sends SUPER+P (Windows' "Project" key, verified 2026-09-26): switch the screen setup with an external
-- monitor (Extend / Mirror / External only / Laptop only), shown in the notch. Replaces pseudo-tile.
hl.bind(mainMod .. " + P",             hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/bin/display-mode"))
-- themes (user 2026-09-26): SUPER + T = theme + wallpaper switcher (Quickshell sheet at the top),
-- SUPER + SHIFT + T = next wallpaper of the current theme (~/.local/bin/rice-theme)
hl.bind(mainMod .. " + T",             hl.dsp.exec_cmd("qs ipc call themes toggle"))
hl.bind(mainMod .. " + SHIFT + T",     hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/bin/rice-theme next"))
hl.bind(mainMod .. " + SHIFT + J",     hl.dsp.layout("togglesplit")) -- dwindle only (moved from SUPER+J, now resize)

-- window extras (2026-10-02): pin = stays on every workspace (floats it first), centre a floating window,
-- picture-in-picture = small, pinned, bottom-right; the same keys again put it back
hl.bind(mainMod .. " + SHIFT + P", function() -- pin: on every workspace
    local w = hl.get_active_window()
    if not w then return end
    if not w.pinned and not w.floating then hl.dispatch(hl.dsp.window.float({ action = "enable" })) end
    hl.dispatch(hl.dsp.window.pin())
end)
hl.bind(mainMod .. " + C",             hl.dsp.window.center())
hl.bind(mainMod .. " + ALT + backslash", function() -- picture-in-picture: small, pinned, bottom-right
    local w = hl.get_active_window()
    if not w then return end
    if w.pinned then
        hl.dispatch(hl.dsp.window.pin())
        hl.dispatch(hl.dsp.window.float({ action = "disable" }))
        return
    end
    local m = w.monitor
    local sw, sh = m.width / m.scale, m.height / m.scale
    local pw = math.floor(sw * 0.25)
    local ph = math.floor(pw * w.size.y / math.max(1, w.size.x))
    hl.dispatch(hl.dsp.window.float({ action = "enable" }))
    hl.dispatch(hl.dsp.window.resize({ x = pw, y = ph }))
    hl.dispatch(hl.dsp.window.move({ x = m.x + sw - pw - 20, y = m.y + sh - ph - 20 }))
    hl.dispatch(hl.dsp.window.pin())
end)

-- window groups = tabs: SUPER + G makes / breaks a group, SUPER + ALT + arrows move the window INTO the group on that
-- side (SUPER + SHIFT + arrows only swap places with it), SUPER + Tab / SUPER + SHIFT + Tab step through its tabs,
-- SUPER + ALT + G takes the window out, SUPER + CTRL + G locks it
hl.bind(mainMod .. " + G",             hl.dsp.group.toggle())
hl.bind(mainMod .. " + TAB",           hl.dsp.group.next())
hl.bind(mainMod .. " + SHIFT + TAB",   hl.dsp.group.prev())
hl.bind(mainMod .. " + ALT + G",       hl.dsp.window.move({ out_of_group = true }))
hl.bind(mainMod .. " + ALT + left",    hl.dsp.window.move({ into_group = "l" }))
hl.bind(mainMod .. " + ALT + right",   hl.dsp.window.move({ into_group = "r" }))
hl.bind(mainMod .. " + ALT + up",      hl.dsp.window.move({ into_group = "u" }))
hl.bind(mainMod .. " + ALT + down",    hl.dsp.window.move({ into_group = "d" }))
hl.bind(mainMod .. " + CTRL + G",      hl.dsp.group.lock_active({ action = "toggle" }))

-- move focus with arrow keys
hl.bind(mainMod .. " + left",          hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right",         hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",            hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",          hl.dsp.focus({ direction = "down" }))

-- move the active window (user 2026-09-26): SUPER + SHIFT + arrows
hl.bind(mainMod .. " + SHIFT + left",  hl.dsp.window.move({ direction = "l" }))
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.move({ direction = "r" }))
hl.bind(mainMod .. " + SHIFT + up",    hl.dsp.window.move({ direction = "u" }))
hl.bind(mainMod .. " + SHIFT + down",  hl.dsp.window.move({ direction = "d" }))

-- resize the active window: SUPER + H / J / K / L (user 2026-09-26: H = left, J = up, K = down,
-- L = right; right/down = bigger, left/up = smaller; hold to repeat)
hl.bind(mainMod .. " + L", hl.dsp.window.resize({ x =  40, y =   0, relative = true }), { repeating = true })
hl.bind(mainMod .. " + H", hl.dsp.window.resize({ x = -40, y =   0, relative = true }), { repeating = true })
hl.bind(mainMod .. " + K", hl.dsp.window.resize({ x =   0, y =  40, relative = true }), { repeating = true })
hl.bind(mainMod .. " + J", hl.dsp.window.resize({ x =   0, y = -40, relative = true }), { repeating = true })

-- workspaces: SUPER + [0-9] switch, SUPER + SHIFT + [0-9] move window
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key,           hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key,   hl.dsp.window.move({ workspace = i }))
end
-- next / previous workspace (an empty one next in line too): SUPER + Page Down / Up or SUPER + CTRL + arrows;
-- with SHIFT the window goes along
hl.bind(mainMod .. " + Page_Down",          hl.dsp.focus({ workspace = "r+1" }))
hl.bind(mainMod .. " + Page_Up",            hl.dsp.focus({ workspace = "r-1" }))
hl.bind(mainMod .. " + CTRL + right",       hl.dsp.focus({ workspace = "r+1" }))
hl.bind(mainMod .. " + CTRL + left",        hl.dsp.focus({ workspace = "r-1" }))
hl.bind(mainMod .. " + SHIFT + Page_Down",  hl.dsp.window.move({ workspace = "r+1" }))
hl.bind(mainMod .. " + SHIFT + Page_Up",    hl.dsp.window.move({ workspace = "r-1" }))

-- scratchpad
hl.bind(mainMod .. " + S",             hl.dsp.workspace.toggle_special("magic"))
-- every screenshot goes through rice-shot (saves, copies, "Screenshot saved" card; a click opens the picture)
local shot = os.getenv("HOME") .. "/.local/bin/rice-shot"

-- move the window to the scratchpad: SUPER + SHIFT + S.
-- Laptops' "snip" key (Windows' Win+Shift+S) sends the same keys, but with the RIGHT Shift, all within a
-- few ms (G16 F6, measured 2026-09-29) -- so Super + Right Shift + S takes a region screenshot instead.
-- With your own LEFT Shift held as well, the snip key takes a window (like Shift + Print); the key's burst is
-- Right Shift only, so Left Shift down at the same time can only be you.
hl.bind(mainMod .. " + SHIFT + S", function() -- window to the scratchpad (Right Shift: region screenshot)
    if hl.is_key_down("Shift_R") then
        hl.dispatch(hl.dsp.exec_cmd(shot .. (hl.is_key_down("Shift_L") and " window" or " area")))
    else
        hl.dispatch(hl.dsp.window.move({ workspace = "special:magic" }))
    end
end)

-- Laptops without Print Screen: the same modes on the snip key (F6 sends Super + Right Shift + S), mirroring the
-- Print Screen modifiers: Ctrl = whole screen, Alt = draw on it, Ctrl + Alt = a window. Typed by hand, either Shift works.
hl.bind(mainMod .. " + CTRL + SHIFT + S",       hl.dsp.exec_cmd(shot .. " screen"))
hl.bind(mainMod .. " + ALT + SHIFT + S",        hl.dsp.exec_cmd(shot .. " edit"))
hl.bind(mainMod .. " + CTRL + ALT + SHIFT + S", hl.dsp.exec_cmd(shot .. " window"))

-- app scratchpads (~/.local/bin/rice-scratch): each app on its own hidden workspace, the key shows / hides it
-- and starts the app the first time. System monitor = btop; music and chat = the apps picked in
-- Settings > Apps (music: ncspot + cava when ncspot is installed)
local scratch = os.getenv("HOME") .. "/.local/bin/rice-scratch"
hl.bind("CTRL + SHIFT + Escape",       hl.dsp.exec_cmd(scratch .. " sysmon"))
hl.bind(mainMod .. " + M",             hl.dsp.exec_cmd(scratch .. " music"))
hl.bind(mainMod .. " + D",             hl.dsp.exec_cmd(scratch .. " chat"))

-- scroll through workspaces / move+resize with the mouse
hl.bind(mainMod .. " + mouse_down",    hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",      hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mainMod .. " + mouse:272",     hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273",     hl.dsp.window.resize(), { mouse = true })

-- screenshots (hyprshot): region / window / whole screen -> file + clipboard
hl.bind("Print",                       hl.dsp.exec_cmd(shot .. " area"))
hl.bind("SHIFT + Print",               hl.dsp.exec_cmd(shot .. " window"))
hl.bind("CTRL + Print",                hl.dsp.exec_cmd(shot .. " screen"))
-- screenshot to draw on: the screen freezes, pick an area, it opens in the editor (satty; Enter saves + copies)
hl.bind("ALT + Print",                 hl.dsp.exec_cmd(shot .. " edit"))

-- screen recording (~/.local/bin/rice-record): the same keys again stop it (or click the dot in the notch);
-- saved in ~/Videos/Recordings
local record = os.getenv("HOME") .. "/.local/bin/rice-record"
hl.bind(mainMod .. " + ALT + R",         hl.dsp.exec_cmd(record .. " screen"))
hl.bind(mainMod .. " + ALT + SHIFT + R", hl.dsp.exec_cmd(record .. " region"))
hl.bind(mainMod .. " + ALT + CTRL + R",  hl.dsp.exec_cmd(record .. " sound"))

-- colour picker: click anywhere, the hex code is copied and shown in the notch
hl.bind(mainMod .. " + SHIFT + C",     hl.dsp.exec_cmd(os.getenv("HOME") .. "/.local/bin/rice-pick"))

-- volume / mic
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1.25 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })

-- screen brightness: brightnessctl picks the panel's backlight itself (whatever the machine / GPU mode calls it);
-- -e2 = the same curve as the notch and Settings. `qs ipc call osd brightness` shows the level pop-up (Osd.qml).
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -c backlight -e2 -n2 set 5%+; qs ipc call osd brightness"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -c backlight -e2 -n2 set 5%-; qs ipc call osd brightness"), { locked = true, repeating = true })

-- Caps Lock / Num Lock: show their state in the notch. non_consuming = the key still
-- works normally; the short sleep lets the keyboard LED change before it is read.
hl.bind("Caps_Lock", hl.dsp.exec_cmd("sleep 0.1; qs ipc call osd caps"), { non_consuming = true })
hl.bind("Num_Lock",  hl.dsp.exec_cmd("sleep 0.1; qs ipc call osd num"),  { non_consuming = true })

-- airplane mode key (if the laptop reports one: XF86RFKill, or XF86WLAN on some models).
-- Blocks every radio when any is on, otherwise unblocks all; the notch shows the new state
-- by itself (Osd.qml watches `rfkill event`). Tested 2026-09-25 on an ASUS G16: F12 sends NOTHING
-- (no key, no ASUS hotkey, not even the firmware's EC query 0xAF) -> use the Wi-Fi panel's
-- Airplane switch. Kept in case a firmware/kernel update adds it.
local airplane = "rfkill -n -o SOFT | grep -q '^unblocked' && rfkill block all || rfkill unblock all"
hl.bind("XF86RFKill", hl.dsp.exec_cmd(airplane), { locked = true })
hl.bind("XF86WLAN",   hl.dsp.exec_cmd(airplane), { locked = true })

-- touchpad off / on: F10 arrives as KEY_F21 = the standard touchpad-toggle key
-- (keysym XF86TouchpadToggle; F21 bound too in case the keymap names it that way)
-- (full path: Hyprland's PATH does not include ~/.local/bin)
local touchpad = os.getenv("HOME") .. "/.local/bin/touchpad-toggle"
hl.bind("XF86TouchpadToggle", hl.dsp.exec_cmd(touchpad), { locked = true })
hl.bind("F21",                hl.dsp.exec_cmd(touchpad), { locked = true })

-- media transport (playerctl)
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })
