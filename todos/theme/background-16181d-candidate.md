# Background candidate: `#16181d` (VS Code One Dark Pro Darker, customised)

- **Created:** 2026-10-29
- **Status:** Deferred to the 2026-12-31 checkpoint. Live stays `#131312`.
- **Saved as:** `reference.one_dark_pro_vscode.darker_custom` in `lua/config/ui.lua`
- **Source:** VS Code `settings.json` overrides One Dark Pro Darker's `editor.background`
  (`#23272e`) to `#16181d`, with `#131519` for sidebar, tabs, panel and status bar.

## Verdict (2026-10-29)

A small upgrade at best, and only if every surface moves together. Not worth doing
inside the freeze.

- **Readability: no gain.** Every text colour scores exactly 0.5 APCA Lc higher on
  `#131312`, about 1/30 of a visible step. No colour crosses a threshold on either
  background, in any language measured.
- **Eye comfort: slight gain for `#16181d`.** Lighter (L\* 8.2 vs 5.9), so less glow
  around bright text. Matters most for Claude Code in Ghostty, which prints pure
  white text at Lc ~107.
- **Fit: `#16181d`.** The live syntax colours are One Dark style, and One Dark was
  designed on a blue-grey background. `#16181d` is that family (hue 277, C\* 3.9);
  `#131312` is warm neutral (hue 110, C\* 0.6). Warm syntax (yellow types, green
  strings, escapes) separates more on `#16181d`; cool syntax (violet keywords, blue
  functions) separates more on `#131312`. The largest single gap is the keyword:
  dE00 48.3 on `#131312` vs 44.5.

## Per language

Glyph census over real files: Go, TS, TSX, JS, JSX, Lua, Bash, Python, Rust and C.
The share of ink below Lc 45 is identical on both backgrounds in every file, so no
language changes the verdict. C++ and C# were not measured, because their
tree-sitter parsers (`cpp`, `c_sharp`) are not installed.

## If adopted at the checkpoint, move all of these together

Changing one piece alone is a downgrade (a lighter box inside a darker frame).

1. `bg` in `lua/config/ui.lua`.
2. Ghostty `background` (currently `#131312`).
3. `BlinkCmpMenu` / `BlinkCmpMenuBorder` in `lua/colorschemes/solarized-osaka/init.lua`,
   which hardcode `second_darkest` instead of following `bg`.
4. Optional: the status line matte greys (`status_line` in `ui.lua`) are warm and
   were tuned for `#131312`.

## Found during the analysis, true for either background

- Comments (`#5f767d`) score Lc ~27, the weakest text, and are 34-65% of ink in
  Bash, Lua, Go and Rust files. This affects reading more than the background does.
- `LineNr` (`#3d555b`) scores Lc 13.5, below the APCA floor for non-text UI.
- The UI surfaces are still the old Solarized teal (`StatusLine #002c38`,
  `#063540` on PmenuSel / ColorColumn / TabLineFill / WinSeparator / picker border,
  `Pmenu #001419`, `FloatBorder #103a3c`), tuned for `#001014`. They read as teal
  bands on both candidates.
- Claude Code's `dark` theme hint grey (`#505050`) scores Lc ~13 on both; only the
  `dark-ansi` theme would let Ghostty's palette control it.
