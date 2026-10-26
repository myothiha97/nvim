# Deep config review: findings

Findings only, no fixes. Format from `deep-config-review.md` section 6:
`<file>:<line> — <what is wrong> → <when it breaks> → <cheapest fix>`, then
`[verified | unverified] [change-gate: pass | fail | n/a]`.

## Phase 0 — baseline (2026-10-26)

Done. See `deep-config-review-baseline/README.md`. Clean boot, startup
47 to 49 ms, zero per-keystroke handlers.

## Carried in from the Sept/Oct commit audit (2026-10-26)

Found by reading every Sept and Oct commit, not by the phase reads. Do not
re-derive; confirm in the matching phase and fold in.

Medium:

- `lua/plugins/copilot.lua:8-24` — secret filter misses `prod.env`, `*/secrets/*`, `kubeconfig`, `.pgpass`, `.vault-token`, `*.jks`, `*.ovpn`, `.dev.vars` → those files reach Copilot once the toggle is on → add the patterns, match `secrets?` on the path [verified] [change-gate: pass, data leak]
- `lua/plugins/git.lua:264-265` — buffer-local `]]`/`[[` hunk maps shadow the built-in ftplugin section jumps (markdown headers, Go/Python sections); the comment says nothing else claims them → `]]` in a tracked `.md` jumps to a hunk → deliberate choice, fix the comment and `notes/git/git-keymaps.md` [verified] [change-gate: pass for docs only]
- `lua/config/keymaps.lua:388-406` — `scroll_popup_or` picks a focusable `snacks_notif` toast (z 100) → `<C-e>`/`<C-y>` scroll the toast while one is visible → skip `snacks_notif`/`snacks_notif_history` [verified] [change-gate: pass]
- `lua/colorschemes/solarized-osaka/variants.lua:155,158` — duplicate `member` key in `custom-latest`, the second wins → member colour applies to every language, docs say Go only → keep one line (breakage only, no colour choice) [verified] [change-gate: pass]
- `variants.lua` `M.load` + `palette.lua:472` — `member` is nil in the base, so the restore never runs; `override_go` is global → numbered builds `custom-v1..v4` no longer reproduce → uncomment `member = false` in the base [verified] [change-gate: fail until checkpoint, palette closed]

Low-Medium and Low:

- `copilot.lua:138-163` — `InsertEnter` NES has no macro guard → `100@a` sends ~100 requests → return when `reg_executing() ~= ""` [unverified] [change-gate: pass]
- `keymaps.lua:588` — insert `<M-j>`/`<M-h>` unmapped → Cmd+J while typing exits insert and moves a line → map to `<Nop>` [verified] [change-gate: pass]
- `keymaps.lua:430-431` — arrow fallback in panels is inverted → `<Up>` moves down in help/quickfix/oil → make the fallback the pressed key, unless intended [verified by reading] [change-gate: pending user confirm]
- `git.lua:247-258` — `]c` in a diff split drops the count → `3]c` moves one → prefix `vim.v.count1` [verified by reading] [change-gate: fail until checkpoint]
- `lua/plugins/markdown-preview.lua:33` — `silent update` errors on a readonly buffer → `<leader>ui` raw error → `pcall` [unverified] [change-gate: fail until checkpoint]
- `copilot.lua:330` — toggle-off clears NES in the current buffer only → stale NES in another split, `<Tab>` applies it → clear every buffer with `nes_state` [verified by reading] [change-gate: fail until checkpoint]
- `copilot.lua:154-157` — NES marked done before the buffer attaches → no retry right after load → mark only when attached [unverified] [change-gate: fail until checkpoint]
- `lua/plugins/trouble.lua:573` — outline fold uses the current buffer → async reply can fold the wrong buffer → use `filter_memo.result[1].buf` [unverified] [change-gate: fail until checkpoint]
- Root `CLAUDE.md` — untracked since 5ccaec4 with local-only edits; tracked files link to it → track it again or merge into `docs/CLAUDE.md` [verified] [change-gate: pass, backup]
- Stale docs: `README.md` (`<leader>ui`, Copilot, CodeCompanion), `neovide.lua:58-63`, `notes/copilot-nes.md:59`, `CLAUDE.md` Go member and LSP doc rows, `copilot.lua:42` comment [verified] [change-gate: pass, text only]
- `lua/plugins/snacks.lua` dead explorer-input code and `transparent = true` comments after 94eb3e0; `lua/config/picker-size.lua` unused `compact` [verified] [change-gate: fail until checkpoint]

## Found while validating the audit fixes (2026-10-26)

- todo-comments `TODO` keyword highlight — `TodoFgTODO`/`TodoBgTODO`/`TodoSignTODO` resolve to a different fg from one start to the next with identical code (2 of 4 captures `#268bd3`, 2 of 4 `#29a298`) → load-order race: the colour depends on which group exists when todo-comments sets up → pin the `TODO` colour to a fixed group or set it after the colorscheme; breakage only, no colour choice [verified, 4 captures] [change-gate: fail until checkpoint]

## Insert-mode check (2026-10-26)

Measured in a real TUI through tmux, 9 filetypes x 4 scenarios + big files +
Copilot ON/OFF; raw numbers in `deep-config-review-baseline/insert-mode-results.txt`,
instrument in `insert-mode-measure.lua` / `insert-mode-driver.py` (checked first
against a control that adds 20 ms per key: p50 0.72 -> 20.86 ms). Config files
on the insert path were read in full by a second reviewer.

