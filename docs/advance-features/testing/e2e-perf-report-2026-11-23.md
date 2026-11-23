# Runtime performance and large-file E2E report (2026-11-23, second run)

Tested against `main` at `9ed46d8` (after the breakpoint-icon, statusline-hunk and sticky-explorer
merges). Harness: `scripts/e2e/` (`perf.py`, `suite_bigfile.py`, `targets.json`); its README
explains how to rerun everything, including on your own files.

## 1. Bottom line

- **No runaway runtime problem in Go, TS or TSX.** On a 3.7k-line Go file, a 3.5k-line TS file and
  an 11.5k-line TSX file, a held `j` stays at a 2–6 ms median per key and typing at 7–8 ms. The
  biggest single cost is core treesitter, not your Lua.
- **Python is the outlier, and the cause is the diagnostic count.** basedpyright's default mode
  reports **2,379 warnings + 117 errors** on django's `query.py`. Three things then scale with that
  number on every key: bufferline (F17), Snacks statuscolumn (F18) and Neovim's own diagnostic
  bookkeeping (F19). `j` costs **26.5 ms CPU per key** there, against 9.6 ms in Go. Switching
  basedpyright to `typeCheckingMode = "standard"` (F20) cuts it to **9.1 ms**; that is your call,
  because it removes warnings.
- **`o` / `<CR>` in a big TS/TSX file stalls 150–170 ms** (11.5k lines). The cause is
  nvim-treesitter's indent (F21): it walks the whole file's indent captures after every edit.
- **1 bug fixed (F16):** every `nvim <file>` opened scrolled one line down, with the cursor on
  **line 12** and line 1 hidden. Fixed in `config/options.lua`, with a regression check.
- **11 items flagged, not fixed** (F17–F27): 7 for your decision, 4 upstream or language-server
  behaviour recorded for reference. Each has its measured cost and a suggested fix in §5.
- **UI suite:** 37 scenarios × 3 runs = 111 runs (final pass: **108/111**). The only failures are the 3
  `[known F24]` checks. No flaky results.

## 2. How it was tested

| Item | Detail |
|---|---|
| Machine | Disposable Linux sandbox (x86_64, 4 CPUs, 15 GB). Not your Mac. |
| Neovim | 0.12.6 release build |
| Plugins | Your exact `lazy-lock.json` commits. The first restore left 10 plugins on newer commits (mini.pairs, nvim-ts-autotag, mason-lspconfig among them); they were pinned back and every number here was re-measured on the pinned set. |
| Treesitter parsers | Built from git at the revisions nvim-treesitter pins (tarball download blocked) |
| Language servers | Current Mason versions on 2026-11-23: gopls, vtsls, basedpyright + ruff. Go 1.27 (the gopls module needs it), Node 22, Python 3.13 |
| Terminal | tmux 3.4, 200×50, truecolor, `escape-time 0`, `extended-keys on`, `focus-events on` |

**Your files were not available.** The Mac's `~/.config/nvim` and `~/.dotfiles` folders are in
Remote Control but are not offered to cloud sessions (hidden folders under home), so I used the
largest hand-written file per language from big real projects, with their dependencies installed
so the language servers had real types:

| Target | File | Lines | Project state |
|---|---|---|---|
| Go | `golang/tools` `gopls/internal/golang/completion/completion.go` | 3,660 | module deps downloaded |
| TS | `excalidraw` `packages/element/src/binding.ts` | 3,489 | `yarn install` |
| TSX | `excalidraw` `packages/excalidraw/components/App.tsx` | 11,501 | `yarn install` |
| Python | `django` `django/db/models/query.py` | 3,145 | no venv (see Limits) |

To rerun on your own files: copy `scripts/e2e/targets.json`, point `cwd`/`file`/`anchor` at them,
and run with `E2E_TARGETS=...` (README).

**Method:**
- **Real TUI, real keys.** Keys go through tmux at human pace: held `j` at 33 ms, typing at
  ~14 chars/s, `<C-d>` at 80 ms. Mouse wheel and pointer moves are SGR mouse sequences written
  into the pty.
- **Latency per key:** from `vim.on_key` to the end of the first redraw after it (decoration
  provider `on_end`). Normal mode fires `SafeState` *before* that redraw, so `SafeState` only
  closes keys that need no redraw at all. This is Neovim's own work; the terminal's paint is not
  included.
