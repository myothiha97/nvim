-- nvim-dap: keys, listeners and Delve hooks on top of LazyVim's `dap.core`.
--
-- Nothing new is installed. Every hook runs at a debug-session boundary or on
-- a breakpoint action, never on a hot editor path. The only startup work is
-- the breakpoint-restore autocmd (see debugging/breakpoints.lua).

-- Jump to a dap-ui panel. If it's on screen its window is focused; otherwise
-- it opens as a float with the same contents and mappings (Watches and
-- Breakpoints are not in the default layout, so they always float until used).
local function focus_element(name)
  return function()
    local ft = "dapui_" .. name
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == ft then
        vim.api.nvim_set_current_win(win)
        return
      end
    end
    require("dapui").float_element(name, { enter = true })
  end
end

local function toggle_breakpoint()
  require("dap").toggle_breakpoint()
  require("debugging.breakpoints").save()
end

return {
  {
    "mfussenegger/nvim-dap",
    init = function()
      require("debugging.breakpoints").setup()
      -- Gutter click -> breakpoint (a normal-mode <LeftMouse> mapping).
      vim.api.nvim_create_autocmd("User", {
        pattern = "VeryLazy",
        once = true,
        callback = function()
          require("debugging.mouse").setup()
        end,
      })
    end,
    -- stylua: ignore
    keys = {
      -- Same action as LazyVim's, plus an immediate save so a crash can't lose it.
      { "<leader>db", toggle_breakpoint, desc = "Toggle Breakpoint" },
      -- Panels. In Call Stack: `o` on a frame jumps to it and repoints
      -- Variables at that frame, `t` toggles runtime-internal frames.
      { "<leader>dG", focus_element("stacks"), desc = "Goroutines / Call Stack" },
      { "<leader>dv", focus_element("scopes"), desc = "Variables" },
      { "<leader>dW", focus_element("watches"), desc = "Watches" },
      { "<leader>dp", focus_element("breakpoints"), desc = "Breakpoints List" },
      -- LazyVim: dB = condition. Clearing a file is more frequent, so dB clears
      -- and the condition prompt moves to dN.
      { "<leader>dB", function() require("debugging.breakpoints").clear_buffer() end, desc = "Clear Breakpoints (File)" },
      { "<leader>dX", function() require("debugging.breakpoints").clear_all() end, desc = "Clear Breakpoints (Project)" },
      { "<leader>dN", function() require("debugging.prompts").condition() end, desc = "Breakpoint Condition" },
      { "<leader>dH", function() require("debugging.prompts").hit_condition() end, desc = "Breakpoint Hit Condition" },
      { "<leader>dL", function() require("debugging.prompts").log_point() end, desc = "Log Point" },
      { "<leader>dF", function() require("debugging.delve").toggle_fn_breakpoint() end, desc = "Toggle Function Breakpoint" },
      -- LazyVim ships these the other way round (do = step out, dO = step over).
      { "<leader>do", function() require("dap").step_over() end, desc = "Step Over" },
      { "<leader>dO", function() require("dap").step_out() end, desc = "Step Out" },
      { "<leader>dR", function() require("dap").restart() end, desc = "Restart Session" },
      { "<leader>dx", function() require("dap").set_exception_breakpoints() end, desc = "Exception Breakpoints" },
    },
    opts = function()
      local dap = require("dap")
      local delve = require("debugging.delve")

      -- Applied at launch time rather than by editing `dap.configurations.go`,
      -- so it also covers `.vscode/launch.json` and mason-nvim-dap configs.
      dap.listeners.on_config["go_delve_opts"] = delve.on_config

      -- Keep the goroutine/thread list fresh. nvim-dap only re-requests
      -- `threads` when it saw a `thread` event or the stop is on an unknown
      -- thread; Delve sends no `thread` events for goroutines, so Call Stack
      -- kept the list from the FIRST stop: goroutines started later were
      -- missing, and `dlv config hideSystemGoroutines false` changed nothing.
      -- !! WARNING: uses nvim-dap INTERNALS (`session.dirty`,
      -- `session:update_threads`). Guarded: if they disappear after an nvim-dap
      -- update this silently does nothing and the stale-list bug returns.
      -- Check: after an update, `dlv config hideSystemGoroutines false` in the
      -- REPL must change Call Stack immediately.
      -- Mark the list dirty before every stop (one `threads` request per stop,
      -- as VS Code does). `dirty` is an nvim-dap internal; if it disappears
      -- this becomes a no-op, not an error.
      dap.listeners.before.event_stopped["debugging_threads"] = function(session)
        if type(session.dirty) == "table" then
          session.dirty.threads = true
        end
      end
      -- Delve sends `invalidated` (areas: threads) after `dlv config
      -- hideSystemGoroutines/goroutineFilters/showPprofLabels`; nvim-dap
      -- ignores it, so refetch now. dap-ui redraws Call Stack from the reply.
      dap.listeners.after.event_invalidated["debugging_threads"] = function(session, body)
        local areas = body and body.areas or {}
        if vim.tbl_contains(areas, "threads") or vim.tbl_contains(areas, "all") or #areas == 0 then
          if type(session.dirty) == "table" then
            session.dirty.threads = true
          end
          if session.stopped_thread_id and session.update_threads then
            session:update_threads(function() end)
          end
        end
      end

      -- Rejected-breakpoint icons only mean something during a session;
      -- nvim-dap never reverts them. Once nvim-dap drops the session
      -- (on_session old -> nil), wait briefly for the adapter's last
      -- breakpoint events, then restore the normal icons.
      dap.listeners.on_session["debugging_signs"] = function(_, new)
        if not new then
          vim.defer_fn(function()
            if not require("dap").session() then
              require("debugging.breakpoints").reset_signs()
            end
          end, 300)
        end
      end

      dap.listeners.after.event_initialized["debugging_core"] = function(session)
        if #delve.fn_breakpoints > 0 then
          delve.sync_fn_breakpoints(session)
        end
        require("debugging.breakpoints").save()
      end
    end,
  },
}
