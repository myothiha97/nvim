# Palette ideas for the 2026-12-31 checkpoint

One line per idea, nothing else (rules.md, "The palette is CLOSED"). Review in
the single 60-minute checkpoint session.

- 2026-09-24: revert the Visual selection band from the current violet-blue to the earlier grey / faded white (`hl.Visual` in `lua/colorschemes/solarized-osaka/init.lua`, see its "Selection band" comment).
- 2026-09-30: LSP hover popup code blocks (e.g. Lua signatures) use highlight colours that do not match the editor palette (`string` yellow, `nil` blue). Screenshot: ~/Pictures/screen-shorts/Screenshot 2026-09-30 at 13.30.09.png
- 2026-09-30: migrate from the custom solarized-osaka build to a custom onedark-based one (`lua/colorschemes/onedark.lua`, with variants like solarized-osaka's `variants.lua`). Why: onedark reads better in use, likely thanks to its matte dark background. Staying on solarized-osaka until then.
