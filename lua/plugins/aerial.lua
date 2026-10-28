-- React-aware symbol list for JS/TS/JSX/TSX. The extra nodes (hook calls,
-- destructured hook results, object methods, `obj.fn = () => {}`) come from
-- after/queries/{javascript,typescript,tsx}/aerial.scm. This function decides
-- what each symbol is shown as, by reading its treesitter node:
--   Hook       use*() calls and custom hook definitions
--   Component  PascalCase functions, incl. memo()/forwardRef() (JSX languages only)
--   Function   other function values, plus useCallback()/useMemo() results
--   Object     an object literal holding functions, so its methods nest under it
-- Every other variable is hidden.
--
-- Do not go back to matching source text: `text:find("memo")` listed
-- `const memoryLimit = 5` as a function, and it cost a buffer read per symbol.

local ECMA_LANGS = { javascript = true, typescript = true, tsx = true }
-- Plain .ts has no JSX, so a PascalCase function there is a factory or a
-- decorator (NestJS `Roles()`), not a component. `javascript` also parses .jsx.
local COMPONENT_LANGS = { javascript = true, tsx = true }

local FUNCTION_NODES = { arrow_function = true, function_expression = true, generator_function = true }
-- Calls whose result is still a function or component, so they keep the
-- function/component row instead of the hook row
local FUNCTION_WRAPPERS = { useCallback = true, useMemo = true, memo = true, forwardRef = true }

local get_node_text = vim.treesitter.get_node_text

local function is_hook_name(name)
  return name:match("^use%u") ~= nil
end

-- `useState` for useState(...), `memo` for React.memo(...)
local function callee_name(call, bufnr)
  local fn = call:field("function")[1]
  if fn and fn:type() == "member_expression" then
    fn = fn:field("property")[1]
  end
  if fn and (fn:type() == "identifier" or fn:type() == "property_identifier") then
    return get_node_text(fn, bufnr)
  end
end

local function has_function_member(object)
  for child in object:iter_children() do
    local type = child:type()
    if type == "method_definition" then
      return true
    end
    if type == "pair" then
      local value = child:field("value")[1]
      if value and FUNCTION_NODES[value:type()] then
        return true
      end
    end
  end
  return false
end

local function set_function_kind(item, lang)
  if is_hook_name(item.name) then
    item.kind = "Hook"
  elseif COMPONENT_LANGS[lang] and item.name:match("^%u") then
    item.kind = "Component"
  else
    item.kind = "Function"
  end
end

local post_parse_symbol = function(bufnr, item, ctx)
  -- Only the treesitter backend hands over the matched nodes
  if ctx.backend_name ~= "treesitter" or not ECMA_LANGS[ctx.lang] then
    return true
  end
  if item.kind ~= "Variable" and item.kind ~= "Function" then
    return true
  end

  local symbol = ctx.match.symbol and ctx.match.symbol.node
  -- A statement call: useEffect(...) from aerial.scm, or a describe()/it() test
  -- block from aerial's own query, which must stay a Function
  if symbol and symbol:type() == "call_expression" then
    if is_hook_name(item.name) then
      item.kind = "Hook"
    end
    return true
  end

  local value = ctx.match.var_type and ctx.match.var_type.node
  if not value then
    -- Function declarations, and JS function variables the base query already typed
    set_function_kind(item, ctx.lang)
    return true
  end

  local type = value:type()
  if type == "as_expression" or type == "satisfies_expression" then
    value = value:named_child(0)
    type = value and value:type()
  end

  if FUNCTION_NODES[type] then
    set_function_kind(item, ctx.lang)
    return true
  end
  if type == "call_expression" then
    local callee = callee_name(value, bufnr)
    if callee and FUNCTION_WRAPPERS[callee] then
      set_function_kind(item, ctx.lang)
      return true
    end
    if callee and is_hook_name(callee) then
      -- "useState [count, setCount]": the hook says what it is, the binding says which
      item.kind = "Hook"
      item.name = callee .. " " .. (item.name:gsub("%s+", " "))
      return true
    end
    return false
  end
  if type == "object" and has_function_member(value) then
    item.kind = "Object"
    return true
  end

  -- Plain data (selectedVariant, items.find(...), config objects)
  return false
end

-- `l` in the panel: expand a collapsed row, otherwise jump like <CR>. A leaf or
-- an already open row has nothing to expand, and aerial's own `tree_open` would
-- then do nothing at all.
local function open_or_jump()
  local bufdata = require("aerial.data").get(0)
  local item = bufdata and bufdata:item(vim.api.nvim_win_get_cursor(0)[1])
  if item and bufdata:is_collapsable(item) and bufdata:is_collapsed(item) then
    require("aerial").tree_open()
  else
    require("aerial").select()
  end
end

-- The lualine breadcrumb is hidden by default. While it is drawn, aerial is
-- loaded at startup, attached to every buffer, and re-reads symbols after each
-- edit, even with the panel closed. Hidden, aerial does nothing until <leader>cs.
--
-- It is hidden by swapping in an empty component rather than removed, so it
-- keeps its slot, and lualine never `require`s the aerial component (which
-- would load the plugin). The key marks the slot, because lualine.get_config()
-- returns a deep copy and a table reference would not survive.
local BREADCRUMB_KEY = "aerial_breadcrumb"

local function hide_breadcrumb(component)
  component[1] = function()
    return ""
  end
  component.cond = function()
    return false
  end
