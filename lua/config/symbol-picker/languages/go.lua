-- Go (gopls). Measured 2026-11-10:
--   * a named type is `Struct`, `Interface`, or `Class` for the rest
--     (`type Status int`), but a named func type (`type Handler func()`)
--     arrives as `Function`
--   * methods are top-level rows named `(*Service).Find`
--   * struct fields are `Field` children, interface methods `Method` children
--   * locals and closures are not reported at all

local TYPE_NODES = { type_alias = true, type_spec = true }
-- Kinds that can own methods
local RECEIVER_KINDS = { Struct = true, Type = true }

---@type symbol_picker.Language
return {
  structure = { "Function", "Interface", "Method", "Struct", "Type" },
  data = { "Constant", "Field", "Variable" },
  -- A named type that is not a struct or an interface
  kinds = { Type = { like = "Class" } },

  resolve = function(symbol, ctx)
    -- Type declarations are top-level only
    if symbol.parent then
      return
    end
    if symbol.kind == "Class" then
      -- Go has no classes: this is every named type that is not a struct or
      -- an interface (`type Status int`, `type Labels map[string]string`)
      symbol.kind = "Type"
    elseif symbol.kind == "Function" then
      local node = ctx.node(symbol)
      local declaration = node and node:parent()
      if declaration and TYPE_NODES[declaration:type()] then
        symbol.kind = "Type"
      end
    end
  end,

  -- Nests each method under its type, as GoLand does: a file with a hundred
  -- flat `(*Context).Name` rows is hard to scan. A method whose type is
  -- declared in another file stays where it is, under its full name.
  arrange = function(symbols)
    local types = {}
    for _, symbol in ipairs(symbols) do
      if RECEIVER_KINDS[symbol.kind] then
        types[symbol.name] = symbol
      end
    end

    local top = {}
    for _, symbol in ipairs(symbols) do
      local receiver, name
      if symbol.kind == "Method" then
        -- `(*Service).Find`, `(Status).String`, `(*Pair[K, V]).Get`
        receiver, name = symbol.name:match("^%(%*?([%w_]+)[^)]*%)%.(.+)$")
      end
      local owner = receiver and types[receiver]
      if owner then
        symbol.name, symbol.parent = name, owner
        -- After the fields, in source order
        owner.children[#owner.children + 1] = symbol
      else
        top[#top + 1] = symbol
      end
    end
    return top
  end,
}
