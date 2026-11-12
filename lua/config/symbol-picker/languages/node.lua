-- JavaScript and TypeScript (vtsls): Node.js first, React second.
-- Measured 2026-11-10:
--   * `const`/`let`, arrow functions, type aliases and enum members all arrive
--     as `Variable`
--   * a callback is a `Function` named after its call:
--     `router.get("/users/:id") callback`, `users.find() callback`
--   * an object literal built inside a function leaks its keys as `Property`
--     and `Method` children of that function
--   * a class field holding an arrow function is a `Property`
--   * `detail` is always empty, so nothing can be read from it
--
-- The rules read the treesitter node, never the source text: matching text
-- once listed `const memoryLimit = 5` as a function (see plugins/aerial.lua).

local FUNCTION_NODES = { arrow_function = true, function_expression = true, generator_function = true }
local WRAPPER_NODES = { as_expression = true, parenthesized_expression = true, satisfies_expression = true }
local FIELD_NODES = { field_definition = true, public_field_definition = true }
-- Calls whose result is still a function or a component
local FUNCTION_WRAPPERS = { forwardRef = true, memo = true, useCallback = true }
local CALLABLE_KINDS = { Component = true, Constructor = true, Function = true, Hook = true, Method = true }
-- Callables whose plain variables are only locals
local LOCAL_SCOPE_KINDS = { Constructor = true, Function = true, Method = true }
-- A PascalCase function is a component only where JSX can exist; in plain
-- .ts or .js it is a factory or a decorator (NestJS `Roles()`)
local JSX_FILETYPES = { javascriptreact = true, typescriptreact = true }

---@param name string
---@param filetype string
---@return string kind
local function function_kind(name, filetype)
  if name:match("^use%u") then
    return "Hook"
  end
  if JSX_FILETYPES[filetype] and name:match("^%u") then
    return "Component"
  end
  return "Function"
end

-- `value as T`, `value satisfies T` and `(value)` all stand for `value`
---@param node? TSNode
---@return TSNode?
local function unwrap(node)
  while node and WRAPPER_NODES[node:type()] do
    node = node:named_child(0)
  end
  return node
end

-- `useCallback` for useCallback(...), `memo` for React.memo(...)
---@param call TSNode
---@param buf integer
---@return string?
local function callee_name(call, buf)
  local callee = call:field("function")[1]
  if callee and callee:type() == "member_expression" then
    callee = callee:field("property")[1]
  end
  if callee and (callee:type() == "identifier" or callee:type() == "property_identifier") then
    return vim.treesitter.get_node_text(callee, buf)
  end
end

---@param object TSNode
local function has_function_member(object)
  for child in object:iter_children() do
    local type = child:type()
    if type == "method_definition" then
      return true
    end
    if type == "pair" then
      local value = unwrap(child:field("value")[1])
      if value and FUNCTION_NODES[value:type()] then
        return true
      end
    end
  end
  return false
end

-- The declaration that owns a name. A destructured name sits a few levels
-- below its declarator: `const { a: [b] } = value`.
---@param node? TSNode
---@return TSNode?
local function declaration(node)
  for _ = 1, 5 do
    if not node then
      return nil
    end
    local type = node:type()
    if type == "variable_declarator" or type == "type_alias_declaration" then
      return node
    end
    node = node:parent()
  end
end

-- vtsls names a callback after the call it is passed to. One that a string
-- labels is a real unit of the file (a route, a test block, an event
-- handler); the rest (`users.find()`, `items.map()`) are noise.
---@param symbol symbol_picker.Symbol
---@param call string the name without its " callback" suffix
local function resolve_callback(symbol, call)
  local effect = call:match("^(use%w*Effect)%(%)$")
  if effect then
    -- An effect has no variable to stand for it, so the callback is its row
    symbol.kind, symbol.name = "Hook", effect
  elseif call:match("%([\"'`]") then
    symbol.name = call
  else
    symbol.level = 3
  end
end

---@param symbol symbol_picker.Symbol
---@param ctx symbol_picker.Context
local function resolve_variable(symbol, ctx)
  if symbol.parent and symbol.parent.kind == "Enum" then
    symbol.kind = "EnumMember"
    return
  end

  local owner = declaration(ctx.node(symbol))
  if not owner then
    return
  end
  if owner:type() == "type_alias_declaration" then
    symbol.kind = "Type"
    return
  end

  local value = unwrap(owner:field("value")[1])
  local type = value and value:type()
  if FUNCTION_NODES[type] then
    symbol.kind = function_kind(symbol.name, ctx.filetype)
  elseif type == "call_expression" and FUNCTION_WRAPPERS[callee_name(value, ctx.buf)] then
    symbol.kind = function_kind(symbol.name, ctx.filetype)
  elseif type == "object" and has_function_member(value) then
    -- `const api = { get() {}, post: () => {} }`: its methods nest under it
    symbol.kind = "Object"
  elseif symbol.parent and LOCAL_SCOPE_KINDS[symbol.parent.kind] then
    -- A local of a plain function. Inside a component or a hook the same
    -- thing is its state, which stays at the data level.
    symbol.level = 3
  end
end

---@type symbol_picker.Language
return {
  structure = {
    "Class",
    "Component",
    "Constructor",
    "Enum",
    "Function",
    "Hook",
    "Interface",
    "Method",
    "Module",
    "Namespace",
    "Object",
    "Type",
  },
  data = { "Constant", "EnumMember", "Field", "Property", "Variable" },
  kinds = {
    Component = { icon = " ", like = "Function" },
    Hook = { icon = "󰛢 ", like = "Function" },
    Type = { like = "Interface" },
  },

  resolve = function(symbol, ctx)
    local kind, parent = symbol.kind, symbol.parent

    -- Placeholders for things without a name: `<function>`, `<unknown>`, `<class>`
    if symbol.name:match("^<.*>$") then
      symbol.level = 3
    elseif kind == "Function" then
      local call = symbol.name:match("^(.+) callback$")
      if call then
        resolve_callback(symbol, call)
      else
        symbol.kind = function_kind(symbol.name, ctx.filetype)
      end
    elseif (kind == "Property" or kind == "Method") and parent and CALLABLE_KINDS[parent.kind] then
      -- Keys of an object literal built inside a function body
      symbol.level = 3
    elseif kind == "Property" then
      -- Class field holding a function: `save = async () => {}`
      local node = ctx.node(symbol)
      local field = node and node:parent()
      local value = field and FIELD_NODES[field:type()] and unwrap(field:field("value")[1])
      if value and FUNCTION_NODES[value:type()] then
        symbol.kind = "Method"
      end
    elseif kind == "Variable" then
      resolve_variable(symbol, ctx)
    end
  end,
}
