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

return {
  {
    "mfussenegger/nvim-dap",
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
    end,
  },
}
