-- C# / .NET: easy-dotnet.nvim (debugging/csharp.lua has what our bar and
-- menu need from it).
--
-- Why this plugin and not LazyVim's dotnet extra: Mason's netcoredbg is an
-- Intel-only build, which cannot debug arm64 .NET apps on Apple Silicon.
-- easy-dotnet's server (a dotnet tool, `dotnet tool install -g EasyDotnet`,
-- installed for you on first use) bundles a native arm64 netcoredbg, builds
-- before debugging, reads launchSettings.json profiles and runs the Roslyn
-- LSP. Sessions go through nvim-dap, so our panels, bar and menu apply.
--
-- Loads only for C#/F#/VB/Razor buffers or :Dotnet. Cost: none elsewhere.

return {
  {
    "GustavEikaas/easy-dotnet.nvim",
    ft = { "cs", "fsharp", "vb", "razor" },
    cmd = "Dotnet",
    dependencies = { "nvim-lua/plenary.nvim", "mfussenegger/nvim-dap" },
    opts = {
      picker = "snacks",
      test_runner = {
        -- Its in-file test keys default to <leader>r/d/t/p, which would
        -- shadow the <leader>d (debug) and <leader>t (test) groups in test
        -- files. Same actions on the keys neotest uses for other languages.
        mappings = {
          run_test_from_buffer = { lhs = "<leader>tr", desc = "Run Nearest" },
          debug_test_from_buffer = { lhs = "<leader>td", desc = "Debug Nearest" },
          run_all_tests_from_buffer = { lhs = "<leader>tt", desc = "Run File" },
          peek_stack_trace_from_buffer = { lhs = "<leader>to", desc = "Show Output" },
        },
      },
    },
    config = function(_, opts)
      require("easy-dotnet").setup(opts)
      local dap = require("dap")
      -- Its own <leader>dc entry ("easy-dotnet" = Debug project…) is
      -- replaced by csharp.lua's, which Restart / Run Again can repeat.
      for _, ft in ipairs({ "cs", "fsharp", "vb" }) do
        dap.configurations[ft] = vim.tbl_filter(function(c)
          return c.name ~= "easy-dotnet"
        end, dap.configurations[ft] or {})
      end
      dap.listeners.after.event_initialized["debugging_csharp"] = function(session)
        require("debugging.csharp").on_session(session)
      end
      -- WARNING (easy-dotnet internal, terminal/tabline.lua): its terminal
      -- panel (:Dotnet run / build / test output) maps <LeftMouse> and
      -- <2-LeftMouse> globally while open and DELETES both when it closes,
      -- which removed debugging/mouse.lua's gutter-click breakpoints for
      -- every language (Go included) until restart. Put them back on close.
      -- While that panel is open, gutter clicks act as plain clicks.
      -- If upstream renames `destroy`, this is skipped (README "Upstream internals").
      local tabline = require("easy-dotnet.terminal.tabline")
      local destroy = tabline.destroy
      if type(destroy) == "function" then
        tabline.destroy = function(...)
          destroy(...)
          require("debugging.mouse").setup()
        end
      end
    end,
  },
  {
    "mfussenegger/nvim-dap",
    opts = function()
      require("dap").providers.configs["debugging.csharp"] = function(bufnr)
        return require("debugging.csharp").configs(bufnr)
      end
    end,
  },
}
