# Git keymaps: hunk review and changed-file navigation

Added 2026-09-23/24. All code lives in `lua/plugins/git.lua` (gitsigns spec).

## Keys

| key | mode | action | where |
| --- | --- | --- | --- |
| `gn` / `gN` | n | open next / prev changed file, cursor on its first hunk | gitsigns `keys` |
| `]]` / `[[` | n | next / prev hunk in this file | `on_attach` |
| `]c` / `[c` | n | same as `]]`/`[[` (kept; native diff jump inside a diff split) | `on_attach` |
| `ghp` | n | preview hunk popup | `on_attach` |
| `ghs` / `ghr` | n | stage / reset the hunk under the cursor | `on_attach` |
| `ghs` / `ghr` | v | stage / reset only the selected lines (partial hunk) | `on_attach` |
| `n` / `N` | n | while the `ghp` popup is open: next / prev hunk, popup re-opens on it | set per preview |
| `c1` / `c2` | n | inside the focused popup: stage toggle / revert hunk | set per preview |

**Secondary keys**, kept for muscle memory and marked `(secondary)` in which-key.
They will be rebound to something else later:
`<leader>gn`, `<leader>gN`, `<leader>ghp`, `<leader>ghs`, `<leader>ghr`.

Review flow: `gn` to a file, `ghp` to preview, `n`/`N` to walk its hunks,
`c1` (after `<Tab>` into the popup) or `ghs` to stage, `gn` to the next file.

## How `gn`/`gN` work

- File list: `git status --porcelain=v1 -z` from the repo root. Staged, unstaged
  and untracked files, sorted by path. Deleted files are skipped; a rename counts
  once, under its new path. Git runs only on keypress, with a 5 s timeout.
- The file opens in a normal file window, never inside a sidebar (Trouble, the
  explorer) or a float; focus only moves once there is a file to open.
- The current file is compared by its real path (`fs_realpath`), because git
  reports physical paths and a repo opened through a symlink never matched.
- From an unchanged file, the step lands on the nearest changed neighbour by path.
  Wraps at both ends.
- On open the cursor is set to line 1 first, overriding LazyVim's restore of the
  last-edit position (that restore was the "random position" bug).
- Then it polls every 50 ms, up to 10 s, until `gitsigns.get_hunks(buf)` is
  non-nil, and calls `nav_hunk("first", { target = "all" })`, so staged hunks count.
- If you move the cursor before the jump, it cancels. When the first hunk is on
  line 1 it stops after one jump; a staged-only file gets ~1 s of retries.

Measured: the gitsigns diff of a newly opened file takes ~0.5 s with or without
an LSP; vtsls starting on the same file stretched it to ~0.9 s by competing for
the main loop. The LSP never blocks gitsigns and never moves the cursor. The
first version gave up at 0.5 s, the second at 3 s; both missed in real projects.

Limits: untracked files have no hunks (`attach_to_untracked = false`) and open
on line 1, after up to 10 s of cheap polling in the background.

## Traps (each cost a failed attempt)

- **`gitsigns_status_dict` is not a "ready" signal.** It appears on attach,
  before the diff exists. Wait for `get_hunks(buf) ~= nil`.
- **Staged hunks are diffed after unstaged ones.** A staged-only file reports no
  hunks on the first pass, so the jump retries when the cursor did not move.
- **`preview_hunk()` focuses an already-open preview** instead of opening a new
  one. The `n`/`N` step closes the popup before navigating.
- **`WARN: SILENT FAILURE`: `WinClosed` cleanup alone leaks the `n`/`N` keys.**
  gitsigns closes the popup on cursor move from inside its own non-nested
  `CursorMoved` autocmd, and autocmds do not fire from inside another one, so
  `WinClosed` never runs on that path (silent-failure note #16). A buffer-local
  `CursorMoved` of our own checks the popup, scheduled, and releases the keys the
  moment it is gone. One augroup, cleared on release, keeps it to two autocmds.
  If a release were ever missed, `n` still replays as normal search (with count).
- `n`/`N` are only taken in a buffer that has no other local `n` mapping.
- **Visual `<cmd>Gitsigns stage_hunk<cr>` gets no range** and staged the whole
  hunk under a one-line selection. Visual mode now passes
  `{ line("."), line("v") }`, gitsigns' README form.

## Why these keys are safe

- **`gn`/`gN`**: native meaning is "select next/prev search match". It matters
  in operator-pending and visual mode (`cgn` + `.`), and those modes are
  untouched: the mapping is normal mode only.
- **`gh`**: native "start Select mode", unused. A bare `gh` now waits
  `timeoutlen` (300 ms) before acting.
- **`]]`/`[[`**: LazyVim maps them to `Snacks.words.jump` only while
  `Snacks.words` is enabled, and it is off in `lua/plugins/snacks.lua`.
- **`n`/`N`**: LazyVim's global search keys; ours are buffer-local and removed
  when the popup is gone.

## `g` prefix map (who owns what)

- LazyVim LSP: `gd`, `gr`, `gI`, `gy`, `gK`, and `gD` (Goto Declaration; in
  TS/JS files the TypeScript extra rebinds it to **Goto Source Definition**,
  which skips `.d.ts` and opens the package's JS).
- Core Vim, keep: `gg`, `gc`, `gu`/`gU`/`g~`, `gq`/`gw`, `gv`, `gi`, `gj`/`gk`,
  `g;`/`g,`, `gf`, `gx`.
- Ours: `gn`/`gN`, `ghp`/`ghs`/`ghr`.
- Mostly free (check before claiming): `gb`, `gl`, `gm`, `go`, `gp`, `gs`, `gz`.

## Related

- Arrow-key scroll toggle: `<leader>uv` in `lua/config/keymaps.lua`
  (`<leader>uA` is LazyVim's tabline toggle).
- Outline split plan: `todos/ui/symbol-outline-split.md`.
