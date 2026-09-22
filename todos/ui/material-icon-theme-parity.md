# Material Icon Theme parity for file/folder icons

Raised 2026-09-22, **deferred the same day by the user** ("which is huge so defer
it as future todo"). Reference the user pointed at: the VS Code extension
[PKief.material-icon-theme](https://marketplace.visualstudio.com/items?itemName=PKief.material-icon-theme).

Nothing was built. Only the **text colour** half of that session shipped (see
"Already done" below), which is what actually made the tree readable.

## The ask

Three parts, in the order they were raised:

1. Folder/file **names** were unreadable in the `<leader>r` tree: blue name next
   to a blue folder icon. **DONE, shipped 2026-09-22.**
2. Match the VS Code Material Icon Theme's **icons and icon colours**.
3. Put the icon mapping in a **dedicated folder** for file/folder icon themes,
   rather than inline in a plugin spec.

## Read this first — exact parity is not reachable in a terminal

VS Code draws each icon as an **SVG** it ships itself (~1,000 of them, arbitrary
size, multi-colour, at whatever pixel size the sidebar row gives it). Neovim
draws a **single font glyph in one terminal cell**, from whatever the Nerd Font
patch happens to contain. Material Icon Theme's artwork is not in any Nerd Font,
so "exactly like VS Code" cannot be delivered, only approximated.

What *is* reachable, and worth separating before any work starts:

- **The colour scheme — cheap and high value.** Material assigns a colour per
  filetype (and one folder colour), and that mapping is plain data in the
  extension's repo. This is the half that is portable, because it is independent
  of the glyph.
- **Closest-glyph mapping — expensive, low ceiling.** Hand-picking the nearest
  Nerd Font glyph per filetype. This runs straight into the measurements already
  taken in
  [`snacks-file-tree-icon-legibility.md`](snacks-file-tree-icon-legibility.md):
  in Maple Mono NF every icon glyph is squeezed to a single-cell advance, ink
  widths vary 4x, and a previous glyph-swap pass was **built and rejected on
  sight**. Read that file before touching glyphs. Its conclusion still holds:
  either normalise *every* glyph or leave them alone, and start with the Ghostty
  `font-codepoint-map` question, not with glyph tables.
- **One-colour-per-name (the VS Code look) may already be most of it.** After
  the text fix, the icon is the only thing carrying the file/folder distinction,
  which is the structure Material uses. Re-judge whether the icons still feel
  wrong *before* assuming they do.

## Research directions, none verified

- A devicons fork that ships the Material set (a `nvim-material-icon`-style drop-in
  for `nvim-tree/nvim-web-devicons`) may exist. **Not checked** whether one exists,
  is maintained, or works with the current devicons API. Verify before planning
  around it.
- Failing that: build the colour table from the extension's own JSON and feed it
  through `require("nvim-web-devicons").set_icon()` / the `override` option. Oil
  and the snacks explorer both resolve icons through devicons, so one table
  reaches both.
- Watch the fragment trap: oil's spec declares `nvim-web-devicons` as a
  dependency. Any new spec file for devicons must not define a second
  `config`/`init` — see the note in `CLAUDE.md` about lazy.nvim keeping only the
  last fragment.

## Where the dedicated folder should go

`lua/config/` holds non-plugin config modules. An icon theme is data plus one
apply function, so `lua/config/icons/` (a `material.lua` table plus an
`init.lua` that applies it) fits the existing layout. **Do not** create it until
part 2 is actually being built — an empty folder is worse than no folder.

## Second item from the same session, also deferred

**Brighten the name under the cursor**, the way VS Code brightens on hover and
on the active row. Recorded here because the finding is the expensive part:

- It **cannot be done with a highlight group.** `CursorLine`'s foreground only
  paints text that has no other foreground, and every name in the tree is
  painted by a snacks extmark, which wins. Setting a fg on
  `SnacksPickerListCursorLine` does nothing to the name.
- It **cannot be done in the `format` function** either. A snacks picker list
  only re-renders when it is `dirty`, and `list:_move` marks it dirty only if
  `top` changed, so moving the cursor between visible rows performs no render.
  (`snacks.nvim/lua/snacks/picker/core/list.lua`, `M:render` and `M:_move`.)
- So it needs its own `CursorMoved` handler on the list buffer, setting one
  higher-priority extmark over the name's byte range and clearing the previous
  one. That is a hot-path autocmd, which is why it was not done on the spot.
  Cost is small (one buffer-local autocmd, active only while the tree is open,
  over a buffer the height of the window), but it has to be measured, and it has
  to survive a re-render leaving a stale mark on a row that now means something
  else.

## Already done, 2026-09-22 — the text colour fix

Directory **names** now read as body text (`Normal`'s fg, #a0b6b8) instead of
`Directory` blue (#268bd3), which was the same blue family as the folder icon
beside it. Two places, same defect:

- `SnacksPickerDirectory` in `lua/plugins/snacks.lua` (`set_snacks_hl`)
- `OilDir` in `lua/plugins/oil.lua` (`set_oil_highlights`)

Two traps, both recorded in the code comments: `fg` only, never
`link = "Normal"` (a link drags Normal's background over the cursor row and the
active-file band); and oil links `OilDirIcon` -> `OilDir`, so the icon has to be
pinned to the blue **first** or greying the name greys the icon with it and the
listing loses its only file/folder cue.

## Gate

Part 1 shipped as a legibility fix in a daily-use panel. Parts 2 and 3 are
aesthetic polish inside the freeze window, deferred by the change-gate at the
user's own instruction. Do not reopen before the next freeze checkpoint
(~2026-10-20).
