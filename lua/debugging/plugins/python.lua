-- Python: extra launch configurations (debugging/python.lua). The adapter
-- (debugpy via nvim-dap-python) and the basic configs come from LazyVim's
-- python extra; pytest debugging comes from neotest-python (test.core).

return {
  {
    "mfussenegger/nvim-dap",
    opts = function()
      require("dap").providers.configs["debugging.python"] = function(bufnr)
        return require("debugging.python").configs(bufnr)
      end
    end,
  },
}
