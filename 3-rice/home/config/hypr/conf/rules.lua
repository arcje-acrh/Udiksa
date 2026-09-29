-- Window / layer rules.
-- https://wiki.hypr.land/Configuring/Basics/Window-Rules/

-- ignore maximize requests from apps
hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },

    suppress_event = "maximize",
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

    no_focus = true,
})

-- Hyprland's own run-dialog window
hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },

    move  = "20 monitor_h-120",
    float = true,
})

-- ---------------------------------------------------------------------------
-- Windows that should OPEN FLOATING (never tiled). Add more by copying a block.
-- ---------------------------------------------------------------------------
-- Picture-in-Picture video (Zen/Firefox, Chromium): small, bottom-right corner,
-- pinned (follows you to every workspace), keeps the video shape, does not
-- steal focus from what you are doing.
hl.window_rule({
    name  = "pip",
    match = { title = "^(Picture-in-Picture|Picture in picture)$" },

    float             = true,
    pin               = true,
    size              = "480 270",
    move              = "monitor_w-500 monitor_h-290",
    keep_aspect_ratio = true,
    no_initial_focus  = true,
})

-- file pickers and save / open / print dialogs: float in the middle
hl.window_rule({
    name  = "dialogs",
    match = { title = "^(Open|Open File|Open Files|Open Folder|Save|Save As|Save File|Select a File|Choose Files?|File Upload|Select Folder|Export|Import|Print|Properties|Preferences|Rename)( .*)?$" },

    float  = true,
    center = true,
})
hl.window_rule({
    name  = "portal-file-chooser",
    match = { class = "^(xdg-desktop-portal-gtk|xdg-desktop-portal-kde|org.freedesktop.impl.portal.desktop.kde)$" },

    float  = true,
    center = true,
    size   = "1000 640",
})

-- small utility windows (sound, Bluetooth, network editor, calculator,
-- the browser's Library / Downloads window, screen-sharing indicator)
hl.window_rule({
    name  = "utility-apps",
    match = { class = "^(pavucontrol|org.pulseaudio.pavucontrol|blueman-manager|.blueman-manager-wrapped|nm-connection-editor|qalculate-gtk|org.gnome.Calculator|gnome-calculator)$" },

    float  = true,
    center = true,
    size   = "900 600",
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
    match = { class = "^(zen|firefox|librewolf|chromium|google-chrome|brave-browser)$" },

    float  = true,
    center = true,
})
-- browser EXTENSION pop-outs (user 2026-09-26: the Bitwarden unlock window opened tiled). Their title is
-- "Extension: (<extension name>) - <page> — Zen Browser" (same pattern in Firefox; Chromium: class
-- "crx_..."): float them in the middle at the size they ask for. (Zen names its pop-ups only AFTER they
-- open, so ~/.config/quickshell/FloatWatcher.qml floats those the moment they appear.)
hl.window_rule({
    name  = "browser-extension-popups",
    match = { title = "^Extension: \\(.*" },

    float  = true,
    center = true,
})
hl.window_rule({
    name  = "chromium-extension-popups",
    match = { class = "^crx_.*" },

    float  = true,
    center = true,
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
    move             = "monitor_w/2-100 40",
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

    opacity = "1.0 override 1.0 override",
})

-- ---------------------------------------------------------------------------
-- Layer surfaces (bar, launcher, notifications from the future Quickshell
-- shell): blur what is behind them, and let their own transparent pixels
-- show it (ignore_alpha = don't blur fully transparent areas).
-- ---------------------------------------------------------------------------
hl.layer_rule({
    name  = "shell-blur",
    match = { namespace = "^(quickshell|shell).*" },

    blur         = true,
    ignore_alpha = 0.2,
})

-- ---------------------------------------------------------------------------
-- music (~/.local/bin/music): ncspot + cava as ONE centred block on the scratchpad (user 2026-09-26).
-- ncspot 968x640 on top, 12 px gap, cava 968x220 below; block height 872 -> top = centre - 436
-- (+15 for the 30 px bar at the top of the screen).
-- the disk image flasher (~/.local/bin/rice-flash, caligula): floating in the middle
hl.window_rule({
    name  = "flash-window",
    match = { class = "^rice-flash$" },
    float = true,
    size  = "1000 640",
    move  = "monitor_w*0.5-500 monitor_h*0.5-320",
})
hl.window_rule({
    name      = "music-ncspot",
    match     = { class = "^rice-ncspot$" },
    float     = true,
    size      = "968 640",
    move      = "monitor_w*0.5-484 monitor_h*0.5-421",
    workspace = "special:magic",
})
hl.window_rule({
    name             = "music-cava",
    match            = { class = "^rice-cava$" },
    float            = true,
    size             = "968 220",
    move             = "monitor_w*0.5-484 monitor_h*0.5+231",
    workspace        = "special:magic",
    no_initial_focus = true,
})

-- Settings app (~/.config/quickshell/Settings.qml, Super+I): floating, centred, 1600x1000 (user 2026-09-26)
hl.window_rule({
    name   = "settings-window",
    match  = { title = "^Settings$" },
    float  = true,
    center = true,
    size   = "1600 1000",
})

-- btop from Settings > Monitor: floating, centred
hl.window_rule({
    name   = "btop-window",
    match  = { class = "^rice-btop$" },
    float  = true,
    center = true,
    size   = "1400 860",
})

-- nano (text files, "Edit" in Settings) and script runs: small centred floating terminals
hl.window_rule({
    name   = "edit-window",
    match  = { class = "^(rice-edit|rice-script)$" },
    float  = true,
    center = true,
    size   = "1100 720",
})
