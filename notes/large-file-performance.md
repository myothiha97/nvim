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

## Semantic tokens: on for vtsls and gopls only (2026-11-26)

Treesitter has no scopes, so it colours a parameter only where it is declared.
Semantic tokens add the uses in the body (and, for Go, constant uses and type
parameter declarations). `lua/plugins/lsp.lua` keeps tokens only for vtsls and
gopls and clears every `@lsp` group except a short list of links, so nothing
else changes colour.

Measured with the same tmux harness, 3 rounds, tokens off -> on, p50/p95 ms:

| file | scroll `<C-d>` | `j` | typing |
| --- | --- | --- | --- |
| Go 3.8k lines, 98 KB | 2.4/10.7 -> 3.6/14.8 | 2.9/8.1 -> 4.5/9.5 | 4.7/9.9 -> 4.7/8.5 |
| Go 33k lines, 847 KB (sqlc parser) | 3.1/16.8 -> 3.4/17.2 | 3.2/10.1 -> 3.4/11.3 | 8.0/12.8 -> 8.3/14.0 |
| ClassAddBookingDrawer.tsx (67K chars) | 2.6/15.4 -> 3.3/17.4 | 3.2/9.2 -> 4.4/11.1 | 5.2/13.3 -> 6.6/14.1 |
| TransactionDetailsCard.tsx (78K chars) | 2.7/15.2 -> 3.7/16.6 | 2.8/11.7 -> 3.8/12.2 | 4.7/13.7 -> 5.3/13.0 |

About 1 ms per key at p50, inside one frame. The ~135 ms stalls in TSX files
show up with tokens off too, so they are not from tokens.

- gopls sent tokens for an 847 KB file. The old "refuses over 100,000 bytes"
  note no longer holds for the current gopls.
- vtsls (like VS Code) returns NO tokens for a full request above 100,000
  characters but still answers range requests, so Nvim painted the range and
  then wiped it. That is why the first test "returned no tokens at all".
  `range` is turned off for vtsls: those files stay on treesitter colours.
- TypeScript relabels a callable parameter (`onClose()`) as `function`, so it
  stays function blue. A name-based workaround was considered and dropped.
- basedpyright stays off: it made scrolling slower (`<C-d>` p50 3 to 20 ms,
  wheel 1 to 15 ms).
