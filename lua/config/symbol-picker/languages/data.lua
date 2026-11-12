-- Data files (JSON, YAML, TOML). Every symbol is a key, so there is nothing to
-- hide: the detail levels all show the same full tree.
-- Measured 2026-11-10 (jsonls): keys arrive as `Module`, `Array`, `String`,
-- `Number` and `Boolean` by the type of their value, which the default rules
-- would cut down to the object keys alone.

---@type symbol_picker.Language
return {
  structure = {},
  data = {},

  resolve = function(symbol)
    symbol.level = 1
  end,
}