- **Stalls:** a 5 ms libuv timer. When it fires late, the main loop was blocked for that long.
  This catches work not tied to one key (LSP replies, async parses, timers).
- **CPU per key:** Neovim server process user+sys time over the action, divided by the keys
  sent. It includes everything after the redraw too (debounced handlers, completion,
  diagnostics).
- **Baseline:** the same files in `nvim --clean` with treesitter highlighting and relative
  numbers. That is the floor this hardware can do.
- **Pricing:** one feature off at a time (`perf.py AB=...`, 3 runs each), plus LuaJIT sampling
  profiles of scrolling and typing.
- **Repeats:** every perf action and UI scenario ran 3×. The perf instrument was self-tested
  (§8).

### Limits of this test: read before trusting a number

1. **Linux, not macOS + Ghostty.** Not covered: Nerd Font glyph widths (screenshots use
   JetBrains Mono, so icons render as boxes in the PNGs), Ghostty's `super+…=esc:…` Meta
   bindings, CSI-u `<C-i>`, `display-p3` colour, Ghostty's own input/paint latency.
2. **Absolute numbers are sandbox numbers.** This CPU is slower than an M-series Mac; expect
   your absolute times to be roughly 2–3× lower. The comparisons (config vs clean, A vs B) are
   what transfer. The terminal's paint time is not in any number.
3. **Mouse is simulated** through the terminal mouse protocol: no trackpad momentum, no
   `precision:3` multiplier (your Ghostty setting); one wheel event = one notch.
4. **Python had no virtualenv**, so django's own imports (`asgiref`, `sqlparse`) are
   unresolved. That accounts for most of the 117 errors. The 2,379 warnings are basedpyright's
   default rules on untyped code and would mostly remain in a real venv.
5. **Language servers are today's Mason versions**, not necessarily yours.
6. **Not covered:**
   - CodeCompanion / Copilot / cursortab (no accounts in the sandbox);
   - the debugger and test runner (covered by the first report);
   - Rust, Terraform, Docker, YAML, Markdown rendering;
   - Neovide;
   - multi-hour sessions (memory growth);
   - files over 20k lines.

## 3. Results

### UI suite (`suite_bigfile.py`, real keys, 3 runs)

| Scenario (× go, ts, tsx, py) | Result |
|---|---|
| open: starts at line 1, treesitter on, bufferline name, statusline mode, LSP attached, no errors | ✅ all (after F16 fix) |
| scroll: `G`/`gg`, `<C-d>` recentres, 10 wheel steps = 10 lines (your `scroll_depth = 1`), cursor stays in view, scrollview bar drawn | ✅ all |
| goto definition: `gd` lands on the definition (TS: across files into `collision.ts`), `<C-o>` returns | ✅ all (after server warm-up, F23) |
| hover float opens, Esc closes it; `gr` lists references, Esc Esc closes | ✅ all |
| completion while typing: menu opens, expected item in top 10, first Esc closes menu, second leaves insert | ✅ all (after warm-up, F23) |
| context: aerial breadcrumb, bracket-match pair, snacks.words reference highlights, indent guides | ✅ go/ts/py; ❌ tsx breadcrumb `[known F24]` |
| find files (`<leader>ff`) and grep (`<leader>/`) in the large repos | ✅ all |
| explorer (`<leader>r`): reveals the file; after scrolling, the pinned rows are exactly its ancestor folders | ✅ all |
| diagnostics: end-of-line text only for errors; `]d` jumps; `<leader>cd` float | ✅ all |
| four big files as buffers: bufferline lists all, `<S-l>` cycles through every one | ✅ |

### Runtime performance (`perf.py`, medians of 3 runs)

**CPU per key, ms — your config (clean `nvim` + treesitter in brackets).** What a key costs Neovim in total, including deferred work.

