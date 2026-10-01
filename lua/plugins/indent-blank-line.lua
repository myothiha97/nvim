return {
  "lukas-reineke/indent-blankline.nvim",
  main = "ibl",
  enabled = false, -- if u want to see the indent lines, set this to true
  ---@module "ibl"
  ---@type ibl.config
  opts = {
    enabled = false, -- if u want to see the indent lines, set this to true
    -- 1. Configure the static background lines to be subtle
    indent = {
      char = "│",
    },
    -- 2. Tune scope tracking for immediate deeper block resolution
    scope = {
      enabled = true,
      char = "│",
      show_start = false, -- Disables horizontal top bars
      show_end = false, -- Disables horizontal bottom bars
      show_exact_scope = false, -- Turning this false helps ibl lock into the inner vertical guide cleanly
      priority = 500, -- Adding a set priority helps Neovim render virtual text more efficientl
      -- Treesitter node selections used to calculate the active scope
      include = {
        node_type = {
          -- Targets JSX/TSX tags aggressively
          typescript = { "jsx_element", "jsx_self_closing_element", "statement_block" },
          tsx = { "jsx_element", "jsx_self_closing_element", "statement_block" },
        },
      },
    },
  },
  -- 3. Set WebStorm colors specifically for ibl highlight groups
  init = function()
    vim.api.nvim_create_autocmd("ColorScheme", {
      callback = function()
        -- Inactive background indent lines (Subtle Gray/Dark)
        vim.api.nvim_set_hl(0, "IblIndent", { fg = "#2c323c", nocombine = true })
        -- Active Current Scope Line
        -- vim.api.nvim_set_hl(0, "IblScope", { fg = "#5c6370", nocombine = true }) -- A classic, muted dark gray feel a bit brighter than below color
        vim.api.nvim_set_hl(0, "IblScope", { fg = "#4b5263", nocombine = true }) -- current live one, A slightly darker, subtle slate gray
        -- belows are tested teal colors
        -- vim.api.nvim_set_hl(0, "IblScope", { fg = "#29a298", nocombine = true })
        -- vim.api.nvim_set_hl(0, "IblScope", { fg = "#195e59", nocombine = true })
        -- vim.api.nvim_set_hl(0, "IblScope", { fg = "#1f736d", nocombine = true })
        -- vim.api.nvim_set_hl(0, "IblScope", { fg = active_indentline_color, nocombine = true })
      end,
    })
  end,
}
