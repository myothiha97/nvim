# Inline virtual text for ERROR diagnostics only

Requested 2026-10-22. **Done the same day by override**, see `../freeze/freeze-override-2026-10-22.md`. Reading an error message needs
`<leader>cd` today, because `virtual_text = false` in `lua/plugins/lsp.lua`.

Idea: show end-of-line text for errors only, keep warnings/hints as sign + underline:

```lua
virtual_text = { severity = vim.diagnostic.severity.ERROR },
```

Until then, `]e` / `[e` jump to the next/prev error and open its float (LazyVim
passes `float = true`), so no second key is needed.
