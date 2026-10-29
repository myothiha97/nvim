# Freeze-override trace — 2026-10-29 teal UI surfaces

Required by rule 10 in [`discipline-stop-rules.md`](../process/discipline-stop-rules.md).

**The change:** UI surfaces still painted from the theme's teal ramp (`base02`,
`base03`, `base04`, `bg_popup`) move to neutral values derived from `ui.bg`, and the
completion menu and its doc window follow `ui.bg` instead of a fixed value.

**Why it did not wait:** the teal background was retired, so these are leftovers
from it, not a colour choice: they render as teal bands on the black matte
background. The visible trigger was the completion doc popup (teal background,
`palette.type` border). Found while measuring the `#16181d` candidate
([`../theme/background-16181d-candidate.md`](../theme/background-16181d-candidate.md)).
Overridden knowingly ("Fix now") after the closed-palette rule was quoted. Scope:
UI surfaces only, no syntax colours.

**What moved:** `config/ui.lua` gains `surface` (panel, raised, selection,
active_file), each lifted from `bg` toward white. `on_colors` points the theme's
base04/base03/base02, `bg_popup` and `bg_highlight` at them, which clears 38 teal
groups at once. The completion menu and its doc window both sit on `c.bg` with a
`base02` border. `FloatBorder` and the explorer's active-file band are neutral
too. Left on purpose: `DiffAdd` / `@diff.plus` (`cyan900`), a diff colour, not a
surface.

**Scope wobbled once:** narrowed to the doc popup alone, then restored the same
session because the full pass keeps the other UI in step with the background.

**Scope grew once, same session:** the list cursor band (`ListCursorLine`,
violet `#3b4261`, used by the picker, explorer and outline) and the explorer tree
lines (`SnacksPickerTree`, which snacks links to the teal-grey `LineNr`) moved to
`surface.list_cursor` and `surface.guide`; `SnacksIndent` shares the guide value.
The cursor band was then darkened to `lift 0.18` and the active-file band to
`lift 0.10`, so it stays ~8 L* below the cursor
band now that neither has a hue to separate them.

**Selected row, final:** after a side-by-side of old and new screenshots, every
selected row (picker, explorer, outline, completion menu, `PmenuSel`, Oil) moved
to one muted slate, `surface.list_cursor = "#383c4a"`. Plain grey `#3d3d3d` was
calmer but only dE00 13.2 from the background and 5.9 from the active-file band;
the old violet was dE00 21.5 but cost text contrast (body 5.14:1). The slate gives
15.6 and 10.3 with body at 5.74:1.

**Active-file band, final:** `surface.active_file = "#312f2b"`, a soft warm taupe.
Plain `#2b2b2a` was too faint (dE00 7.4 from bg); lighter greys raised that but
slid toward the slate cursor row (9.0). The warm tint gives 11.1 from bg and 13.5
from the slate, but read too heavy on screen; halving the tint to `#312f2b` gives
9.0 from bg, 11.5 from the slate and a 6 L* gap below it.

`QuickFixLine` (theme blue `#1a6397`) joined the slate selected-row colour the
same session, keeping its bold, and `WildMenu` with it.
