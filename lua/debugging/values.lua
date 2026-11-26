-- How a variable reads in the debug panels (Variables, Watches) and inline,
-- modelled on GoLand: `name = {type} value`, one line per variable.
--
-- Delve's DAP values repeat the type in front of every compound value
-- (`chan main.Order 3/8`, `*main.Server {mu: …}`) and dap-ui printed the type
-- again before them, then wrapped up to 256 characters onto ~6 lines in the
-- 46-column sidebar. Here the value loses its type prefix, unsigned integers
-- lose Delve's ` = 0x…` suffix (GoLand's default integer format is decimal),
-- and channels read `len:3, cap:8`. The children (expand) still hold every
-- detail, and a cut value opens in full with double-click / <CR>
-- (debugging/variables.lua).
--
-- Pure string functions: no state, no requests. Called once per rendered
-- variable when a panel re-renders (on stop / expand), never on keystrokes.
-- Non-Go adapters pass through unchanged: their values don't start with
-- their type, so nothing is stripped.

local M = {}

-- `context.Context(*context.timerCtx)` -> `context.Context | *context.timerCtx`
-- (GoLand's interface notation). Only `Name(Concrete)`: a func type such as
-- `func(int) string` has a space or a second paren and is left alone.
function M.type_label(t)
  if not t or t == "" then
    return ""
  end
  local iface, concrete = t:match("^([%w_%./]+)%((%*?[%w_%./%[%]{}]+)%)$")
  if iface then
    return iface .. " | " .. concrete
  end
  return t
end

-- Value text without the repeated type and Delve's noise.
function M.summary(t, value)
  value = value or ""
  if t and t ~= "" then
    -- Interfaces: Delve's type is `iface(*concrete)` and so is the value's
    -- prefix, followed by ` *{…}` for a pointer; drop both.
    if value:sub(1, #t + 1) == t .. " " then
      value = value:sub(#t + 2)
    elseif value:sub(1, #t + 1) == t .. "(" and not t:match("^[%w_%./]+%(") then
      -- Delve's built-in formats put the readable form in parens, then the
      -- raw struct: `time.Time(2026-11-26T18:59:51Z, +124590){wall: …}`.
      -- Keep the readable part; the fields are one expand away.
      local rest = value:sub(#t + 2)
      value = rest:match("^(.-)%){") or rest:match("^(.*)%)$") or value
    end
    local iface = t:match("^[%w_%./]+%(") and t
    if iface and value:sub(1, 2) == "*{" then
      value = value:sub(2)
    end
    -- Unsigned integers: `8 = 0x8` -> `8`.
    if t:match("^uint%d*$") or t == "uintptr" then
      value = value:gsub("^(%d+) = 0x%x+$", "%1")
    end
    -- Channels: Delve prints `len/cap`.
    if M.is_chan(t) then
      local len, cap = value:match("^(%d+)/(%d+)$")
      if len then
        value = ("len:%s, cap:%s"):format(len, cap)
      end
    end
  end
  -- Delve ends map previews with a stray separator: `["a": 1, "b": 2, ]`.
  value = value:gsub(", %]$", "]")
  -- Newlines would break the one-line row (multi-line strings are escaped by
  -- Delve already; other adapters may not).
  return (value:gsub("%s*\n%s*", " "))
end

-- Cut `text` to `width` display cells, ending in "…" when cut.
function M.fit(text, width)
  if width <= 1 then
    return "…", true
  end
  if vim.fn.strdisplaywidth(text) <= width then
    return text, false
  end
  local out = vim.fn.strcharpart(text, 0, width - 1)
  while vim.fn.strdisplaywidth(out) > width - 1 do
    out = vim.fn.strcharpart(out, 0, vim.fn.strchars(out) - 1)
  end
  return out .. "…", true
end

-- The text after `{type} ` on a collapsed row, for `width` cells.
--   * scalars and strings: the value, cut with "…" if needed
--   * errors: the message (`{s: "boom"}` / `{msg: "boom", …}` -> "boom")
--   * slices / arrays: `len:3, cap:3`, plus the elements if they fit whole
--   * channels: `len:3, cap:8`
--   * structs, maps, pointers, interfaces: the value only if it fits whole,
--     else `{…}` / `[…]`. A half-cut struct (`{mu: sync.Mutex {_: s…`) says
--     nothing; GoLand shows only the type. Expand for the fields.
---@return string text, boolean cut
function M.value_text(t, value, width, expandable)
  local v = M.summary(t, value)
  if not expandable then
    return M.fit(v, width)
  end
  if M.is_chan(t) then
    return M.fit(v, width)
  end
  if t and t:match("^error%(") then
    local msg = v:match('^{s: (".-")}$') or v:match('^{msg: (".-")[,}]')
    if msg then
      return M.fit(msg, width)
    end
  end
  local loaded, rest = v:match("^(%(loaded %d+/%d+%) )(.*)$")
  rest = rest or v
  local len, cap, elems = rest:match("^len: (%d+), cap: (%d+), (.*)$")
  if len then
    local head = (loaded or "") .. ("len:%s, cap:%s"):format(len, cap)
    local full = head .. " " .. elems
    if vim.fn.strdisplaywidth(full) <= width then
      return full, false
    end
    return M.fit(head, width)
  end
  if vim.fn.strdisplaywidth(v) <= width then
    return v, false
  end
  local first = v:sub(1, 1)
  return (first == "[" and "[…]") or (first == "{" and "{…}") or M.fit(v, width), true
end

-- `{type}` label, at most `max` cells: an interface first drops its
-- interface name (`{*context.timerCtx}`), then the label is cut.
function M.type_text(t, max)
  local label = M.type_label(t)
  if label == "" then
    return ""
  end
  if vim.fn.strdisplaywidth(label) + 2 > max then
    label = label:match("| (.+)$") or label
  end
  return "{" .. M.fit(label, math.max(max - 2, 4)) .. "}"
end

-- The level to skip when a variable is expanded, or nil. Delve puts a
-- pointer's target in one unnamed child (`srv` -> `` -> fields) and an
-- interface's value in one `data` child (`err` -> `data` -> `` -> `s`);
-- GoLand opens straight to the fields. Only a single child that has children
-- itself is skipped, so a pointer to a scalar still shows its value row.
function M.unwrap(parent_type, children)
  if not parent_type or #children ~= 1 or children[1].variablesReference == 0 then
    return nil
  end
  local child = children[1]
  if child.name == "" and parent_type:sub(1, 1) == "*" then
    return child
  end
  if child.name == "data" and parent_type:match("^[%w_%./]+%(") then
    return child
  end
  return nil
end

function M.is_chan(t)
  return t ~= nil and (t:match("^chan[ <]") ~= nil or t:match("^<%-chan ") ~= nil)
end

return M
