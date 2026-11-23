# E2E tests: debugger and test runner

Scripted end-to-end checks for `lua/debugging/` and `lua/testing/`, written 2026-11-23.
Nothing here loads with Neovim. It runs only when you start it, like `scripts/palette/`.

## What it does

- Starts **real Neovim (TUI) inside tmux** at 200×50 and sends **real keystrokes**
  (`tmux send-keys`) and **mouse clicks**: SGR mouse escape sequences written into the
  terminal, the same bytes a terminal sends for a click. Headless mode is not used, because
  it skips `keymaps.lua`/VeryLazy and has no real window sizes (see docs/CLAUDE.md).
- Checks the **state** over the `--listen` socket (dap session, frame, breakpoints, open panels,
  neotest results, diagnostics, registers) and the **screen** (`tmux capture-pane`).
- Each step **waits on a condition** (with a timeout), not on fixed sleeps. Keys are paced like
  a person: at least 40 ms between special keys and 150 ms after `<CR>`. Keys sent within
  50 ms of a `:cmd<CR>` can be lost, which is sub-human speed.
- Saves a screenshot per key step to `shots/` (`.ans` = raw ANSI; `.png` when the
  JetBrains Mono font is installed, which is Linux-only paths in `render.py`).
- Cleans up after each scenario: quits Neovim, then kills that Neovim's own process tree
  (LSP, Delve, js-debug, test binaries). Other editors' processes are never touched.
- Deletes only the fixtures' own saved breakpoints and swap files, never yours.

## Run

```sh
pip install pynvim pyte pillow          # pyte/pillow only for PNG screenshots
scripts/e2e/setup.sh                    # copies fixtures/ to /tmp/nvim-e2e-fx, npm/pip installs
cd scripts/e2e
python3 suite_go.py                     # Go / Delve debugger      (13 scenarios)
python3 suite_node_py.py                # Node/TS js-debug + Python debugpy (8)
python3 suite_test.py                   # neotest, panel, coverage, history (10)
REPEAT=3 python3 suite_go.py stepping   # repeat runs / name filter
python3 startup.py 15                   # TUI startup time (median of N)
python3 nvc.py start s1 /tmp/nvim-e2e-fx/goapp main.go   # drive one session by hand
```

Needs: tmux, Go ≥ 1.25 (Delve 1.27 refuses older Go), Node + `npm i -g tsx`, Python 3, and the
Mason packages delve, js-debug-adapter and debugpy.

Checks marked `[known Fn]` fail on purpose. Each one is an open issue in
`docs/advance-features/testing/e2e-report-2026-11-23.md`. When one of them starts
passing, the issue is fixed.

Workflow (how to ask Claude, the loop, limits): `docs/advance-features/e2e-testing/e2e-workflow.md`.

Use it after `:Lazy update`, and after unpinning nvim-dap or nvim-dap-ui: a green run covers
every row of the "Upstream internals" table in `lua/debugging/README.md` that has a scenario.
