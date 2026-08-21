# Shape snacks explorer into the telescope-browser experience

Direction chosen 2026-08-21 (~03:00). **In progress since ~11:30 the same day** —
implemented in `lua/plugins/snacks-file-browser.lua`, uncommitted on
`trial/telescope-file-browser`, being used before a keep/drop decision.

## Status

Built and verified in a real terminal:

- `<leader>e` opens a 90x25 dropdown, `nvim <dir>` opens it edge-to-edge.
- Flat, one-directory listing (`tree = false`), directories first, cwd row filtered.
- Path in the prompt (`./lua/config/`), static `File Browser` title, `x/y` counter.
- Path editor in the prompt, copied from file_browser: `<BS>` on an empty query
  goes to the parent, `/` enters the typed directory, so `lua/plugins/keym` walks
  two levels and leaves `keym` filtering.
- Permissions/size/date columns with `gs` to toggle — cheaper than telescope's,
  which stat'd every entry; this stats only visible rows and caches per item.
- `l` / `=` / `<CR>` enter, `h` / `-` up, `s` (and double-click) expand in
  place, `q` close, `H` hidden, `N`/`a` create, `/` focuses the prompt from the
  list. `<Esc>` in the list clears search highlight; `<Esc>` in the prompt returns
  the cursor to the LIST (snacks splits input and list, so leaving insert used to
  park you in the prompt where bulk select and the file operations do not exist).
- Insert mode: `<C-l>` select, `<C-h>` parent, `<C-j>`/`<C-k>` move the highlight,
  `<BS>` parent on an empty query, `/` enter the typed directory.
- CRUD from snacks' explorer defaults: `a` add, `r` rename, `d` delete, `c` copy,
  `m` move, `y` yank, `p` paste, `o` system open, `u` refresh. `<Tab>`/`<S-Tab>`
  mark rows for the bulk operations (visual mode + `<Tab>` marks a whole range),
  `<C-a>` selects all, `<C-s>` clears every mark — `<C-a>` alone only clears when
  everything is already selected.
- Creation and move/copy/paste target the PATH IN THE PROMPT, not the folder under
  the cursor: `picker:dir()` is shadowed to return the cwd, matching telescope's
  `finder.path`.
- Search audited 2026-08-21: matches the NAME (`item.text` is reset to the
  basename, or every row matched through its absolute path — `config` in
  `~/.config/nvim` returned everything), ranks best-match-first
  (`sort = { score desc, idx }`; the explorer's own sort orders by a field that
  only exists in its recursive-search branch), and stays non-recursive.
- Measured: enter a directory 42ms, filter 24ms, 2000-file directory 136ms to
  list and ~100ms to filter. Stat columns stat only visible rows and cache per
  item, so a 2000-file directory costs ~120 stats, not 2000.
- Survives another picker opening on top; no veil, no dim.
- UI matched to telescope: `File Browser` title, path in the prompt in
  `Identifier` blue, white folder glyph with blue name and trailing `/`, mode
  coloured per character, size teal / date blue, white `> ` caret via the list
  `statuscolumn`, indentation without guide glyphs.

`<C-h>/<C-j>/<C-k>/<C-l>` are explicitly `false` in this mode: snacks.lua binds
them to window focus for the whole `explorer` source, which is right for the
sidebar and orphaned the dropdown here.

`lua/plugins/telescope-file-browser.lua` is parked with `ENABLED = false` (its
only change) so `<leader>e` is free. Flip it back and change `TRIAL_KEY` to A/B.

### Still open

- Not bound: telescope's `<C-t>` change_cwd, `<C-e>` home, `<C-w>` goto_cwd.
- Decision 1 below (netrw ownership) is still unresolved: `:e <dir>` remains
  oil's, and the startup path uses its own `VimEnter` hook rather than
  `replace_netrw`.

## Why

The telescope browser works, but every problem of the 2026-08-20 night traced to
one property: a telescope picker is a **modal float that remaps `Normal` and
destroys itself on focus loss**. That cost two hacks to keep it open under another
picker, made a dim impossible, and poisoned snacks' transparency detection so
every popup blacked out the editor. See
`notes/popup-backdrop-darkening-investigation.md`.

The snacks explorer has neither property. Measured 2026-08-21:

| property | telescope browser | snacks explorer |
| --- | --- | --- |
| stays open under another picker | needs 2 hacks (cleared `BufLeave` + `WinEnter` watcher) | `auto_close = false` by default, free |
| remaps `Normal` via `winhighlight` | yes → poisons `Snacks.util.is_transparent()` | no (`NormalFloat:…`), cannot poison |
| startup (`nvim <dir>`) path | ~60 lines of custom `VimEnter` + oil-buffer swap | `replace_netrw = true`, first-class (`explorer/init.lua:27`) |
| dim behind it | impossible on a transparent theme | not needed |

If this lands, telescope can be removed entirely and the two `backdrop = false`
lines in `snacks.lua` can go with it.

## Verified achievable by config alone

Measured with `Snacks.explorer.open({...})` in a real terminal:

- **Flat, per-directory listing** — `tree = false` (honoured at
  `picker/source/explorer.lua:176,322`); entries came back flat, no tree indent.
- **Fullscreen borderless** — `layout = { layout = { width = 0, height = 0, border = "none" } }`
  gave a `188x46` list in a 190x50 terminal.
- **Parent navigation** — the `explorer_up` action is `set_cwd(dirname(cwd))` +
  refind, i.e. exactly the browser's `h` / `-`.
- **Stays open** — a smart picker opened over it and cancelled left it untouched.
- Keys, normal-mode start (`focus = "list"`), dropdown geometry: all config.

## Needs custom work

- **Permissions / size / date columns.** Not built in. The hook exists — the
  explorer `format` is already wrapped in `snacks.lua` for the active-file band —
  so a formatter can append them from `vim.uv.fs_stat`. Same per-entry cost that
  was measured during the telescope trial, so treat it as a perf decision, not a
  freebie. **Suggest shipping v1 without them** and adding only if they are
  actually missed.
- **`gs` toggle** for those columns: a small custom action.

## Decisions to make before starting

1. **netrw ownership.** `replace_netrw = true` is the clean startup mechanism but
   takes directory buffers from oil, so `:e <dir>` mid-session opens snacks
   explorer instead of oil. `lua/plugins/oil.lua` currently keeps
   `default_file_explorer = true` on purpose for that case. Either accept the
   swap, or keep oil on netrw and add a startup-only hook (more custom code, the
   thing this change exists to avoid).
2. **Keys and layouts.** Two entry points are possible since layout can be passed
   per call: keep `<leader>r` as today's 25% sidebar, and give the browser-style
   flat dropdown its own key (`<leader>e`, freed when the telescope trial goes).
3. **Fullscreen at startup, dropdown on demand** — matching the current telescope
   behaviour — or one geometry everywhere.

## Order of work

1. Draft the browser-style explorer alongside the existing sidebar, on
   `trial/telescope-file-browser` or a fresh branch, and use both for a few days.
2. If it wins: delete `lua/plugins/telescope-file-browser.lua`, revert the two
   `backdrop = false` lines, set oil's `default_file_explorer` per decision 1,
   then `NVIM_LAZY_UNLOCK=1 nvim` + `:Lazy clean` to drop telescope.
3. If it loses: keep the telescope trial as it stands and close this out.
