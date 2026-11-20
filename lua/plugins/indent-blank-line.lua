return {
  "lukas-reineke/indent-blankline.nvim",
  main = "ibl",
  -- Enabled 2026-11-20 to tell nested block scopes apart. Chosen over snacks'
  -- indent, which stays off in snacks.lua: do not enable both, or every guide
  -- is drawn twice.
  --
  -- Accepted cost: guides refresh on scroll and edits, and the scope line on
  -- cursor moves. ibl debounces this (200 ms by default), so a held j/k does not
  -- redraw on every keystroke.
  --
  -- Loaded on the first real file (LazyFile), not at startup.
  event = "LazyFile",
  ---@module "ibl"
  ---@type ibl.config
  opts = {
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
      -- WHY THIS LIST: ibl's "scope" is a treesitter node, not the indent level
      -- the cursor sits in. Its built-in lists cover only functions, if/for and
      -- blocks, so inside an object, table, call or argument list nothing lit up
      -- (a nested Lua table in variants.lua showed no active guide at all). These
      -- add the multi-line containers per language. The innermost match wins.
      --
      -- A one-line `{ a = 1 }` cannot steal the scope: ibl looks up the node from
      -- column 0 of the cursor line, so only a node that started on an earlier
      -- line can contain it.
      include = {
        node_type = {
          lua = { "table_constructor", "arguments", "parameters" },
          typescript = {
            "object", "array", "arguments", "formal_parameters", "object_pattern", "array_pattern",
            "class_body", "interface_body", "object_type", "enum_body", "switch_body", "named_imports",
          },
          tsx = {
            "object", "array", "arguments", "formal_parameters", "object_pattern", "array_pattern",
            "class_body", "interface_body", "object_type", "enum_body", "switch_body", "named_imports",
            "jsx_element", "jsx_self_closing_element",
          },
          javascript = {
            "object", "array", "arguments", "formal_parameters", "object_pattern", "array_pattern",
            "class_body", "switch_body", "named_imports", "jsx_element", "jsx_self_closing_element",
          },
          go = {
            "literal_value", "argument_list", "parameter_list", "field_declaration_list", "interface_type",
            "import_spec_list", "const_declaration", "var_declaration", "type_switch_statement", "select_statement",
          },
          python = { "block", "dictionary", "list", "set", "tuple", "argument_list", "parameters" },
        },
      },
    },
    -- Panels whose leading spaces are layout, not code indentation. The
    -- dashboard would otherwise draw guides through its centred menu.
    exclude = {
      filetypes = {
        "Trouble",
        "trouble",
        "help",
        "lazy",
        "mason",
        "notify",
        "oil",
        "snacks_dashboard",
        "snacks_notif",
        "snacks_terminal",
        "snacks_win",
        "snacks_picker_list",
        "snacks_picker_preview",
      },
    },
  },
  -- With the cursor ON a bracket, ibl's active scope becomes that bracket's
  -- block, not the block around the line. ibl looks the scope up from column 0
  -- of the cursor line, and on `foo = {` column 0 is outside the table.
  --
  -- WARN: SILENT FAILURE. This replaces ibl's internal
  -- `ibl.scope.get_cursor_range`. If an update renames it, the bracket case
  -- quietly falls back to ibl's default and nothing errors. Re-check after
  -- `:Lazy update`: cursor on a `{` that ends a line should light that block.
  config = function(_, opts)
    require("ibl").setup(opts)

    local pairs_by_char = require("config.bracket-match").PAIRS
    local scope = require("ibl.scope")
    local default_range = scope.get_cursor_range
    scope.get_cursor_range = function(win)
      local range = default_range(win)
      local row, col = range[1], range[4]
      local line = vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(win), row, row + 1, false)[1] or ""
      if pairs_by_char[line:sub(col + 1, col + 1)] then
        return { row, col, row, col + 1 }
      end
      return range
    end

    require("config.bracket-match").setup()
  end,
  -- Neutral greys read by ROLE from config/ui.lua, so they follow the background.
  -- Idle guides sit just above the background; the active scope takes
  -- `guide_active`, which carries its own ceiling note in ui.lua.
  --
  -- MatchParen (config/bracket-match.lua) is a box, not a colour: `guide` grey
  -- behind the bracket, syntax colour kept, bold. The theme's own is white on
  -- red, the same alarm red as errors.
  init = function()
    vim.api.nvim_create_autocmd("ColorScheme", {
      callback = function()
        local surface = require("config.ui").surface
        vim.api.nvim_set_hl(0, "IblIndent", { fg = surface.raised, nocombine = true })
        vim.api.nvim_set_hl(0, "IblScope", { fg = surface.guide_active, nocombine = true })
        vim.api.nvim_set_hl(0, "MatchParen", { bg = surface.guide, bold = true })
      end,
    })
  end,
}