| action | Go 3.7k | TS 3.5k | TSX 11.5k | Python 3.1k |
|---|---|---|---|---|
| `j` held (150×) | 9.6 (4.9) | 7 (1.9) | 5.8 (1.1) | 26.5 (2.2) |
| `<C-d>`/`<C-u>` (60×) | 24.3 (9.3) | 18.3 (5.3) | 16 (3.3) | 53.8 (6.7) |
| wheel (60 notches) | 14 (8.3) | 8.7 (3) | 7.5 (1.3) | 37 (4) |
| `w` (120×) | 5.8 (1.3) | 6.3 (1.3) | 6.2 (1.2) | 9.5 (1.4) |
| `G` `gg` `50%`… | 33.8 (10) | 30 (8.1) | 33.1 (26.2) | 74.4 (10) |
| typing a line (~60 chars) | 26 (27.9) | 26.5 (4) | 23.9 (2.1) | 39.4 (5.7) |
| mouse pointer moves (100×) | 1.5 | 1.3 | 1.3 | 1.4 |

**Latency per key, ms: median / p95** (key received → redraw done).

| action | Go 3.7k | TS 3.5k | TSX 11.5k | Python 3.1k |
|---|---|---|---|---|
| `j` held (150×) | 5.7 / 31 | 3.1 / 13.6 | 2.3 / 7.6 | 7.9 / 29.8 |
| `<C-d>`/`<C-u>` (60×) | 4.4 / 24.4 | 3 / 20.2 | 2.4 / 14.4 | 8.8 / 39.4 |
| wheel (60 notches) | 7.5 / 31.6 | 3.6 / 10.8 | 3 / 11.4 | 9.9 / 33.4 |
| `w` (120×) | 2 / 15.2 | 2 / 11.7 | 2.6 / 13.5 | 1.9 / 29.9 |
| `G` `gg` `50%`… | 11.5 / 27.2 | 9.8 / 22 | 11.1 / 28 | 17 / 47.7 |
| typing a line (~60 chars) | 7.6 / 33.7 | 7.5 / 36.4 | 8.3 / 19.9 | 21.3 / 65.8 |
| clean `nvim`, `j` | 2.3 / 12.2 | 1.1 / 4.4 | 0.6 / 0.8 | 1.2 / 5.9 |
| clean `nvim`, typing | 2.6 / 9.1 | 2 / 9.6 | 0.5 / 0.9 | 2.6 / 7.5 |

**Longest main-loop stall during each action, ms** (60 fps = 16.7 ms per frame).

| action | Go 3.7k | TS 3.5k | TSX 11.5k | Python 3.1k |
|---|---|---|---|---|
| `j` held (150×) | 44.9 | 21.6 | 16.6 | 54.1 |
| `<C-d>`/`<C-u>` (60×) | 44 | 29 | 26.8 | 63.1 |
| wheel (60 notches) | 52.6 | 10.9 | 16.3 | 57.2 |
| `w` (120×) | 34.2 | 31.3 | 29.7 | 53.6 |
| `G` `gg` `50%`… | 25.5 | 26.4 | 19 | 54.6 |
| typing a line (~60 chars) | 52.9 | 69.7 | 129.4 | 80.7 |

Slowest single keys: `o` (new line) is the slowest key in every TS/TSX/Python typing run: TSX 153–171 ms, TS 52–107, Python 81–161, Go 41–48 (F21).

**Open, LSP, save, memory** (median of 3).

| | Go 3.7k | TS 3.5k | TSX 11.5k | Python 3.1k |
|---|---|---|---|---|
| VeryLazy after launch, s | 0.3 | 0.5 | 0.7 | 0.4 |
| LSP attached, s | 0.4 | 0.6 | 0.8 | 0.5 |
| LSP first answer (documentSymbol), s | 0.9 | 1.7 | 2.1 | 3.8 |
| `:w` with format-on-save, ms | 19.2 | 11.9 | 16.6 | 65.3 |
| Neovim RSS, MB | 76.3 | 101.2 | 134.4 | 109.1 |
| language server RSS, MB | 512.3 | 823.5 | 1318.4 | 2214.6 |
| LSP hover round trip, ms | 0.7 | 1.4 | 1.2 | 1139.8 |
| LSP definition round trip, ms | 0.8 | 0.9 | 0.7 | 0.7 |
| LSP references round trip, ms | 1.9 | 1.3 | 3.9 | 92.1 |
| LSP documentSymbol round trip, ms | 2.2 | 8 | 81.6 | 5.8 |
| LSP completion round trip, ms | 53.6 | 162.8 | 165.5 | 54.3 |

**What each feature costs (one off at a time, 3 runs each; CPU ms per key, medians).** Differences under ~2 ms CPU / ~5 ms p95 are noise.

