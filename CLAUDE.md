## Guideline

- **Before doing anything with this config, read `rules.md` at the repo root FIRST.**
  It holds the discipline rules, the active config-freeze window, and links the
  change-gate (`neovim-config-change-gate.md`) that decides whether a requested
  change should happen at all. Apply that gate to every change request.
- Then read all the infos and instructions inside `docs/` and follow them closely.
  `docs/CLAUDE.md` is the canonical one; `docs/AGENTS.md` just points at it.

> This file is the canonical entry point for **every** AI agent, not only Claude.
> `AGENTS.md` at the repo root is a pointer here so that Codex and anything else
> looking for that filename lands in the same place. Keep it a pointer — two
> copies of these rules will drift, and an agent will then follow the stale one.

## File browser: oil.nvim (reverted to oil 2026-09-04)

`<leader>e` is **oil.nvim**, in `lua/plugins/oil.lua`. `<leader>E` is the same
command, kept so the muscle memory from the months oil spent on that key still
works. Oil also owns netrw, so it handles `:e <dir>` and `nvim <dir>`.

Oil opens as a **centred popup** in every case, including startup. `USE_FLOAT`
at the top of the file is the one-word switch back to fullscreen-in-the-window.
On `nvim <dir>` a `VimEnter` hook swaps oil's directory buffer for a blank
`[No Name]` one and opens the popup over it, so closing the popup lands you on an
empty buffer instead of fullscreen oil.

The snacks browser that held `<leader>e` from 2026-08-21 is **retired, not
deleted**: `lua/plugins/snacks-file-browser.lua` with `ENABLED = false`. It was
kept for a week of real use and worked, but never felt as smooth as oil. Flip
`ENABLED` back to `true` to revive it, and then give it a key other than
`<leader>e`. The telescope attempt at the same thing is parked the same way in
`lua/plugins/telescope-file-browser.lua` (`ENABLED = false`, which also keeps
telescope uninstalled). Do not revive either to "compare" without a reason.

Things a new session must know before touching `oil.lua`, `snacks.lua`, or the
two retired browsers:

- **The theme is OPAQUE now (2026-09-04), which is the precondition for
  everything below.** `transparent = false` and `bg = #000f13` in
  `lua/colorschemes/solarized-osaka/init.lua`. That hex is the colour Ghostty was
  already emitting (its `background = #031219` blended at `background-opacity =
  0.9` over a dark desktop), measured off a screenshot, so the editor looks the
  same and no longer depends on the terminal. Ghostty's opacity and blur now
  reach only the window padding. **`transparent` must be an explicit `false` —
  the plugin's own default is `true`, so commenting the line out re-enables it.**
- **The oil popup backdrop is ON, and with an opaque background it is a real
  dim.** `USE_BACKDROP = true` in `oil.lua`, strength in `BACKDROP_BLEND`. The old
  "a backdrop renders as solid black" finding was true *because* of
  transparency — nothing to blend against — and that precondition is gone. The
  two settings are coupled: turning transparency back on turns this into a black
  sheet again. **Do not flip it off on the strength of the old note — ask first.**
- **Still never re-enable snacks' picker backdrop.** That one is not a
  preference, it is the mis-detection below.
- The whole-editor darkening behind popups is a **snacks transparency
  mis-detection triggered by another plugin's `winhighlight`**, not a browser bug.
  It is fixed by `backdrop = false` in two places in `snacks.lua`. Those two lines
  **stay**: telescope was one trigger and is gone, but the lazy.nvim UI
  (`Normal:LazyNormal`) is the other and ships with the config.
- **`snacks.explorer` is still enabled**, for the `<leader>r` tree sidebar only,
  with `replace_netrw = false`. That is deliberate: oil must keep netrw.
