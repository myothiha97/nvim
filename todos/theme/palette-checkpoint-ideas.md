# Palette ideas for the 2026-12-31 checkpoint

One line per idea, nothing else (rules.md, "The palette is CLOSED"). Review in
the single 60-minute checkpoint session.

- 2026-09-24: revert the Visual selection band from the current violet-blue to the earlier grey / faded white (`hl.Visual` in `lua/colorschemes/solarized-osaka/init.lua`, see its "Selection band" comment).
- 2026-09-30: LSP hover popup code blocks (e.g. Lua signatures) use highlight colours that do not match the editor palette (`string` yellow, `nil` blue). Screenshot: ~/Pictures/screen-shorts/Screenshot 2026-09-30 at 13.30.09.png
- 2026-09-30: migrate from the custom solarized-osaka build to a custom onedark-based one (`lua/colorschemes/onedark.lua`, with variants like solarized-osaka's `variants.lua`). Why: onedark reads better in use, likely thanks to its matte dark background. Staying on solarized-osaka until then.
- 2026-09-30: compare `body.tinted` vs `body.brighter` for body text and file names on the current teal bg (commit 9a1702f moved to tinted "for eye comfort"); decide which to keep.
- 2026-10-01: full audit of the live palette (readability, eye comfort, token separation per language) against popular dark themes; not satisfied with the current result.