| file | variant | scroll_j CPU | half_page CPU | typing CPU | scroll_j p95 | typing p95 | typing max |
|---|---|---|---|---|---|---|---|
| py | **config as is** | 26.5 | 53.8 | 39.4 | 29.8 | 65.8 | 128.9 |
| py | no-bracket-match | 27.1 | 56.0 | 39.3 | 32.0 | 65.8 | 108.8 |
| py | no-bufferline-diagnostics | 19.5 | 42.7 | 38.1 | 31.9 | 67.6 | 110.5 |
| py | no-bufferline | 12.7 | 32.7 | 36.7 | 32.8 | 61.8 | 99.1 |
| py | no-indent-guides | 23.9 | 45.2 | 34.1 | 17.6 | 57.3 | 122.2 |
| py | no-statuscolumn | 22.6 | 39.5 | 30.2 | 12.0 | 61.0 | 125.9 |
| py | no-words | 24.9 | 52.7 | 37.2 | 22.4 | 66.4 | 99.2 |
| py | pyright-standard | 9.1 | 23.5 | 23.7 | 14.7 | 45.4 | 79.2 |
| go | **config as is** | 9.6 | 24.3 | 26.0 | 31.0 | 33.7 | 51.2 |
| go | no-bracket-match | 10.1 | 23.8 | 25.8 | 35.4 | 22.6 | 81.2 |
| go | no-bufferline | 10.1 | 22.5 | 24.7 | 33.0 | 29.0 | 63.0 |
| go | no-gitsigns | 11.7 | 25.5 | 26.7 | 38.3 | 42.8 | 65.0 |
| go | no-indent-guides | 8.9 | 16.3 | 17.7 | 27.7 | 15.6 | 44.3 |
| go | no-lualine | 10.4 | 23.0 | 26.1 | 34.9 | 33.2 | 57.4 |
| go | no-scrollview | 9.3 | 22.5 | 24.7 | 35.1 | 26.9 | 64.9 |
| go | no-semantic-tokens | 11.7 | 25.5 | 26.8 | 38.2 | 28.2 | 55.6 |
| go | no-statuscolumn | 9.1 | 20.8 | 24.0 | 31.6 | 30.4 | 51.2 |
| go | no-ufo | 11.7 | 25.5 | 27.5 | 34.3 | 19.3 | 64.2 |
| go | no-words | 11.4 | 25.2 | 27.9 | 38.0 | 18.4 | 91.8 |
| tsx | **config as is** | 5.8 | 16.0 | 23.9 | 7.6 | 19.9 | 160.4 |
| tsx | no-bufferline | 5.1 | 15.0 | 22.9 | 7.5 | 23.1 | 162.1 |
| tsx | no-ts-indent | 5.4 | 15.2 | 23.1 | 7.6 | 26.3 | 47.8 |
| ts | **config as is** | 7.0 | 18.3 | 26.5 | 13.6 | 36.4 | 62.3 |
| ts | no-semantic-tokens | 7.2 | 19.5 | 24.6 | 13.3 | 35.0 | 81.5 |
| ts | no-ts-indent | 7.0 | 18.0 | 23.9 | 11.8 | 34.5 | 51.6 |

A second full config pass at the end (with the F16 fix) agreed within ±10% on every action.

## 4. Bug fixed (in this PR)

### F16: every file opened from the shell started on line 12, with line 1 hidden
- **Seen:** `nvim file.go` showed the file from line 2, cursor on line 12 (all four languages, every
  time). `nvim --clean` opens at line 1.
- **Cause:** bufferline turns the tab bar on when it loads (`VeryLazy`), after the file has been
  drawn. The window loses its top row. LazyVim's `splitkeep = "screen"` keeps the text on the same
  screen rows by scrolling it up one line, so topline becomes 2. Then `scrolloff = 10` pushes the
  cursor to line 12. Reproduced in `nvim --clean` with only `splitkeep=screen scrolloff=10` and a
  late `showtabline=2`.
- **Fix** (`lua/config/options.lua`, inside the existing bufferline `ENABLED` branch):
  `showtabline = 2` and a blank `tabline` from the first frame. bufferline's own
  `showtabline = 2` then changes nothing, and it replaces the blank tabline a few ms later.
- **Behaviour change:** only the bug. The tab bar row now exists from the first frame instead of
  appearing at `VeryLazy`; it is blank for that moment, as before.