- **A picker list is VIRTUALLY scrolled, so native `<C-e>`/`<C-y>` are inert in
  it.** The buffer only holds the rows on screen and `list.top` maps a row to an
  item, so there is no text below the last line to scroll to — the keys are not
  being swallowed, they have nothing to move. `config/keymaps.lua` also skips any
  `^snacks_picker` float on purpose, so each picker window must answer for
  itself: bind them to `list:scroll()`, which is what the mouse wheel already
  calls there. Bound **picker-wide** in `snacks.lua` (`picker_scroll` +
  `list_scroll_down`/`list_scroll_up`), so every picker gets it, not just the
  explorer. Binding it on the picker window also matters for a second reason:
  the global handler scrolls the first focusable NON-picker float it finds, so
  with a picker open over the oil popup it scrolled OIL. A buffer-local mapping
  in the picker window takes precedence and fixes that too.
- **A picker has TWO windows, and keys bound on the list are unreachable from the
  input.** After typing a filter, focus sits in the input — where snacks binds
  `j`/`k` to list movement but leaves `h`/`l` as native text motion, so the tree
  walked but would not collapse/expand. Tree keys are now bound on both windows,
  **normal mode only**, so the prompt still types those letters while filtering.
  When adding a picker key, ask which window will have focus when it is pressed.
- **The oil path label is built once and rendered two ways** — as a border-title
  chunk list for the popup (`float.get_win_title`) and as a winbar string for a
  real oil window. Change `path_segments` / `SEPARATOR` and both follow. Its
  colours are `OilPathSegment` (copper, read from the syntax palette by role) and
  `OilPathSeparator`.
- **The popup's top three rows are load-bearing:** the border's top edge carries
  the path label (as the window title), the winbar under it is one space (the
  spacing), then the first entry. Swapping which of those two rows holds the text
  moves the spacing above the label — tried 2026-09-04 and reverted, so it is a
  small edit if it comes up again. The blank row cannot be an extmark: Neovim does
  not DRAW `virt_lines_above` on the first buffer line (measured, though
  `win_text_height` counts it), while a real blank line would be read as a rename
  to `""` when oil diffs the buffer on save.
- **Nothing per-directory can live in oil's `float.win_options`.** Oil re-applies
  that whole table on every navigation, so the constant blank `winbar` is fine
  there but a label would be overwritten. The label goes through
  `float.get_win_title`, which oil re-reads on every navigation.
- **Oil's border is invisible on purpose** (`OilFloatBorder`, fg = bg, remapped
  through `OIL_WINHIGHLIGHT` for oil's windows only). What separates the popup
  from the buffer under it is the backdrop dim, not a ring.

Full reasoning, measurements and the rejected alternatives:
[`notes/popup-backdrop-darkening-investigation.md`](notes/popup-backdrop-darkening-investigation.md)
and [`todos/snacks-explorer-as-file-browser.md`](todos/snacks-explorer-as-file-browser.md).

## Syntax palette: CLOSED 2026-09-07

The final update fixes dense JS/TS object literals where cyan keys and values
mixed together. `custom-latest` now keeps brackets bright, delimiters quiet, and
Type below the old brightness peak. No more colour tweaking is planned.

| role | value | contrast |
| --- | --- | --- |
| body / `@variable` | `#b1bebf` | 10.19:1 |
| bracket / object structure | `#9eabac` | 8.23:1 |
| type | `#2ac3de` | 9.24:1 |
| names: params, tags, `${}` | `#aea134` | 7.37:1 |
| delimiter / operator | `#7f9195` | 5.93:1 |
| keyword | `#a17bcc` | 5.77:1 |
| comment | `#576d74` | 3.57:1 |

The 2026-09-06 measurements remain useful history, but their former live values
are superseded by the `custom-latest` overrides in
`lua/colorschemes/solarized-osaka/variants.lua`. See
[`notes/syntax-palette-decisions.md`](notes/syntax-palette-decisions.md).

## Silent-failure surfaces — read before debugging "my change did nothing"

