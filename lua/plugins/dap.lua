-- Debugger enhancements on top of LazyVim's `dap.core` + `lang.go` extras.
--
-- Nothing new is installed here. Every spec below only extends a plugin the
-- extras already pull in, so startup cost is unchanged, and every hook runs at
-- a debug-session boundary (config resolve / session start), never on a hot
-- editor path.
--
-- Why this file exists: the stock setup gives breakpoints, stepping and locals,
-- but leaves the Go-specific half of Delve switched off. Background, the
-- measured Delve capabilities and the remaining gaps live in
-- `todos/nvim-dap-webstorm-parity-and-enhancements.md`.

-- Delve DAP launch options, applied to every Go config (see `dlv config -list`
-- in the REPL for the live values, and `dlv config <name> <value>` to change
-- one mid-session without restarting).
local delve_opts = {
  -- Package-level vars show up as a "Globals (package main)" scope, next to
  -- Locals. Off by default in Delve.
  showGlobalVariables = true,
  -- Hide runtime-internal goroutines from the goroutine list, so the Stacks
  -- panel shows your goroutines instead of a dozen `runtime.gopark` entries.
  -- Flip at runtime with `dlv config hideSystemGoroutines false`.
  hideSystemGoroutines = true,
  -- Delve stops collecting frames at 50 by default; deep call chains and
  -- panics get truncated.
  stackTraceDepth = 100,
}

-- Function breakpoints: stop on entry to a function by name, e.g. `main.worker`
-- or `(*Server).Handle`, without opening the file. Delve supports them
-- (`supportsFunctionBreakpoints`), but nvim-dap keeps no state for them, so the
-- list lives here and is re-sent on every session start.
local fn_breakpoints = {}

local function sync_fn_breakpoints(session)
  session = session or require("dap").session()
  if not session then
    return
  end
  local breakpoints = vim.tbl_map(function(name)
    return { name = name }
  end, fn_breakpoints)
  session:request("setFunctionBreakpoints", { breakpoints = breakpoints }, function(err)
    if err then
      vim.notify("Function breakpoints: " .. tostring(err), vim.log.levels.ERROR)
    end
  end)
end

local function toggle_fn_breakpoint()
  vim.ui.input({ prompt = "Function breakpoint (e.g. main.worker): " }, function(name)
    name = name and vim.trim(name) or ""
    if name == "" then
      return
    end
    local removed = false
    for i, existing in ipairs(fn_breakpoints) do
      if existing == name then
        table.remove(fn_breakpoints, i)
        removed = true
        break
      end
    end
    if not removed then
      table.insert(fn_breakpoints, name)
    end
    sync_fn_breakpoints()
    vim.notify(
      #fn_breakpoints == 0 and "Function breakpoints: none"
        or ("Function breakpoints: " .. table.concat(fn_breakpoints, ", ")),
      vim.log.levels.INFO
    )
  end)
end

