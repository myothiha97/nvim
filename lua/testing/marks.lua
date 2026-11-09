-- <leader>tx toggles a clean editor after testing.
--   hide: removes neotest's ✓/✗/▶ marks and inline failure messages in every buffer and
--         closes the summary, output panel and test popups (attach / output). The marks stay
--         hidden (also when a test file is reopened) until <leader>tx again or the next run.
--   show: brings the marks and the failure messages of the last run back.
-- Results are kept: <leader>ts / to / th still show the last run. neotest itself stays loaded
-- until nvim quits; restarting nvim is the full reset.
--
-- WARNING: neotest has no public "hide marks" switch. This flips neotest's own
-- config.status.virtual_text, which its status layer reads on every redraw. If a neotest
-- update moves it, the pcall makes the key only clear the current marks (they come back when
-- a test file is focused); nothing else breaks. "Show" also replays BufEnter for neotest's
-- autocmd group by name ("neotest.Client", checked on neotest 27bf921).
--
-- Cost: only on the key, plus one flag check per test run.

local M = {}

local function status_config()
  local ok, config = pcall(require, "neotest.config")
  return ok and type(config.status) == "table" and config.status or nil
end

function M.consumer(client)
  local hidden = false
  local saved = {} -- bufnr -> neotest failure diagnostics hidden by the last hide

  local function set_marks(on)
    local status = status_config()
    if status then
      status.virtual_text = on
    end
  end

  client.listeners.run = function()
    if hidden then
      hidden, saved = false, {}
      set_marks(true)
    end
  end

  local function hide()
    hidden = true
    set_marks(false)
    local marks = vim.api.nvim_create_namespace("neotest-status")
    local diag_ns = vim.api.nvim_create_namespace("neotest")
    saved = {}
    for _, d in ipairs(vim.diagnostic.get(nil, { namespace = diag_ns })) do
      saved[d.bufnr] = saved[d.bufnr] or {}
      table.insert(saved[d.bufnr], d)
    end
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(buf) then
        vim.api.nvim_buf_clear_namespace(buf, marks, 0, -1)
      end
    end
    vim.diagnostic.reset(diag_ns)
    local neotest = require("neotest")
    pcall(neotest.summary.close)
    pcall(neotest.output_panel.close)
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      local ft = vim.bo[vim.api.nvim_win_get_buf(win)].filetype
      if ft == "neotest-attach" or ft == "neotest-output" then
        pcall(vim.api.nvim_win_close, win, true)
      end
    end
  end

  local function show()
    hidden = false
    set_marks(true)
    local diag_ns = vim.api.nvim_create_namespace("neotest")
    for buf, diags in pairs(saved) do
      if vim.api.nvim_buf_is_valid(buf) then
        vim.diagnostic.set(diag_ns, buf, diags)
      end
    end
    saved = {}
    -- neotest redraws a file's marks when it is entered. Replay BufEnter for each visible
    -- buffer, but only for neotest's own autocmds (group "neotest.Client"), so no other
    -- plugin's BufEnter runs. If the group is renamed upstream, the pcall skips this and the
    -- marks come back the next time each file is entered.
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      local buf = vim.api.nvim_win_get_buf(win)
      if vim.bo[buf].buftype == "" then
        pcall(vim.api.nvim_exec_autocmds, "BufEnter", { group = "neotest.Client", buffer = buf, modeline = false })
      end
    end
  end

  return {
    toggle = function()
      if hidden then
        show()
        vim.notify("Test marks shown", vim.log.levels.INFO)
      else
        hide()
        vim.notify("Test marks hidden", vim.log.levels.INFO)
      end
    end,
  }
end

return M
