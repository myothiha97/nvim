-- Rules for every language without a file of its own: the server's kinds are
-- trusted as they are. Give a language its own file once this is not enough.

---@type symbol_picker.Language
return {
  structure = {
    "Class",
    "Constructor",
    "Enum",
    "Function",
    "Interface",
    "Method",
    "Module",
    "Namespace",
    "Struct",
  },
  data = {
    "Constant",
    "EnumMember",
    "Field",
    "Object",
    "Property",
    "Variable",
  },
}
