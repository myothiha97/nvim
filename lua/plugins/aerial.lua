return {
  "stevearc/aerial.nvim",
  opts = function(_, opts)
    -- Sync options
    opts.autojump = true
    opts.highlight_on_hover = true
    opts.highlight_closest = true
    opts.highlight_mode = "last"

    -- Panel size & position rules (matching your 28% width choice)
    opts.default_direction = "right"
    -- opts.width = 0.28
    -- Dynamically clamp the 28% width between a minimum of 30 columns
    -- and a maximum of 43 columns, matching your snacks explorer layout logic.
    -- opts.width = math.min(math.max(math.floor(vim.o.columns * 0.28), 30), 43)
    opts.layout = {
      default_direction = "right",
      width = nil,
      min_width = 30,
      max_width = { 43, 0.30 }, -- Lesser of 43 columns or 28% width
    }

    opts.manage_folds = false
    -- Block two-way sync between your code folds and the aerial tree
    opts.link_folds_to_tree = false
    opts.link_tree_to_folds = false
    return opts
  end,
  config = function(_, opts)
    -- Run standard base setup
    require("aerial").setup(opts)

    -- Force Aerial's hover highlight to use your theme's grep/search highlight color
    vim.api.nvim_set_hl(0, "AerialHoverHighlight", { link = "Search" })
  end,
}
