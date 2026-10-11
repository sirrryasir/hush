#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
cd "$(dirname "$0")/.."
EVD="${HUSH_EVIDENCE_DIR:-assets/evidence}"; mkdir -p "$EVD"
t_all_themes() {
  bin/hush theme fog >/dev/null  # prime with a different theme so the first change is observable
  for t in harbor ember moss dusk paper fog; do
    local before after
    before=$(md5sum < ~/.config/hush/Colors.json 2>/dev/null | awk '{print $1}' || echo none)
    bin/hush theme "$t" >/dev/null || { fail "apply $t"; continue; }
    after=$(md5sum < ~/.config/hush/Colors.json | awk '{print $1}')
    [[ "$before" != "$after" ]] && pass "$t changed Colors.json" || fail "$t did not change Colors.json"
    assert_exit 0 "$t passes hush check" bin/hush check
    local mode; mode=$(python3 -c "import json;print(json.load(open('$CFG/hush/Colors.json'))['mode'])")
    local want; want=$(grep -oE '^mode = "[a-z]+"' "themes/$t/theme.toml" | cut -d'"' -f2)
    assert_eq "$want" "$mode" "$t mode is $want"
    local gs; gs=$(gsettings get org.gnome.desktop.interface color-scheme)
    if [[ "$want" == "light" ]]; then assert_eq "'prefer-light'" "$gs" "$t sets GTK light"; else assert_eq "'prefer-dark'" "$gs" "$t sets GTK dark"; fi
    hyprctl dispatch dpms on >/dev/null; sleep 2
    grim "$EVD/task12-$t.png" && pass "$t screenshot" || fail "$t screenshot"
  done
  bin/hush theme harbor >/dev/null
}
run_test "all six themes" t_all_themes
finish
