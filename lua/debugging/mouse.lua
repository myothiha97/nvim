-- Mouse: click the gutter to toggle a breakpoint (VS Code / GoLand style),
-- without moving the cursor or changing the focused window.
--
-- Why a <LeftMouse> mapping and not the statuscolumn's own %@ click handler:
-- Neovim moves the cursor to the clicked line (jump_to_mouse in mouse.c)
-- BEFORE it calls a statuscolumn click function, so a handler can't keep the
-- cursor where it was. The mapping sees the click first.
--
--   gutter layout:  [mark/sign 2][line number][fold/git 2]
--   left-click on sign area or line number -> toggle breakpoint, cursor stays
--   double/triple-click there               -> swallowed (no add+remove, no jump)
--   left-click on the fold cells (right 2)  -> default (fold), as before
--   anywhere else                           -> default <LeftMouse>
--
-- Cost: one getmousepos() + getwininfo() per click in normal mode. Nothing
-- runs on mouse moves or keystrokes. While an LSP hover popup is open,
-- config/mouse-hover.lua temporarily owns <LeftMouse>; a gutter click then
-- behaves like Neovim's default for that one click.

local M = {}

local FOLD_CELLS = 2

-- Returns buf, line when the mouse is on the breakpoint part of a file
-- buffer's gutter; nil otherwise.
local function gutter_target()
  local pos = vim.fn.getmousepos()
  local win = pos.winid
  if win == 0 or pos.line == 0 or not vim.api.nvim_win_is_valid(win) then
    return
  end
  if vim.api.nvim_win_get_config(win).relative ~= "" then
    return
  end
  local buf = vim.api.nvim_win_get_buf(win)
  if vim.bo[buf].buftype ~= "" then
    return
  end
  local textoff = vim.fn.getwininfo(win)[1].textoff
  if pos.wincol < 1 or pos.wincol > textoff - FOLD_CELLS then
    return
  end
  return buf, pos.line
end

local function passthrough(key)
  local codes = vim.api.nvim_replace_termcodes(key, true, true, true)
  return function()
    local buf, line = gutter_target()
    if not buf then
      vim.api.nvim_feedkeys(codes, "n", false)
      return
    end
    if key == "<LeftMouse>" then
      require("debugging.breakpoints").toggle(buf, line)
    end
  end
end

function M.setup()
  for _, key in ipairs({ "<LeftMouse>", "<2-LeftMouse>", "<3-LeftMouse>", "<4-LeftMouse>" }) do
    vim.keymap.set("n", key, passthrough(key), { desc = "Gutter click: toggle breakpoint" })
  end
end

return M
