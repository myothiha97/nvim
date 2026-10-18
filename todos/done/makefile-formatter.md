# Makefile formatter (conform `bake`)

Done 2026-10-18, on request: Makefiles are now edited often. Before this,
saving a Makefile ran nothing (`formatters_by_ft` had no `make` entry and no
LSP covers it), so recipe lines typed without a tab stayed that way and
`make` failed with `missing separator`.

What changed, in `lua/plugins/formatting.lua`:

- `make = { "bake" }`: conform's built-in `bake` formatter, which runs `mbake`.
- `mbake` added to Mason's `ensure_installed`.

Measured:

- Unindented recipe lines get a tab on save; a correctly formatted Makefile
  is left byte-identical. Verified in a real nvim on an isolated tmux server;
  the same test showed no change before the fix.
- About 120 ms per save, Makefiles only (Python startup). Editor startup
  unchanged (0.07 s headless, before and after).
- Go format-on-save unchanged.

Undo: remove the two lines and `:MasonUninstall mbake`.
