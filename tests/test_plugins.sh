#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
cd "$(dirname "$0")/.."
H=bin/hush
# A PATH of stubs: hyprctl reports one plugin, hyprpm knows nothing and records its calls.
mkstubs() {
  local d; d=$(mktemp -d)
  cat > "$d/hyprctl" <<'S'
#!/usr/bin/env bash
case "$1 $2" in
  "plugin list") printf 'Plugin GloView by Someone:\n\tHandle: 1\n' ;;
  "configerrors "*) ;;
  gloview*) echo "gloview-called" ;;
esac
S
  cat > "$d/hyprpm" <<S
#!/usr/bin/env bash
echo "\$*" >> "$d/hyprpm.log"
[[ "\$1" == list ]] && exit 0
exit 0
S
  chmod +x "$d/hyprctl" "$d/hyprpm"; echo "$d"
}
t_status() {
  local d out; d=$(mkstubs)
  out=$(PATH="$d:$PATH" HOME="$d/home" USER=nobody-zz $H plugins status)
  grep -qE '^gloview +loaded yes +installed (yes|no)$' <<<"$out" && pass "status lists gloview as loaded" || fail "gloview line: $out"
  grep -qE '^dynamic-cursors +loaded no +installed no$' <<<"$out" && pass "status lists dynamic-cursors as missing" || fail "dynamic-cursors line: $out"
  out=$(PATH="$d:$PATH" $H overview); assert_eq "gloview-called" "$out" "overview runs hyprctl gloview"
  rm -rf "$d"
}
t_install() {
  local d out; d=$(mkstubs)
  out=$(PATH="$d:$PATH" HOME="$d/home" USER=nobody-zz $H plugins install 2>&1)
  grep -q '^+ hyprpm add https://github.com/VirtCode/hypr-dynamic-cursors' <<<"$out" && pass "install prints and runs hyprpm add" || fail "install output: $out"
  grep -q '^enable dynamic-cursors$' "$d/hyprpm.log" && pass "install enables the plugin" || fail "no enable call"
  rm -rf "$d"
}
t_check_warns() {
  local d out; d=$(mkstubs)
  out=$(PATH="$d:$PATH" HYPRLAND_INSTANCE_SIGNATURE=x $H check 2>&1)
  grep -q 'warning: plugin dynamic-cursors is not loaded' <<<"$out" && pass "check warns about the missing plugin" || fail "no warning: $out"
  grep -q 'warning: plugin gloview' <<<"$out" && fail "check warned about a loaded plugin" || pass "check is quiet about loaded plugins"
  rm -rf "$d"
}
t_fragment() {
  luac -p hypr/plugins.lua && pass "plugins.lua compiles" || fail "plugins.lua syntax"
  USER=nobody-zz XDG_CACHE_HOME=/nonexistent-zz lua -e '
    local loaded, cfg = {}, {}
    hl = { plugin = { load = function(p) loaded[#loaded+1] = p end }, config = function(t) cfg[#cfg+1] = t end }
    dofile("hypr/plugins.lua")
    assert(#loaded == 0 and #cfg == 0, "nothing loads when the plugins are absent")' \
    && pass "fragment is a no-op without plugins" || fail "fragment errored without plugins"
  local tmp; tmp=$(mktemp -d); mkdir -p "$tmp/c/dynamic-cursors" "$tmp/c/hyprpm/gloview" "$tmp/c/hyprpm/dynamic-cursors" "$tmp/cfg/hypr/modules"
  touch "$tmp/c/hyprpm/gloview/gloview.so" "$tmp/c/hyprpm/dynamic-cursors/dynamic-cursors.so"
  echo 'return { backdrop_color = 1 }' > "$tmp/cfg/hypr/modules/gloview-colors.lua"
  USER=nobody-zz XDG_CACHE_HOME="$tmp/c" XDG_CONFIG_HOME="$tmp/cfg" lua -e '
    local loaded, cfg = {}, {}
    hl = { plugin = { load = function(p) loaded[#loaded+1] = p end }, config = function(t) cfg[#cfg+1] = t end }
    dofile("hypr/plugins.lua")
    assert(#loaded == 2, "both plugins load")
    assert(cfg[1].plugin.dynamic_cursors.shake.enabled == true)
    assert(cfg[2].plugin.gloview.backdrop_color == 1)' \
    && pass "fragment loads both plugins and applies config" || fail "fragment with plugins"
  rm -rf "$tmp"
}
run_test "status" t_status
run_test "install" t_install
run_test "check warning" t_check_warns
run_test "fragment" t_fragment
finish
