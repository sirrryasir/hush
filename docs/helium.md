# Helium and Hush

Hush writes a Chromium theme to `~/.config/hush/helium-theme/manifest.json` every time the theme changes.
Load it once:

1. Open `chrome://extensions` in Helium.
2. Turn on Developer mode (top right).
3. Click "Load unpacked" and choose `~/.config/hush/helium-theme`.

From then on, restart Helium after `hush theme <name>` to pick up the new colors. Helium also follows
the GTK dark/light preference that `hush` sets, so pages that respect `prefers-color-scheme` switch too.
