# E2E tests: debugger, test runner, large files and runtime performance

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
- Breakpoint keys are written `<BP>` `<BPD>` `<BPC>` `<BPH>` `<BPL>` in the suites and looked up by their which-key
  description (`dapkit.ALIASES`), so remapping them doesn't break the tests.
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

## Large files and runtime performance (added 2026-11-23, second run)

Everyday editing and per-key cost on big real-world files: Go, TS, TSX and Python
(`targets.json`: gopls `completion.go` 3.7k lines, excalidraw `binding.ts` 3.5k and `App.tsx`
11.5k, django `query.py` 3.1k). Report: `docs/advance-features/testing/e2e-perf-report-2026-11-23.md`.

```sh
scripts/e2e/setup_bigfile.sh                     # clones the pinned projects to /tmp/nvim-e2e-big
python3 suite_bigfile.py                         # UI: open, scroll, gd, hover/refs, completion,
                                                 # breadcrumb/brackets/words/indent, pickers,
                                                 # explorer sticky rows, diagnostics, 4 buffers
python3 perf.py go ts tsx py                     # per-key latency, stalls, CPU/key, LSP, memory
MODE=clean python3 perf.py go                    # same file in `nvim --clean` + treesitter: the floor
PROFILE=1 python3 perf.py py                     # + LuaJIT profile of scrolling and typing
AB=no-bufferline-diagnostics python3 perf.py py  # one feature off (perf.py AB_VARIANTS)
E2E_TARGETS=~/my-targets.json python3 perf.py go # your own files (same JSON shape)
```

How perf.py measures (all inside Nvim, so the RPC and the terminal are not in the numbers):
- **Latency per key**: `vim.on_key` → end of the first redraw after it (decoration provider
  `on_end`). In Normal mode `SafeState` fires *before* that redraw, so it only closes keys that
  need no redraw at all (`no_redraw`).
- **Stalls**: a 5 ms libuv timer; when it fires late, the main loop was blocked that long.
  Catches work not tied to one key (LSP replies, async parses, timers).
- **CPU per key**: user+system time of the Nvim server process over the action, divided by the
  keys sent. Includes work after the redraw (debounced handlers, completion, diagnostics).
- Keys are sent at human speed: `j` held (33 ms), typing at ~14 chars/s.
- Numbers are relative: the sandbox CPU is slower than an M-series Mac. Compare config vs
  `MODE=clean`, or A vs B, in the same session.

### Comparing configs: "is it still as fast as it was?" (added 2026-11-24)

```sh
scripts/e2e/setup_config_version.sh 9232680 nvim-jun     # this config as of 2026-06-23, side by side
python3 compare.py --name history --configs now=ab: now2=ab: jun=app:nvim-jun \
  --ref now --targets go-mid ts-mid tsx-mid py-mid --reps 5   # ~1 h; resumable
python3 compare.py --name feat --configs now=ab: ibl=ab:no-indent-guides \
  --ref now --targets go-mid --reps 5 --actions scroll_j,half_page,typing   # price one feature
python3 compare.py --table compare-history.json          # re-print a finished comparison
python3 e2e_latency.py go-mid                            # independent end-to-end check (raw pty)
```

- `now2=ab:` is the same config under a second label: an A/A run. Any difference between
  `now` and `now2` is noise, the bar every other difference must clear.
- Runs are interleaved (each round runs every config once, shuffled). Cells are the median of
  runs [min–max] with a Mann-Whitney U p-value against `--ref`; 5 runs per side are the minimum
  for p < 0.05.
- Calibration: `AB=selftest-1ms|2ms|5ms|10ms` adds a known busy loop per key. The median
  latency moved by +1.1 / +1.9 / +4.8 / +9.9 ms (2026-11-24), so the instrument resolves ~1 ms.
  p95 is much noisier: treat p95 differences under ~5 ms as noise.
- Every finished run is appended to `compare-<name>.jsonl`; the same command resumes after a crash
  and retries failed runs.
- Never run two harness sessions at once. The `AB=` spec variants write
  `lua/plugins/zz_perf_ab.lua` into the shared config, and perf.py refuses to write it while
  another test session is alive.
