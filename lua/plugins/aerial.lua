-- WIP:
-- post_parse_symbol still does not able to display certain react symbols like built in hooks and custom hooks
-- for Go, the aerial config still cant distinguish betweeen normal function and method

local post_parse_symbol = function(bufnr, item, ctx)
  -- 1. Scope exclusively to JS, TS, JSX, and TSX filetypes
  local ft = vim.bo[bufnr].filetype
  local js_ts_filetypes = {
    javascript = true,
    typescript = true,
    javascriptreact = true,
    typescriptreact = true,
  }

  if not js_ts_filetypes[ft] then
    return true
  end

  -- Catch Variable, Constant, Function, and Component
  if item.kind == "Variable" or item.kind == "Constant" or item.kind == "Function" or item.kind == "Component" then
    local end_line = math.min(item.lnum + 2, item.end_lnum or item.lnum)
    local lines = vim.api.nvim_buf_get_lines(bufnr, item.lnum - 1, end_line, false)
    local text = table.concat(lines, " ")

    -- Stricter check: Ensures the variable is directly assigned to a function.
    -- This prevents inline arrows (like inside .find or .map) from being mislabeled.
    local is_func = text:find("useCallback")
      or text:find("useMemo")
      or text:find("forwardRef")
      or text:find("memo")
      or text:match("=%s*%(.-%)%s*=>")
      or text:match("=%s*async%s*%(.-%)%s*=>")
      or text:match("=%s*function")

    if is_func then
      -- PascalCase names starting with a capital letter are React components
      if item.name:match("^[A-Z]") then
        -- Map to "Component" to give it the unique React icon
        item.kind = "Component"
      else
        item.kind = "Function"
      end
      return true
    end

    -- Hide non-function variables (like selectedVariant) and constants
    if item.kind == "Variable" or item.kind == "Constant" then
      return false
    end
  end

  return true
end

return {
  "stevearc/aerial.nvim",
  keys = {
    {
      "<leader>cs",
      function()
        require("aerial").toggle()
        if require("aerial").is_open() then
          require("aerial").tree_close_all()
        end
      end,
      desc = "Aerial Symbols View (Collapsed by default)",
    },
  },
  opts = function(_, opts)
    -- Sync options
    -- opts.autojump = true
    -- opts.highlight_on_hover = true
    -- opts.highlight_closest = true
    -- opts.highlight_mode = "last"

    -- Panel size & position rules (matching your 28% width choice)
    opts.default_direction = "right"
    -- opts.width = 0.28
    -- Dynamically clamp the 28% width between a minimum of 30 columns
    -- and a maximum of 43 columns, matching your snacks explorer layout logic.
    -- opts.width = math.min(math.max(math.floor(vim.o.columns * 0.28), 30), 43)
    opts.layout = {
      default_direction = "right",
      width = nil,
      min_width = 40,
      max_width = { 45, 0.32 }, -- Lesser of 45 columns or 35% width
    }
    opts.backends = { "treesitter", "lsp", "markdown", "man" }
    opts.filter_kind = {
      "Class",
      "Constructor",
      "Enum",
      "Function",
      "Interface",
      "Module",
      "Method",
      "Struct",
      "Variable",
      "Constant",
      "Component",
    }
    opts.icons = vim.tbl_deep_extend("force", opts.icons or {}, {
      Component = " ",
      ComponentCollapsed = " ", -- Keeps the React icon when the component node is collapsed
    })
    opts.post_parse_symbol = post_parse_symbol

    opts.manage_folds = false
    -- Block two-way sync between your code folds and the aerial tree
    opts.link_folds_to_tree = false
    opts.link_tree_to_folds = false

    opts.on_first_symbols = function(bufnr)
      require("aerial").tree_close_all(bufnr)
    end
    opts.keymaps = {
      -- ["<2-LeftMouse>"] = "actions.tree_toggle", -- Double click to expand/collapse node
      ["<RightMouse>"] = "actions.tree_toggle",
    }
    return opts
  end,
  config = function(_, opts)
    -- Run standard base setup
    require("aerial").setup(opts)
    vim.api.nvim_set_hl(0, "AerialComponentIcon", { fg = "#61afef" })
    -- Force Aerial's hover highlight to use your theme's grep/search highlight color
    vim.api.nvim_set_hl(0, "AerialHoverHighlight", { link = "Search" })
  end,
}
