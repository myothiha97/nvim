# Comments: Drop the Italic

## Status

Open. Filed 2026-10-07, inside the freeze window (running to 2026-12-31). Nothing
was applied to the config. Deferred because the palette is closed (`rules.md`),
and that includes highlight styles.

## The Idea

Comments are dim and italic, a double de-emphasis that reads poorly in long,
documentation-style comment blocks. Remove the italic and keep the colour.

Likely change: `styles.comments = { italic = false }` in the theme setup in
`lua/colorschemes/solarized-osaka/init.lua`.

## Related

Same idea as E6 option 1 in [`theme-enhancements.md`](theme-enhancements.md).
Decide them together at the checkpoint.
