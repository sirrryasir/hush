# Testing

Every test is a `tests/test_*.sh` script that prints `PASS`/`FAIL` lines and exits non-zero on
failure. Helpers: `tests/lib.sh` (assertions, `HUSH_ROOT`, `CFG`, `test_matugen_cfg` to render
templates into a temp dir), `tests/shell_lib.sh` (restart, IPC, log scan, idle CPU of the live
shell), `tests/nested.sh` (a nested Hyprland with headless outputs).

## Running

| Command | What it does |
| --- | --- |
| `bash tests/sandbox.sh` | the whole suite in a nested Hyprland; your session is not touched |
| `bash tests/run_all.sh` | every `test_*.sh` against the live session (restarts the shell, moves the cursor, takes screenshots) |
| `bash tests/test_<name>.sh` | one script |

`run_all.sh` skips nothing on a Hyprland desktop with a GPU; a script goes in its `SKIP` list only
when it needs hardware that is absent, with a comment saying which.

## Kinds of test

- **Static** (no compositor): templates render and parse (`test_templates_*`), WCAG contrast for
  the shell and every templated app on all six themes (`test_contrast`, `test_app_contrast`,
  `test_island_contrast`), the CLI (`test_hush_cli`), README coverage (`test_readme`) and the
  personal-data guard (`test_no_personal`). `test_hooks` briefly breaks and restores the live
  `theme.lua` to prove the pre-commit hook rejects it.
- **QML unit**: `test_arbiter` runs `tests/qml/tst_arbiter.qml` under `qmltestrunner` offscreen.
- **Harness**: `test_*_surface`, `test_activity*`, `test_colorfade` load one component in its own
  Quickshell config (`tests/harness/*.qml`, which links the real `config`, `modules` and
  `services`) and drive it over IPC, with stubs (fake MPRIS, rfkill, cava) where hardware would
  answer. They never touch the running shell.
- **Live**: the rest restart the Hush shell and drive it through `qs -c hush ipc call hush ...`,
  `hyprctl` and `grim`: surface geometry and input mask, spring continuity (`test_morph`), hover
  timing, modes and fullscreen, notifications and queueing, idle CPU (`test_perf`).
- **Nested**: `test_hyprlock` and `test_sddm` lock and greet inside a nested Hyprland and compare
  screenshots; the live session is never locked.

Screenshots go to `~/.cache/hush/evidence/` (a few older live scripts still use `assets/evidence/`,
which is gitignored). A change is ready when the suite is green; the
`pre-commit` hook only runs the personal-data scan and `hush check`.
