-- Right-click menu: debug entries for the clicked line, at most 5 at a time.
--
-- 'mousemodel' is popup_setpos (config/options.lua), so the cursor is already
-- on the clicked line and word when these run.
--
--   stopped in a session -> Run to Cursor · Evaluate · Add to Watches
--   line has breakpoint  -> Edit Condition… · Edit Log Message… · Remove Breakpoint
--   line has none        -> Add Conditional Breakpoint… · Add Log Point…
--   Go test file, idle   -> Debug Test
--
-- The entries are defined once. On each right-click a MenuPopup autocmd
-- enables the ones that apply and disables the rest; Neovim's popup menu
-- hides disabled entries (popupmenu.c), the same way runtime defaults.lua
-- handles "Go to definition". Only the separator is added/removed, because
-- separators are always shown.
--
-- Cost: one autocmd per right-click, ~12 :menu commands. Nothing on mouse
-- moves or keystrokes. nvim-dap is not loaded by a right-click.
--
-- Hit count and function breakpoints stay on <leader>dH / <leader>dF.
-- There is no "Disable breakpoint": nvim-dap has no disabled state.

local M = {}

local MAX = 5
local SEP = [[PopUp.-debugging-]]

local function expr()
  local mode = vim.fn.mode()
  if mode == "v" or mode == "V" or mode == "\22" then
    return table.concat(vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), { type = mode }), "\n")
  end
  return vim.fn.expand("<cexpr>")
end

local function stopped_session()
  if not package.loaded["dap"] then
    return nil
  end
  local s = require("dap").session()
  return s and s.stopped_thread_id and s or nil
end

local function has_bp()
  if not package.loaded["dap.breakpoints"] then
    return false -- no breakpoint can exist yet (see breakpoints.lua)
  end
  local buf, line = vim.api.nvim_get_current_buf(), vim.fn.line(".")
  for _, bp in ipairs(require("dap.breakpoints").get(buf)[buf] or {}) do
    if bp.line == line then
      return true
    end
  end
  return false
end

-- In menu order. `when(ctx)` decides visibility; `run()` is the action.
local ITEMS = {
  {
    label = "Run to Cursor",
    when = function(c)
      return c.stopped
    end,
    run = function()
      require("dap").run_to_cursor()
    end,
  },
  {
    label = "Evaluate",
    when = function(c)
      return c.stopped and c.expr
    end,
    run = function()
      require("dapui").eval(expr())
    end,
  },
  {
    label = "Add to Watches",
    when = function(c)
      return c.stopped and c.expr
    end,
    run = function()
      require("dapui").elements.watches.add(expr())
      require("debugging.layout").refresh_sidebar()
    end,
  },
  {
    label = "Edit Condition…",
    when = function(c)
      return c.bp
    end,
    run = function()
      require("debugging.prompts").condition()
    end,
  },
  {
    label = "Edit Log Message…",
    when = function(c)
      return c.bp
    end,
    run = function()
      require("debugging.prompts").log_point()
    end,
  },
  {
    label = "Remove Breakpoint",
    when = function(c)
      return c.bp
    end,
    run = function()
      require("debugging.breakpoints").toggle(vim.api.nvim_get_current_buf(), vim.fn.line("."))
    end,
  },
  {
    label = "Add Conditional Breakpoint…",
    when = function(c)
      return not c.bp
    end,
    run = function()
      require("debugging.prompts").condition()
    end,
  },
  {
    label = "Add Log Point…",
    when = function(c)
      return not c.bp
    end,
    run = function()
      require("debugging.prompts").log_point()
    end,
  },
  {
    label = "Debug Test",
    when = function(c)
      return c.idle and vim.api.nvim_buf_get_name(0):match("_test%.go$") ~= nil
    end,
    run = function()
      require("dap-go").debug_test()
    end,
  },
}

local function path(item)
  return "PopUp." .. item.label:gsub(" ", "\\ ")
end

function M.run(i)
  ITEMS[i].run()
end

local function on_popup()
  for _, item in ipairs(ITEMS) do
    vim.cmd("amenu disable " .. path(item))
  end
  pcall(vim.cmd, "aunmenu " .. SEP)

  if vim.bo.buftype ~= "" then
    return -- panels, terminals, pickers: no debug entries
  end
  local e = expr()
  local s = stopped_session()
  local ctx = {
    stopped = s ~= nil,
    idle = not (package.loaded["dap"] and require("dap").session()),
    bp = has_bp(),
    expr = e ~= "" and e:match("^%s*$") == nil,
  }
  local shown = 0
  for _, item in ipairs(ITEMS) do
    if shown < MAX and item.when(ctx) then
      vim.cmd("amenu enable " .. path(item))
      shown = shown + 1
    end
  end
  if shown > 0 then
    -- Same priority as the last item; Neovim inserts after equal priorities,
    -- so it lands below our entries and above the LSP ones (1.10).
    vim.cmd(("anoremenu 1.%d %s <Nop>"):format(#ITEMS, SEP))
  end
end

function M.setup()
  -- Priorities 1.1..1.9 sort above the LSP entries at 1.10+ in options.lua.
  -- Keep #ITEMS <= 9 or they interleave with those.
  for i, item in ipairs(ITEMS) do
    vim.cmd(("anoremenu 1.%d %s <Cmd>lua require('debugging.menu').run(%d)<CR>"):format(i, path(item), i))
  end
  local group = vim.api.nvim_create_augroup("debugging_menu", { clear = true })
  vim.api.nvim_create_autocmd("MenuPopup", { group = group, callback = on_popup })
end

return M
