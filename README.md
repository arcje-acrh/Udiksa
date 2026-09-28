# Udiksa

An Arch Linux rice you can put on any machine: Hyprland + a home-made Quickshell shell (notch bar, launcher, lock and
login screen, Settings), 22 themes that recolour everything (Super+T) including GRUB, the login screen and the apps,
plus a set of apps that come themed.

**Design ships, personal choices stay.** The repo holds the design: the look, key binds, gaps, animations, window
rules, themes and wallpapers, the shell, app theming (no close / minimise buttons anywhere), core apps and maintenance
scripts. It adapts to the machine it lands on (screens, GPU, battery, Bluetooth, ASUS controls, boot loader) and never
replaces your system files: it edits single lines. Everything you choose afterwards stays on your machine only (§ Personal layer).

## Install

**Any installed Arch** (archinstall, your own setup, or part 1 below), logged in as your user, online:
```sh
sudo pacman -S --needed git
git clone <this repo> ~/Udiksa && cd ~/Udiksa
./install.sh 2 3
```
* **Part 2 (apps)**: the core apps, then asks about each optional app (Zen, OnlyOffice, ncspot, Tailscale).
* **Part 3 (the rice)**: links the configs, installs the rice's own system files (login screen, boot splash, quiet
  session), the GRUB theme if you use GRUB (other systems like Windows appear by themselves), and asks about
  **hibernation**: use a swap you already have, or make a swap file (size asked; its own `@swap` subvolume on btrfs).
* **Reboot.** The login screen appears; the first login sets the theme, desktop settings and default apps.

**A blank machine** (optional): from the Arch USB, `./install.sh 1` installs Arch itself on the disk you pick (never a
disk with Windows; `--dry-run` shows every step first): EFI + /boot + btrfs (`@ @home @log @pkg @snapshots @swap`),
a RAM-sized swap file for hibernation, zram, GRUB, your user. Then reboot and run `./install.sh 2 3`.

Left for you: Wi-Fi passwords, signing in to your apps, `sudo tailscale up`, OnlyOffice's theme (View > Interface theme > Rice).

## Layout

| Folder | What |
|---|---|
| `install.sh` | runs the parts |
| `1-arch/` | optional base installer for a blank disk |
| `2-packages/` | `repo.txt` + `aur.txt` (core apps), `hw-nvidia.txt`, `hw-intel.txt` (only with that GPU), `install-packages.sh` |
| `3-rice/home/` | the design's home files, **linked with GNU Stow**: `config/` → `~/.config`, `shell/` → `~` (`dot-bashrc` = `~/.bashrc`), `bin/` → `~/.local/bin`, `apps/` → `~/.local/share/applications`, `scripts/` → `~/.local/share/rice/scripts`, `wallpapers/` → `~/Pictures/Wallpapers` |
| `3-rice/optional/<app>/` | optional apps: `about`, `packages.txt`, `home/` (their rice files, linked only when the app is installed) |
| `3-rice/system/` | the rice's own system files (`common/`), `setup-hibernation.sh` |
| `3-rice/apply.sh` | part 3: stages `home`, `system`, `user` (each can run alone; `--dry-run` for the system stage) |

## Personal layer

`~/.config/hypr/local/` is yours: git ignores it, Hyprland loads it last, so it overrides the design on your machine.
Settings writes there (`settings.lua`: look / input / your startup apps and key binds; `monitors.lua`: your screens;
`power.json`: idle, lid, hibernate). You can add `env.lua` / `device.lua` by hand for machine-specific extras.
Other personal things (app settings, logins, Zen extensions) stay in the apps themselves, never in the repo.

## Everyday use

Configs are linked, so editing them at their normal paths edits the repo:
```sh
cd ~/Udiksa && git status && git add -A && git commit -m "what I changed"
```
* **Add an app's config to the design:** `mv ~/.config/<app> 3-rice/home/config/ && ./3-rice/apply.sh home`
* **Add a theme / script / launcher:** put it in `3-rice/home/wallpapers/`, `scripts/` or `apps/`, then `./3-rice/apply.sh home`
  (a theme folder made straight in `~/Pictures/Wallpapers` is moved into the repo by `apply.sh home`).
* **Not in the repo on purpose:** the personal layer, files the themer rewrites on every theme switch (`.gitignore`), secrets.

## Tools that come with it

`rice-theme` (themes), `rice-settings` (back end of Settings), `rice-defaults` (default apps per file type), `rice-idle`
(idle screen-off / sleep, battery vs charger), `rice-xdpi` (X11 apps follow the screen scale), `rice-panel-hz`
(built-in panel refresh rate), `display-mode` (F9 / Super+P: extend, mirror, …), `rice-firstrun` (first-login setup),
maintenance scripts in the launcher and Settings (update, mirrors via reflector, orphans, cache, …).