**Verdict: normal-size files are fast in every language** (Go, TS, Python,
Bash, Rust, C/C++, C#, Markdown, SQL): per key p50 ~0.5-1 ms, p95 <= 2 ms,
on screen within 1-5 ms at p95, event-loop p95 ~1.2 ms. Copilot ON adds nothing
measurable. The one-off 10-28 ms is the first `o`/`i` of a session (blink loads).

Fixed the same day:

- `lua/config/options.lua` — `ttimeoutlen` 50 -> 10. `<Esc>` to normal mode 61 -> 22 ms (wall clock, tmux), and fixes the regression the insert `<M-h>/<M-j>/<M-l>` `<Nop>` maps introduced: a quick `<Esc>` then `j` (< 50 ms) was read as `<M-j>` and both keys were lost [verified with control at 5/10/20/30/40/50 ms gaps] [change-gate: pass, regression fix]
  - Re-checked with exact byte timing in a raw pty (`deep-config-review-baseline/ttimeoutlen-check.py`, control `ttimeoutlen=50`): arrows (CSI and SS3), mouse wheel, focus events, Cmd+J/Cmd+H, `<Esc>` then `O`, and a 330 KB bracketed paste all pass, same as the control. Two leftovers, both accepted: an `<Esc>` then `j` under ~10 ms is still read as Cmd+J (the bytes are identical, no setting can split them); and over a slow remote link an arrow or mouse code split by more than 10 ms is misread (local Ghostty + tmux sends each code in one write).

Open, slow only in big files or on one key:

- Markdown, `render_modes` without insert (`lua/plugins/render-markdown.lua:52`) — entering/leaving insert clears and re-renders the buffer: 3-9 ms in a normal file, 87-109 ms in a 3,300-line file → only very large `.md` files [verified] [change-gate: fail, deliberate trade-off]
- Big files, Enter — LazyVim's treesitter `indentexpr` scales with file size: 30-50 ms per `<CR>` at 6,000 lines (Go/TS), ~6 ms at 800 → stock behaviour; a size-based fallback is the only fix [verified, jit.p profile] [change-gate: fail]
- `basedpyright` with no project config runs its strictest default (`recommended`): 1,200 warnings on a 6,600-line file and 47 event-loop stalls (max 42 ms) while typing → set `typeCheckingMode = "standard"` in `lua/plugins/lsp.lua` settings (a project's own pyproject still wins) [verified] [change-gate: fail until checkpoint]
- which-key registers preview on `<C-r>` (insert) and `"` (normal) — with `clipboard=unnamedplus` each preview calls `getreg('+')`/`('*')`, 13.5 ms each via `pbpaste`, popup ~65-72 ms after the key → `opts.plugins.registers = false` loses the preview [verified] [change-gate: fail, feature trade-off]
- nvim-ts-autotag in plain `typescript` and `markdown` — each `>` reparses the buffer (4 ms at 43 KB, 12.6 ms avg / 25 max at 130 KB TS, 10.6 ms at 28 KB md), and `.` repeat drops every `>` there → `opts.per_filetype` disabling close/rename for typescript and markdown, keep tsx/jsx/html [verified by reviewer] [change-gate: fail until checkpoint]

Open, behaviour (not speed):

- `lua/config/keymaps.lua:526` — global insert `<Tab>` replaces Neovim's default snippet jump; after typing over a placeholder `<Tab>` inserts a tab instead of jumping → check `vim.snippet.active({direction=1})` first (same for `<S-Tab>`) [verified] [change-gate: fail until checkpoint]
- `lua/config/mouse-hover.lua:225` — no mode check, so a hover float opens over the code ~1 s after you start typing with the pointer over a word → return early in insert mode [verified] [change-gate: fail until checkpoint]
- `keymaps.lua:266-280` — insert-mode wheel maps use `<C-o>`, so each tick leaves and re-enters insert (closes the blink menu; with Copilot on, one NES request per tick) → `<Cmd>` maps [verified by reviewer; NES part unverified] [change-gate: fail until checkpoint]
- SQL — the stock `ftplugin/sql.vim` remaps insert `<Left>`/`<Right>` via `feedkeys`, so a fast `ab<Left>X` gives `abX` → `vim.g.omni_sql_no_default_maps = 1` [verified by reviewer] [change-gate: fail until checkpoint]
- Rust — every `.rs` file opens on a blocking "rust-analyzer not found, Press ENTER" prompt; the rust extra is on but the binary is missing → install it or drop the extra (Rust is 2027+) [verified] [change-gate: fail until checkpoint]
- tailwindcss LSP attaches in any git repo to ts/tsx/md/css/html, full-text sync, no tailwind config needed; measured cost on typing is ~1 ms → restrict `root_dir` to tailwind config files [verified] [change-gate: fail until checkpoint]
- blink-cmp.lua `<ESC>` comment says the second Esc exits "via copilot's handler"; that map was removed 2026-10-04 (native Esc does it) → comment only [verified] [change-gate: pass, text only]

Checked and clean: blink-cmp config and the Rust fuzzy dylib, sql-keyword-source (~0.6 ms), copilot idle path, autocmds.lua, options.lua paste wrapper, performance.lua, vim-visual-multi, mouse-hover ModeChanged, ufo, snacks (scroll/indent/words off), LSP debounce 200 with no semantic-token/inlay/codelens traffic, no blocking I/O on insert paths, no TextChangedP handlers, `.` repeat vs the undo-break maps. Startup in a real tmux pane: ~65 ms, Neovim's own `vim._core.defaults` 15 ms (the 114 ms was the test pty).

## Phase 1 — `lua/config/keymaps.lua`

Deferred to the 2026-12-31 checkpoint.
