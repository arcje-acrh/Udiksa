# Hardware support

Udiksa runs on any Arch machine. It **detects the hardware at login** and the notch and Settings show **only what
works here**: no fan sliders without fan control, no Wi-Fi page without Wi-Fi, no laptop-screen controls on a desktop.
Settings › About › *Hardware support* lists what was found on your machine.

This page shows what each part needs, what is covered today, and how to add support for your own device.

---

## What is supported

| Feature | Works on | Uses | Not found → |
|---|---|---|---|
| Performance modes (Silent / Balanced / Turbo), Auto on battery | **ASUS**: modes + CPU watts + fan curves · **any other machine**: modes | `asusctl` · `power-profiles-daemon` | page and notch section hidden |
| GPU mode (Eco / Standard / Ultimate) | hybrid NVIDIA laptops (Ultimate only with a MUX switch) | `supergfxctl` (`hardware/nvidia`) | hidden |
| Laptop screen: 60 Hz / top rate / Auto | any laptop panel with more than one refresh rate | `hyprctl`, `rice-panel-hz` | hidden |
| Panel overdrive | ASUS laptops that have it | `asusctl armoury` | hidden |
| Keyboard light | **any** backlit keyboard (brightness) · **ASUS**: colours and effects too | `/sys/class/leds/*::kbd_backlight` + `brightnessctl` · `rice-kbd` | hidden |
| Slash lid light | ASUS laptops with a Slash bar | `rice-slash` | hidden |
| Battery, charge limit | any battery · charge limit: ASUS | UPower · `asusctl` | battery rows hidden; the page becomes *Power & sleep* |
| Lid actions | laptops | logind | hidden |
| Touchpad settings | touchpads | Hyprland | hidden; pointer speed stays (under *Mouse*) |
| Fans | **ASUS**: speeds + curves · **other**: speeds only | hwmon | hidden |
| GPU load / temperature | desktop GPUs (AMD, or NVIDIA as the only card) | sysfs, `nvidia-smi` | hidden |
| External monitor brightness | monitors with DDC/CI | `ddcutil` | row hidden |
| Wi-Fi, Bluetooth, Tailscale | when the adapter / app is there | NetworkManager, BlueZ, Tailscale | page hidden (the notch always keeps a network icon: Wi-Fi, LAN or "not connected") |
| Hibernate | when a swap file is set up (`3-rice/system/setup-hibernation.sh`) | systemd | button and row hidden |

## How detection works

Everything is detected in one place: [`3-rice/home/config/quickshell/Power.qml`](../3-rice/home/config/quickshell/Power.qml),
section *what this machine has*. A short shell probe sets flags such as `asus`, `gfx`, `ppd`, `kbdName`, `panelRates`,
`touchpad`, `lid`, `fans`; `battery`, `wifi` and `bt` are live. Every panel and Settings page reads these flags
(`visible: Power.kbd`, `needs: "wifi"` in `Settings.qml`, …).

**Test without the hardware.** Start the shell with `UDIKSA_FAKE` to make it act as if parts were missing:

```sh
UDIKSA_FAKE="noasus nogfx nopanel nobattery nolid notouchpad nokbd nowifi" setsid -f rice-shell --restart   # roughly a desktop
setsid -f rice-shell --restart                                                                              # back to normal
```
Words: `noasus nogfx noppd nopanel nokbd notouchpad nolid nofans nobattery nowifi nobt`. Only the shell is fooled;
nothing on the machine changes.

---

## Add support for your device

### 1. Is there already a standard way?
Many features work through standard Linux interfaces; if your machine has them, Udiksa uses them without changes:

- **Keyboard light**: needs a `*::kbd_backlight` LED in `/sys/class/leds` (ThinkPad, Dell, HP, Lenovo, Framework… usually yes).
- **Performance modes**: `power-profiles-daemon` (`powerprofilesctl list`). Uses the firmware's *platform profile* where there is one.
- **Fan speeds**: anything under `/sys/class/hwmon/*/fan*_input`. Missing? Try `sudo sensors-detect` (package `lm_sensors`).
- **Monitor brightness**: `ddcutil detect` should list the monitor; if not, turn on DDC/CI in the monitor's own menu.

### 2. Add a hardware module
A device family gets its own folder, like `hardware/asus` and `hardware/nvidia`:

```
hardware/<name>/
├── about          one paragraph: what it adds (shown by the installer)
├── detect         exit 0 when this machine needs it (e.g. grep the vendor in /sys/class/dmi/id/sys_vendor)
├── install.sh     installs packages.txt, links home/bin into ~/.local/bin, copies system/ to /, enables services
├── packages.txt   one package per line; "aur:name" for the AUR
├── home/bin/      your tools (on PATH as ~/.local/bin/…)
└── system/        files copied to / (services, udev rules)
```
`~/Udiksa/install.sh` runs every `detect` after part 3 and offers the module when it fits. Copy `hardware/nvidia`
(the smallest) as a start.

### 3. Connect it to the shell
1. **Detect it** in `Power.qml`: add a line to the probe (`command -v mytool >/dev/null && echo mytool`) and a flag
   (`property bool mytool: false`, set in `onStreamFinished`).
2. **Use it**: put the commands next to the existing ones in `Power.qml` (e.g. `applyMode()` has an ASUS branch and a
   power-profiles-daemon branch: add yours), and show the control with `visible: Power.mytool`.
3. **Add it to Settings › About › Hardware support** (`SetAbout.qml`, the `found` list).

Rule: **a control is visible only when it works.** Nothing greyed out, nothing that silently does nothing.

### Ideas and where to start

| Want | Tool / link |
|---|---|
| Fan control on ThinkPad | [`thinkfan`](https://wiki.archlinux.org/title/Fan_speed_control#ThinkPad_laptops) |
| Fan control on Dell | [`i8kutils` / `dell-smm-hwmon`](https://wiki.archlinux.org/title/Fan_speed_control#Dell_laptops) |
| Fan control on many other laptops | [NBFC-Linux](https://github.com/nbfc-linux/nbfc-linux) |
| Battery charge limit (ThinkPad, Dell, Framework, LG, Huawei, Samsung…) | `/sys/class/power_supply/BAT*/charge_control_end_threshold` ([ArchWiki](https://wiki.archlinux.org/title/Laptop#Battery_charge_threshold)) |
| Keyboard colours (non-ASUS) | [OpenRGB](https://openrgb.org) |
| Performance modes on older machines | [ArchWiki: CPU frequency scaling](https://wiki.archlinux.org/title/CPU_frequency_scaling), [power-profiles-daemon](https://gitlab.freedesktop.org/upower/power-profiles-daemon) |
| Hybrid GPU on non-ASUS laptops | [supergfxctl](https://gitlab.com/asus-linux/supergfxctl) (works on many brands), [ArchWiki: NVIDIA Optimus](https://wiki.archlinux.org/title/NVIDIA_Optimus) |
| External monitor brightness | [ArchWiki: ddcutil](https://wiki.archlinux.org/title/Backlight#External_monitors) |
| Your laptop model in general | [ArchWiki: Laptop](https://wiki.archlinux.org/title/Laptop) and the model's own page |

Made it work? A pull request with your `hardware/<name>` folder is welcome.
