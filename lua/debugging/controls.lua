-- The debug control bar (winbar of the REPL tray), built here in full.
--
-- dap-ui's bar is a fixed list (play, step into/over/out, step back, run last,
-- terminate, disconnect) with 2-column gaps, a click region that stays open to
-- the right edge, and no extension point. The old fix rewrote its output with
-- gsub, which silently stops matching on any upstream format change. Instead,
-- `dapui.controls.controls` is replaced by `M.render`; dap-ui still decides
-- WHEN to redraw (its listeners), this module decides WHAT is drawn.
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
local status = { ran = false, exit_code = nil }

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
    if dap().session() then
      dap().restart()
    else
      dap().run_last()
    end
  end,
  stop = function()
    if dap().session() then
      dap().terminate()
    else
      require("debugging.layout").close_all()
    end
  end,
  run = function()
    if status.ran then
      dap().run_last()
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

function M.refresh()
  pcall(function()
    require("dapui.controls").refresh_control_panel()
  end)
end

function M.setup()
  require("dapui.controls").controls = M.render

  local key = "debugging_controls"
  local listeners = dap().listeners
  listeners.after.event_initialized[key] = function()
    status.ran, status.exit_code = true, nil
  end
  listeners.after.event_exited[key] = function(_, body)
    status.exit_code = body and body.exitCode
  end

  -- dap-ui redraws the bar right after the `stopped` event arrives, but
  -- nvim-dap handles that event asynchronously: when it first refetches the
  -- thread list (every stop, see plugins/core.lua) `stopped_thread_id` is set
  -- only after that reply. The bar was drawn too early and showed Pause with
  -- greyed-out steps while the program was stopped. Redraw again once the
  -- stop is fully processed (threads -> stackTrace -> scopes).
  local function late_refresh()
    vim.schedule(M.refresh)
  end
  for _, request in ipairs({ "threads", "stackTrace", "scopes" }) do
    listeners.after[request][key] = late_refresh
  end
end

return M
