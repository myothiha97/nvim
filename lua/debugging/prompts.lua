-- Floating prompts for breakpoint details.
--
-- Replaces `vim.fn.input`, which used the cmdline and returned "" on <Esc>, so
-- cancelling still created a breakpoint. `vim.ui.input` is routed to snacks'
-- floating input by LazyVim. Cancel (<Esc>) does nothing.

local M = {}

---@param opts {prompt: string, default?: string}
---@param on_confirm fun(value: string) called only when not cancelled; value is trimmed
function M.input(opts, on_confirm)
  vim.ui.input({ prompt = opts.prompt .. ": ", default = opts.default }, function(value)
    if value == nil then
      return
    end
    on_confirm(vim.trim(value))
  end)
end

-- Existing breakpoint on the cursor line, if any.
local function current_bp()
  local bufnr = vim.api.nvim_get_current_buf()
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  for _, bp in ipairs(require("dap.breakpoints").get(bufnr)[bufnr] or {}) do
    if bp.line == lnum then
      return bp
    end
  end
end

-- Set one property of the breakpoint on the cursor line, keeping the others.
-- An empty answer clears that property (the breakpoint stays).
local function edit(field, prompt)
  return function()
    local bp = current_bp() or {}
    M.input({ prompt = prompt, default = bp[field] }, function(value)
      local next_bp = {
        condition = bp.condition,
        hitCondition = bp.hitCondition,
        logMessage = bp.logMessage,
      }
      next_bp[field] = value ~= "" and value or nil
      require("dap").set_breakpoint(next_bp.condition, next_bp.hitCondition, next_bp.logMessage)
      require("debugging.breakpoints").save()
    end)
  end
end

M.condition = edit("condition", "Breakpoint condition")
M.hit_condition = edit("hitCondition", "Hit condition (e.g. > 5)")
M.log_point = edit("logMessage", "Log message ({expr} interpolates)")

return M
