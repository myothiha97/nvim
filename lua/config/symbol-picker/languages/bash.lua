-- Shell scripts (bashls). Measured 2026-11-10:
--   * the list is flat: no symbol has children or a parent
--   * every assignment is a `Variable`, including `local` ones inside a function

---@type symbol_picker.Language
return {
  structure = { "Function" },
  data = { "Variable" },

  resolve = function(symbol, ctx)
    if symbol.kind ~= "Variable" then
      return
    end
    -- The server gives no parent, so the syntax tree says if this is a local
    local node = ctx.node(symbol)
    while node do
      if node:type() == "function_definition" then
        symbol.level = 3
        return
      end
      node = node:parent()
    end
  end,
}
