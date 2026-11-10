-- Window / layer rules.
-- https://wiki.hypr.land/Configuring/Basics/Window-Rules/

-- ignore maximize requests from apps
hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },  -- every window

    suppress_event = "maximize",  -- ignore apps' maximize requests
})

-- fix some dragging issues with XWayland
hl.window_rule({
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },

    no_focus = true,  -- do not give these focus
})

-- Hyprland's own run-dialog window
hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },

    move  = "20 monitor_h-120",  -- px from the left, 120 px above the bottom
    float = true,                -- floating
})

-- ---------------------------------------------------------------------------
-- Windows that should OPEN FLOATING (never tiled). Add more by copying a block.
-- ---------------------------------------------------------------------------
-- file pickers and save / open / print dialogs: float in the middle
hl.window_rule({
    name  = "dialogs",
    min_size = "monitor_w*0.390625 monitor_h*0.4375",  -- GTK/Qt dialogs open small; 800x560 on the 2048x1280 laptop, the same share anywhere
    match = { title = "^(Open|Open File|Open Files|Open Folder|Save|Save As|Save File|Select a File|Choose Files?|File Upload|Select Folder|Export|Import|Print|Properties|Preferences|Rename)( .*)?$" },

    float  = true,  -- float ...
    center = true,  -- ... in the middle
})
-- Zed's secondary windows (Settings, ...) are titled "Zed — <what>"; the editor windows are titled by their project.
-- They float in the middle (user 2026-10-06: "settings and all keep floating, same for sub-windows of other apps").
hl.window_rule({
    name  = "zed-subwindows",
    match = { class = "^dev\\.zed\\.Zed$", title = "^Zed — .*" },

    float  = true,
    center = true,
    size   = "monitor_w*0.5859375 monitor_h*0.625",  -- 1200x800 on the 2048x1280 laptop; the same share on any screen
})
-- sub-windows of other apps that are plain top-level windows (not dialogs with a parent: Hyprland floats those itself):
-- settings / options / about / shortcuts windows. The WHOLE title must match, so a browser tab "Settings — Zen Browser"
-- (the main window) is never caught.
hl.window_rule({
    name  = "app-subwindows",
    match = { title = "^(Settings|Options|Preferences|About|About .*|Keyboard Shortcuts|Keymap Editor|Customi[sz]e.*|Configure.*|Appearance|Task Manager)$" },

    float  = true,
    center = true,
})
hl.window_rule({
    name  = "portal-file-chooser",
    match = { class = "^(xdg-desktop-portal-gtk|xdg-desktop-portal-kde|org.freedesktop.impl.portal.desktop.kde)$" },

    float  = true,
    center = true,
    size   = "monitor_w*0.48828125 monitor_h*0.5",  -- 1000x640 on the laptop
})

