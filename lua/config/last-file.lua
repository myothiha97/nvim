-- Per-directory "last open file" -- the VS Code / WebStorm behaviour: reopening
-- a project puts you back in the file you were last editing, at the cursor
-- position you left it, with the file tree beside it.
--
-- Storage mirrors config/quickfix-persistence.lua exactly: one JSON file per
-- project root under stdpath("state"), named by the root's sha256. The cost is
-- one bounded read at startup and one bounded write on exit. Nothing here runs
-- on an interactive path -- no CursorMoved, no BufEnter, no timer.
--
-- persistence.nvim stays disabled (lua/plugins/performance.lua). This is
-- deliberately NOT a session manager: it restores one file, not a window
-- layout, so there is no session state to go stale or fight with the explorer.

local M = {}

--- The project root this record belongs to.
---
--- It cannot just be the cwd. `nvim <dir>` does NOT chdir into <dir>, so
--- opening two different projects from the same shell would collide on one
--- record. The startup hook calls `set_root` with the directory it was given;
--- everything else falls back to the cwd.
local root = nil

---@param dir string
function M.set_root(dir)
  if type(dir) == "string" and dir ~= "" then
    root = vim.fs.normalize(dir)
  end
end

local function state_file()
  local dir = root or vim.fs.normalize(vim.uv.cwd() or vim.fn.getcwd())
  local base = vim.fs.joinpath(vim.fn.stdpath("state"), "last-file")
  return vim.fs.joinpath(base, vim.fn.sha256(dir) .. ".json")
end

--- Only ordinary, named, on-disk file buffers qualify.
---
--- The dashboard, the explorer, oil, terminals and scratch buffers all have a
--- non-empty `buftype` or no name, and none of them is "the file you were
--- working on". Quitting while one of those is focused must leave the previous
--- record alone rather than overwrite it with something unopenable.
local function recordable(buf)
  if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].buftype ~= "" then
    return false
  end

  local name = vim.api.nvim_buf_get_name(buf)
  return name ~= "" and vim.fn.filereadable(name) == 1
end

--- Record the active buffer. Called from VimLeavePre, so it covers `:wq`,
--- `<leader>qq`, `:qa` and every other exit, rather than hooking one command.
function M.save()
  local buf = vim.api.nvim_get_current_buf()
  if not recordable(buf) then
    return
  end

  local lnum, col = 1, 0
  if vim.api.nvim_win_get_buf(0) == buf then
    local ok, pos = pcall(vim.api.nvim_win_get_cursor, 0)
    if ok then
      lnum, col = pos[1], pos[2]
    end
  end

  local target = state_file()
  if not pcall(vim.fn.mkdir, vim.fs.dirname(target), "p") then
    return
  end

  local ok_json, json = pcall(vim.json.encode, {
    file = vim.api.nvim_buf_get_name(buf),
    lnum = lnum,
    col = col,
  })
  if not ok_json then
    return
  end

  pcall(vim.fn.writefile, { json }, target)
end

--- The remembered entry, or nil when there is none or the file is gone.
function M.read()
  local target = state_file()
  if vim.fn.filereadable(target) ~= 1 then
    return nil
  end

  local ok_read, lines = pcall(vim.fn.readfile, target)
  if not ok_read or #lines == 0 then
    return nil
  end

  local ok_json, decoded = pcall(vim.json.decode, table.concat(lines, "\n"))
  if not ok_json or type(decoded) ~= "table" then
    return nil
  end

  local file = decoded.file
  -- A file deleted or renamed since the last session must not resurrect as an
  -- empty buffer with a stale name.
  if type(file) ~= "string" or file == "" or vim.fn.filereadable(file) ~= 1 then
    return nil
  end

  return { file = file, lnum = tonumber(decoded.lnum) or 1, col = tonumber(decoded.col) or 0 }
end

--- Open the remembered file in the current window. Returns whether it did.
function M.restore()
  local saved = M.read()
  if not saved then
    return false
  end

  if not pcall(vim.cmd.edit, vim.fn.fnameescape(saved.file)) then
    return false
  end

  -- The file can have shrunk since the last session, and a cursor past the end
  -- throws rather than clamping.
  local last_line = vim.api.nvim_buf_line_count(0)
  pcall(vim.api.nvim_win_set_cursor, 0, { math.min(saved.lnum, last_line), saved.col })
  return true
end

return M
