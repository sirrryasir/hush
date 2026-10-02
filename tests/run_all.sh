#!/usr/bin/env bash
cd "$(dirname "$0")"
rc=0
for t in test_fonts.sh test_themes.sh test_templates_hypr.sh test_templates_term.sh test_templates_toolkit.sh test_hush_cli.sh test_plugins.sh test_hypr_live.sh test_nvim.sh test_helium.sh test_gtk.sh test_hyprlock.sh test_contrast.sh test_island_contrast.sh test_integration.sh test_shell.sh test_island.sh test_surface.sh test_modes.sh test_morph.sh test_rest.sh test_hover.sh test_launcher.sh test_wallpapers.sh test_media.sh test_activity_ui.sh test_osd.sh test_arbiter.sh test_settings.sh test_notifications.sh test_control_center.sh test_island_focus.sh test_retire.sh test_hooks.sh test_no_personal.sh test_readme.sh test_shell_integration.sh test_colorfade.sh; do
  echo "=== $t ==="; bash "$t" || rc=1
done
exit $rc