Fifteen places in this config accept a wrong value and **do nothing** rather than
erroring: unresolved picker action names get typed as keystrokes, an action name
matching a snacks built-in replaces it everywhere, spelling out a layout `box`
drops the preset's overrides, `virt_lines_above` on line 1 renders nothing while
still being counted, `transparent` re-enables itself when the line is deleted, a
duplicate key in a Lua table silently keeps the last one, and so on. Each is
marked in code with `-- WARN: SILENT FAILURE`.

- List them: `:TodoLocList keywords=WARN` or `rg "WARN: SILENT" lua/`
- Full explanations, with what each one actually broke:
  [`notes/silent-failure-surfaces.md`](notes/silent-failure-surfaces.md)

**The rule that comes out of it:** in these areas a clean test result proves
nothing unless the test can also detect the broken state. Run the check once
against a deliberately broken version first; if it cannot tell the two apart, it
is worthless. Several checks reported "working" for both the fixed and broken
config during the session that produced this list.

## Two structural traps in this config (read before editing plugin specs)

**One `init`/`config`/`opts`-function per plugin, across ALL spec files.**
lazy.nvim chains the fragments of a plugin through `__index`, so for a
single-valued key only the LAST fragment wins, and fragments are ordered by module
name. This silently broke things for weeks: `lua/plugins/snacks-file-browser.lua`
defined an `init` for `folke/snacks.nvim`, sorts after `lua/plugins/snacks.lua`,
and therefore killed snacks.lua's `init` entirely — no `SnacksPickerMatch`, indent
guides stuck on the theme's near-invisible colour, and `SnacksExplorerActiveFile`
undefined, so the explorer's active-file band did nothing at all. Nothing errored.

The same applies to `enabled`: an `enabled = false` in one fragment disables the
whole plugin, which is why `snacks-file-browser.lua` gates its `keys` and `init`
on a local flag and sets **no** `enabled` key. When a second spec file for a
plugin needs disabling, make the key ABSENT (`init = FLAG and function() … end or
nil`) — an `init` that merely returns early still wins the lookup.

**One background colour, in `lua/config/ui.lua`.** The colorscheme's `on_colors`
reads it and assigns `bg`, `bg_float`, `bg_sidebar` and `bg_popup` from it, so
every panel matches the editor. Two traps there, both measured: `bg_statusline`
is *not* the statusline/winbar key (the theme writes `StatusLine = { bg =
c.base03 }` directly and links `WinBar` to it, so `WinBar` is handled in
`on_highlights` instead), and anything needing the background at runtime should
read `Normal`'s `bg` rather than requiring the module.

## One loose end from the freeze session (review by ~2026-10-20)

LOW priority, non-blocking. The pre-freeze build-out is committed + pushed; this is the
only thing not yet eyeballed. Do it casually next time you open one of these files — it is
NOT a reason to reopen the frozen config.

### Actually left to verify — only the NEW DevOps filetypes

- [ ] `.tf` (Terraform) — open one, `:LspInfo` shows `terraform-ls` attached, hover/complete works.
- [ ] `Dockerfile` — `:LspInfo` shows `dockerls`, hover works.
- [ ] helm chart (`templates/*.yaml` or `values.yaml`) — `helm-ls` attaches.
- [x] `.yaml` — already confirmed working.

If a server doesn't attach: `:Mason` → find it → press `i` to reinstall. It's isolated to
that filetype and can't affect anything else.

### NOT a concern (no action needed)

- **TS/JS/Python/Go LSP** (hover / go-to-def / completion): the freeze session never touched
  `lsp.lua` or `blink-cmp.lua`, so their behavior is unchanged from the already-
  production-validated state. "Only tested on a small lua/tsx file" just means *not re-tested* —
  the config they run on didn't change, so there is nothing that could have regressed.
- **TS/JS/etc. format-on-save** (prettierd): this *was* changed, but it was verified to produce
  byte-identical output for files with a project `.prettierrc` (your production repos) — confirmed
  safe, no team git-diff churn.

**Bottom line:** the only genuinely-unverified thing is whether `terraform-ls` / `dockerls` /
`helm-ls` attach on real files. High-impact areas (daily languages) are untouched or proven-safe.