-- Clear every breakpoint in the current file. nvim-dap only ships an
-- all-buffers `clear_breakpoints()`, so drop this buffer's signs and push the
-- now-empty list to any running session (an empty table would be a no-op, the
-- buffer key has to be present).
local function clear_buffer_breakpoints()
  local bps = require("dap.breakpoints")
  local bufnr = vim.api.nvim_get_current_buf()
  local in_buf = bps.get(bufnr)[bufnr] or {}
  if #in_buf == 0 then
    vim.notify("No breakpoints in this file", vim.log.levels.INFO)
    return
  end
  for _, bp in ipairs(in_buf) do
    bps.remove(bufnr, bp.line)
  end
  for _, session in pairs(require("dap").sessions()) do
    session:set_breakpoints({ [bufnr] = {} })
  end
  vim.notify(("Cleared %d breakpoint%s"):format(#in_buf, #in_buf == 1 and "" or "s"))
end

-- Goroutine list in a float: every goroutine Delve reports, expandable to its
-- own stack, `<CR>` on a frame jumps there and repoints the Scopes panel at it.
-- This is how you read a goroutine that is parked on a channel or a mutex.
local function goroutines()
  if not require("dap").session() then
    vim.notify("No debug session", vim.log.levels.WARN)
    return
  end
  local widgets = require("dap.ui.widgets")
  widgets.centered_float(widgets.threads)
end

return {
  {
    "mfussenegger/nvim-dap",
    -- stylua: ignore
    keys = {
      { "<leader>dG", goroutines, desc = "Goroutines / Threads" },
      -- LazyVim puts "Breakpoint Condition" on <leader>dB; clearing a file's
      -- breakpoints is the more frequent action, so it takes dB and the
      -- condition prompt moves to dN.
      { "<leader>dB", clear_buffer_breakpoints, desc = "Clear Breakpoints (File)" },
      { "<leader>dN", function() require("dap").set_breakpoint(vim.fn.input("Breakpoint condition: ")) end, desc = "Breakpoint Condition" },
      { "<leader>dF", toggle_fn_breakpoint, desc = "Toggle Function Breakpoint" },
      { "<leader>dR", function() require("dap").restart() end, desc = "Restart Session" },
      { "<leader>dL", function() require("dap").set_breakpoint(nil, nil, vim.fn.input("Log point message: ")) end, desc = "Log Point" },
      { "<leader>dH", function() require("dap").set_breakpoint(nil, vim.fn.input("Hit condition (e.g. > 5): ")) end, desc = "Breakpoint Hit Condition" },
      { "<leader>dx", function() require("dap").set_exception_breakpoints() end, desc = "Exception Breakpoints" },
    },
    opts = function()
      local dap = require("dap")

      -- Applied at launch time rather than by editing `dap.configurations.go`,
      -- so it also covers configs that come from a project `.vscode/launch.json`
      -- or from mason-nvim-dap, and never overrides a value set there.
      dap.listeners.on_config["go_delve_opts"] = function(config)
        if config.type == "go" or config.type == "delve" then
          return vim.tbl_extend("keep", config, delve_opts)
        end
        return config
      end

      dap.listeners.after.event_initialized["go_fn_breakpoints"] = function(session)
        if #fn_breakpoints > 0 then
          sync_fn_breakpoints(session)
        end
      end
    end,
  },

  -- Bigger Stacks panel: with concurrency the goroutine list is the panel you
  -- read most, and a quarter of the sidebar is not enough for it.
  {
    "rcarriga/nvim-dap-ui",
    opts = {
      layouts = {
        {
          elements = {
            { id = "scopes", size = 0.35 },
            { id = "stacks", size = 0.35 },
            { id = "watches", size = 0.15 },
            { id = "breakpoints", size = 0.15 },
          },
          size = 46,
          position = "left",
        },
        {
          elements = { "repl", "console" },
          size = 12,
          position = "bottom",
        },
      },
    },
  },

  -- Inline values are already on; Go struct values are just long enough to push
  -- the code off screen, so cap them.
  {
    "theHamsta/nvim-dap-virtual-text",
    -- Required. This plugin has no lazy trigger of its own; it only ships as a
    -- dependency of nvim-dap. Declaring it at the top level here would make
    -- lazy.nvim treat it as a root spec (`lazy = false`), and since it
    -- `require`s dap at module scope that pulls the whole debug stack into
    -- startup. Measured, not theoretical.
    lazy = true,
    opts = {
      display_callback = function(variable, _, _, _, opts)
        local value = variable.value:gsub("%s+", " ")
        if #value > 60 then
          value = vim.fn.strcharpart(value, 0, 59) .. "…"
        end
        return opts.virt_text_pos == "inline" and (" = " .. value) or (variable.name .. " = " .. value)
      end,
    },
  },

  -- nvim-dap-go already registers seven Go configurations; mason-nvim-dap
  -- appends four more ("Delve: ...") that duplicate them under a second adapter.
  -- Keep its adapter, drop the duplicate entries from the run picker.
  {
    "jay-babu/mason-nvim-dap.nvim",
    opts = {
      handlers = {
        delve = function(config)
          config.configurations = nil
          require("mason-nvim-dap").default_setup(config)
        end,
      },
    },
  },
}