- **Cost:** two option sets at startup; nothing on keys or redraws. Startup median
  unchanged (§6).
- **Regression check:** `open` → "file opens at the top, cursor on line 1". It fails on `main`
  in all 4 languages (§8).

## 5. Flagged, not fixed: needs your decision

### Your decision (each changes behaviour or touches plugin internals)

| # | What | Measured cost | Suggested fix / effort |
|---|---|---|---|
| F17 | **bufferline re-reads all diagnostics and all signs on every tabline render.** `diagnostics.lua` deep-copies `vim.diagnostic.get()` (all buffers). `get_buf_count()` and `get_valid_buffers()` call `getbufinfo()` with no filter, which copies every buffer's placed signs. Nothing is cached outside insert mode. | Python (2.5k diagnostics): bufferline diagnostics off → `j` 26.5 → **19.5 ms CPU**; bufferline off → **12.7 ms**. Go/TS/TSX: ≤ 1 ms (noise). | (a) `diagnostics = false` in `plugins/bufferline.lua`: drops the error count from the tabs. One line. (b) Cache the diagnostics result and refresh it on `DiagnosticChanged`: about 30 lines that replace bufferline internals (a new silent-failure surface). (c) Upstream issue. |
| F18 | **Snacks statuscolumn rebuilds every sign in the buffer every 50 ms** (`buf_signs`, cache cleared by a 50 ms timer). | Python: statuscolumn off → `j` 26.5 → 22.6 ms CPU, **p95 29.8 → 12.0 ms**. Go: ~0.5 ms. | `statuscolumn = { refresh = 200 }` in snacks opts: signs and git marks then update up to 200 ms later. One line; your call. Or upstream: rebuild per range. |
| F20 | **basedpyright runs its strictest default mode** (`recommended`): 2,379 warnings on `query.py` (`reportUnknown…`, `reportAny`…). This count is what feeds F17, F18 and F19. | `typeCheckingMode = "standard"`: `j` 26.5 → **9.1 ms CPU**, `<C-d>` 53.8 → 23.5, typing 39.4 → **23.7**, worst typing key 129 → 79 ms. Diagnostics on `query.py`: **2,496 → 134** (108 errors, mostly the unresolved imports of Limits #4, 1 warning, 25 ruff). | One setting in the basedpyright block of `plugins/lsp.lua`. Shows PyCharm-like warnings instead of strict-typing ones. Behaviour change → your call. |
| F21 | **`o` / `O` / `<CR>` stall in big TS/TSX files.** nvim-treesitter's `indentexpr` collects the indent captures of the **whole file** once per new tree (`get_indents` memoized on the root id), and every edit makes a new tree. | TSX 11.5k lines: `o` **150–170 ms** in all 3 runs (other keys 15–50). TS 3.5k: 52–107 ms. With Vim's own indent: worst TSX typing key **160 → 48 ms**. | (a) Use Vim's regex indent for typescript/tsx (`indentexpr` from `indent/typescript.vim`): indentation rules change (JSX in particular), so test first. (b) Upstream: limit the capture walk to a range around the line. |
| F22 | **indent-blankline costs ~8 ms CPU per typed key in Go.** Its "debounce" refreshes immediately on the first event, then again 200 ms later. The comment in `plugins/indent-blank-line.lua` says a held `j`/`k` is cheap (true: −0.7 ms), but typing and paging are not. | Go: typing 26.0 → **17.7 ms CPU**, typing p95 33.7 → 15.6, `<C-d>` 24.3 → 16.3. Python: −3 to −9 ms. | Accept and update the comment with these numbers; or raise ibl's `debounce`; or turn scope off. Your call: the cost was accepted on 2026-11-20 without these numbers. |
| F24 | **No breadcrumb and no outline in files over 10,000 lines.** aerial's default `disable_max_lines = 10000` silently skips them (`App.tsx`, 11,501 lines: empty breadcrumb, empty `<leader>cs`). | n/a (missing feature) | `disable_max_lines = 20000` in `plugins/aerial.lua`. aerial then parses symbols in those files too (one-off per change, async treesitter backend). Your call. |
| F25 | **Format-on-save rewrites lines nobody touched** when the project uses a different formatter. `:w` on an unedited file: gofumpt changed `completion.go` (gofmt-formatted upstream) by **3 removed lines**; ruff format changed django's black-formatted `query.py` by **5 lines**; prettierd changed nothing in excalidraw, which configures prettier. | Unrelated diff lines in team repos | Format only when the project configures that formatter (conform `condition` / `require_cwd`), or `gofmt` instead of `gofumpt` for Go. Small, but a workflow choice. |

### Upstream or language-server behaviour (recorded, no config action suggested)

| # | What | Measured |
|---|---|---|
| F19 | Core `vim.diagnostic` re-reads **all** diagnostic extmarks (with details) on every buffer change (`restore_extmarks`, `on_lines`). 21% of Python typing samples. | Scales with the diagnostic count; disappears with F20. |
| F23 | **Language-server warm-up.** For a few seconds after its first reply, vtsls answers `definition` with the import line (`gd` lands on `import { … }`; 1.6–2.5 s across runs), `this.` completion without inherited React members (`state`, `setState`; 1.2–1.7 s), and hover starting with `(loading...)`. blink keeps filtering that early list while you type. basedpyright's completion list was complete only after 1–4 s. | `gd` again, or `<C-i>` to re-request completion. VS Code shows the same early import jump; JetBrains blocks navigation while indexing. |
| F26 | Compiling the TS/TSX treesitter queries costs ~245 ms the first time a TS/TSX file opens in a session. Your `after/queries` add nothing to it. | Opening `App.tsx` at startup: 487 ms vs 202 ms for the Go file. |
| F27 | Go typing costs ~26 ms CPU per key **even in `nvim --clean`** with treesitter (tree-sitter-go reparse), vs 2–6 ms for TS/TSX/Python. Your config adds ~0 to it. | Not config. Noticeable only on slower machines. |

Other observations (deliberate behaviour, no action):
- The first `<Esc>` closes the completion menu and stays in insert mode (your blink keymap); the
  first `<Esc>` in a Snacks picker filter switches it to normal mode, the second closes it
  (Snacks default; VS Code closes on one).
- One wheel notch = 1 line (`scroll_depth = 1`; Ghostty's multiplier does the rest).
- `u` undoes a typed line in chunks: LazyVim maps `.` `,` `;` to `<c-g>u` (undo break-points) in
  insert mode.
- `gr` on a symbol with a single other use jumps straight there (Snacks `auto_confirm`), no list.
- In `this.sta`, `state` ranks second behind `startImageCropping` (same fuzzy score).
- Deep JSX gets a comb of up to 14 indent guides (normal for indent guides; VS Code draws the
  same, fainter).
- basedpyright hover on `query.py` took ~1.1 s per request (server side).

## 6. Performance of this PR

- `lua/config/options.lua` already loads at startup; the fix adds two option sets. Nothing
  new on keys, cursor moves or redraws.
- TUI startup, `--startuptime`, 15 runs each, same session:

| | Go file, median | TSX file, median |
|---|---|---|
| main (`9ed46d8`) | 202.2 ms | 487.1 ms |
| this branch | 193.8 ms | 497.8 ms |

  The differences are noise (min–max spans are 70–170 ms).
- `stylua --check` passes on the changed Lua file.

## 7. Compared with JetBrains (GoLand/WebStorm/PyCharm) and VS Code

This compares behaviour, not measured numbers: the other editors were not run here.

| Area | This config | JetBrains | VS Code |
|---|---|---|---|
| Per-key latency on 3–11k-line files | 2–8 ms median, Go/TS/TSX (sandbox); Python 8–21 ms, driven by diagnostic count (F20) | Typing can stall during re-highlighting and inspections on very large files | Usually smooth; heavy extensions add latency |
| Warm-up after opening a project | Seconds per language server (F23); editing works at once | Indexing blocks navigation until done | Same TS server warm-up as here (same tsserver) |
| Breadcrumb / outline on huge files | Off above 10k lines (F24) | Works | Works (limits apply only to very large files) |
| Enter/`o` in a huge TSX file | 150–170 ms stall (F21) | Smart indent, no full-file pass | Regex indent rules, no stall |
| Format on save | On, project-agnostic (F25) | Off by default; per-project code style | Off by default; per-workspace formatter |
| Strictness of Python diagnostics | basedpyright "recommended" (strict) by default (F20) | PyCharm inspections, moderate | Pylance "off"/"basic" by default |
| Memory | Neovim 76–134 MB + servers (gopls 0.5 GB, vtsls 0.8–1.3 GB, basedpyright 2.2 GB) | IDE heap typically 1–4 GB + indexes | Electron + same servers |

## 8. UI review (from the screenshots)

- **Open, scroll, explorer, buffers:** clean. The tab bar row is now there from the first frame
  (F16), the winbar gap sits under it, and the statusline shows mode, branch, breadcrumb and
  position. The explorer's pinned band (`internal`, `golang > completion`) is readable and its
  rows are exactly the ancestor folders.
- **Hover:** a rounded float under the symbol, signature with a rule under it, then the doc text.
  TS hover shows `(loading...)` before the type during warm-up (F23).
- **Completion menu:** compact, 8 rows visible, no docs (`auto_show = false`, by design).
- **Diagnostics:** end-of-line text for errors only, as configured. The `<leader>cd` float lists
  every diagnostic on the line with its rule name.
- **Noise:**
  - Python's 2.4k warnings are invisible inline, by design (sign column only), but they are what
    makes the file slow (F20).
  - Deep JSX shows up to 14 indent guide columns.
- No overlapping floats, cut-off titles or misplaced windows found.

## 9. Proof the checks can fail (negative controls)

| Broken on purpose | Check that went red |
|---|---|
| F16 fix removed (= `main`) | "file opens at the top, cursor on line 1" in all 4 languages (topline 2, cursor 12) |
| `bracket-match` setup made a no-op | "bracket-match marks one matching pair around the cursor" |
| snacks `words.enabled = false` | "other uses of the word are highlighted" |
| `explorer-sticky` attach made a no-op | "deepest pinned row is the file's folder" |
| perf instrument: 5 ms busy loop added on `CursorMoved` (`AB=selftest-5ms`) | `j`: median latency +5.5 ms, CPU +6.0 ms per key; `w`: +5.5 / +5.5. The instrument tracks real cost. |

All controls were reverted; `git diff` contains only the intended changes.

## 10. Problems in the test harness itself (not your config)

- **tmux ate `;`:** `send-keys -l ';'` sent nothing, because tmux treats an argument ending in `;`
  as its own command separator. Every typed statement lost its final `;`, and the rest of the
  sequence went astray. `nvh.tmux_literal()` now escapes it. The older suites never send `;`, so
  their results are unaffected.
- **Undo:** one `u` does not undo a typed line (LazyVim's `<c-g>u` break-points), so a leftover
  line was saved by the first save measurement. perf now reloads with `:e!`.
- **Stale swap files** from an aborted run stopped the next start at the E325 prompt.
  `nvh.reset_fixture()` now removes the fixture's own swap file and resets its edits.
- **Latency end point:** in Normal mode `SafeState` fires before the redraw (measured), and a
  key that needs no redraw has no redraw of its own. The probe ends a key at its first redraw, or
  at `SafeState` when no redraw follows within 15 ms. An earlier version attributed a later,
  unrelated redraw to a sideways `w` (80 ms "latency").
- **Plugin versions:** `:Lazy! restore` left 10 plugins on newer commits; they were re-pinned and
  every number re-measured.
- **Test expectations corrected** (the config was right):
  - wheel = 1 line per notch;
  - Snacks pickers close on the second `<Esc>`;
  - pinned explorer rows depend on the top visible row;
  - `gd`/completion needed the server warm (F23);
  - a docstring `(` is correctly not a bracket.

## 11. Files changed

| File | Change |
|---|---|
| `lua/config/options.lua` | F16: tab bar row from the first frame |
| `scripts/e2e/perf.py`, `perf_table.py` | Runtime performance harness and table generator (new) |
| `scripts/e2e/suite_bigfile.py`, `targets.json`, `setup_bigfile.sh` | Large-file UI suite, targets, fixture setup (new) |
| `scripts/e2e/nvh.py`, `startup.py`, `README.md` | `;` escaping, fixture reset, startup on any target, docs |
| `.gitignore` | Harness output and the temporary A/B spec file |
| `docs/advance-features/testing/e2e-perf-report-2026-11-23.md` | This report |
| `docs/advance-features/e2e-testing/e2e-workflow.md`, `docs/advance-features/INDEX.md` | Links and the new run type |
