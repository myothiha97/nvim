-- Go: nvim-dap-go comes from LazyVim's `lang.go` extra; Delve options and
-- function breakpoints are in debugging/delve.lua.

return {
  -- nvim-dap-go already registers its Go configurations; mason-nvim-dap would
  -- append four more ("Delve: ...") duplicating them under a second adapter.
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
