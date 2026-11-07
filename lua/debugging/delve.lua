-- Delve-specific behaviour: launch options and function breakpoints.
--
-- Launch options are applied at config-resolve time (see plugins/core.lua), so
-- they also cover configs from a project `.vscode/launch.json` and never
-- override a value set there. `dlv config -list` in the REPL shows the live
-- values; `dlv config <name> <value>` changes one mid-session.

local M = {}

M.opts = {
  -- Package-level vars show up as a "Globals (package main)" scope next to
  -- Locals. Off by default in Delve.
  showGlobalVariables = true,
  -- Hide runtime-internal goroutines so Call Stack lists your goroutines, not
  -- a dozen `runtime.gopark` entries. Live toggle:
  -- `dlv config hideSystemGoroutines false`.
  hideSystemGoroutines = true,
  -- Delve stops collecting frames at 50 by default; deep chains and panics
  -- get truncated.
  stackTraceDepth = 100,
  -- Show pprof labels (pprof.Do / pprof.WithLabels) in goroutine names, so a
  -- server goroutine reads as the request it belongs to. "*" = all labels.
  showPprofLabels = { "*" },
  -- Not set: goroutineFilters. For servers with hundreds of goroutines, put
  -- e.g. `goroutineFilters = "-with userloc main"` in a project launch.json.
}

function M.on_config(config)
  if config.type == "go" or config.type == "delve" then
    return vim.tbl_extend("keep", config, M.opts)
  end
  return config
end

-- Function breakpoints: stop on entry to a function by name (`main.worker`,
-- `(*Server).Handle`) without opening the file. nvim-dap keeps no state for
-- them, so the list lives here, is persisted by debugging.breakpoints, and is
-- re-sent on every session start.
M.fn_breakpoints = {}

function M.sync_fn_breakpoints(session)
  session = session or require("dap").session()
  if not session or not session.capabilities or not session.capabilities.supportsFunctionBreakpoints then
    return
  end
  local breakpoints = vim.tbl_map(function(name)
    return { name = name }
  end, M.fn_breakpoints)
  session:request("setFunctionBreakpoints", { breakpoints = breakpoints }, function(err)
    if err then
      vim.notify("Function breakpoints: " .. tostring(err), vim.log.levels.ERROR)
    end
  end)
end

-- Right-click Debug Test (menu.lua): Go test files, nvim-dap-go's nearest test.
function M.is_test_file(name)
  return name:match("_test%.go$") ~= nil
end

function M.debug_test()
  require("dap-go").debug_test()
end

function M.toggle_fn_breakpoint()
  require("debugging.prompts").input({ prompt = "Function breakpoint (e.g. main.worker)" }, function(name)
    if name == "" then
      return
    end
    local removed = false
    for i, existing in ipairs(M.fn_breakpoints) do
      if existing == name then
        table.remove(M.fn_breakpoints, i)
        removed = true
        break
      end
    end
    if not removed then
      table.insert(M.fn_breakpoints, name)
    end
    M.sync_fn_breakpoints()
    require("debugging.breakpoints").save()
    vim.notify(
      #M.fn_breakpoints == 0 and "Function breakpoints: none"
        or ("Function breakpoints: " .. table.concat(M.fn_breakpoints, ", ")),
      vim.log.levels.INFO
    )
  end)
end

return M
