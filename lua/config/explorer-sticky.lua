-- Sticky ancestor folders for the snacks explorer, like VS Code's sticky scroll.
--
-- When you scroll deep into the tree, the folders that contain the rows at the
-- top of the panel stay pinned there (`src > components > organisms`), so you
-- always know where you are. snacks (882c996) has nothing like this.
--
-- How it works, and why it is cheap:
--   * The explorer list is VIRTUAL: every scroll re-renders the visible rows in
--     `list:render()`. We wrap that one method on the explorer's own list
--     instance, so no other picker is touched.
--   * Each tree item already links to its folder through `item.parent`. Finding
--     the stack is a walk up those links for at most MAX_ROWS rows: no scan of
--     the list, no file system, no git.
--   * The pinned rows live in a small non-focusable float over the top of the
--     list window. It is only redrawn when the stack actually changes, which
--     happens when you cross a folder boundary, not on every scroll step.
--
-- The pinned rows COVER the rows under them, exactly like VS Code. If the
-- cursor is on a covered row, the deepest pinned rows are dropped so the cursor
-- row stays visible.
--
-- Measured 2026-11-23 (225 rows, 42-row window, 1840 scroll steps): snacks'
-- own render p50 1.48 ms; this adds p50 7 us when the stack is unchanged (76% of
-- steps) and p50 86 us / p95 235 us when the float is redrawn.
--
-- WARN: SILENT FAILURE. This replaces snacks INTERNALS on one list instance:
-- `list.render`, `list.close`, `list.visible`, `list:format()` and
-- `list:idx2row()` (snacks 882c996, picker/core/list.lua). If a snacks update
-- renames or reshapes any of them, the pinned rows stop appearing or go stale
-- with no error. Re-check after every snacks update: open `<leader>r`, scroll
-- deep into a folder, and confirm its parents stay pinned.
--
-- The band colour is `SnacksExplorerSticky`, defined in plugins/snacks.lua.

local M = {}

local MAX_ROWS = 5
local ns = vim.api.nvim_create_namespace("explorer_sticky")

--- Folders that contain `item`, shallowest first. The tree root (the cwd row,
--- the only item without a parent) is left out: it is the panel itself, the same
--- way VS Code never pins the workspace folder.
---@param item snacks.picker.Item?
local function ancestors(item)
  local ret = {}
  local dir = item and item.parent
  while dir and dir.parent do
    table.insert(ret, 1, dir)
    dir = dir.parent
  end
  return ret
end

--- The folders to pin. Slot k+1 holds the folder at depth k+1 above the row
--- that slot k+1 would cover, as long as it continues the stack above it. That
--- one rule gives VS Code's behaviour: a folder stays pinned while any of its
--- children are under the stack, and the next sibling folder replaces it.
---@param list snacks.picker.list
local function stack(list)
  local ret = {}
  local visible = list.visible or {}
  while #ret < MAX_ROWS do
    local chain = ancestors(visible[#ret + 1])
    local dir = chain[#ret + 1]
    if not dir or (#ret > 0 and chain[#ret] ~= ret[#ret]) then
      break
    end
    ret[#ret + 1] = dir
  end
  -- Never cover the cursor row.
  local cursor_row = list:idx2row(list.cursor)
  while #ret > 0 and #ret >= cursor_row do
    ret[#ret] = nil
  end
  return ret
end

---@param state {win?: integer, buf?: integer}
local function hide(state)
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_close(state.win, true)
  end
  state.win = nil
end

--- Draw `items` into the float, the same way snacks draws a list row
--- (`list:_render`), so icons, tree guides and highlights match exactly.
---@param list snacks.picker.list
---@param state {win?: integer, buf?: integer}
---@param items snacks.picker.Item[]
local function draw(list, state, items)
  if not (state.buf and vim.api.nvim_buf_is_valid(state.buf)) then
    state.buf = vim.api.nvim_create_buf(false, true)
    vim.bo[state.buf].bufhidden = "hide"
    -- WARN: SILENT FAILURE. The global normal-mode <Esc> (config/keymaps.lua)
    -- closes every float except buffers whose filetype starts with
    -- `snacks_picker`. Without this name, <Esc> in the explorer closes the
    -- pinned rows and they only come back on the next scroll.
    vim.bo[state.buf].filetype = "snacks_picker_sticky"
  end
  local buf = state.buf
  local lines, marks = {}, {}
  for i, item in ipairs(items) do
    local text, extmarks = list:format(item)
    lines[i] = text:gsub("\n", " ")
    marks[i] = extmarks
  end
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for row, extmarks in ipairs(marks) do
    for _, extmark in ipairs(extmarks) do
      local col = extmark.col
      extmark.col, extmark.row, extmark.field = nil, nil, nil
      pcall(vim.api.nvim_buf_set_extmark, buf, ns, row - 1, col, extmark)
    end
  end

  local list_win = list.win.win
  local config = {
    relative = "win",
    win = list_win,
    row = 0,
    col = 0,
    width = vim.api.nvim_win_get_width(list_win),
    height = #items,
    focusable = false,
    style = "minimal",
    -- One step above the list (33 in the sidebar layout), so the pinned rows
    -- sit with the explorer and under any float that covers it. A fixed 45 put
    -- them ABOVE the <leader>e oil backdrop (40, plugins/oil.lua): the rest of
    -- the sidebar went blank but the pinned rows stayed bright.
    zindex = (vim.api.nvim_win_get_config(list_win).zindex or 44) + 1,
  }
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_set_config(state.win, config)
  else
    config.noautocmd = true
    state.win = vim.api.nvim_open_win(buf, false, config)
    vim.wo[state.win].winhighlight = "Normal:SnacksExplorerSticky,NormalFloat:SnacksExplorerSticky"
    vim.wo[state.win].wrap = false
  end
end

--- Pin ancestor folders at the top of `picker`'s list. Call once, from the
--- explorer's `on_show`.
---@param picker snacks.Picker
function M.attach(picker)
  local list = picker.list
  if list._sticky then
    return
  end
  local state = {} ---@type {win?: integer, buf?: integer, items?: snacks.picker.Item[], width?: integer}
  list._sticky = state

  local render = list.render
  list.render = function(self)
    render(self)
    if not self.win:valid() or self.reverse then
      return hide(state)
    end
    local items = stack(self)
    local width = vim.api.nvim_win_get_width(self.win.win)
    -- Skip the redraw unless the stack or the width changed: most scroll steps
    -- stay inside the same folders.
    local same = width == state.width and state.items and #items == #state.items
    if same then
      for i = 1, #items do
        if items[i] ~= state.items[i] then
          same = false
          break
        end
      end
    end
    if same and (#items == 0 or (state.win and vim.api.nvim_win_is_valid(state.win))) then
      return
    end
    state.items, state.width = items, width
    if #items == 0 then
      return hide(state)
    end
    draw(self, state, items)
  end

  local close = list.close
  list.close = function(self)
    hide(state)
    if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
      vim.api.nvim_buf_delete(state.buf, { force = true })
    end
    return close(self)
  end
end

return M
