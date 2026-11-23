# `o` / `<CR>` stall in big TS/TSX files: treesitter indent (F21)

Found 2026-11-23 (runtime perf E2E report).

- nvim-treesitter's `indentexpr` collects the indent captures of the **whole file**
  (`get_indents`, memoized per tree root), and every edit makes a new root. So the first
  `o`/`O`/`<CR>` after any edit walks the whole file.
- Measured: 11.5k-line TSX `o` = 150–170 ms (3/3 runs); 3.5k-line TS 52–107 ms; Python 81–161.
  Normal-size files are not affected noticeably.
- With Vim's own indent (`indentexpr` from `indent/typescript.vim`): worst TSX key 160 → 48 ms.
  JSX indentation rules differ, so it needs a real check before switching.
- Alternative: upstream issue/PR to limit the capture walk to a range around the line.
