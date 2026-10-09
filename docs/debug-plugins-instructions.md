# Debug Plugin Instructions

## Copilot Suggestions Not Appearing

### Check state from normal mode

```vim
" Check the toggle (source of truth, default false at startup)
:lua =vim.g.copilot_enabled

" Check if copilot client is attached to current buffer
:lua =require("copilot.client").buf_is_attached(0)

" Check the per-buffer copy (synced from vim.g.copilot_enabled on BufEnter)
:lua =vim.b.copilot_suggestion_auto_trigger

" General health check
:checkhealth copilot

" View copilot logs for errors
:Copilot log
```

### Check / force from inside insert mode

```vim
" Temporarily map a key to manually fetch next suggestion
:lua vim.keymap.set("i", "<C-x><C-c>", require("copilot.suggestion").next)
```

### Turn suggestions on

`vim.g.copilot_enabled` is the single source of truth, and it starts as `false`.
A `BufEnter` autocmd in `lua/plugins/copilot.lua` copies it into
`vim.b.copilot_suggestion_auto_trigger` for every buffer.

To turn suggestions on, press `<leader>ad` or `<M-k>`. Do NOT call
`require("copilot.suggestion").toggle_auto_trigger()`: it only changes the
current buffer, and the next `BufEnter` overwrites it.

### Common causes

- Toggle is off (the default at startup) → press `<leader>ad` / `<M-k>`
- `buf_is_attached(0)` returns `false` → copilot never initialized for the buffer (loaded before buffer existed, or filetype excluded)
