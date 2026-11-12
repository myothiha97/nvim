-- Symbols popup (<leader>ss): a file-structure picker built on Snacks.picker.
--
-- Why not plain `Snacks.picker.lsp_symbols()`: it filters on the kind the
-- language server sends, and servers mislabel a lot. Measured 2026-11-10 on a
-- 1,203-line TSX file: vtsls reported 9 top-level symbols, 8 of them as
-- `Variable` (arrow functions, components, type aliases), so the old kind
-- filter showed 1 row.
--
-- How it works:
--   1. Ask the server for the buffer's symbols once.
--   2. Let the language's rules fix each symbol's kind and name.
--   3. Show the rows for the current detail level. Cycling the level rebuilds
--      the rows from the cached answer, without a second request.
--
-- Detail levels, cycled inside the popup with <C-o> (or `a` in normal mode):
--   1 structure   callables and types
--   2 + data      plus constants, variables, fields and properties
--   3 all         everything the server reports
-- A symbol hidden at a level hides its children too.
--
-- Nothing here runs until the key is pressed: no autocmds and no timers.
--
-- ADDING A LANGUAGE: create `languages/<name>.lua` returning a
-- `symbol_picker.Language` and list its filetypes in LANGUAGES below. Probe
-- what the server really sends first; every existing file records what was
-- measured, because the kinds are rarely what you would expect.

local M = {}

---@class symbol_picker.Symbol
---@field name string
---@field kind string LSP kind name, or a custom kind its language declares in `kinds`
---@field detail string
---@field lnum integer 1-based line of the name
---@field col integer 0-based byte column of the name
---@field end_lnum integer
---@field end_col integer
---@field parent? symbol_picker.Symbol already resolved when a rule sees the child
---@field children symbol_picker.Symbol[]
---@field level? integer lowest detail level that shows the symbol

---@class symbol_picker.Context
---@field buf integer
---@field filetype string
---@field node fun(symbol: symbol_picker.Symbol): TSNode? treesitter node at the symbol's name

---@class symbol_picker.Kind a kind the language server does not have
---@field like string LSP kind whose icon colour (and icon, unless `icon` is set) it borrows
---@field icon? string

---@class symbol_picker.Language
---@field structure string[] kinds shown from detail level 1
---@field data string[] kinds shown from detail level 2; any other kind needs level 3
---@field kinds? table<string, symbol_picker.Kind> custom kinds its rules introduce
---@field resolve? fun(symbol: symbol_picker.Symbol, ctx: symbol_picker.Context) may set `kind`, `name` or `level`
---@field arrange? fun(symbols: symbol_picker.Symbol[]): symbol_picker.Symbol[] reshapes the resolved tree: top level in, top level out

-- filetype -> module under config.symbol-picker.languages
local LANGUAGES = {
  bash = "bash",
  go = "go",
  javascript = "node",
  javascriptreact = "node",
  json = "data",
  jsonc = "data",
  python = "python",
  sh = "bash",
  toml = "data",
  typescript = "node",
  typescriptreact = "node",
  yaml = "data",
  zsh = "bash",
}

local LEVELS = { "structure", "+ data", "all" }
local SYMBOL_METHOD = "textDocument/documentSymbol"

-- Session-wide, so the level you choose stays for the next file
local detail = 1

---@param filetype string
---@return symbol_picker.Language
local function language(filetype)
  return require("config.symbol-picker.languages." .. (LANGUAGES[filetype] or "default"))
end

---@param a symbol_picker.Symbol
---@param b symbol_picker.Symbol
local function by_position(a, b)
  if a.lnum ~= b.lnum then
    return a.lnum < b.lnum
  end
  return a.col < b.col
end

