-- nvim-dap-ui + inline values. Layout policy and the control bar live in
-- debugging/layout.lua and debugging/controls.lua.

return {
  {
    "rcarriga/nvim-dap-ui",
    -- Pinned: :Lazy update skips it (README "Upstream internals"). To update on
    -- purpose, remove this line, update, run the README checks, put it back.
    pin = true,
    -- stylua: ignore
    keys = {
      { "<leader>du", function() require("debugging.layout").toggle() end, desc = "Debug Panels" },
      -- Replaces LazyVim's dapui.eval(): skips keywords/operators/literals (debugging/menu.lua).
      { "<leader>de", function() require("debugging.menu").eval() end, desc = "Eval", mode = { "n", "x" } },
    },
    opts = function(_, opts)
      -- Long values (a sync.WaitGroup prints ~200 chars) stay inside the panel.
      --   wrap = false         cuts the value off at the panel edge
      --   expand_lines = true  opens a borderless float as wide as the value on
      --                        cursor, painting over the editor
      opts.wrap = true
      opts.expand_lines = false
      opts.layouts = require("debugging.layout").layouts
      -- Evaluate / floated panels: capped so big values don't cover the
      -- screen. Width is generous because dap-ui floats never wrap (float.lua
      -- forces nowrap) and horizontal scrolling is awkward in Neovim; only a
      -- line wider than 90% of the screen needs zl / horizontal scroll.
      -- Height scrolls normally (wheel, j/k).
      opts.floating = vim.tbl_deep_extend("force", opts.floating or {}, { max_width = 0.9, max_height = 0.5 })
      opts.controls = vim.tbl_deep_extend("force", opts.controls or {}, { enabled = true, element = "repl" })
      -- Call Stack: double-click / <CR> / za toggles a goroutine or opens a
      -- frame (see debugging/stacks.lua); o opens, t shows runtime frames.
      opts.element_mappings = vim.tbl_deep_extend("force", opts.element_mappings or {}, {
        stacks = { expand = { "<CR>", "<2-LeftMouse>", "za" }, open = "o", toggle = "t" },
      })
      return opts
    end,
    -- Replaces LazyVim's config, which opened every panel on session start and
    -- closed them all on exit (two layout jumps per run, output gone at exit).
    config = function(_, opts)
      -- Collapsible goroutines in Call Stack. Must be in place before setup,
      -- which builds the stacks element and requires this module.
      -- !! WARNING: overrides a dap-ui INTERNAL module; may break when
      -- nvim-dap-ui is updated. Check Call Stack after every dap-ui update;
      -- delete this line to roll back. Details: debugging/stacks.lua.
      package.loaded["dapui.components.threads"] = require("debugging.stacks")
      require("dapui").setup(opts)
      require("debugging.controls").setup()
      require("debugging.layout").setup()
      require("debugging.copy").setup() -- y: Copy Value (Variables, Watches), Copy Stack (Call Stack)
    end,
  },

  -- Inline values; Go struct values push the code off screen, so cap them.
  {
    "theHamsta/nvim-dap-virtual-text",
    -- Required. This plugin has no lazy trigger of its own; declared at the top
    -- level without `lazy = true`, lazy.nvim treats it as a root spec and,
    -- since it `require`s dap at module scope, pulls the whole debug stack into
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

  -- REPL completion from the debug adapter (debugging/repl_complete.lua),
  -- in the debug REPL only (blink already enables itself in dap-repl
  -- buffers). `inherit_defaults` keeps the sources the REPL had before
  -- (lsp, path, snippets, buffer); buffer words show when the adapter has no
  -- completion support (Delve) or no match.
  {
    "saghen/blink.cmp",
    optional = true,
    opts = {
      sources = {
        per_filetype = { ["dap-repl"] = { "dap", inherit_defaults = true } },
        providers = {
          dap = { name = "DAP", module = "debugging.repl_complete", min_keyword_length = 0, fallbacks = { "buffer" } },
        },
      },
    },
  },
}
