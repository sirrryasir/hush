# Lock and login screens

Both screens share one layout, "island-native" (`lockscreen/layout.toml`, sizes at 1080p,
positions as fractions of the screen height): a thin Inter clock with tabular figures and the
date over the blurred, dimmed wallpaper, and one black pill, the same black as the island,
holding your avatar and the password. Battery and network sit top right as icons. A wrong
password turns the pill's hairline red. `hush face <image>` sets the avatar for both (a round
512 px crop written to `~/.face`, then `hush sddm sync`).

## Lock (hyprlock)

`hush reload` and `hush lock` generate `~/.config/hush/hyprlock-layout.conf` from the spec, one
widget set per connected monitor; `hyprlock/hyprlock.conf` sources it. Caps lock and the
fingerprint prompt show as glyphs inside the pill. hyprlock cannot animate shapes, so the lock
screen is the static form of the layout.

## Login (SDDM)

`sddm/hush/` is a Qt 6 greeter with the same layout plus motion: the pill grows when you type,
a round submit button appears, it shrinks to a circle with a spinning arc while checking, shakes
on a wrong password, and fades with the clock lifting on success. Three buttons at the bottom
open the session list (Hyprland first, last choice remembered), suspend, and restart/shut down.
Type and press Enter; Tab reaches the buttons, arrows and Enter pick a session, Esc closes.

Install it once, as root (`install.sh` never runs sudo):

```
sudo sddm/install.sh
```

This copies the theme to `/usr/share/sddm/themes/hush` with Inter and Material Symbols (the
greeter runs as the `sddm` user and cannot see your fonts), writes
`/etc/sddm.conf.d/hush.conf` (`[Theme] Current=hush`) and links `hush/current` to
`~/.cache/hush/sddm`. A `Current=` line in `/etc/sddm.conf` is read last and wins; the installer
prints the fix when it finds one. `hush sddm sync` writes the wallpaper, avatar, palette
(`colors.qml`) and layout (`layout.qml`) there, world-readable; `hush theme` and `hush wall`
call it once that directory exists. `$HOME` must be traversable by the `sddm` user
(`chmod o+x ~`); `hush sddm sync` warns when it is not.

Preview without logging out: `sddm-greeter-qt6 --test-mode --theme sddm/hush` inside a nested
compositor (`tests/test_sddm.sh` does this in a nested Hyprland).
