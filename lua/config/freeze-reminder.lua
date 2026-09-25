-- Freeze reminder: a blocking popup that summarises rules.md whenever Neovim
-- is started from this config directory (cwd under stdpath("config")) while
-- the freeze window is active. It waits for one key press: `q` quits Neovim,
-- any other key gets out of the way. The key is consumed, so it never reaches
-- the editor.
--
-- Cost: one UIEnter autocmd per startup that removes itself after firing, and
-- none at all once the freeze is over. Headless runs never fire UIEnter, so
-- scripts and probes are unaffected.
--
-- KEEP IN SYNC with rules.md: FREEZE_END and SUMMARY are a copy of that file.
-- When the next freeze window is set there, update FREEZE_END here too.

local M = {}

local FREEZE_END = "2026-12-31"

local SUMMARY = {
  "This config is a tool for work, not the work.",
  "The default answer to any change is NO.",
  "",
  "Allowed: only a MAJOR issue that blocks real work.",
  "",
  "Everything else goes to todos/, not the config:",
  "• New config, plugin or feature",
  "• Any change to how nvim behaves today",
  "• Colours, keymaps, options, layout",
  "• Minor issues and 'quick' tweaks",
  "",
  "Even a fix: never on main, performance first.",
}

local FOOTER = "q  quit Neovim   ·   any other key  continue"

-- True when Neovim was started from the config directory or a folder under it.
local function started_in_config(root)
  local cwd = vim.fs.normalize(vim.fn.getcwd())
  return cwd == root or vim.startswith(cwd, root .. "/")
end

-- True when a file argument lives inside a .git directory: git itself opened
-- Neovim as its editor (COMMIT_EDITMSG, git-rebase-todo, MERGE_MSG, ...).
local function opened_by_git()
  for _, arg in ipairs(vim.fn.argv()) do
    if vim.fn.fnamemodify(arg, ":p"):find("/.git/", 1, true) then
      return true
    end
  end
  return false
end

local function days_left()
  local y, m, d = FREEZE_END:match("(%d+)-(%d+)-(%d+)")
  local finish = os.time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 23, min = 59 })
  return math.max(0, math.floor(os.difftime(finish, os.time()) / 86400))
end

local function show()
  local lines = { ("❄  Config frozen until %s  (%d days left)"):format(FREEZE_END, days_left()), "" }
  vim.list_extend(lines, SUMMARY)
  vim.list_extend(lines, { "", FOOTER })

  local width = 0
  for _, line in ipairs(lines) do
    width = math.max(width, vim.fn.strdisplaywidth(line))
  end
  width = math.min(width + 4, vim.o.columns - 4)
  local height = math.min(#lines, vim.o.lines - 4)

  -- Two-space left margin inside the box; the footer is centred.
  for i, line in ipairs(lines) do
    lines[i] = "  " .. line
  end
  lines[#lines] = string.rep(" ", math.floor((width - vim.fn.strdisplaywidth(FOOTER)) / 2)) .. FOOTER

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  local ns = vim.api.nvim_create_namespace("freeze_reminder")
  vim.api.nvim_buf_set_extmark(buf, ns, 0, 0, { end_col = #lines[1], hl_group = "DiagnosticWarn" })
  vim.api.nvim_buf_set_extmark(buf, ns, #lines - 1, 0, { end_col = #lines[#lines], hl_group = "Comment" })

  -- A blank full-screen layer behind the box. It hides the startup screen, so
  -- the box never cuts through a double-width icon (tmux draws those rows one
  -- column off), and nothing else competes with the message.
  local backdrop_buf = vim.api.nvim_create_buf(false, true)
  local backdrop = vim.api.nvim_open_win(backdrop_buf, false, {
    relative = "editor",
    width = vim.o.columns,
    height = vim.o.lines,
    row = 0,
    col = 0,
    style = "minimal",
    zindex = 249,
    focusable = false,
  })
  vim.wo[backdrop].winhighlight = "NormalFloat:Normal"

  -- enter = false: focus stays on whatever startup opened (dashboard, oil box).
  local win = vim.api.nvim_open_win(buf, false, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2) - 1,
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
    title = " rules.md ",
    title_pos = "center",
    zindex = 250,
    focusable = false,
  })

  vim.cmd("redraw")
  -- pcall: <C-c> raises "Keyboard interrupt"; treat it like any other key.
  local ok, key = pcall(vim.fn.getcharstr)

  pcall(vim.api.nvim_win_close, win, true)
  pcall(vim.api.nvim_win_close, backdrop, true)
  pcall(vim.api.nvim_buf_delete, buf, { force = true })
  pcall(vim.api.nvim_buf_delete, backdrop_buf, { force = true })

  if ok and key == "q" then
    -- Plain `qa`, not `qa!`: nothing is modified this early, and if something
    -- somehow is, Neovim refuses and you land in the editor instead of losing it.
    pcall(vim.cmd, "qa")
  end
end

function M.setup()
  -- ISO dates compare correctly as strings.
  if os.date("%Y-%m-%d") > FREEZE_END then
    return
  end
  vim.api.nvim_create_autocmd("UIEnter", {
    group = vim.api.nvim_create_augroup("freeze_reminder", { clear = true }),
    once = true,
    callback = function()
      local root = vim.fs.normalize(vim.fn.stdpath("config"))
      -- `:restart` relaunches the same session; the reminder was already seen.
      if vim.v.startreason == "restart" or not started_in_config(root) or opened_by_git() then
        return
      end
      -- Scheduled so the startup screen is drawn behind the box first.
      vim.schedule(show)
    end,
  })
end

return M
