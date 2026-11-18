-- Open lazygit focused on the CURRENT file's uncommitted diff (<leader>gd).
--
-- Lazygit has no CLI option for this. `-f <path>` only filters the commit log,
-- never the Files panel (`lazygit --help`, 0.62.2). So this opens lazygit as
-- usual and then types into it what you would type by hand:
--
--   2              focus the Files panel
--   /<path><CR>    filter it to this file (lazygit's substring filter)
--   >              jump to the last row, i.e. the file under its folder rows
--
-- The `>` is only sent when exactly ONE changed path contains this file's path.
-- A root file like `README.md` also matches `docs/README.md`, and in lazygit's
-- tree the root files come first, so "last row" would select the wrong one.
-- With several matches the filter is applied and the cursor is left alone.
--
-- WARN: SILENT FAILURE. Everything here depends on lazygit's default keys and
-- screen text (`2`, `/`, `>`, the `Files` panel title). Remapping those in
-- lazygit's config.yml, or a lazygit release that renames the panel, makes
-- this open plain lazygit with no error. Re-test after a lazygit upgrade.

local M = {}

local POLL_MS = 20
local TIMEOUT_MS = 3000

-- Changed paths (relative to the repo root) that lazygit's filter would show
-- for `rel`. Lowercased on both sides, so it can only over-count, which just
-- skips the `>` jump; it never makes the jump land on a wrong file.
local function matching_changes(root, rel)
  local out = vim.fn.systemlist({ "git", "-C", root, "status", "--porcelain=v1", "--untracked-files=all" })
  if vim.v.shell_error ~= 0 then
    return nil
  end
  local needle = rel:lower()
  local matches = {}
  for _, line in ipairs(out) do
    -- `XY path`, or `XY old -> new` for a rename (lazygit shows the new path).
    local path = line:sub(4):gsub("^.* %-> ", ""):gsub('^"(.*)"$', "%1")
    if path:lower():find(needle, 1, true) then
      matches[#matches + 1] = path
    end
  end
  return matches
end

-- Poll the terminal buffer until `ready(text)` is true, then run `fn`.
-- Gives up quietly after TIMEOUT_MS, leaving plain lazygit on screen.
local function when(buf, ready, fn)
  local timer = assert(vim.uv.new_timer())
  local waited = 0
  timer:start(POLL_MS, POLL_MS, vim.schedule_wrap(function()
    waited = waited + POLL_MS
    if not vim.api.nvim_buf_is_valid(buf) or waited > TIMEOUT_MS then
      timer:stop()
      timer:close()
      return
    end
    local text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
    if ready(text) then
      timer:stop()
      timer:close()
      fn()
    end
  end))
end

function M.open()
  local file = vim.api.nvim_buf_get_name(0)
  local root = file ~= "" and Snacks.git.get_root(file) or nil
  if not root then
    vim.notify("Not a file inside a git repo", vim.log.levels.WARN)
    return
  end
  local rel = vim.fs.relpath(root, vim.fs.normalize(file))
  local matches = rel and matching_changes(root, rel)
  if not matches then
    vim.notify("git status failed", vim.log.levels.WARN)
    return
  end
  if #matches == 0 then
    vim.notify("No uncommitted changes in " .. rel, vim.log.levels.INFO)
    return
  end

  local term = Snacks.lazygit({ cwd = root })
  local buf = term and term.buf
  local job = buf and vim.b[buf].terminal_job_id
  if not job then
    return
  end

  -- Phase 1: the panel exists, so lazygit is reading keys.
  when(buf, function(text)
    return text:find("─Files", 1, true) ~= nil
  end, function()
    vim.api.nvim_chan_send(job, "2/" .. rel .. "\r")
    if #matches ~= 1 then
      return
    end
    -- Phase 2: wait for the filtered ROW, not just the filter prompt. The file
    -- list loads asynchronously, and a `>` sent into a still-empty list leaves
    -- the cursor on the folder row.
    --
    -- A screen line holds the Files panel AND the diff beside it, and the diff
    -- repeats the path, so only the left panel (`│ ... ││`) is searched. The
    -- row reads `M  main.go`: status code, an optional Nerd Font icon, name.
    local row = "^%s*[%u?]+%s.-" .. vim.pesc(vim.fs.basename(rel)) .. "%s*$"
    when(buf, function(text)
      if not text:find("matches for", 1, true) then
        return false
      end
      for line in text:gmatch("[^\n]+") do
        local left = line:match("^│(.-)││")
        if left and left:find(row) then
          return true
        end
      end
      return false
    end, function()
      vim.api.nvim_chan_send(job, ">")
    end)
  end)
end

return M
