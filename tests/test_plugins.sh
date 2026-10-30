#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
cd "$(dirname "$0")/.."
H=bin/hush
# A PATH of stubs: hyprctl reports no plugin, hyprpm knows nothing and records its calls.
mkstubs() {
  local d; d=$(mktemp -d)
  cat > "$d/hyprctl" <<'S'
#!/usr/bin/env bash
case "$1 $2" in
  "plugin list") ;;
  "configerrors "*) ;;
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
  grep -qE '^dynamic-cursors +loaded no +installed no$' <<<"$out" && pass "status lists dynamic-cursors as missing" || fail "dynamic-cursors line: $out"
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
  rm -rf "$d"
}
t_fragment() {
  luac -p hypr/plugins.lua && pass "plugins.lua compiles" || fail "plugins.lua syntax"
  USER=nobody-zz XDG_CACHE_HOME=/nonexistent-zz lua -e '
    local loaded, cfg = {}, {}
    hl = { plugin = { load = function(p) loaded[#loaded+1] = p end }, config = function(t) cfg[#cfg+1] = t end }
    dofile("hypr/plugins.lua")
    assert(#loaded == 0 and #cfg == 0, "nothing loads when the plugin is absent")' \
    && pass "fragment is a no-op without the plugin" || fail "fragment errored without the plugin"
  local tmp; tmp=$(mktemp -d); mkdir -p "$tmp/c/hyprpm/dynamic-cursors"
  touch "$tmp/c/hyprpm/dynamic-cursors/dynamic-cursors.so"
  USER=nobody-zz XDG_CACHE_HOME="$tmp/c" lua -e '
    local loaded, cfg = {}, {}
    hl = { plugin = { load = function(p) loaded[#loaded+1] = p end }, config = function(t) cfg[#cfg+1] = t end }
    dofile("hypr/plugins.lua")
    assert(#loaded == 1, "the plugin loads")
    assert(cfg[1].plugin.dynamic_cursors.shake.enabled == true)' \
    && pass "fragment loads the plugin and applies config" || fail "fragment with plugins"
  rm -rf "$tmp"
}
# GloView is gone: only the changelog's history may name it.
t_no_gloview() {
  local hits; hits=$(git grep -il gloview -- . ':!docs' ':!CHANGELOG.md' ':!tests/test_plugins.sh')
  assert_eq "" "$hits" "nothing outside the changelog mentions GloView"
}
run_test "status" t_status
run_test "install" t_install
run_test "check warning" t_check_warns
run_test "fragment" t_fragment
run_test "no gloview" t_no_gloview
finish
