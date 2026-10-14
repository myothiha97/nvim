
# Markdown preview: browser choice and live updates

## Goal
Improve the browser markdown preview (`iamcco/markdown-preview.nvim`).

## Where
`lua/plugins/markdown-preview.lua`

## 1. Open the preview in a different browser
Render the preview in a different browser instead of the main one (Chrome is currently the default browser).

- Check `vim.g.mkdp_browser` (browser to open the preview in).
- Check `vim.g.mkdp_browserfunc` for a custom open function.

## 2. Live edit updates in the browser
Make the preview update live while editing, not only on save.

- Check `vim.g.mkdp_refresh_slow`: `0` refreshes while typing, `1` only on save or when leaving insert mode.
- Verify the current behaviour first, then change only if it does not already update live.
- Watch for lag on large documents (Mermaid, KaTeX) before keeping it on.