-- small utility windows (sound, Bluetooth, network editor, calculator,
-- the browser's Library / Downloads window, screen-sharing indicator)
hl.window_rule({
    name  = "utility-apps",
    match = { class = "^(pavucontrol|org.pulseaudio.pavucontrol|blueman-manager|.blueman-manager-wrapped|nm-connection-editor|qalculate-gtk|org.gnome.Calculator|gnome-calculator)$" },

    float  = true,
    center = true,
    size   = "monitor_w*0.439453125 monitor_h*0.46875",  -- 900x600 on the laptop
})
-- Kaze (file manager) and RDP Desk always open floating, centred, at the size they ask for
-- (Kaze 1280x800, RDP Desk 1220x800). User 2026-11-10: "open rdpdesk and kaze as floating always".
-- FreeRDP's session windows have their own class (com.freerdp.*), so remote desktops still tile.
hl.window_rule({
    name  = "kaze-rdpdesk-floating",
    match = { class = "^(kaze|io\\.github\\.rdpdesk)$" },

    float  = true,
    center = true,
})
hl.window_rule({
    name  = "browser-library",
    match = { title = "^(Library|Downloads|Page Info.*)$" },

    float  = true,
    center = true,
})
-- every NEW browser window opens floating, centred, at the size it asks for (user 2026-09-26: pop-ups like the
-- Bitwarden unlock / email sign-in window must not flash tiled first). ~/.config/quickshell/FloatWatcher.qml
-- then puts REAL browser windows back into tiling at once (the first window of the browser, or one that
-- asks to be nearly screen-sized), so only pop-ups stay floating.
hl.window_rule({
    name  = "browser-windows-open-floating",
    match = { class = "^(zen|firefox|librewolf|chromium|google-chrome|brave-browser)$",
              title = "negative:^(Picture-in-Picture|Picture in picture)$" },   -- the PiP window has its own rule below

    float    = true,
    center   = true,
    min_size = "monitor_w*0.439453125 monitor_h*0.5078125",  -- pop-ups (Gmail compose, ...) ask for a tiny CSS-pixel size; never smaller than this (900x650 on the laptop)
})
-- browser EXTENSION pop-outs (user 2026-09-26: the Bitwarden unlock window opened tiled). Their title is
-- "Extension: (<extension name>) - <page> — Zen Browser" (same pattern in Firefox; Chromium: class
-- "crx_..."): float them in the middle at the size they ask for. (Zen names its pop-ups only AFTER they
-- open, so ~/.config/quickshell/FloatWatcher.qml floats those the moment they appear.)
hl.window_rule({
    name  = "browser-extension-popups",
    match = { title = "^Extension: \\(.*" },

    float    = true,
    center   = true,
    min_size = "1 1",  -- extension pop-outs (Bitwarden) are small by design
})
hl.window_rule({
    name  = "chromium-extension-popups",
    match = { class = "^crx_.*" },

    float  = true,
    center = true,
})
-- Picture-in-Picture video (Zen/Firefox, Chromium): small, bottom-right corner,
-- pinned (follows you to every workspace), keeps the video shape, does not
-- steal focus from what you are doing.
-- This block must stay AFTER "browser-windows-open-floating": the PiP window's class is the browser's, so that
-- rule (centre, min_size) matches it too and, coming later, would win: the window could not be made
-- smaller than that and opened in the middle. min_size here puts that back.
hl.window_rule({
    name  = "pip",
    match = { title = "^(Picture-in-Picture|Picture in picture)$" },

    float             = true,
    pin               = true,       -- follow you to every workspace
    size              = "monitor_w*0.234375 monitor_w*0.1318359375",  -- small 16:9 video window (480x270 on the laptop)
    min_size          = "monitor_w*0.09765625 monitor_w*0.0546875",  -- may be resized small (the browser rule above asks for more)
    move              = "monitor_w-window_w-monitor_w*0.01 monitor_h-window_h-monitor_h*0.0156",  -- bottom-right corner
    keep_aspect_ratio = true,  -- keep the video's shape
    no_initial_focus  = true,  -- do not steal focus
})

-- sign-in / authorise pop-ups that sites and apps open ("Sign in with Google", OAuth, password prompts)
hl.window_rule({
    name  = "sign-in-popups",
    match = { title = "^(Sign in|Sign In|Log in|Log In|Login|Authorize|Authorise|Authentication|Unlock|Two-factor|2FA|Verify).*$" },

    float  = true,
    center = true,
})
hl.window_rule({
    name  = "sharing-indicator",
    match = { title = ".*Sharing Indicator.*" },

    float            = true,
    pin              = true,
    no_initial_focus = true,
    move             = "monitor_w/2-window_w/2 monitor_h*0.031",  -- top middle
})

-- ---------------------------------------------------------------------------
-- Transparency: every window gets the SAME global default from
-- decoration.lua (active 0.94 / inactive 0.88; fullscreen is solid). No
-- per-app rules on purpose (browser, file manager, ... all identical).
-- The one exception is technical: kitty makes its own transparency
-- (background_opacity in kitty.conf), so Hyprland's global value is set to an
-- absolute 1.0 for it; otherwise the two would multiply and the terminal
-- would look different from before.
-- ---------------------------------------------------------------------------
hl.window_rule({
    name  = "kitty-own-alpha",
    match = { class = "^kitty$" },

    opacity = "1.0 override 1.0 override",  -- "override" = ignore the global opacity (kitty has its own)
})

-- ---------------------------------------------------------------------------
-- Layer surfaces (bar, launcher, notifications from the future Quickshell
-- shell): blur what is behind them, and let their own transparent pixels
-- show it (ignore_alpha = don't blur fully transparent areas).
-- ---------------------------------------------------------------------------
hl.layer_rule({
    name  = "shell-blur",
    match = { namespace = "^(quickshell|shell).*" },

    blur         = true,  -- blur what is behind the shell
    ignore_alpha = 0.2,   -- do not blur fully transparent pixels
})

-- ---------------------------------------------------------------------------
-- music (~/.local/bin/music): ncspot + cava as ONE centred block on the music scratchpad (special:music, Super+M).
-- ncspot 968x640 on top, 12 px gap, cava 968x220 below (on the 2048x1280 laptop; the same shares of any screen),
-- block centred a little below the 30 px bar.
-- the disk image flasher (~/.local/bin/udiksa flash, caligula): floating in the middle
hl.window_rule({
    name  = "flash-window",
    match = { class = "^udiksa-flash$" },
    float = true,
    size  = "monitor_w*0.48828125 monitor_h*0.5",  -- 1000x640 on the laptop
    move  = "monitor_w*0.256 monitor_h*0.25",  -- centred
})
hl.window_rule({
    name      = "music-ncspot",
    match     = { class = "^rice-ncspot$" },
    float     = true,
    size      = "monitor_w*0.47265625 monitor_h*0.5",  -- 968x640 on the laptop
    move      = "monitor_w*0.2637 monitor_h*0.1711",
    workspace = "special:music",  -- on the music scratchpad (Super+M)
})
hl.window_rule({
    name             = "music-cava",
    match            = { class = "^rice-cava$" },
    float            = true,
    size             = "monitor_w*0.47265625 monitor_h*0.172",  -- 968x220 on the laptop
    move             = "monitor_w*0.2637 monitor_h*0.6805",
    workspace        = "special:music",
    no_initial_focus = true,  -- do not steal focus
})

-- Settings app (~/.config/quickshell/Settings.qml, Super+I): floating, centred, 1600x1000 on the laptop (user 2026-09-26),
-- the same share of any other screen (fixed sizes did not fit a 1366x768 TV, 2026-11-11)
hl.window_rule({
    name   = "settings-window",
    match  = { title = "^Settings$" },
    float  = true,
    center = true,
    size   = "monitor_w*0.78125 monitor_h*0.78125",  -- 1600x1000 on the laptop
})

-- btop from Settings > Monitor: floating, centred
hl.window_rule({
    name   = "btop-window",
    match  = { class = "^rice-btop$" },
    float  = true,
    center = true,
    size   = "monitor_w*0.68359375 monitor_h*0.671875",  -- 1400x860 on the laptop
})

-- system monitor scratchpad (Ctrl+Shift+Esc = ~/.local/bin/udiksa scratch sysmon): btop floating in the middle
hl.window_rule({
    name   = "sysmon-window",
    match  = { class = "^rice-sysmon$" },
    float  = true,
    center = true,
    size   = "monitor_w*0.68359375 monitor_h*0.671875",  -- 1400x860 on the laptop
})

-- screenshot editor (Alt+Print = ~/.local/bin/udiksa shot edit): floating, centred, most of the screen
hl.window_rule({
    name   = "screenshot-editor",
    match  = { class = "^com\\.gabm\\.satty$" },
    float  = true,
    center = true,
    size   = "monitor_w*0.8 monitor_h*0.8",  -- 80 % of the screen
})

-- nano (text files, "Edit" in Settings) and script runs: small centred floating terminals
hl.window_rule({
    name   = "edit-window",
    match  = { class = "^(rice-edit|rice-script)$" },
    float  = true,
    center = true,
    size   = "monitor_w*0.537 monitor_h*0.5625",  -- 1100x720 on the laptop
})

-- ---------------------------------------------------------------------------
-- EVERY window that opens floating (any app, any rule above, an app's own size such as Kaze's) must fit the screen
-- it opens on: bigger than 90 % of that screen -> shrunk to it and centred. Nothing here knows a screen size; it is
-- measured on the window's own monitor each time (user 2026-11-11: "a problem with all floating open apps").
-- ---------------------------------------------------------------------------
hl.on("window.open", function(w)
    if not w or not w.floating or not w.monitor or not w.size then return end
    local m = w.monitor
    local mw, mh = math.floor(m.width / m.scale * 0.9), math.floor(m.height / m.scale * 0.9)
    if w.size.x <= mw and w.size.y <= mh then return end
    local a = tostring(w.address); if not a:match("^0x") then a = "0x" .. a end
    hl.dispatch(hl.dsp.window.resize({ x = math.min(w.size.x, mw), y = math.min(w.size.y, mh), window = "address:" .. a }))
    hl.dispatch(hl.dsp.window.center({ window = "address:" .. a }))
end)
