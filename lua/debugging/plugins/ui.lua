-- nvim-dap-ui + inline values. Layout policy and the control bar live in
-- debugging/layout.lua and debugging/controls.lua.

return {
  {
    "rcarriga/nvim-dap-ui",
    -- stylua: ignore
    keys = {
      { "<leader>du", function() require("debugging.layout").toggle() end, desc = "Debug Panels" },
    },
    opts = function(_, opts)
      -- Long values (a sync.WaitGroup prints ~200 chars) stay inside the panel.
      --   wrap = false         cuts the value off at the panel edge
      --   expand_lines = true  opens a borderless float as wide as the value on
      --                        cursor, painting over the editor
      opts.wrap = true
      opts.expand_lines = false
      opts.layouts = require("debugging.layout").layouts
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
}
