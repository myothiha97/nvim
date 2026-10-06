if not vim.g.neovide then
  return
end

-- vim.o.guifont = "Liga SFMono Nerd Font:h14"
-- SF Mono has no Nerd Font icons, so Maple Mono NF fills in the missing glyphs
vim.o.guifont = "SF Mono,Maple Mono NF:h14"
vim.g.neovide_cursor_vfx_mode = ""
vim.g.neovide_cursor_animation_length = 0
vim.g.neovide_cursor_trail_size = 0

-- Window transparency (matches Ghostty's background-opacity = 0.93)
-- vim.g.neovide_transparency = 0.93

-- Enable macOS Cmd key (<D->) mappings in Neovide
vim.g.neovide_input_use_logo = true

-- Force fresh clipboard reads from OS (don't cache between app switches)
vim.g.clipboard = {
  name = "macOS-clipboard",
  copy = { ["+"] = "pbcopy", ["*"] = "pbcopy" },
  paste = { ["+"] = "pbpaste", ["*"] = "pbpaste" },
  cache_enabled = 0,
}

-- Pane resize with Cmd+arrow (mirrors Ghostty behavior)
vim.keymap.set("n", "<D-Up>", "<cmd>resize +2<cr>", { desc = "Increase Window Height" })
vim.keymap.set("n", "<D-Down>", "<cmd>resize -2<cr>", { desc = "Decrease Window Height" })
vim.keymap.set("n", "<D-Left>", "<cmd>vertical resize -2<cr>", { desc = "Decrease Window Width" })
vim.keymap.set("n", "<D-Right>", "<cmd>vertical resize +2<cr>", { desc = "Increase Window Width" })

-- Cmd+I: signature help (Ghostty sends this as <M-i>)
vim.keymap.set({ "i", "n" }, "<D-i>", vim.lsp.buf.signature_help, { desc = "Signature Help" })

-- Cmd+F: highlight word under cursor (Ghostty sends this as <M-f>)
vim.keymap.set("n", "<D-f>", "*N", { desc = "Highlight word under cursor" })

-- Cmd+/: toggle comment (Ghostty sends this as <M-/>)
vim.keymap.set("n", "<D-/>", "<cmd>normal gcc<CR>", { desc = "Toggle comment line" })
vim.keymap.set("v", "<D-/>", "<Esc>:normal gvgc<CR>", { desc = "Toggle comment block" })

-- Cmd+D: multi-cursor add next occurrence (Ghostty sends this as <M-d>)
vim.keymap.set("n", "<D-d>", "<Plug>(VM-Find-Under)", { desc = "Multi-cursor: add next" })
vim.keymap.set("v", "<D-d>", "<Plug>(VM-Find-Subword-Under)", { desc = "Multi-cursor: add next" })

-- Cmd+K: toggle Copilot suggestions in insert mode (Ghostty sends this as <M-k>).
-- Forwards to the <M-k> handler in plugins/copilot.lua rather than duplicating the
-- toggle, which lives in that file's config closure and is not exported.
--
-- The forward is CHECKED AT PRESS TIME, not registered conditionally. copilot.lua
-- loads on InsertEnter, long after this file runs, so a load-time check would
-- always see the mapping missing. Checking here also means the key starts working
-- again by itself if copilot is re-enabled -- it is `enabled = false` while the
-- subscription is inactive, and without this guard `remap = true` fell through to
-- an unmapped <M-k> and inserted a stray character instead of toggling.
--
-- The DICT form of `maparg` is the documented existence check. The string form
-- happens to work too -- it renders a Lua callback as "<Lua 414>", measured, so it
-- is non-empty -- but that is how Neovim stringifies a callback, not a contract.
vim.keymap.set("i", "<D-k>", function()
  if not vim.tbl_isempty(vim.fn.maparg("<M-k>", "i", false, true)) then
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<M-k>", true, true, true), "m", false)
  end
end, { desc = "Copilot: Toggle Suggestions" })

-- Clipboard: copy/paste with system clipboard
vim.keymap.set({ "n", "v" }, "<D-c>", '"+y', { desc = "Copy to clipboard" })
vim.keymap.set({ "n", "v" }, "<D-y>", '"+y', { desc = "Copy to clipboard" })
vim.keymap.set("n", "<D-v>", '"+p', { desc = "Paste from clipboard" })
vim.keymap.set("v", "<D-v>", '"+p', { desc = "Paste from clipboard" })
vim.keymap.set("i", "<D-v>", "<C-r>+", { desc = "Paste from clipboard" })
