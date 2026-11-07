-- The debug control bar (winbar of the REPL tray), built here in full.
--
-- dap-ui's bar is a fixed list (play, step into/over/out, step back, run last,
-- terminate, disconnect) with 2-column gaps, a click region that stays open to
-- the right edge, and no extension point. The old fix rewrote its output with
-- gsub, which silently stops matching on any upstream format change. Instead,
-- `dapui.controls.controls` is replaced by `M.render` (used by dap-ui on
-- WinEnter/WinLeave of the tray), and M.refresh redraws the bar itself on DAP
-- events (see M.refresh for why dap-ui's own redraw can't be relied on).
--
-- !! WARNING: replaces `dapui.controls.controls`, a dap-ui INTERNAL function.
-- Relies on dap-ui calling `M.controls(is_active)` from
-- refresh_control_panel and on `dapui.config.controls.icons`. After updating
-- nvim-dap-ui, check the bar renders and every button works. If dap-ui stops
-- calling it, the stock bar comes back (no error), and Run Again/exit code
-- disappear.
--
-- During a session (6 buttons, VS Code order):
--   Continue/Pause · Step Over · Step Into · Step Out · Restart · Stop
-- After it ends:
--   Run Again · Close   exited (code N)
-- Run to Cursor is not on the bar: it lives where the cursor is (<leader>dC,
-- and the right-click menu in phase 2).

local M = {}

-- Each click region is " icon " (one padding cell on both sides), and regions
-- are separated by one dead cell that belongs to no button. The old layout put
-- the whole gap AFTER an icon into that icon's region, so a click just left of
-- Step Over landed on Continue.
local PAD = " "
local DEAD = " "
local status = { ran = false, exit_code = nil, config = nil }

local function dap()
  return require("dap")
end

-- After a refused step (e.g. Delve's "Unable to step while the previous step
-- is interrupted by a breakpoint"), nvim-dap can leave `stopped_thread_id`
-- unset although the program IS stopped; the bar then showed Pause and greyed
-- out the steps. Also trust the per-thread `stopped` flags.
local function is_stopped(session)
  if session.stopped_thread_id ~= nil then
    return true
  end
  for _, thread in pairs(session.threads or {}) do
    if thread.stopped then
      return true
    end
  end
  return false
end

-- js-debug (Node) runs the program in a CHILD session (DAP startDebugging)
-- under a launcher session. Run Again, Restart and Stop act on the top-level
-- session, which owns the program; for Go there is only one, so no change.
local function root(session)
  while session and session.parent do
    session = session.parent
  end
  return session
end

-- Restart (bar button, <leader>dR): the whole program, not a child session.
-- With no session, same as Run Again.
function M.restart()
  local session = dap().session()
  if not session then
    M.run_again()
    return
  end
  dap().set_session(root(session))
  dap().restart()
end

-- Stop (bar button, <leader>dt): the top-level session and its children.
function M.stop()
  local session = dap().session()
  if session then
    dap().set_session(root(session))
    dap().terminate({ hierarchy = true })
  end
end

-- Run Again / <leader>dl: rerun the last session's RESOLVED config (the one
-- the adapter actually got). nvim-dap's run_last keeps the raw config and
-- re-expands `${file}` against whatever buffer is open now, so after stepping
-- into fmt/print.go "Run Again" tried to build print.go. Caveat: a config
-- that prompted (e.g. program arguments) reruns with the same answers; pick
-- it again from <leader>dc to be asked anew.
function M.run_again()
  if status.config then
    dap().run(vim.deepcopy(status.config))
  else
    dap().run_last()
  end
end

_G._debugging_bar = {
  play = function()
    local session = dap().session()
    if session and not is_stopped(session) then
      dap().pause()
    else
      dap().continue()
    end
  end,
  step_over = function()
    dap().step_over()
  end,
  step_into = function()
    dap().step_into()
  end,
  step_out = function()
    dap().step_out()
  end,
  restart = function()
    M.restart()
  end,
  stop = function()
    if dap().session() then
      M.stop()
    else
      require("debugging.layout").close_all()
    end
  end,
  run = function()
    if status.ran then
      M.run_again()
    else
      dap().continue()
    end
  end,
}

local function button(hl, fn, icon)
  return ("%%#%s#%%0@v:lua._debugging_bar.%s@%s%s%s%%X%%*%s"):format(hl, fn, PAD, icon, PAD, DEAD)
end

function M.render(is_active)
  local icons = require("dapui.config").controls.icons
  local session = dap().session()
  local nc = is_active and "" or "NC"

  if not session then
    local label = status.ran and "Run Again" or "Run"
    local bar = button("DapUIPlayPause" .. nc, "run", icons.play .. " " .. label)
      .. button("DapUIStop" .. nc, "stop", icons.terminate .. " Close")
    if status.exit_code ~= nil then
      local hl = status.exit_code == 0 and "Comment" or "DiagnosticError"
      bar = bar .. ("%%#%s# exited (code %d)"):format(hl, status.exit_code)
    elseif status.ran then
      bar = bar .. "%#Comment# session ended"
    end
    return bar .. "%<"
  end

  local stopped = is_stopped(session)
  local function step_hl(group)
    if not stopped then
      return "DapUIUnavailable" .. nc
    end
    return group .. nc
  end

  return button("DapUIPlayPause" .. nc, "play", stopped and icons.play or icons.pause)
    .. button(step_hl("DapUIStepOver"), "step_over", icons.step_over)
    .. button(step_hl("DapUIStepInto"), "step_into", icons.step_into)
    .. button(step_hl("DapUIStepOut"), "step_out", icons.step_out)
    .. button("DapUIRestart" .. nc, "restart", icons.run_last)
    .. button("DapUIStop" .. nc, "stop", icons.terminate)
    .. "%<"
end

-- Draw the bar on every window showing the REPL tray in this tab.
--
-- Not via dap-ui's refresh_control_panel: that remembers ONE window id and
-- only re-learns it on BufWinEnter when it holds none. Its WinClosed check
-- runs while the window is still valid, so after the tray closes (Close,
-- <leader>du) the stale id survives, the next BufWinEnter is skipped, the
-- first refresh fails and clears it, and every later refresh is a no-op.
-- The bar then only changed on WinEnter/WinLeave of the tray: Pause and
-- greyed steps while stopped, after Close -> Run Again / Restart.
-- Cost: a scan of the current tab's windows on DAP events only.
function M.refresh()
  local current = vim.api.nvim_get_current_win()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "dap-repl" then
      pcall(vim.api.nvim_set_option_value, "winbar", M.render(win == current), { win = win })
    end
  end
end

function M.setup()
  require("dapui.controls").controls = M.render

  local key = "debugging_controls"
  local listeners = dap().listeners
  listeners.after.event_initialized[key] = function(session)
    status.ran, status.exit_code = true, nil
    status.config = vim.deepcopy(root(session).config)
  end
  listeners.after.event_exited[key] = function(_, body)
    status.exit_code = body and body.exitCode
  end

  -- Redraw on the events dap-ui uses, plus once a stop is fully processed:
  -- nvim-dap sets `stopped_thread_id` only after it refetched the thread
  -- list (every stop, see plugins/core.lua), i.e. after `event_stopped`.
  local function late_refresh()
    vim.schedule(M.refresh)
  end
  for _, event in ipairs({
    "event_initialized",
    "event_stopped",
    "event_continued",
    "event_exited",
    "event_terminated",
    "continue",
    "terminate",
    "restart",
    "disconnect",
    "threads",
    "stackTrace",
    "scopes",
  }) do
    listeners.after[event][key .. "_redraw"] = late_refresh
  end
end

return M
