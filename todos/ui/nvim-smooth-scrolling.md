
# Nvim: Smooth Scrolling Improvement

## Goal
Improve scrolling smoothness to be closer to GUI editors like WebStorm, Zed, or VS Code — for mouse, trackpad, and keyboard navigation.

## Current State
Significant effort has already been made to smooth scrolling, but it still falls short of GUI editors.

## Requirements
- Must not cause performance regressions on large files or large projects.
- Must cover all three input methods: mouse wheel, trackpad gestures, keyboard (`<C-d>`, `<C-u>`, `j/k`, etc.).

## Research Directions
- Evaluate `neoscroll.nvim` configuration options more deeply.
- Check if `mousescroll` option tuning can help with trackpad inertia.
- Investigate terminal-level scroll frame rate as a limiting factor (e.g. `scrollback`, `smoothscroll` in Kitty/WezTerm).
- Profile whether any autocmd or plugin is triggering redraws during scroll.

## Findings 2026-10-23 (from snacks.nvim `lua/snacks/scroll.lua` source + this config)
- snacks.scroll deliberately SKIPS mouse-wheel scrolls (assumes the terminal smooths them) and any scroll of <= 1 line
  (`math.abs(topline delta) <= 1` -> skipped). That is why <C-e>/<C-y>/wheel never animated. Not fixable from a plugin;
  only a terminal-side change could (see ~/Desktop/projects/ghostty-pixel-scroll/PLAN.md).
- Suspects for the <C-u>/<C-b> stutter (untested hypotheses):
  1. `<C-u>zz` / `<C-b>zz` (keymaps.lua ~355/466): two view changes per key; near the top of a file `zz` can't
     centre, so the topline barely moves while the cursor jumps, and snacks only animates the topline delta.
  2. snacks moves the cursor every frame (`H` + `|`), so every CursorMoved handler runs ~15-30x per scroll
     (codecompanion tracker, git popup check, Trouble filter when open). Heavier in TSX buffers.
  3. Treesitter highlighting of the rows revealed at the top on each frame in large TSX files.
- 5-minute test in the batch session: set `scroll = { enabled = true }`, temporarily map <C-u>/<C-b> WITHOUT `zz`,
  run `:lua Snacks.scroll.debug()`, compare a small Lua file vs a large TSX file, then re-add `zz` and compare.
