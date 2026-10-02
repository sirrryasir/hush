# Phase 1 + 2 review (island v2), 2026-10-02

Scope: plan Phase 1 (Tasks 1-7) and Phase 2 (Tasks 8-12, 14, 15) against design 2.1-2.6 and code-study section 9 items 1-11, 14-17, 19. Rulings in the ledger are not findings unless they break the design intent.

Screens (28 PNGs, 640x380 crops of the pill area on the focused monitor, plus `sheet.png`, two columns harbor | paper) are in `~/.cache/hush/evidence/screens/<theme>-<state>.png`. They are not committed: the crops show the workspace behind the island. States: rest, hover, osd-volume, notif-normal, notif-critical, cc, cc-wifi, media, rest-media, calendar, notif-center, launcher, wallpapers, settings. Media used `tests/fakempris.py`.

Checks run: `tests/test_hover.sh` (all interaction groups pass; one flake, see Nice), manual ydotool pass over Esc and click-outside for launcher, settings, wallpapers, calendar and media (all close to rest), a click 2 px outside the pill (does not hover, active window unchanged), `tests/test_no_personal.sh` (PASS), grep for hardcoded monitor names and home paths in quickshell, bin, sddm, hypr (no hits), `hyprctl layers` (only `hush-island` per output plus awww-daemon, no stray hush layers), `hyprctl clients` (VS Code, helium, kitty only), `tests/contrast.py --island-gate`.

## Critical

1. **Light themes draw dark ink on the black pill, unreadable.** paper and fog use `Colors.on_surface` / `on_surface_variant` (dark in light themes) on the always-black pill: ratio 1.22 and 2.26 against 4.5 required (`contrast.py --island-gate`). Seen in `paper-launcher.png`, `paper-calendar.png`, `paper-notif-center.png`, `paper-settings.png`, `paper-wallpapers.png` (labels, values, month grid, "No notifications" nearly invisible). Lines: `surfaces/Settings.qml:47,58,71,80,93,112,140,198`, `surfaces/Launcher.qml:130,148,177`, `surfaces/launcher/ResultRow.qml:35,43`, `surfaces/Calendar.qml:49,59,81,101,115,122`, `surfaces/NotificationCenter.qml:42,59,71,99,105,127,132`, `surfaces/Wallpapers.qml:102,114`, `notif/NotifRow.qml:32,46,54,81`. Fix: use `Colors.darkOnSurface` / a dark-variant role (the rest and notification states already do), and dark-scheme container fills, or give the surfaces their own light backdrop. `paper-cc.png` shows the other half of the mismatch: light tiles on black, which reads but is a different language from the dark-text surfaces.
2. **The media surface is a square-cornered card, not a shape growing out of the pill.** `surfaces/Media.qml:49-57` fills its full 424x180 rect with a tinted rectangle; `Pill.qml:33` `clip: true` clips to a rectangle, not the rounded outline, so all four corners are square (pixel at the top-left corner of `harbor-media.png` is card colour, not wallpaper). Visible in `harbor-media.png`, `paper-media.png`. Fix: `ClippingRectangle` with the pill radius, or radius on the card.

## Important

1. **Media at rest is a 424x36 capsule, not the 2.1/2.7 activity circle on a ~136 px pill.** `harbor-rest-media.png`: title text and a tiny pause glyph, progress hairline offset from the capsule edge. Task 5 built the circle (Rest.qml), but the Task 6/7 media state still takes over while playing, so the slot design is only reachable in the harness. Files `states/MediaState.qml`, `states/MediaRegistrar.qml`. Rest pill is also 104 px alone (ruled), but the capsule is a different shape language from the symmetric three-slot rest.
2. **Critical notification looks like a normal one.** `harbor-notif-critical.png` vs `harbor-notif-normal.png`: same card, a generic purple glyph and no red or other marker, so sticky vs 5 s is invisible. Design 2.1 reserves red for critical. `states/NotifState.qml:40-60` (no urgency branch).
3. **Outside click closes an armed-or-not control center immediately.** The arming window (item 6) covers pill clicks; a click elsewhere 50 ms after opening the CC closed it (session log of the manual run). Probably intended for click-outside, but a stray click during the morph dismisses the surface. `Island.qml` click-outside path. Confirm intent.
4. **Wallpapers surface has dead space and low-contrast labels.** `harbor-wallpapers.png`: 624x340 with two rows of three tiles and an empty band at the bottom; tile names are small and dim; the `ember` and `moss` tiles nearly vanish on black (also in the CC theme strip, `harbor-cc.png`, where the `ember` tile reads as a gap). `surfaces/Wallpapers.qml:91-114`, `cc/ThemeStrip.qml:18`.
5. **Settings and notification center use about half their height.** `harbor-settings.png`, `harbor-notif-center.png` (empty state): content hugs the top, the bottom 100+ px are black. Looks like a fixed size not fitted to content. `config/Sizes.qml` settings, notifCenter.

## Nice

- Wi-Fi sub-page: weak-signal row icon renders as a single dot (`harbor-cc-wifi.png`, `cc/SubPage.qml`); big empty area under two networks.
- Calendar digits show per-column colour fringing on harbor (subpixel text on black, `harbor-calendar.png`); week start is Monday, fine.
- Launcher icons are an unthemed mix (KDE Connect, Xfce, Aduunyo placeholder) and the default list is alphabetical-by-recency oddities (`harbor-launcher.png`).
- `test_hover.sh` "still hover 150 ms after leaving" failed once (state already rest); the next assertion measured 310 ms, so it is IPC latency in the test, not a grace bug. Make the check use the history stamps.
- Rest pill: the status ring shows only a Wi-Fi glyph in an empty ring on a desktop without a battery (`harbor-rest.png`); an empty ring reads as a loading spinner.
- Multi-monitor: during the run the external monitor was disconnected, so only the laptop panel was exercised after the screenshots; item 14 was checked by the ledger tests earlier, not re-checked here.

## Items checked clean
Arbiter and queue (1-3, 17: tests green per ledger), hover dwell 121 ms and re-arm 0 ms (4, 5), arming on the control center (6), constant 1920x360 layer geometry across all states and only `hush-island` namespace (7, 8), 8 px width grid (10), declared sizes (11), IPC for every state (19), no personal data (test_no_personal).

## Verdict
Do not pass Phase 1+2 yet. Interaction, arbitration and geometry are sound, but two Criticals break the visual design: light themes are unreadable on five surfaces, and the media surface ignores the pill shape. Fix those two and the critical-notification styling, then re-shoot paper and the media states.
