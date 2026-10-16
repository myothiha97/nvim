# VS Code-style scrollbar in Neovim

Logged 2026-10-16. Not started. Preference, so it waits for the freeze
checkpoint (`rules.md`).

## First priority: safety before the feature

These come before the scrollbar itself. If any one fails, the plugin is not
adopted:

- **Performance and smoothness:** no lag, stutter or flicker in typing,
  scrolling, window switching or redraws, including large files.
- **No impact on the current config:** every existing feature, key, popup and
  highlight works exactly as before.
- **Extend only:** it adds the scrollbar and nothing else. It must not change
  or replace any current behaviour.

## Objectives

- a scrollbar on the right of each window in terminal Neovim, like VS Code
- ideally with marks on it: diagnostics, git changes, search matches

## Known

- Neovim has no built-in scrollbar, so this needs a plugin. Candidates:
  `lewis6991/satellite.nvim` (marks for diagnostics, git, search) and
  `dstein64/nvim-scrollview` (bar plus signs).
- A plugin draws it as floating windows, so it also shows in Neovide. Side
  note: Neovide itself has no scrollbar option (0.16.2); the
  `neovide_scrollbar_*` lines tried in `lua/config/neovide.lua` did nothing
  and are commented out.

## Cost to measure before adopting

- Both redraw on scroll and window changes. The config has NO `WinScrolled`
  handler today (baseline in `CLAUDE.md`), so this adds the first one to a hot
  path. Check large files and scrolling smoothness, and read
  [`nvim-smooth-scrolling.md`](nvim-smooth-scrolling.md) first: it must not
  regress.
