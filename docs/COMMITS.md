# Commit and release policy

## Commits

- **Conventional Commits.** The header is `type(scope): subject`, at most 72 characters.
  Types: `feat fix perf refactor docs test chore build ci style revert`. The scope is
  optional (`shell`, `island`, `cli`, `matugen`, `themes`, `hyprlock`, `tests`, ...); `!`
  after the type or scope marks a breaking change.
- **One commit per coherent change.** A commit should be reviewable on its own and leave
  the tree working.
- **A body that says why.** Leave one blank line after the header, then explain the reason
  for the change (the diff already shows what). Only `docs` and `chore` commits may omit
  the body.
- **Tests green before every commit.** Run `bash tests/run_all.sh` (the `pre-commit` hook
  runs the personal-data scan and `hush check`; it does not replace the suite).
- **No rapid-fire fixup commits.** Squash fixups locally (`git commit --fixup` plus
  `git rebase --autosquash`) before anything is pushed.

`install.sh` sets `core.hooksPath` to `.githooks`, which enforces the header, length and
body rules (`commit-msg`) and the pre-commit checks.

## Releases

- Releases happen only at milestones, not per commit.
- Versions follow Semantic Versioning and are tagged `vX.Y.Z` with an annotated tag
  (`git tag -a vX.Y.Z -m "Hush X.Y.Z"`), after `VERSION` and `CHANGELOG.md` are updated
  in a `chore(release): X.Y.Z` commit.
- Milestones: **0.1.0** is the shell as of 2026-10-02 (first public history);
  **0.2.0** is island v2.
