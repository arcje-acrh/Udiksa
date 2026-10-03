-- Autostart: runs once when Hyprland starts (not on reload).
-- https://wiki.hypr.land/Configuring/Basics/Autostart/

hl.on("hyprland.start", function()
    -- wallpaper daemon: awww (animated transitions; driven by ~/.local/bin/rice-theme).
    -- It restores the last wallpaper by itself. Launched directly (no UWSM session target).
    hl.exec_cmd("awww-daemon")

    -- X11 apps: ~/.Xresources + Xft.dpi from the real screen scale (Hyprland draws them unscaled = sharp)
    hl.exec_cmd(os.getenv("HOME") .. "/.local/bin/rice-xdpi")

    -- polkit (password) prompts + notifications: handled by Quickshell itself
    -- (~/.config/quickshell/PolkitDialog.qml, Notifications.qml); hyprpolkitagent is no longer started

    -- clipboard history (cliphist): text + images
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")

    -- the Quickshell shell (notch bar, notifications, launcher, lock screen).
    -- config: ~/.config/quickshell/shell.qml (hot-reloads on save). Started through rice-shell: the same physical
    -- size on any screen / scale (QT_SCALE_FACTOR from the screen's scale and pixel density)
    hl.exec_cmd(os.getenv("HOME") .. "/.local/bin/rice-shell")

    -- idle: lock after 10 min, screen off after 11, lock before sleep (~/.config/hypr/hypridle.conf)
    hl.exec_cmd("hypridle")

    -- Hyprland plugins built by hyprpm (shake to find: conf/cursor.lua). Loaded silently (hyprpm's own -n puts up
    -- Hyprland's corner box, not a notification); only a failure is reported, as a normal notification in the notch
    hl.exec_cmd([[sh -c 'command -v hyprpm >/dev/null || exit 0; hyprpm reload >/dev/null 2>&1 || notify-send -a Hyprland "Plugin did not load" "Shake to find is off. Run Update system (launcher > Scripts) to rebuild it."']])

    -- first login after a fresh install (dotfiles 3-rice/apply.sh leaves a marker): theme, gsettings, default apps
    hl.exec_cmd("sh -c '[ -e ~/.local/state/rice/firstrun ] && ~/.local/bin/rice-firstrun'")
end)
