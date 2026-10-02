-- Environment variables. Applied when Hyprland starts (not on reload).
-- https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/

-- the rice's own commands (~/.local/bin: rice-theme, music, rice-onlyoffice, ...) for launchers and key binds
-- only once: this file runs again on every config reload, and each run would add another copy
local bin, path = os.getenv("HOME") .. "/.local/bin", os.getenv("PATH") or "/usr/local/bin:/usr/bin"
if not (":" .. path .. ":"):find(":" .. bin .. ":", 1, true) then hl.env("PATH", bin .. ":" .. path) end

-- mouse pointer: "Udiksa" = Bibata Original in the theme's colours (~/.local/bin/rice-cursor, rebuilt by rice-theme on
-- every theme change). Settings > Themes > Pointer picks another; local/settings.lua (loaded later) then sets these again.
hl.env("XCURSOR_THEME", "Udiksa")
hl.env("HYPRCURSOR_THEME", "Udiksa")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- prefer native Wayland for toolkits, fall back to X11
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
-- Qt apps take their look from qt6ct (style Kvantum "Rice", colours written by ~/.local/bin/rice-theme)
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-- X11 apps that ignore Xft.dpi (Steam, Java) get their scale per machine: ~/.config/hypr/local/env.lua (personal layer)
hl.env("_JAVA_OPTIONS", "-Dawt.useSystemAAFontSettings=on")

-- no title bars / close buttons drawn by Qt apps themselves (Hyprland needs none; Super+Q closes)
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
