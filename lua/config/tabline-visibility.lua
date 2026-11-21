-- Whether a tabline is drawn at the top. The statusline hides the filename
-- while one is (bufferline already shows it) and shows it otherwise.
--
-- bufferline drives `showtabline` itself (0 or 2, see its toggle_bufferline);
-- with bufferline off, Neovim's native tabline uses 1: only with 2+ tab pages.
-- Option reads only, cheap enough for lualine's throttled refresh.
local M = {}

function M.hidden()
  local show = vim.o.showtabline
  return show == 0 or (show == 1 and vim.fn.tabpagenr("$") == 1)
end

return M
