return {
  -- Ensure conform.nvim uses prettierd (faster daemon) instead of prettier
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        javascript = { "prettierd" },
        javascriptreact = { "prettierd" },
        typescript = { "prettierd" },
        typescriptreact = { "prettierd" },
        json = { "prettierd" },
        jsonc = { "prettierd" },
        html = { "prettierd" },
        css = { "prettierd" },
        scss = { "prettierd" },
        markdown = { "prettierd" },
        yaml = { "prettierd" },
        graphql = { "prettierd" },
        sh = { "shfmt" },
        bash = { "shfmt" },
        -- mbake: indents recipe lines with the tab make requires
        make = { "bake" },
      },
      -- prettierd natively resolves project-local config (walking up from the file,
      -- same as VS Code). For files with no project config (e.g. this nvim repo),
      -- fall back to the global config via prettierd's own env var.
      -- NOTE: prettierd is a daemon and does NOT support prettier's `--config` flag
      -- — passing it errors. The fallback MUST go through PRETTIERD_DEFAULT_CONFIG.
      formatters = {
        prettierd = {
          env = {
            PRETTIERD_DEFAULT_CONFIG = vim.fn.expand("~/.config/prettier/.prettierrc"),
          },
        },
      },
    },
  },

  -- Ensure only prettierd is installed via Mason (not prettier)
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      opts.ui = opts.ui or {}
      opts.ui.border = "rounded"

      opts.ensure_installed = opts.ensure_installed or {}
      -- Add prettierd
      table.insert(opts.ensure_installed, "prettierd")
      -- Makefile formatter for conform's `bake`
      table.insert(opts.ensure_installed, "mbake")
      -- Remove packages we don't use (added by LazyVim extras)
      local exclude = { "prettier", "eslint-lsp" }
      opts.ensure_installed = vim.tbl_filter(function(pkg)
        return not vim.tbl_contains(exclude, pkg)
      end, opts.ensure_installed)
    end,
  },
}
