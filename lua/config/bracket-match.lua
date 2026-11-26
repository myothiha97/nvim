-- Matching-bracket highlight, VS Code style: with the cursor ON a bracket, that
-- bracket and its pair get `MatchParen`. Anywhere else, the nearest pair AROUND
-- the cursor gets it, so you see which block or call you are in. Press `%` on a
-- bracket to jump between the two.
--
-- WHY NOT THE BUILT-IN matchparen: init.lua turns it off (`loaded_matchparen`)
-- because it runs a Vimscript `searchpairpos()` on EVERY cursor move. This one
-- asks the treesitter tree instead: one node lookup per move, then a short walk
-- up its parents. The pair comes from treesitter, not a text search: a bracket's
-- pair is a sibling under the same parent node. That also skips brackets inside
-- strings and comments for free, since those are not bracket nodes. The pair
-- around the cursor is the first parent node that starts and ends with one.
--
-- Uses the tree the highlighter already keeps. It never parses: right after an
-- edit the tree can be one change behind, which only costs a missed highlight.
-- No treesitter parser (plain text, big files) means no highlight.
local M = {}

local PAIRS = { ["("] = ")", ["["] = "]", ["{"] = "}", [")"] = "(", ["]"] = "[", ["}"] = "{" }
local OPENERS = { ["("] = true, ["["] = true, ["{"] = true }

M.PAIRS = PAIRS

local ns = vim.api.nvim_create_namespace("bracket_match")
-- Buffer holding the current marks, so a move off a bracket clears once and
-- then costs nothing.
local marked_buf

local function clear()
  if marked_buf then
    if vim.api.nvim_buf_is_valid(marked_buf) then
      vim.api.nvim_buf_clear_namespace(marked_buf, ns, 0, -1)
    end
    marked_buf = nil
  end
end

-- Returns the {row, col} of the bracket paired with the one at (row, col), or nil.
local function find_pair(buf, row, col, char)
  local ok, node = pcall(vim.treesitter.get_node, { bufnr = buf, pos = { row, col }, include_anonymous = true })
  if not ok or not node or node:type() ~= char then
    return nil
  end
  local parent = node:parent()
  if not parent then
    return nil
  end
  local want = PAIRS[char]
  local count = parent:child_count()
  -- An opener's pair is the LAST matching child, a closer's the FIRST, so a
  -- nested pair of the same kind under one parent cannot be picked by mistake.
  local from, to, step = 0, count - 1, 1
  if OPENERS[char] then
    from, to, step = count - 1, 0, -1
  end
  for i = from, to, step do
    local child = parent:child(i)
    if child and child:type() == want and not child:equal(node) then
      local r, c = child:start()
      return { r, c }
    end
  end
end

-- Returns the open and close {row, col} of the nearest pair around the cursor
-- node, or nil: the first parent whose first and last children are a pair
-- (`{ ... }` block, `( ... )` arguments, `[ ... ]` list).
local function find_enclosing(buf, row, col)
  -- No active highlighter means no tree to read. Without this check, every move
  -- in a parserless buffer (text, oil) searched the runtimepath for a parser:
  -- measured ~140 us per move, against ~0 with it.
  if not vim.treesitter.highlighter.active[buf] then
    return nil
  end
  local ok, node = pcall(vim.treesitter.get_node, { bufnr = buf, pos = { row, col }, include_anonymous = true })
  node = ok and node or nil
  while node do
    local first = node:child(0)
    if first and OPENERS[first:type()] then
      local last = node:child(node:child_count() - 1)
      if last and last:type() == PAIRS[first:type()] then
        return { first:start() }, { last:start() }
      end
    end
    node = node:parent()
  end
end

-- True when the text at {row, col} really is a bracket.
local function is_bracket_at(buf, p)
  local line = vim.api.nvim_buf_get_lines(buf, p[1], p[1] + 1, false)[1]
  return line ~= nil and PAIRS[line:sub(p[2] + 1, p[2] + 1)] ~= nil
end

local function update()
  local buf = vim.api.nvim_get_current_buf()
  local pos = vim.api.nvim_win_get_cursor(0)
  local row, col = pos[1] - 1, pos[2]
  local char = vim.api.nvim_get_current_line():sub(col + 1, col + 1)
  clear()
  local pair = PAIRS[char] and find_pair(buf, row, col, char)
  local open, close
  if pair then
    open, close = { row, col }, pair
  else
    -- Also covers a bracket that is only text (inside a string or comment).
    open, close = find_enclosing(buf, row, col)
  end
  -- The tree can be one edit behind (see the header), and error recovery adds
  -- zero-width MISSING brackets that are not in the text. Either can point past
  -- the end of a line, which made the extmark below throw on every move.
  if not open or not is_bracket_at(buf, open) or not is_bracket_at(buf, close) then
    return
  end
  for _, p in ipairs({ open, close }) do
    vim.api.nvim_buf_set_extmark(buf, ns, p[1], p[2], { end_col = p[2] + 1, hl_group = "MatchParen", priority = 1000 })
  end
  marked_buf = buf
end

function M.setup()
  local group = vim.api.nvim_create_augroup("bracket_match", { clear = true })
  -- Normal mode only. In insert mode the cursor sits BETWEEN characters, and a
  -- pair lighting up on every typed bracket is the noise this avoids.
  vim.api.nvim_create_autocmd("CursorMoved", { group = group, callback = update })
  vim.api.nvim_create_autocmd({ "InsertEnter", "BufLeave", "WinLeave" }, { group = group, callback = clear })
end

return M
