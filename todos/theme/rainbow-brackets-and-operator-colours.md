# Rainbow brackets and operator colours

Status: open. Review at the 2026-12-31 checkpoint. Nothing here is live.

## Main goal

Better readability. Every choice here (bracket colours, operator colours, plugin or not) is judged by whether code becomes easier to read, not by looks.

## Problem

- All bracket pairs share one grey (`delimiter.mid_high`), so nesting is hard to read.
- Operators (`=`, `==`, `===`, `>=`, `<=`, `>`, `<`, `+`, `-`, `/`, `*`, `&`, `->`, `<-`, `.`) use the same grey.

## Trial result (2026-10-21)

`lua/plugins/rainbow-delimiters.lua` (HiPhish/rainbow-delimiters.nvim, untracked, not committed) was tried:

- Works: Lua, Go, Python.
- Broken: JSX and TSX.

## Work needed

- Make rainbow-delimiters work in JSX/TSX (check the tsx/javascript queries and the tag `<` `>` handling).
- Goal: VS Code style, a different colour per nesting level (yellow, purple, blue, then repeat). This is intended to be multi-hue, so the one-accent-hue rule in `CLAUDE.md` does not apply to brackets. Keep the levels distinct from the syntax colours.
- First analyze, check and verify whether the plugin's default `RainbowDelimiter*` colours are good enough and match the active theme (contrast against the background, distance from syntax colours, readability on nested code). Only define custom colours if they do not.
- Pick a separate colour for operators and punctuation.
- Measure before judging (see the palette notes).

## Blocked by

Palette is closed until 2026-12-31 (`rules.md`). Collect only.
