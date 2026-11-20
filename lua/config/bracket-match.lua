-- Matching-bracket highlight, VS Code style: with the cursor ON a bracket, that
-- bracket and its pair get `MatchParen`. Press `%` to jump between them.
--
-- WHY NOT THE BUILT-IN matchparen: init.lua turns it off (`loaded_matchparen`)
-- because it runs a Vimscript `searchpairpos()` on EVERY cursor move. This one
-- costs one byte compare per move and does real work only when the cursor sits
-- on a bracket. The pair comes from treesitter, not a text search: a bracket's
-- pair is a sibling under the same parent node. That also skips brackets inside
-- strings and comments for free, since those are not bracket nodes.
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

local function update()
  local buf = vim.api.nvim_get_current_buf()
  local pos = vim.api.nvim_win_get_cursor(0)
  local row, col = pos[1] - 1, pos[2]
  local char = vim.api.nvim_get_current_line():sub(col + 1, col + 1)
  clear()
  if not PAIRS[char] then
    return
  end
  local pair = find_pair(buf, row, col, char)
  if not pair then
    return
  end
  for _, p in ipairs({ { row, col }, pair }) do
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
