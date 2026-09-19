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
works. Oil still owns netrw, so it handles `:e <dir>`.

Oil opens as a **centred popup** on `<leader>e`. `USE_FLOAT` at the top of the
file is the one-word switch back to fullscreen-in-the-window.

**`nvim <dir>` is the snacks explorer, not oil (2026-09-19).** The `VimEnter`
hook still lives in oil's `config` — oil owns netrw, so it is oil that has to
swap its own directory buffer for a blank `[No Name]` one first — but it then
opens the **snacks tree explorer fullscreen** instead of the oil popup, so
closing it lands you on an empty buffer rather than fullscreen oil. The hook is
no longer gated on `USE_FLOAT`: that switch decides how `<leader>e` presents
oil, and startup is no longer oil's to present.

The hook is in `oil.lua` deliberately. snacks.nvim already has exactly one
`init` (`lua/plugins/snacks.lua`), and a second snacks fragment defining one
would silently kill it — see the one-`init`-per-plugin rule below.

Three upstream details that the obvious implementation gets wrong, all read from
the installed snacks source rather than assumed:

- **`fullscreen` is a layout flag, not a preset.** There is no `fullscreen`
  entry in snacks' layouts; the flag is consumed in `snacks/layout.lua`, which
  forces `width`/`height`/`col`/`row` to 0.