end

-- Aerial runs only while it is on screen: the panel open in any tab, or the
-- breadcrumb shown. Once started it never stops by itself (it keeps attaching
-- every buffer you enter and re-reading symbols after each edit), so the last
-- panel closing (q, :q, <leader>cs) stops it here, and <leader>cs starts
-- it again through its own setup(). Nothing of aerial or of this file is left
-- running while it is off: the WinClosed watcher only exists while it runs.
--
-- WARN: SILENT FAILURE - stop_aerial() relies on aerial internals: the
-- "AerialSetup" and "AerialBuffer" augroups and the `b:aerial_backend` var.
-- A missing "AerialSetup" group is reported, not ignored. After `:Lazy update`,
-- check that closing the panel still leaves 0 autocmds in groups named Aerial*.
local setup_opts -- aerial's resolved opts, kept for restarting it
local running = false
local breadcrumb_shown = false
local watcher_group = "aerial_on_demand"

local function panel_open()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "aerial" then
      return true
    end
  end
  return false
end

local function detach_all()
  local backends = require("aerial.backends")
  local data = require("aerial.data")
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    local name = backends.get_attached_backend(bufnr)
    if name then
      backends.get_backend_by_name(name).detach(bufnr)
      pcall(vim.api.nvim_clear_autocmds, { group = "AerialBuffer", buffer = bufnr })
      vim.b[bufnr].aerial_backend = nil
      data.delete_buf(bufnr)
    end
  end
end

local function stop_aerial()
  if not running or breadcrumb_shown or panel_open() then
    return
  end
  running = false
  pcall(vim.api.nvim_del_augroup_by_name, watcher_group)
  if not pcall(vim.api.nvim_del_augroup_by_name, "AerialSetup") then
    vim.notify("aerial: no 'AerialSetup' group to remove, so it may keep running in the background", vim.log.levels.WARN)
  end
  detach_all()
  -- Closing the panel moves focus, and aerial reacts to that through a 10 ms
  -- throttled timer that is already queued and attaches the current buffer
  -- again. With the group gone nothing can queue another, so one late sweep
  -- after that timer is final.
  vim.defer_fn(function()
    if not running then
      detach_all()
    end
  end, 50)
end

local function start_aerial()
  if running then
    return
  end
  running = true
  -- On a restart aerial's own setup() re-creates its autocmds and attaches the
  -- current buffer; before the first use it only stores the opts.
  require("aerial").setup(vim.deepcopy(setup_opts))
  vim.api.nvim_create_autocmd("WinClosed", {
    group = vim.api.nvim_create_augroup(watcher_group, { clear = true }),
    callback = function(args)
      local win = tonumber(args.match)
      if win and vim.api.nvim_win_is_valid(win) and vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "aerial" then
        -- The window still exists during WinClosed, so check after it is gone
        vim.schedule(stop_aerial)
      end
    end,
  })
end

local function toggle_breadcrumb()
  local lualine = require("lualine")
  local config = lualine.get_config()
  for _, component in ipairs(config.sections.lualine_c) do
    if type(component) == "table" and component[BREADCRUMB_KEY] then
      breadcrumb_shown = component[1] ~= "aerial"
      if breadcrumb_shown then
        start_aerial()
        component[1] = "aerial"
        component.cond = nil
      else
        hide_breadcrumb(component)
      end
      lualine.setup(config)
      if not breadcrumb_shown then
        stop_aerial()
      end
      vim.notify("Aerial breadcrumb " .. (breadcrumb_shown and "on" or "off"))
      return
    end
  end
end

return {
  {
    "stevearc/aerial.nvim",
    -- LazyVim's extra loads aerial on LazyFile (every file open). A function is
    -- the only way to drop it: lazy.nvim merges list keys across fragments.
    event = function()
      return {}
    end,
    keys = {
      {
        "<leader>uB",
        toggle_breadcrumb,
        desc = "Toggle Aerial Breadcrumb",
      },
      {
        "<leader>cs",
        function()
          start_aerial()
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
        Hook = "󰛢 ",
        HookCollapsed = "󰛢 ",
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
        ["l"] = { callback = open_or_jump, desc = "Expand the symbol, or jump to it when there is nothing to expand" },
      }
      return opts
    end,
    config = function(_, opts)
      -- Only stores the opts (aerial lazy-loads); start_aerial() runs the real setup
      setup_opts = vim.deepcopy(opts)
      require("aerial").setup(opts)
      vim.api.nvim_set_hl(0, "AerialComponentIcon", { fg = "#61afef" })
      -- A link, not a new colour: Hook is a custom kind, so aerial defines no group for it
      vim.api.nvim_set_hl(0, "AerialHookIcon", { link = "AerialFunctionIcon" })
      -- Force Aerial's hover highlight to use your theme's grep/search highlight color
      vim.api.nvim_set_hl(0, "AerialHoverHighlight", { link = "Search" })
    end,
  },

  -- Hide the breadcrumb LazyVim's aerial extra adds; <leader>uB brings it back
  {
    "nvim-lualine/lualine.nvim",
    optional = true,
    opts = function(_, opts)
      for _, component in ipairs(opts.sections and opts.sections.lualine_c or {}) do
        if type(component) == "table" and component[1] == "aerial" then
          component[BREADCRUMB_KEY] = true
          hide_breadcrumb(component)
          break
        end
      end
    end,
  },
}
