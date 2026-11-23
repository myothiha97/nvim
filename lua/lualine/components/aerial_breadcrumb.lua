-- The aerial breadcrumb for the statusline (plugins/aerial.lua swaps it in).
--
-- Same as aerial's own lualine component, except hook rows show only the hook:
-- the aerial panel names them `useQuery { data, isFetching: loading }` (the
-- binding is dimmed there), but in a one-line breadcrumb the binding buries
-- where you are. The panel is untouched; only this component trims the name.
local Aerial = require("lualine.components.aerial")

local M = Aerial:extend()

function M:format_status(symbols, ...)
  local trimmed = {}
  for i, symbol in ipairs(symbols) do
    if symbol.kind == "Hook" then
      -- `useQuery { data }` -> `useQuery`; a bare `useEffect` is unchanged
      symbol = vim.tbl_extend("force", symbol, { name = symbol.name:match("^%S+") })
    end
    trimmed[i] = symbol
  end
  return M.super.format_status(self, trimmed, ...)
end

return M