- **`auto_close` does NOT close a picker on confirm.** It only fires on
  `WinEnter` of another window. The explorer survives a file open because its
  source sets `jump = { close = false }`; `jump = { close = true }` is the one
  line that makes a file close it. Directories never reach `jump` (the
  explorer's own `confirm` toggles them in place), so browsing keeps it open —
  which is the wanted behaviour, not a compromise.
- **The layout is passed as a FUNCTION, not a table.** `snacks.lua` spells out
  `sources.explorer.layout` with `position = "left"`, and `Snacks.config.merge`
  is a deep force-merge where `nil` cannot unset — a call-time table inherits
  that position and gives a full-height split instead of a fullscreen float. A
  function replaces the inherited value outright.

The fullscreen title rides the input's **top** border (`title_pos = "center"`),
matching the `<leader>r` sidebar. It must be `border = "top"`: a title needs a
border line to sit on, and a `"bottom"` border has nowhere to draw one.

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
  everything below.** `transparent = false` lives in
  `lua/colorschemes/solarized-osaka/init.lua`; the background itself is
  `bg = #031219` in `lua/config/ui.lua`, which `on_colors` reads. That hex is
  Ghostty's own `background` setting, so the editor and the terminal are the same
  colour by construction, not by a matching pick. (At `background-opacity = 0.9`
  Ghostty composites it to `#031116` over a dark desktop, which is what the
  pre-opaque screenshots measured. `#031116` is a `candidates` entry named
  `greyed_light`, NOT the live value.) The editor no longer depends on the
  terminal, and Ghostty's opacity and blur now reach only the window padding.
  The `candidates` ladder in `ui.lua` was explored and then abandoned in favour
  of the Ghostty value, so `bg` points outside that list on purpose. **`transparent` must be an explicit `false` —
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

## Dashboard (2026-09-19)

Bare `nvim` shows the snacks dashboard; only `nvim <dir>` opens the explorer.
`preset.header` is plain text (`Welcome, Myothiha!`), overriding LazyVim's
six-line LAZYVIM ASCII block — this config is only *based* on LazyVim, so the
generic banner was wrong, and the art was the widest thing on screen while
saying nothing.

The block is anchored left by `col = 6` (0-indexed). Leaving `col` nil makes
snacks centre the panes in the window, which on a wide Neovide window parks the
key list in the middle of the screen. `formats.header` and `formats.footer` are
restated as `align = "left"` for the same reason — both ship centred, and would
otherwise float off the left edge the keys establish.

`sections` restates snacks' own default list (header, keys, startup) to slot a
cwd line in after the header. That line has to be a **function** section
(`snacks.dashboard.Gen`, re-run per render); `preset.header` cannot carry it,
because `sections.header` renders that string through a `%s` format and so
freezes whatever the spec file held at load time.

## Syntax palette: yellow warm side, retuned 2026-09-09

**Settled, but no longer the frozen 2026-09-08 combination.** That freeze put
salmon on the warm side; it was replaced the next day. Apply the change gate
before reopening any colour. Open items are in
`todos/theme/syntax-palette-followups.md`.

**Live values are decided by `custom-latest` in
`lua/colorschemes/solarized-osaka/variants.lua`, not by this table and not by
comments in `palette.lua`.** That build is the authority; anything written down
elsewhere is a snapshot and drifts. To read the truth from a running editor:
`:lua =vim.api.nvim_get_hl(0,{name='@boolean',link=false})`

Verified live 2026-09-09:

| role | value | note |
| --- | --- | --- |
| body / `@variable` | `#a7b4b5` | `body.midpoint`; was `#b1bebf` until 2026-09-09 |
| brackets / delimiters / operators | `#7f9195` | the maximin grey rung; was `#96abd3` until 2026-09-09 |
| HTML/JSX/TSX/Vue tag wrappers | `#a7b4b5` | TRACKS body since 2026-09-09; was pinned to `base0` `#9eabac` |
| function / `@property` / `@function.builtin` | `#359ee9` | `@property` is unstyled and duplicates this |
| type | `#2ac3de` | |
| punctuation / parameter | `#baac0d` | the accent yellow; also `@attribute`, `@keyword.import`, `@string.escape` |
| **Go** `@variable.member` / `@property` | `#baac0d` | Go fields only, language-scoped in `init.lua` |
| every other `@variable.member` | `#29a298` | theme default, same as `@string`; the `member` role is `false` |
| boolean / `@constant` / `@number` | `#ed8e55` | `tokyonight_dim`; was amber `#d19c59` |
| keyword | `#a17bcc` | violet |
| comment | `#5f767d` | two stops below the AA value, by preference; upstream is `#576d74` |
| `@string` | `#29a298` | `@number` no longer shares it |

**ONE ACCENT HUE ON THE WARM SIDE.** This is the rule that keeps being broken.
The warm side is now one dominant hue (the yellow) plus one low-dose accent
(`boolean`). Splitting the warm field across three hues is what gets rejected on
sight, not the amount of warm ink: the 2026-09-08 census measured total warm ink
as *identical* (31.86% of `api.ts`) either way.

Salmon vs yellow, measured honestly: yellow is the better single value (7.20:1
vs 5.62:1, wider worst-neighbour), salmon carries 30% less chroma at the same
dose. Salmon ran for one day and was dropped, because a dedicated member colour
floods object-literal files in TS/JS. Yellow won on both counts in daily use.

Roles fixed on 2026-09-08/09, all previously falling through to an alarm red or a
duplicate: `@variable.member` (its paint line had been commented out, so the role
was a silent no-op), `@constant` + `@constant.macro`, `@attribute` (decorators
rendered in `#db302d`, **byte-identical to `DiagnosticError`**), `@string.escape`
(2.87:1, the lowest contrast in the palette), `@function.builtin` (builtin calls
were accent-coloured while user calls beside them were blue), and Terraform/HCL
attribute names (keys and values were one colour).

Still unstyled and duplicating another role: `@property` (= `Function`, which is
why YAML keys are function-blue).

Full role tables, candidate verdicts and measurements:
[`notes/palette-reference.md`](notes/palette-reference.md); deep archive in
[`notes/syntax-palette-decisions.md`](notes/syntax-palette-decisions.md);
follow-up history in
[`todos/theme/syntax-palette-followups.md`](todos/theme/syntax-palette-followups.md).

**All three are HISTORICAL.** They stop at the salmon build and each now carries
a banner saying so. Their reasoning and measurements still hold and are worth
reading; their "which value is live" claims do not. The table above is the only
reconciled snapshot, and a running editor is the only authority.

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

## NEXT SESSION STARTS HERE — deep config review (queued 2026-09-09)

**Read [`todos/deep-config-review.md`](todos/deep-config-review.md) and begin at
phase 0. Do not improvise a different approach; the plan exists because the last
attempt was too shallow.**

Context, so nothing needs re-explaining:

- On 2026-09-09 a **pattern sweep** was run over the config — grep for a fixed
  list of failure classes plus a startup measurement. It found nothing critical
  **within that scope**, but it covered only ~800 of 12,613 lines (~5%), never
  opened the four biggest live files, and did no correctness review at all. Its
  findings are in [`todos/config-audit-2026-09-09.md`](todos/config-audit-2026-09-09.md),
  which leads with its own scope caveat.
- The real review is **4 sessions, ~10,400 lines** after skipping what sits
  behind disable-gates. Per-file targets, the phase-0 baseline step, and the repo
  traps that produce confident wrong findings are all in the plan.
- Findings go to `todos/deep-config-review-findings.md`. **Findings, not fixes** —
  fixing is a separate agreed pass.
- Baselines already measured, do not re-derive: startup **~50 ms** headless
  (slowest entry `require('config.lazy')` at 23.7 ms); exactly one `<MouseMove>`
  handler, one `CursorMoved`/`CursorMovedI` pair, two `CursorHold`, and no
  `WinScrolled`/`TextChanged`/`InsertCharPre` outside disabled plugins.

Also outstanding, smaller: **`README.md` is stale** in six specific ways, listed
at the end of the sweep todo (four dead theme hexes, palette described as closed,
LSP debounce `300` vs the real `200`, `<C-k>` vs `<M-k>`, Copilot presented as
active and its subscription listed as a requirement).

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
