#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
cd "$(dirname "$0")/.."
R=$(mktemp -d); trap 'rm -rf "$R"' EXIT
mkdir -p "$R/helium-theme"
cfg="$R/matugen.toml"
test_matugen_cfg "$R" helium | sed "s|'$R/hush/|'$R/|" > "$cfg"
matugen color hex "#7fb3a3" -c "$cfg" -m dark -t scheme-fidelity -q
t_manifest() {
  python3 - "$R/helium-theme/manifest.json" <<'PY' && pass "manifest valid with frame/toolbar colors" || fail "manifest invalid"
import json, sys
m = json.load(open(sys.argv[1]))
assert m["manifest_version"] == 3 and m["name"] == "Hush"
c = m["theme"]["colors"]
for k in ("frame", "toolbar", "tab_text", "tab_background_text", "ntp_background", "ntp_text", "omnibox_background", "omnibox_text"):
    v = c[k]; assert len(v) == 3 and all(0 <= x <= 255 for x in v), k
PY
}
run_test "helium manifest" t_manifest
finish
