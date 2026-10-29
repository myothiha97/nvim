# Palette ideas for the 2026-12-31 checkpoint

One line per idea, nothing else (rules.md, "The palette is CLOSED"). Review in
the single 60-minute checkpoint session.

- 2026-09-24: revert the Visual selection band from the current violet-blue to the earlier grey / faded white (`hl.Visual` in `lua/colorschemes/solarized-osaka/init.lua`, see its "Selection band" comment).
- 2026-09-30: LSP hover popup code blocks (e.g. Lua signatures) use highlight colours that do not match the editor palette (`string` yellow, `nil` blue). Screenshot: ~/Pictures/screen-shorts/Screenshot 2026-09-30 at 13.30.09.png
- 2026-09-30: migrate from the custom solarized-osaka build to a custom onedark-based one (`lua/colorschemes/onedark.lua`, with variants like solarized-osaka's `variants.lua`). Why: onedark reads better in use, likely thanks to its matte dark background. Staying on solarized-osaka until then.
- 2026-09-30: compare `body.tinted` vs `body.brighter` for body text and file names on the current teal bg (commit 9a1702f moved to tinted "for eye comfort"); decide which to keep.
- 2026-10-01: full audit of the live palette (readability, eye comfort, token separation per language) against popular dark themes; not satisfied with the current result.
- 2026-10-07: markdown inline code (`` `foo` ``) shows yellow text on a faded blue bg and is hard to read; pick a more readable pair. Screenshot: `reference-images/2026-10-07-markdown-inline-code-highlight.png`
- 2026-10-13: Copilot ghost text in the syntax colours of the theme instead of flat grey (VS Code style). Full context: `todos/ai/cursor-tab-level-suggestions.md`.
- 2026-10-01: theme roadmap (the `todo:` block above `custom-latest` in `variants.lua`): re-sync the palette with the black matte background, rename the theme away from Solarized Osaka, and plan three variants (dark teal, dark black matte, then light). Goal is readability, symbol separation and long-session comfort, not just consistency.
- 2026-10-13: too much blue on screen (the `NOTE:` above `func` in `variants.lua` `custom-latest`): functions share one blue with many other elements; consider a distinct blue for functions. Live is `func.vivid`, `func.azure` is the second-best option.
- 2026-10-29: background candidate `#16181d` (VS Code One Dark Pro Darker override), measured against the live `#131312`. Small comfort and fit gain, no readability gain; must move with Ghostty and the completion menu. Findings: `background-16181d-candidate.md`.

- [ ] (2026-10-21) Function parameter colour: trialling `vscode_onedark_pro_darker_yellow_2` (#FAAC55) at `variants.lua:170`, by preference, no analysis. Reason: `keyword.brighter` felt faded/dark. The new hue sits between orange and yellow. Keep `_1` (#E8AF6F) as the softer option. Revisit only at the 2026-12-31 checkpoint.
  - Note: no real analysis has been done on these. The values at `palette.lua:44-46` were copy-pasted from the internet (VS Code One Dark Pro Darker). `_2` is applied at `variants.lua:170` on taste alone.
  - At the checkpoint, redo a deep analysis: are `_1` and `_2` really compatible with the active nvim theme? Their source is the One Dark Pro Darker theme (https://marketplace.visualstudio.com/items?itemName=zhuangtongfa.Material-theme).
