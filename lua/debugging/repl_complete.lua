-- REPL completion: a blink.cmp source that asks the debug adapter (DAP
-- `completions` request) for variables, fields and methods in scope, shown
-- in the normal blink menu while typing in the debug REPL.
--
-- Why not nvim-dap's own REPL omnifunc: it answers asynchronously by calling
-- vim.fn.complete(), which opens Vim's native popup next to blink's menu.
-- This source returns the same adapter items to blink instead.
--
-- Active only in the dap-repl buffer (plugins/ui.lua registers it for that
-- filetype) and only when the adapter supports completions (debugpy,
-- js-debug, netcoredbg; not Delve). Cost: one adapter request per completion
-- trigger there.

local Source = {}

local KIND = {
  method = "Method",
  ["function"] = "Function",
  constructor = "Constructor",
  field = "Field",
  variable = "Variable",
  class = "Class",
  interface = "Interface",
  module = "Module",
  property = "Property",
  unit = "Unit",
  value = "Value",
  enum = "Enum",
  keyword = "Keyword",
  snippet = "Snippet",
  text = "Text",
  color = "Color",
  file = "File",
  reference = "Reference",
  customcolor = "Color",
}

function Source.new()
  return setmetatable({}, { __index = Source })
end

local function session()
  return package.loaded["dap"] and require("dap").session() or nil
end

function Source:enabled()
  local s = session()
  return s ~= nil and (s.capabilities or {}).supportsCompletionsRequest == true
end

function Source:get_trigger_characters()
  local s = session()
  local chars = s and (s.capabilities or {}).completionTriggerCharacters
  return (chars and #chars > 0) and chars or { "." }
end

function Source:get_completions(ctx, callback)
  local s = session()
  local line, col = ctx.line, ctx.cursor[2] -- col: 0-based byte offset of the cursor
  local prompt = vim.fn.prompt_getprompt(ctx.bufnr)
  local offset = (prompt ~= "" and vim.startswith(line, prompt)) and #prompt or 0
  local text = line:sub(offset + 1, col)
  -- ".continue", ".frames" etc. are nvim-dap REPL commands, not code.
  if not s or vim.startswith(text, ".") then
    callback({ items = {}, is_incomplete_forward = false, is_incomplete_backward = false })
    return
  end

  local cancelled = false
  s:request("completions", {
    frameId = s.current_frame and s.current_frame.id,
    text = text,
    column = #text + 1,
  }, function(err, response)
    if cancelled then
      return
    end
    if err or not response then
      callback({ items = {}, is_incomplete_forward = true, is_incomplete_backward = true })
      return
    end
    local kinds = require("blink.cmp.types").CompletionItemKind
    local word_start = offset + vim.fn.match(text, [[\k*$]])
    local row = ctx.cursor[1] - 1
    local items = {}
    for _, t in ipairs(response.targets or {}) do
      -- `start`/`length`: what the adapter wants replaced, 0-based within
      -- `text` (same reading as nvim-dap's omnifunc). Otherwise the word
      -- before the cursor.
      local start = (t.start and (t.length or 0) > 0) and (offset + t.start) or word_start
      items[#items + 1] = {
        label = t.label,
        kind = kinds[KIND[t.type or ""] or "Variable"],
        detail = t.detail,
        sortText = t.sortText,
        textEdit = {
          newText = t.text or t.label,
          range = { start = { line = row, character = start }, ["end"] = { line = row, character = col } },
        },
      }
    end
    callback({ items = items, is_incomplete_forward = true, is_incomplete_backward = true })
  end)
  return function()
    cancelled = true
  end
end

return Source
