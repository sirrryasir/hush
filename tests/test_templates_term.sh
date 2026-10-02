#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
cd "$(dirname "$0")/.."
R=$(mktemp -d); trap 'rm -rf "$R"' EXIT
mkdir -p "$R/hush"
cfg="$R/matugen.toml"
test_matugen_cfg "$R" kitty p10k fastfetch | sed "s|'$R/kitty/|'$R/|; s|'$R/fastfetch/|'$R/|" > "$cfg"
matugen color hex "#7fb3a3" -c "$cfg" -m dark -t scheme-fidelity -q
t_kitty() {
  assert_contains "$R/theme.conf" "background #" "kitty theme has background"
  for i in $(seq 0 15); do grep -qE "^color$i +#[0-9a-f]{6}" "$R/theme.conf" || { fail "kitty color$i missing"; return; }; done
  pass "kitty has color0..color15"
  assert_contains "$R/theme.conf" "cursor #" "kitty theme has cursor"
}
t_p10k() {
  bash -n "$R/hush/p10k-colors.zsh" && pass "p10k colors is valid shell" || fail "p10k colors syntax error"
  assert_contains "$R/hush/p10k-colors.zsh" "POWERLEVEL9K_DIR_FOREGROUND='#" "p10k dir foreground set"
}
t_fastfetch() {
  python3 -c "import json,re,sys; s=open('$R/config.jsonc').read(); s=re.sub(r'//.*','',s); json.loads(s)" \
    && pass "fastfetch config.jsonc is valid JSON" || fail "fastfetch config invalid"
  assert_contains "$R/config.jsonc" '"logo"' "fastfetch config has a logo block"
}
run_test "kitty" t_kitty
run_test "p10k" t_p10k
run_test "fastfetch" t_fastfetch
finish
