-- Breakpoint list in a snacks picker (<leader>dm file, <leader>dM project),
-- same look and size as <leader>xd / <leader>xD (diagnostics): file:line,
-- condition/hit/log note, the code line, live preview. <CR> jumps to the breakpoint.
--
-- Cost: built on demand when the key is pressed; nothing runs otherwise.

local M = {}

---@param scope "file"|"project"
function M.open(scope)
  local file = scope == "file"
  local items = require("debugging.breakpoints").list(file and vim.api.nvim_get_current_buf() or nil)
  if #items == 0 then
    vim.notify(file and "No breakpoints in this file" or "No breakpoints in this project", vim.log.levels.INFO)
    return
  end
  local size = require("config.picker-size").preview
  Snacks.picker.pick({
    title = file and "Breakpoints (current file)" or "Breakpoints (project)",
    items = items,
    format = "file",
    layout = { preview = true, layout = { width = size.width, height = size.height } },
  })
end

return M
