-- Mouse hover while stopped: show the variable's value (VS Code / GoLand).
--
-- config/mouse-hover.lua calls M.request() before its LSP request, only when
-- nvim-dap is already loaded. If no session is stopped, or the adapter can't
-- evaluate the word (keyword, package name, out of scope), it falls back to
-- the normal LSP hover.
--
-- Expression: the hovered word plus any `a.b.` chain to its left on the same
-- line, so hovering `count` in `cfg.limits.count` evaluates the whole path.
-- Context "hover" tells the adapter not to run side effects (Delve doesn't
-- call functions for it).
--
-- Cost: one DAP `evaluate` request per hover that already passed
-- mouse-hover's delay; nothing per mouse move. To dig into nested values use
-- right-click -> Evaluate (expandable dap-ui float).

local M = {}

local function stopped_session()
  local s = require("dap").session()
  if s and s.stopped_thread_id and s.current_frame then
    return s
  end
end

-- True when (row, col), 0-based, is on a name: variable, field, package,
-- type. Keywords, operators and literals (`for`, `:=`, `0`) are not. The
-- tree-sitter node there decides; without a parser, the character must start
-- a name. Also used by debugging/menu.lua (right-click, <leader>de).
function M.is_name(bufnr, row, col)
  local ok, node = pcall(vim.treesitter.get_node, { bufnr = bufnr, pos = { row, col } })
  if ok and node then
    local t = node:type()
    return t:find("identifier", 1, true) ~= nil or t == "self" or t == "this"
  end
  local text = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
  return text:sub(col + 1, col + 1):match("[%a_]") ~= nil
end

local function expression(text, s, e)
  while s > 2 and text:sub(s - 1, s - 1) == "." and text:sub(s - 2, s - 2):match("[%w_]") do
    s = s - 2
    while s > 1 and text:sub(s - 1, s - 1):match("[%w_]") do
      s = s - 1
    end
  end
  return text:sub(s, e)
end

---@param bufnr integer
---@param line integer 1-based
---@param s integer word start column (1-based, byte)
---@param e integer word end column
---@param on_result fun(lines: string[]|nil) nil = adapter couldn't evaluate; fall back
---@return boolean handled false when no session is stopped (caller does LSP now)
function M.request(bufnr, line, s, e, on_result)
  local session = stopped_session()
  if not session or not M.is_name(bufnr, line - 1, s - 1) then
    return false -- not stopped, or a keyword/operator/literal: LSP hover
  end
  local text = vim.api.nvim_buf_get_lines(bufnr, line - 1, line, false)[1] or ""
  local expr = expression(text, s, e)
  local ft = vim.bo[bufnr].filetype
  session:evaluate({ expression = expr, context = "hover" }, function(err, resp)
    vim.schedule(function()
      if err or not resp or not resp.result or resp.result == "" then
        on_result(nil)
        return
      end
      local typ = (resp.type and resp.type ~= "") and (" " .. resp.type) or ""
      -- Values can span lines (strings, some adapters' structs).
      local lines = vim.split(expr .. typ .. " = " .. resp.result, "\n", { plain = true })
      table.insert(lines, 1, "```" .. ft)
      table.insert(lines, "```")
      on_result(lines)
    end)
  end)
  return true
end

return M
