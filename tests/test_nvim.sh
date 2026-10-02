#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
cd "$(dirname "$0")/.."
R=$(mktemp -d); trap 'rm -rf "$R"' EXIT
cfg="$R/matugen.toml"
test_matugen_cfg "$R" nvim | sed "s|'$R/nvim/colors/|'$R/|" > "$cfg"
matugen color hex "#7fb3a3" -c "$cfg" -m dark -t scheme-fidelity -q
t_render() {
  assert_file "$R/hush.lua" "hush.lua rendered"
  lua -e "assert(loadfile('$R/hush.lua'))" && pass "hush.lua parses" || fail "hush.lua does not parse"
}
t_load() {
  nvim --headless -u NONE -c "lua local ok=pcall(dofile,'$R/hush.lua'); if not ok or vim.g.colors_name~='hush' then vim.cmd('cquit 1') end" -c "qa!" \
    && pass "neovim loads the colorscheme headless" || fail "neovim failed to load hush.lua"
}
run_test "render" t_render
run_test "load" t_load
finish
