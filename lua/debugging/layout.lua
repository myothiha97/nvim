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

-- <leader>dr: go to the REPL in the tray (open the tray first if needed); from
-- the REPL, go back. LazyVim's dap.repl.toggle() opened a SECOND REPL split
-- next to the tray's, shrinking the editor to a third of its height.
function M.focus_repl()
  local function repl_win()
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      local buf = vim.api.nvim_win_get_buf(win)
      if vim.bo[buf].filetype == "dap-repl" and vim.api.nvim_win_get_config(win).relative == "" then
        return win
      end
    end
  end
  local win = repl_win()
  if win and win == vim.api.nvim_get_current_win() then
    vim.cmd("wincmd p")
    return
  end
  if not win then
    M.open_tray()
    win = repl_win()
  end
  if win then
    vim.api.nvim_set_current_win(win)
  end
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
  dapui_scopes = { "VARIABLES", "dbl-click expand · e edit · w watch · y copy" },
  dapui_stacks = { "CALL STACK", "dbl-click expand/open/switch · t internals · y copy" },
  dapui_watches = { "WATCHES", "i add · e edit · d remove · y copy" },
  dapui_breakpoints = { "BREAKPOINTS", "o open · t enable/disable · d remove" },
  dapui_console = { "TERMINAL", "" },
}

-- Keep only the hint items that fit after the title. A winbar wider than its
-- window is cut from the LEFT, which hid VARIABLES and CALL STACK at the
-- sidebar's 46 columns ("< dbl-click expand ..."). Items drop from the end.
local function fit_hint(title, hint, width)
  local room = width - vim.fn.strdisplaywidth(title) - 3 -- " TITLE " + " " before the hint
  local items = vim.split(hint, " · ", { plain = true })
  while #items > 0 and vim.fn.strdisplaywidth(table.concat(items, " · ")) > room do
    table.remove(items)
  end
  return table.concat(items, " · ")
end

local function decorate(win, buf)
  local ft = vim.bo[buf].filetype
  local title = TITLES[ft]
  if title and vim.api.nvim_win_get_config(win).relative == "" then
    local hint = fit_hint(title[1], title[2], vim.api.nvim_win_get_width(win))
    vim.wo[win].winbar = ("%%#Title# %s %%#Comment# %s"):format(title[1], hint)
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
  -- The hint is fitted to the window width (fit_hint), and dap-ui sizes its
  -- windows after BufWinEnter, so fit again once a panel's size settles or
  -- changes. Fires on resizes only; one filetype lookup per resized window.
  vim.api.nvim_create_autocmd("WinResized", {
    group = group,
    callback = function()
      for _, win in ipairs(vim.v.event.windows or {}) do
        if vim.api.nvim_win_is_valid(win) then
          local buf = vim.api.nvim_win_get_buf(win)
          if TITLES[vim.bo[buf].filetype] then
            decorate(win, buf)
          end
        end
      end
    end,
  })
  -- A watch added from anywhere (`w` in Variables, right-click Add to
  -- Watches) shows the Watches panel at once, and an expression that is
  -- already watched is skipped. Wraps dap-ui's PUBLIC `elements.watches.add`,
  -- which its own `w` action also calls. Typing in the Watches panel (`i`)
  -- bypasses it, so duplicates are still possible there.
  local watches = require("dapui").elements.watches
  local add = watches.add
  watches.add = function(expr, ...)
    for _, w in ipairs(watches.get()) do
      if w.expression == expr then
        vim.notify("Already watching " .. expr, vim.log.levels.INFO)
        return
      end
    end
    add(expr, ...)
    vim.schedule(M.refresh_sidebar)
  end

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
