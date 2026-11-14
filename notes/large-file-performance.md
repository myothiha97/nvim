# Large-file performance (measured 2026-11-14)

What is slow on big files, why, and what was decided. Read this before adding a
size guard or blaming a plugin for lag in a big file.

## How it was measured

Real config, real TUI: nvim in a detached tmux pane (200x50), driven over RPC.
Each key is timed until nvim has run it AND redrawn the screen; a second probe
pings the main loop every 10 ms after the keys to catch async stalls (LSP
replies, scheduled callbacks). 16 ms (one frame) is the "can you feel it" line.

The harness was checked against deliberately broken builds first: a 20 ms
`CursorMoved` sleep moved `j` from 1.8 ms to 31.5 ms, and a deferred 80 ms
stall showed up in the async probe. Culprits were then confirmed by switching
one component off at a time (diagnostics, LSP, bufferline, scrollview, ufo,
blink, statuscolumn, snacks indent, regex syntax).

## Normal files: no issue

Go, TS, TSX, JS, JSX and Python files up to ~6k lines (the work portals, Go
stdlib, zod, `_pydecimal.py`) and the ledgerflow backend: `j` p50 about 1 ms,
typing p50 under 5 ms, p95 under ~25 ms. Nothing to fix.

## Known lag: typing in a file with thousands of diagnostics

`ssa/rewritegeneric.go` (40k lines) carries **10,907** gopls diagnostics.
Typing there costs ~29 ms per key (p95 ~100 ms), and a pasted line ~900 ms.

- Cause: Neovim core's diagnostic extmark handling in insert mode
  (`vim/diagnostic.lua` `restore_extmarks`), plus snacks statuscolumn reading
  every sign. Diagnostics off: 1.6 ms per key. LSP off: 1.9 ms.
- NOT the cause: bufferline, scrollview, ufo, blink, statuscolumn on their own
  (each switched off, no change).
- Treesitter on vs off makes no difference there.
- Decision: no change. It needs a generated-code-sized diagnostic count; real
  files have tens. If it ever bites, `vim.diagnostic.enable(false, { bufnr = 0 })`
  for that buffer is the instant workaround.

## Known stall: bufferline's error count in a huge workspace

bufferline (`diagnostics = "nvim_lsp"`) calls `vim.diagnostic.get()` for ALL
buffers on every tab-bar redraw in normal mode, deep-copying every diagnostic in
the workspace (`bufferline/diagnostics.lua`). Insert mode is cached.

- Go stdlib as the workspace: gopls published 5,009 diagnostics over 570 files,
  freezing nvim for **13.7 s** after the first open (1.8 s with bufferline's
  diagnostics off), and 50 to 90 ms hitches while scrolling a 10.9k-diagnostic
  file.
- Your projects: ledgerflow 3 diagnostics, business-portal 49 to 188. Cost there
  is negligible.
- Decision: keep it. If you work in a repo with thousands of diagnostics, set
  `diagnostics = false` in `lua/plugins/bufferline.lua` (loses the red error
  count on tabs).

## Treesitter size guard: removed

`lua/config/autocmds.lua` stopped treesitter above 100 KB (about 2,500+ lines),
falling back to regex `syntax`:

| file | `G` with the guard (regex syntax) | regex syntax off | treesitter on |
| --- | --- | --- | --- |
| react-dom.development.js (26k lines) | 250 ms | 31 ms | 22 ms |

Treesitter forced on `net/http/server.go`, a 2.3k-line TSX form and the 40k-line
Go file was equal or better than the guard. The guard also raced LazyVim's
treesitter start, so the same file came up with treesitter on in one session
and off in another. snacks' bigfile (1.5 MB) already covers truly huge files.

## Bigfile mode (over 1.5 MB)

`ssa/rewriteAMD64.go` (110k lines, 2.6 MB): filetype `bigfile`, no LSP, no
treesitter, regex syntax only. `j` 1 to 5 ms, `G` 45 ms, typing under 5 ms.
Fine.

Papercut: the "Big file detected" notice opens as a **Press ENTER** prompt,
because noice's message view and notify are both off, so the multi-line
message falls back to Vim's hit-enter prompt.

## Semantic tokens: stay off

- gopls refuses files over 100,000 bytes ("too large").
- In Go it adds doc links in comments (`[Attr]`, `[Logger.Log]`), `//go:`
  directives and printf verbs. It does NOT highlight plain words the way
  GoLand does.
- The `@lsp.type.*` groups are not mapped to the palette, so types and
  functions across all code would change colour.
- basedpyright made scrolling slower (`<C-d>` p50 3 to 20 ms, wheel 1 to 15 ms);
  vtsls returned no tokens at all.
