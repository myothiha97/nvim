return {
  {
    "HiPhish/rainbow-delimiters.nvim",
    -- Parked: broken in JSX/TSX. See todos/theme/rainbow-brackets-and-operator-colours.md
    enabled = false,
    dependencies = "nvim-treesitter/nvim-treesitter",
    config = function()
      -- This plugin hooks automatically into Tree-sitter.
      -- You can configure specific strategies or overrides here if needed:
      local rainbow_delimiters = require("rainbow-delimiters")

      vim.g.rainbow_delimiters = {
        strategy = {
          [""] = rainbow_delimiters.strategy["global"],
        },
        query = {
          [""] = "rainbow-delimiters",
        },
      }
    end,
  },
}
