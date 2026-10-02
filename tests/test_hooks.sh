#!/usr/bin/env bash
cd "$(dirname "$0")/.." || exit 1
CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
fail=0; ok() { echo "ok: $1"; }; bad() { echo "FAIL: $1"; fail=1; }
[ -x .githooks/pre-commit ] && ok "pre-commit executable" || bad "pre-commit not executable"
[ -x .githooks/commit-msg ] && ok "commit-msg executable" || bad "commit-msg not executable"
[ "$(git config core.hooksPath)" = .githooks ] && ok hooksPath || bad hooksPath
# Generated outputs that some repo tracks must be skip-worktree there (hush track off).
n=0; while read -r f; do
  n=$((n + 1))
  git -C "$(dirname "$f")" ls-files -v -- "$f" | grep -q '^S' || bad "not skip-worktree: $f"
done < <(bin/hush generated)
ok "checked skip-worktree on $n tracked generated files"
tl="$CFG/hypr/modules/theme.lua"; cp "$tl" "$tl.testbak"
trap 'mv -f "$tl.testbak" "$tl"' EXIT
echo 'this is not lua (' > "$tl"
HUSH_CHECK_NO_HYPR=1 .githooks/pre-commit >/dev/null 2>&1 && bad "broken theme.lua accepted" || ok "broken theme.lua rejected"
mv -f "$tl.testbak" "$tl"; trap - EXIT
HUSH_CHECK_NO_HYPR=1 .githooks/pre-commit >/dev/null 2>&1 && ok "clean tree accepted" || bad "clean tree rejected"
# commit-msg: Conventional Commits, <= 72 chars, body required except docs/chore.
m=$(mktemp); trap 'rm -f "$m"' EXIT
msg() { printf '%b' "$1" > "$m"; .githooks/commit-msg "$m" >/dev/null 2>&1; }
msg 'feat(shell): add a thing\n\nBecause it was missing.\n' && ok "feat with body accepted" || bad "feat with body rejected"
msg 'fix: a thing\n' && bad "fix without body accepted" || ok "fix without body rejected"
msg 'docs: tidy the readme\n' && ok "docs without body accepted" || bad "docs without body rejected"
msg 'chore(deps): bump\n' && ok "chore without body accepted" || bad "chore without body rejected"
msg 'Added stuff\n\nbody\n' && bad "non-conventional header accepted" || ok "non-conventional header rejected"
msg 'wip: stuff\n\nbody\n' && bad "unknown type accepted" || ok "unknown type rejected"
msg "feat: $(printf 'x%.0s' $(seq 1 70))\n\nbody\n" && bad "header over 72 accepted" || ok "header over 72 rejected"
msg 'feat: x\nno blank line\n' && bad "missing blank line accepted" || ok "missing blank line rejected"
[ $fail -eq 0 ] && echo "PASS hooks"; exit $fail
