#!/usr/bin/env bash
# setup/rice.sh -- PART 3: put the whole rice in place (after part 2 installed the apps).
#   home    link dots/ into ~ with GNU Stow -- dots/ mirrors your home 1:1 (files you already have there are moved to
#           ~/.dotfiles-backup/<date>)
#   system  the rice's own system files (login screen, boot splash, quiet session), GRUB theme (if GRUB), services,
#           hibernation (checked / asked); your own system files are only edited line by line, never replaced
#   user    standard folders, ble.sh prompt, first-login setup (theme, default apps)
# Usage:  setup/rice.sh [home] [system] [user] [--dry-run]      (no stage = all three)
# --dry-run prints the system commands instead of running them (home/user stages are safe to repeat anyway).
# Run as your normal user; sudo is used for the system stage. Safe to run again.
set -euo pipefail
REPO=$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)
DOTS="$REPO/dots"
SYS="$REPO/system"
DRY=0; STAGES=()
for a in "$@"; do case $a in --dry-run) DRY=1 ;; home|system|user) STAGES+=("$a") ;; *) echo "unknown: $a"; exit 1 ;; esac; done
[[ ${#STAGES[@]} -eq 0 ]] && STAGES=(home system user)
[[ $EUID -eq 0 ]] && { echo "Run as your user, not root."; exit 1; }

say()  { printf '\n\033[1;32m==>\033[0m %s\n' "$*"; }
note() { printf '    %s\n' "$*"; }
warn() { printf '\033[1;33m  ! %s\033[0m\n' "$*"; }
run()  { if ((DRY)); then printf '    [dry] %s\n' "$*"; else "$@"; fi; }          # system commands
S()    { run sudo "$@"; }
has_stage() { [[ " ${STAGES[*]} " == *" $1 "* ]]; }

# ============================================================== home ==========================================
# dots/ (and optional/<app>/dots, hardware/<x>/dots) mirror your home: dots/.config/hypr -> ~/.config/hypr, ...
# These folders are made as REAL folders first, so Stow links what is inside them (one link per app / tool / theme)
# and never turns a whole ~/.config or ~/Pictures into a link into the repo.
REAL_DIRS=(.config .local/bin .local/share/applications .local/share/rice .local/share/rice/scripts Pictures/Wallpapers)
link_dots() {   # link_dots <a dots/ folder>
    local d=$1 f rel t p part
    for rel in "${REAL_DIRS[@]}"; do [[ -d $d/$rel ]] && mkdir -p "$HOME/$rel"; done
    # anything already at a target path that is not ours: backed up; a link left dangling (e.g. by a repo move): removed
    while IFS= read -r -d '' f; do
        rel=${f#"$d/"}; t="$HOME/$rel"
        [[ "$(readlink -f "$t" 2>/dev/null)" == "$(readlink -f "$f")" ]] && continue      # already ours
        p=$HOME
        IFS=/ read -ra parts <<<"$rel"
        for part in "${parts[@]}"; do
            p="$p/$part"
            if [[ -L $p && ! -e $p ]]; then rm "$p"; break; fi
        done
        if [[ -e $t || -L $t ]]; then
            mkdir -p "$backup/$(dirname "$rel")"; mv "$t" "$backup/$rel"; moved=$((moved + 1))
        fi
    done < <(find "$d" -type f -print0)
    stow -d "$(dirname "$d")" -t "$HOME" --restow "$(basename "$d")"
}
stage_home() {
    say "Linking your dotfiles into ~ (GNU Stow)"
    command -v stow >/dev/null || { warn "stow is missing (part 2 installs it)"; exit 1; }
    moved=0; backup="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
    # theme folders made straight in ~/Pictures/Wallpapers (not links yet): move them into the repo so they ship with it
    local w
    for w in "$HOME/Pictures/Wallpapers"/*/; do
        w=${w%/}; [[ -L $w || ! -d $w ]] && continue
        if [[ -e $DOTS/Pictures/Wallpapers/$(basename "$w") ]]; then warn "$(basename "$w"): also in the repo, left alone"
        else mv "$w" "$DOTS/Pictures/Wallpapers/"; note "wallpapers: added theme $(basename "$w") to the repo"; fi
    done
    link_dots "$DOTS"
    note "linked dots/ -> ~"
    # optional apps (optional/<app>, asked in part 2): their rice files only where the app is installed
    local o pkg
    for o in "$REPO"/optional/*/; do
        pkg=$(grep -vE '^\s*(#|$)' "$o/packages.txt" | head -1); pkg=${pkg#aur:}
        pacman -Qq "$pkg" &>/dev/null || continue
        [[ -d $o/dots ]] && { link_dots "${o%/}/dots"; note "linked optional app $(basename "$o")"; }
    done
    ((moved)) && note "$moved existing file(s) moved to $backup"
    mkdir -p "$HOME/Pictures/Screenshots" "$HOME/.local/state/rice" "$HOME/.local/state/quickshell"
    fc-cache -f >/dev/null 2>&1 || true
}

# ============================================================== system ========================================
install_tree() {                      # copy a system/<group> tree to /, keeping file modes
    local root=$1 f rel
    while IFS= read -r -d '' f; do
        rel=${f#"$root"}
        S install -D -m "$(stat -c %a "$f")" "$f" "$rel"
    done < <(find "$root" -type f -print0)
}

# set KEY="VALUE" in /etc/default/grub (replaced if there, added if not); the rest of your file stays as it is
grub_set() { if grep -q "^$1=" /etc/default/grub; then S sed -i "s|^$1=.*|$1=$2|" /etc/default/grub; else echo "$1=$2" | S tee -a /etc/default/grub >/dev/null; fi; }
# set it only if this machine has not chosen it yet (an existing line, even a different value, is kept)
grub_default() { grep -q "^$1=" /etc/default/grub || echo "$1=$2" | S tee -a /etc/default/grub >/dev/null; }
# add a kernel parameter to GRUB_CMDLINE_LINUX_DEFAULT unless it is there
grub_param() { grep -qE "^GRUB_CMDLINE_LINUX_DEFAULT=\"([^\"]* )?${1//./\\.}( |\")" /etc/default/grub || S sed -i -E "s|^(GRUB_CMDLINE_LINUX_DEFAULT=\"[^\"]*)|\1 $1|" /etc/default/grub; }

stage_system() {
    # The rice installs only its OWN system files and edits single lines elsewhere: your pacman.conf, mkinitcpio.conf,
    # GRUB settings, fstab, ... stay yours. Whatever is missing on this machine (GRUB, mkinitcpio) is skipped.
    say "The rice's system files (login screen, boot splash, quiet session, power helper)"
    install_tree "$SYS/common"
    S chmod 440 /etc/sudoers.d/udiksa-power           # Settings > Battery & sleep may set lid / power-button actions
    # the Hyprland session starts through the quiet wrapper (the pacman hook re-applies this after updates)
    [[ -f /usr/share/wayland-sessions/hyprland.desktop ]] && S sed -i 's|^Exec=.*|Exec=/usr/local/bin/start-hyprland-quiet|' /usr/share/wayland-sessions/hyprland.desktop

    say "Login screen + lock screen folders"
    S install -d -o "$USER" -g "$USER" -m 755 /var/lib/rice-greeter
    if getent passwd greeter >/dev/null; then S install -d -o greeter -g greeter -m 700 /var/cache/rice-greeter; fi

    if [[ -f /etc/mkinitcpio.conf ]]; then
        say "Boot splash (plymouth hook in mkinitcpio.conf)"
        if grep -qE '^HOOKS=.*\bplymouth\b' /etc/mkinitcpio.conf; then note "already there"
        else S sed -i -E 's/^(HOOKS=\([^)]*\b(udev|systemd))\b/\1 plymouth/' /etc/mkinitcpio.conf; note "added"; fi
    else note "no mkinitcpio: add plymouth to your initramfs yourself for the boot splash"; fi
    if [[ -f /etc/mkinitcpio.conf ]]; then
        # early KMS: the splash shows from the start in full resolution when the screen's GPU driver is in the boot image.
        # Only the driver of the GPU the firmware draws on (boot_vga), and only the open ones -- not the `kms` hook,
        # which would also pull in nouveau on NVIDIA machines.
        say "Early display driver (mkinitcpio MODULES)"
        kms=""
        for d in /sys/bus/pci/devices/*; do
            [[ -f $d/boot_vga && $(<"$d/boot_vga") == 1 && -e $d/driver ]] && kms=$(basename "$(readlink -f "$d/driver")")
        done
        case $kms in
            i915|xe|amdgpu|radeon)
                if grep -qE "^MODULES=\(.*\b$kms\b" /etc/mkinitcpio.conf; then note "$kms: already there"
                else S sed -i -E "s/^MODULES=\(([^)]*)\)/MODULES=(\1 $kms)/; s/^MODULES=\( /MODULES=(/" /etc/mkinitcpio.conf; note "$kms added"; fi ;;
            *) note "skipped (screen GPU driver: ${kms:-unknown})" ;;
        esac
    fi

    local GRUB=0
    [[ -f /etc/default/grub ]] && command -v grub-mkconfig >/dev/null && GRUB=1
    if ((GRUB)); then
        say "GRUB: the rice theme, quiet boot, other systems (Windows, ...) found automatically"
        S install -d -o "$USER" -g "$USER" /boot/grub/themes/rice     # rice-theme writes the theme into it
        local F=/usr/share/fonts/TTF
        if [[ -f $F/IosevkaNerdFont-Regular.ttf ]]; then
            run grub-mkfont -n RiceTerm -s 24 -o /boot/grub/themes/rice/term-24.pf2 $F/IosevkaNerdFont-Regular.ttf 2>/dev/null
            run grub-mkfont -n RiceTerm -s 34 -o /boot/grub/themes/rice/term-34.pf2 $F/IosevkaNerdFont-Regular.ttf 2>/dev/null
            run grub-mkfont -n RiceTermBold -s 34 -o /boot/grub/themes/rice/termbold-34.pf2 $F/IosevkaNerdFont-Bold.ttf 2>/dev/null
        else warn "Iosevka Nerd Font missing (part 2): GRUB keeps its default font"; fi
        grub_set GRUB_THEME '"/boot/grub/themes/rice/theme.txt"'
        grub_set GRUB_TERMINAL_OUTPUT gfxterm
        grub_default GRUB_GFXMODE auto
        grub_set GRUB_GFXPAYLOAD_LINUX keep
        grub_default GRUB_DISABLE_SUBMENU y                  # one entry per system, no "Advanced options" menu
        grub_default GRUB_DISABLE_OS_PROBER false            # Windows / other systems show up by themselves
        grub_default GRUB_DISABLE_RECOVERY true
        for p in quiet splash loglevel=3 vt.global_cursor_default=0; do grub_param "$p"; done
    else note "no GRUB here: the boot menu theme is skipped (the rest of the rice does not need it)"; fi

    say "Services"
    local svc=(NetworkManager bluetooth greetd systemd-timesyncd power-profiles-daemon)
    pacman -Qq tailscale &>/dev/null && svc+=(tailscaled)             # optional app
    for s in "${svc[@]}"; do
        systemctl list-unit-files "$s.service" >/dev/null 2>&1 && S systemctl enable "$s" 2>/dev/null || note "skip $s (not installed)"
    done

    say "Hibernation"
    if ((DRY)); then note "[dry] would check / ask (system/setup-hibernation.sh)"; else S "$SYS/setup-hibernation.sh" --no-rebuild; fi

    say "Snapshots (btrfs only: automatic for part 1 installs, asked otherwise)"
    if ((DRY)); then note "[dry] would check / ask (system/setup-snapshots.sh)"; else S "$SYS/setup-snapshots.sh"; fi

    say "Boot image + boot menu"
    [[ -f /etc/mkinitcpio.conf ]] && S mkinitcpio -P
    ((GRUB)) && S grub-mkconfig -o /boot/grub/grub.cfg
    true
}

# ============================================================== user ==========================================
stage_user() {
    say "Standard folders (Documents, Downloads, Music, Pictures, Videos)"
    xdg-user-dirs-update


    say "ble.sh (the bash line editor behind the prompt's right-hand clock)"
    if [[ ! -f $HOME/.local/share/blesh/ble.sh ]]; then
        local tmp; tmp=$(mktemp -d)
        curl -sfL https://github.com/akinomyoga/ble.sh/releases/download/nightly/ble-nightly.tar.xz -o "$tmp/ble.tar.xz" &&
            tar -xJf "$tmp/ble.tar.xz" -C "$tmp" && bash "$tmp"/ble-nightly/ble.sh --install "$HOME/.local/share" >/dev/null &&
            note "installed" || warn "could not install ble.sh (the prompt still works without it)"
        rm -rf "$tmp"
    else note "already there"; fi

    say "First login"
    touch "$HOME/.local/state/rice/firstrun"
    note "At your next Hyprland login: theme + wallpaper, desktop settings and default apps are set up by themselves"
    note "(log: ~/.cache/rice-firstrun.log). Tailscale: run 'sudo tailscale up' once, then 'sudo tailscale set --operator=\$USER'."
}

has_stage home && stage_home
has_stage system && stage_system
has_stage user && stage_user
say "Part 3 done."
