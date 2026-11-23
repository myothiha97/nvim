# No breadcrumb / outline in files over 10,000 lines (F24)

Found 2026-11-23 (runtime perf E2E report). aerial's default `disable_max_lines = 10000`
silently skips bigger files: excalidraw `App.tsx` (11,501 lines) has an empty statusline
breadcrumb and an empty `<leader>cs`.

- Fix: `disable_max_lines = 20000` in `lua/plugins/aerial.lua`. Cost: aerial then builds
  symbols for those files too (on change, treesitter backend). Measure on the big file first.
