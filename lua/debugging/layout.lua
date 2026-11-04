-- When the debug panels open and close, and what is in them.
--
-- Minimal by default (see README.md):
--   * session starts   -> bottom tray only (REPL/output + control bar)
--   * first stop       -> left sidebar: Variables + Call Stack
--   * Watches          -> in the sidebar only while the watch list is non-empty
--   * Breakpoints      -> never in the layout; <leader>dp opens it as a float
--   * Terminal console -> joins the tray only when the adapter runs the program
--                         in a terminal (debugpy, codelldb...); Delve doesn't
--   * session ends     -> panels STAY, the bar shows the exit code + Run Again
--   * Stop with no session / <leader>du -> close everything
--
-- Layout indexes must match `layouts` in plugins/ui.lua.

local M = {}

M.SIDEBAR, M.SIDEBAR_WATCHES, M.TRAY, M.TRAY_CONSOLE = 1, 2, 3, 4

M.layouts = {
  [M.SIDEBAR] = {
    elements = { { id = "scopes", size = 0.6 }, { id = "stacks", size = 0.4 } },
    size = 46,
    position = "left",
  },
  [M.SIDEBAR_WATCHES] = {
    elements = {
      { id = "scopes", size = 0.45 },
      { id = "watches", size = 0.2 },
      { id = "stacks", size = 0.35 },
    },
    size = 46,
    position = "left",
  },
  [M.TRAY] = {
    elements = { { id = "repl", size = 1 } },
    size = 10,
    position = "bottom",
  },
  [M.TRAY_CONSOLE] = {
    elements = { { id = "repl", size = 0.5 }, { id = "console", size = 0.5 } },
    size = 10,
    position = "bottom",
  },
}

local state = {
  console = false, -- adapter asked for a terminal this session
  equalalways = nil, -- saved 'equalalways' while panels are open
}

local function layout_obj(i)
  return require("dapui.windows").layouts[i]
end

local function is_open(i)
  local l = layout_obj(i)
  return l ~= nil and l:is_open()
end

local function any_open()
  for i = 1, #M.layouts do
    if is_open(i) then
      return true
    end
  end
  return false
end

-- Opening a split with 'equalalways' on re-equalises every other window; that
-- is the "whole editor jumps" effect. Keep it off while panels are open.
local function hold_layout()
  if state.equalalways == nil then
    state.equalalways = vim.o.equalalways
    vim.o.equalalways = false
  end
end

local function release_layout()
  if state.equalalways ~= nil then
    vim.o.equalalways = state.equalalways
    state.equalalways = nil
  end
end

local function open(i)
  if is_open(i) then
    return
  end
  hold_layout()
  require("dapui").open({ layout = i })
end

local function close(i)
  if is_open(i) then
    require("dapui").close({ layout = i })
  end
end

local function has_watches()
  local ok, list = pcall(function()
    return require("dapui").elements.watches.get()
  end)
  return ok and type(list) == "table" and #list > 0
end

function M.sidebar_open()
  return is_open(M.SIDEBAR) or is_open(M.SIDEBAR_WATCHES)
end

function M.open_sidebar()
  local want = has_watches() and M.SIDEBAR_WATCHES or M.SIDEBAR
  local other = want == M.SIDEBAR and M.SIDEBAR_WATCHES or M.SIDEBAR
  close(other)
  open(want)
end

function M.open_tray()
  local want = state.console and M.TRAY_CONSOLE or M.TRAY
  local other = want == M.TRAY and M.TRAY_CONSOLE or M.TRAY
  close(other)
  open(want)
end

-- Swap the sidebar variant if the watch list became (non-)empty.
function M.refresh_sidebar()
  if M.sidebar_open() then
    M.open_sidebar()
  end
end

function M.close_all()
  for i = #M.layouts, 1, -1 do
    close(i)
  end
  release_layout()
end

function M.toggle()
  if any_open() then
    M.close_all()
  else
    M.open_tray()
    M.open_sidebar()
  end
end

-- Window titles + one hint each. Sidebar windows keep their width and the
-- tray its height when other splits open or close.
local TITLES = {
  dapui_scopes = { "VARIABLES", "dbl-click expand · e edit" },
  dapui_stacks = { "CALL STACK", "click expand/open · t internals" },
  dapui_watches = { "WATCHES", "i add · e edit · d remove" },
  dapui_breakpoints = { "BREAKPOINTS", "o open · t enable/disable · d remove" },
  dapui_console = { "TERMINAL", "" },
}

local function decorate(win, buf)
  local ft = vim.bo[buf].filetype
  local title = TITLES[ft]
  if title and vim.api.nvim_win_get_config(win).relative == "" then
    vim.wo[win].winbar = ("%%#Title# %s %%#Comment# %s"):format(title[1], title[2])
  end
  if ft == "dapui_scopes" or ft == "dapui_stacks" or ft == "dapui_watches" then
    vim.wo[win].winfixwidth = true
  elseif ft == "dap-repl" or ft == "dapui_console" then
    vim.wo[win].winfixheight = true
  end
end

function M.setup()
  local dap = require("dap")
  local key = "debugging_layout"

  dap.listeners.after.event_initialized[key] = function()
    state.console = false
    M.open_tray()
  end
  dap.listeners.after.event_stopped[key] = function()
    if not M.sidebar_open() then
      M.open_sidebar()
    end
  end
  -- Ended: keep the panels, make sure the output is visible.
  local function ended()
    vim.schedule(function()
      M.open_tray()
      require("debugging.controls").refresh()
    end)
  end
  dap.listeners.after.event_terminated[key] = ended
  dap.listeners.after.disconnect[key] = ended

  -- dap-ui's console element is nvim-dap's terminal provider; wrap it so the
  -- tray grows a terminal pane only when an adapter actually uses one.
  local get_term_buf = dap.defaults.fallback.terminal_win_cmd
  if type(get_term_buf) == "function" then
    dap.defaults.fallback.terminal_win_cmd = function(...)
      local buf, win = get_term_buf(...)
      if not state.console then
        state.console = true
        vim.schedule(M.open_tray)
      end
      return buf, win
    end
  end

  local group = vim.api.nvim_create_augroup("debugging_layout", { clear = true })
  vim.api.nvim_create_autocmd("BufWinEnter", {
    group = group,
    pattern = "*",
    callback = function(args)
      local ft = vim.bo[args.buf].filetype
      if TITLES[ft] or ft == "dap-repl" then
        for _, win in ipairs(vim.fn.win_findbuf(args.buf)) do
          decorate(win, args.buf)
        end
      end
    end,
  })
  -- Adding/removing a watch (typed in the Watches float or panel) can change
  -- which sidebar variant should be shown.
  vim.api.nvim_create_autocmd("BufLeave", {
    group = group,
    callback = function(args)
      if vim.bo[args.buf].filetype == "dapui_watches" then
        vim.schedule(M.refresh_sidebar)
      end
    end,
  })
end

return M