-- Turns the server's answer into a tree in source order. Handles both shapes a
-- server may send: nested `DocumentSymbol` and flat `SymbolInformation`.
---@param result table[]
---@param buf integer
---@param encoding string the client's offset encoding
---@return symbol_picker.Symbol[]
local function parse(result, buf, encoding)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

  -- LSP columns count in the client's encoding; the cursor needs bytes
  local function position(pos)
    local line = lines[pos.line + 1]
    local col = line and vim.str_byteindex(line, encoding, pos.character, false) or pos.character
    return pos.line + 1, col
  end

  ---@param raw table
  ---@param parent? symbol_picker.Symbol
  ---@return symbol_picker.Symbol
  local function convert(raw, parent)
    local range = raw.selectionRange or raw.location.range
    local lnum, col = position(range.start)
    local end_lnum, end_col = position(range["end"])
    ---@type symbol_picker.Symbol
    local symbol = {
      name = raw.name,
      kind = vim.lsp.protocol.SymbolKind[raw.kind] or "Unknown",
      detail = raw.detail or "",
      lnum = lnum,
      col = col,
      end_lnum = end_lnum,
      end_col = end_col,
      parent = parent,
      children = {},
    }
    for _, child in ipairs(raw.children or {}) do
      symbol.children[#symbol.children + 1] = convert(child, symbol)
    end
    table.sort(symbol.children, by_position)
    return symbol
  end

  local symbols = {}
  for _, raw in ipairs(result) do
    symbols[#symbols + 1] = convert(raw)
  end
  table.sort(symbols, by_position)
  return symbols
end

-- The buffer is parsed once per popup; a buffer without a parser gets a lookup
-- that always answers nil, so rules must cope with a missing node.
---@param buf integer
---@return fun(symbol: symbol_picker.Symbol): TSNode?
local function node_lookup(buf)
  local ok, parser = pcall(vim.treesitter.get_parser, buf, nil, { error = false })
  local tree = ok and parser and parser:parse()[1]
  local root = tree and tree:root()
  return function(symbol)
    if not root then
      return nil
    end
    local row = symbol.lnum - 1
    return root:named_descendant_for_range(row, symbol.col, row, symbol.col)
  end
end

-- Parents first, so a rule can read the resolved kind of `symbol.parent`
---@param symbols symbol_picker.Symbol[]
---@param lang symbol_picker.Language
---@param kind_level table<string, integer>
---@param ctx symbol_picker.Context
local function resolve(symbols, lang, kind_level, ctx)
  for _, symbol in ipairs(symbols) do
    if lang.resolve then
      lang.resolve(symbol, ctx)
    end
    symbol.level = symbol.level or kind_level[symbol.kind] or #LEVELS
    resolve(symbol.children, lang, kind_level, ctx)
  end
end

---@param lang symbol_picker.Language
---@return table<string, integer>
local function kind_levels(lang)
  local levels = {}
  for _, kind in ipairs(lang.data) do
    levels[kind] = 2
  end
  for _, kind in ipairs(lang.structure) do
    levels[kind] = 1
  end
  return levels
end

-- The first level from `from` that shows anything. A JSON or YAML file has no
-- callables at all, and an empty popup would look broken.
---@param symbols symbol_picker.Symbol[]
---@param from integer
---@return integer
local function level_with_rows(symbols, from)
  for level = from, #LEVELS do
    for _, symbol in ipairs(symbols) do
      if symbol.level <= level then
        return level
      end
    end
  end
  return #LEVELS
end

---@param symbols symbol_picker.Symbol[]
---@param level integer
---@param buf integer
---@return snacks.picker.finder.Item[]
local function rows(symbols, level, buf)
  local file = vim.api.nvim_buf_get_name(buf)
  local items = {}

  ---@param list symbol_picker.Symbol[]
  ---@param parent snacks.picker.finder.Item
  local function add(list, parent)
    local last
    for _, symbol in ipairs(list) do
      if symbol.level <= level then
        local item = {
          -- The prompt matches names only: with the kind in here, "find" also
          -- hit every `Function` row. Type `kind:method` to filter by kind.
          text = symbol.name,
          name = symbol.name,
          kind = symbol.kind,
          detail = symbol.detail,
          parent = parent,
          buf = buf,
          file = file,
          pos = { symbol.lnum, symbol.col },
          end_pos = { symbol.end_lnum, symbol.end_col },
        }
        items[#items + 1] = item
        last = item
        add(symbol.children, item)
      end
    end
    -- The tree guides close on the last visible child of each parent
    if last then
      last.last = true
    end
  end

  -- Snacks draws tree guides from `parent` and `last`, and stops at a root item
  add(symbols, { text = "", root = true })
  return items
end

-- One row, drawn like the stock LSP symbols picker: tree guides, kind icon,
-- name highlighted as code. Only the kinds a language adds need a lookup.
---@param lang symbol_picker.Language
---@return snacks.picker.format
local function formatter(lang)
  return function(item, picker)
    local icons = picker.opts.icons.kinds
    local custom = lang.kinds and lang.kinds[item.kind]
    local kind = custom and custom.like or (icons[item.kind] and item.kind or "Unknown")
    local line = Snacks.picker.format.tree(item, picker)
    line[#line + 1] = { custom and custom.icon or icons[kind], "SnacksPickerIcon" .. kind }
    line[#line + 1] = { " " }
    Snacks.picker.highlight.format(item, item.name, line)
    return line
  end
end

---@param level integer
local function title(level)
  return ("Symbols (%s)"):format(LEVELS[level])
end

---@param buf integer
---@param symbols symbol_picker.Symbol[]
---@param lang symbol_picker.Language
local function show(buf, symbols, lang)
  local level = level_with_rows(symbols, detail)
  local cycle = { "symbols_cycle_detail", mode = { "n", "i" }, desc = "Cycle symbol detail level" }
  local cycle_normal = { "symbols_cycle_detail", mode = "n", desc = "Cycle symbol detail level" }

  Snacks.picker.lsp_symbols({
    title = title(level),
    finder = function()
      return rows(symbols, level, buf)
    end,
    format = formatter(lang),
    -- Filtering keeps the parents of a match and the source order, so the list
    -- stays a tree while you type
    matcher = { keep_parents = true, sort = false },
    -- WARN: SILENT FAILURE. The name must not match a snacks built-in action
    -- (it would replace it), and a typo in the keys below is typed as text.
    actions = {
      symbols_cycle_detail = function(picker)
        -- Step from the level on screen, which may be above the saved one
        detail = level % #LEVELS + 1
        level = level_with_rows(symbols, detail)
        picker.title = title(level)
        picker:find()
      end,
    },
    win = {
      -- `a` is normal mode only, so the prompt still types the letter
      input = { keys = { ["<C-o>"] = cycle, ["a"] = cycle_normal } },
      list = { keys = { ["<C-o>"] = cycle_normal, ["a"] = cycle_normal } },
    },
  })
end

--- Opens the symbols popup for the current buffer.
function M.open()
  local buf = vim.api.nvim_get_current_buf()
  -- The first server that can answer. Stock snacks merges every server's list,
  -- which duplicates rows when two servers both report symbols.
  local client = vim.lsp.get_clients({ bufnr = buf, method = SYMBOL_METHOD })[1]
  if not client then
    Snacks.notify.warn("No language server with symbols is attached to this buffer", { title = "Symbols" })
    return
  end

  local params = { textDocument = vim.lsp.util.make_text_document_params(buf) }
  client:request(
    SYMBOL_METHOD,
    params,
    vim.schedule_wrap(function(err, result)
      if not vim.api.nvim_buf_is_valid(buf) then
        return
      end
      if err or not result or vim.tbl_isempty(result) then
        local message = err and ("Symbol request failed: " .. tostring(err.message)) or "No symbols in this buffer"
        Snacks.notify.warn(message, { title = "Symbols" })
        return
      end

      local filetype = vim.bo[buf].filetype
      local lang = language(filetype)
      local symbols = parse(result, buf, client.offset_encoding)
      resolve(symbols, lang, kind_levels(lang), { buf = buf, filetype = filetype, node = node_lookup(buf) })
      if lang.arrange then
        symbols = lang.arrange(symbols)
      end
      show(buf, symbols, lang)
    end),
    buf
  )
end

return M
