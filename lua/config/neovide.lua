if not vim.g.neovide then
  return
end

-- Matches Ghostty (dotfiles ghostty/config: JetBrains Mono, font-size 14.2,
-- adjust-cell-height 35%) on the 4K monitor at 2x. Ghostty sizes fonts by the
-- display's real density, so its 14.2 renders like 13.33 here: 16 x 47 physical-px
-- cells, a 239x44 grid. Neovide sizes in macOS points, so 14.2 drew ~6% larger.
-- Measured 2026-11-19: h13.33 gives 16px cells; rows are the font height rounded
-- up (36px) plus `linespace` in PHYSICAL px, so 11 gives 47. Grid: 240x44.
-- Will not match on another display density (e.g. the built-in Retina screen).
-- Ghostty draws Nerd Font icons from a built-in copy; Neovide needs the fallback.
vim.o.guifont = "JetBrains Mono,JetBrainsMono Nerd Font:h13.33"
vim.o.linespace = 11
vim.g.neovide_cursor_vfx_mode = ""
vim.g.neovide_cursor_animation_length = 0
vim.g.neovide_cursor_trail_size = 0
-- Short cursor moves (a character or a line) animate separately, default 0.04s.
vim.g.neovide_cursor_short_animation_length = 0
-- Scroll animation, in seconds, for EVERY scroll: <C-e>/<C-y>, <C-d>/<C-u>, the
-- mouse wheel, gg/G, zz and search jumps. Neovide's default 0.3 made held keys lag
-- behind. 0.12 is close to VS Code's smooth scrolling (~125 ms). Long jumps stay
-- quick on their own: `neovide_scroll_animation_far_lines` (default 1) animates
-- only the last line. snacks.scroll is off (plugins/snacks.lua), so nothing
-- stacks a second animation on top.
vim.g.neovide_scroll_animation_length = 0.12
-- Splits and floats slide when they open, move or resize (default 0.15s). Off, as
-- in Ghostty and VS Code.
vim.g.neovide_position_animation_length = 0

-- See-through editor background, like Ghostty's `background-opacity = 0.9` and
-- `background-blur`. Needs a solid `Normal` background to apply to, which is why
-- the theme turns transparency off in Neovide (TRANSPARENT in
-- colorschemes/solarized-osaka/init.lua): with no background colour Neovide draws
-- black. Only `Normal` is see-through; floats stay solid, as in Ghostty.
vim.g.neovide_normal_opacity = 0.9
vim.g.neovide_window_blurred = true

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

-- Scrollbar: DISABLED, does nothing. Neovide 0.16.2 has no scrollbar option
-- (checked 2026-10-16: "scrollbar" is not in its binary), and it ignores
-- `guioptions`. A scrollbar needs a plugin instead; see
-- todos/ui/vscode-style-scrollbar.md.
-- vim.g.neovide_scrollbar_enabled = true
-- vim.g.neovide_scrollbar_mode = "scroll"
-- vim.opt.guioptions:append("r")

-- Cmd keys that Ghostty turns into Meta keys (its `esc:` keybinds), sent on to the
-- same <M-> mapping so each works in Neovide too, without duplicating the handler.
--
-- The forward is CHECKED AT PRESS TIME, not registered conditionally. Some targets
-- load late (copilot.lua on InsertEnter, vim-visual-multi's buffer-local maps only
-- while it is active), so a load-time check would see them missing. Checking at
-- press time also means a key starts working again by itself if copilot is
-- re-enabled -- it is `enabled = false` while the subscription is inactive, and a
-- plain `remap = true` fell through to an unmapped <M-k> and inserted a stray
-- character instead of toggling.
--
-- The DICT form of `maparg` is the documented existence check. The string form
-- happens to work too -- it renders a Lua callback as "<Lua 414>", measured, so it
-- is non-empty -- but that is how Neovim stringifies a callback, not a contract.
local function forward_cmd_key(mode, cmd_key, meta_key, desc)
  vim.keymap.set(mode, cmd_key, function()
    if not vim.tbl_isempty(vim.fn.maparg(meta_key, mode, false, true)) then
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(meta_key, true, true, true), "m", false)
    end
  end, { desc = desc })
end

-- Cmd+H/J/K/L: window moves in normal mode (config/keymaps.lua). In insert mode
-- they land on the <Nop> maps there, and Cmd+K/L on Copilot's toggle/accept line.
for _, key in ipairs({ "h", "j", "k", "l" }) do
  forward_cmd_key("n", "<D-" .. key .. ">", "<M-" .. key .. ">", "Go to window (Cmd+" .. key:upper() .. ")")
end
forward_cmd_key("i", "<D-h>", "<M-h>", "Nothing (Cmd+H is a window move)")
forward_cmd_key("i", "<D-j>", "<M-j>", "Nothing (Cmd+J is a window move)")
forward_cmd_key("i", "<D-k>", "<M-k>", "Copilot: Toggle Suggestions")
forward_cmd_key("i", "<D-l>", "<M-l>", "Copilot: Accept Line")
forward_cmd_key("i", "<D-w>", "<M-w>", "Copilot: Accept Word")
forward_cmd_key("i", "<D-]>", "<M-]>", "Copilot: Next Suggestion")
forward_cmd_key("i", "<D-[>", "<M-[>", "Copilot: Prev Suggestion")
-- vim-visual-multi (plugins/vim-visual-multi.lua)
forward_cmd_key("n", "<D-L>", "<M-L>", "Multi-cursor: select all")
forward_cmd_key("n", "<D-]>", "<M-]>", "Multi-cursor: skip region")

-- Clipboard: copy/paste with system clipboard
vim.keymap.set({ "n", "v" }, "<D-c>", '"+y', { desc = "Copy to clipboard" })
vim.keymap.set({ "n", "v" }, "<D-y>", '"+y', { desc = "Copy to clipboard" })
vim.keymap.set("n", "<D-v>", '"+p', { desc = "Paste from clipboard" })
vim.keymap.set("v", "<D-v>", '"+p', { desc = "Paste from clipboard" })
vim.keymap.set("i", "<D-v>", "<C-r>+", { desc = "Paste from clipboard" })
