-- Node / JS / TS: extra launch configurations (debugging/node.lua). The
-- adapter (js-debug) and the basic configs come from LazyVim's typescript
-- extra; jest tests are in plugins/testing.lua next to vitest.

return {
  {
    "mfussenegger/nvim-dap",
    opts = function()
      require("dap").providers.configs["debugging.node"] = function(bufnr)
        return require("debugging.node").configs(bufnr)
      end
    end,
  },
}
