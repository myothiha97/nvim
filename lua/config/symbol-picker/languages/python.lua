-- Python (basedpyright). Measured 2026-11-10:
--   * UPPER_CASE names are `Constant`, other assignments `Variable`
--   * parameters and locals are `Variable` children of their function
--   * class and instance attributes are `Variable` children of the class
--   * `@property` and `@classmethod` functions are plain `Method`

local CALLABLE_KINDS = { Function = true, Method = true }
local VALUE_KINDS = { Constant = true, Variable = true }

---@type symbol_picker.Language
return {
  structure = { "Class", "Function", "Method" },
  data = { "Constant", "Field", "Property", "Variable" },

  resolve = function(symbol)
    -- Parameters and locals: module and class attributes stay at the data level
    if VALUE_KINDS[symbol.kind] and symbol.parent and CALLABLE_KINDS[symbol.parent.kind] then
      symbol.level = 3
    end
  end,
}
