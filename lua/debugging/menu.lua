-- Right-click menu: debug entries for the clicked line, at most 5 at a time.
--
-- 'mousemodel' is popup_setpos (config/options.lua), so the cursor is already
-- on the clicked line and word when these run.
--
--   stopped in a session -> Run to Cursor · Evaluate · Add to Watches
--   line has breakpoint  -> Remove Breakpoint · Edit Condition… · Edit Log Message…
--                           (VS Code order; with 5 entries max, Edit Log Message
--                           is the one dropped when all of the above apply)
--   line has none        -> Add Conditional Breakpoint… · Add Log Point…
--   test file, idle      -> Run Test · Debug Test · Run File Tests · Show Test Output
--   Go/JS/TS/Python, idle -> Go to Test or Go to Implementation (extra, testing/jump.lua)
--                           (Debug Test per language: delve.lua, node.lua,
--                           python.lua, csharp.lua; the other three are extras,
--                           see `extra` below)
--   Test Results panel   -> Jump to Code · Show Output · Full Output · Rerun Test · Rerun Failed
--   Variables panel      -> Add to Watches (the row's full expression, e.g.
--                           wg.state, via dap-ui's own `w` action)
--
-- The entries are defined once. On each right-click a MenuPopup autocmd
-- enables the ones that apply and disables the rest; Neovim's popup menu
-- hides disabled entries (popupmenu.c), the same way runtime defaults.lua
-- handles "Go to definition". Only the separator is added/removed, because
-- separators are always shown.
--
-- Cost: one autocmd per right-click, ~15 :menu commands. Nothing on mouse
-- moves or keystrokes. nvim-dap is not loaded by a right-click.
--
-- Hit count and function breakpoints stay on <leader>dH / <leader>dF.
-- There is no "Disable breakpoint": nvim-dap has no disabled state.

local M = {}

local MAX = 5
local LAST = 9 -- highest menu priority we use (1.9); LSP entries start at 1.10
local SEP = [[PopUp.-debugging-]]

local function expr()
  local mode = vim.fn.mode()
  if mode == "v" or mode == "V" or mode == "\22" then
    return table.concat(vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), { type = mode }), "\n")
  end
  return vim.fn.expand("<cexpr>")
end

-- The expression to Evaluate / Watch, or nil when there is nothing sensible.
-- A selection is used as is. Otherwise the cursor must be on a name
-- (variable, field, package, type), like GoLand's Quick Evaluate: keywords,
-- operators and literals (`for`, `:=`, `0`) give nil (hover.is_name, also
-- used by mouse hover). Runs only on right-click / <leader>de.
local function evaluable()
  local e = expr()
  if e == "" or e:match("^%s*$") then
    return nil
  end
  if vim.fn.mode():find("^[vV\22]") then
    return e
  end
  local pos = vim.api.nvim_win_get_cursor(0)
  return require("debugging.hover").is_name(vim.api.nvim_get_current_buf(), pos[1] - 1, pos[2]) and e or nil
end

-- <leader>de: dap-ui's Eval, with the same check as the menu. The popup takes
-- focus (like GoLand's Quick Evaluate) so <CR>/double-click expands, e edits
-- the expression, q/<Esc> or leaving the popup closes it.
function M.eval()
  local e = evaluable()
  if e then
    require("dapui").eval(e, { enter = true })
  else
    vim.notify("Nothing to evaluate here: put the cursor on a name or select an expression", vim.log.levels.INFO)
  end
end

local function stopped_session()
  if not package.loaded["dap"] then
    return nil
  end
  local s = require("dap").session()
  return s and s.stopped_thread_id and s or nil
end

local function has_bp()
  if not package.loaded["dap.breakpoints"] then
    return false -- no breakpoint can exist yet (see breakpoints.lua)
  end
  local buf, line = vim.api.nvim_get_current_buf(), vim.fn.line(".")
  for _, bp in ipairs(require("dap.breakpoints").get(buf)[buf] or {}) do
    if bp.line == line then
      return true
    end
  end
  return false
end

-- Debug Test: each language's own module says what a test file is and how
-- to debug the test at the cursor, so languages stay independent.
local TEST_LANGS = {
  go = "debugging.delve",
  javascript = "debugging.node",
  typescript = "debugging.node",
  javascriptreact = "debugging.node",
  typescriptreact = "debugging.node",
  python = "debugging.python",
  cs = "debugging.csharp",
}

local function test_lang()
  local mod = TEST_LANGS[vim.bo.filetype]
  return mod and require(mod) or nil
end

-- Run / output actions for test files. A language module may define its own
-- (csharp.lua: easy-dotnet's runner); otherwise neotest, which Go, Python and
-- vitest/jest already use for <leader>tr / tt / to.
local NEOTEST = {
  run_test = function()
    require("neotest").run.run()
  end,
  run_file = function()
    require("neotest").run.run(vim.api.nvim_buf_get_name(0))
  end,
  show_output = function()
    require("neotest").output.open({ enter = true, auto_close = true })
  end,
}

local function test_action(name)
  local lang = test_lang()
  if lang then
    (lang[name] or NEOTEST[name])()
  end
end

local function in_test_file(c)
  return c.test
end

-- In menu order. `when(ctx)` decides visibility; `run()` is the action.
-- `extra = true`: not counted in MAX, so the test actions never push a
-- breakpoint entry out and the debug entries show exactly as before.
local ITEMS = {
  {
    label = "Run to Cursor",
    when = function(c)
      return c.stopped
    end,
    run = function()
      require("dap").run_to_cursor()
    end,
  },
  {
    label = "Evaluate",
    when = function(c)
      return c.stopped and c.expr
    end,
    run = function()
      M.eval()
    end,
  },
  {
    label = "Add to Watches",
    when = function(c)
      return c.stopped and c.expr
    end,
    run = function()
      if vim.bo.filetype == "dapui_scopes" then
        vim.cmd.normal("w") -- dap-ui's watch action for the row under the cursor
      else
        local e = evaluable()
        if e then
          require("dapui").elements.watches.add(e)
        end
      end
    end,
  },
  {
    label = "Remove Breakpoint",
    when = function(c)
      return c.bp
    end,
    run = function()
      require("debugging.breakpoints").toggle(vim.api.nvim_get_current_buf(), vim.fn.line("."))
    end,
  },
  {
    label = "Edit Condition…",
    when = function(c)
      return c.bp
    end,
    run = function()
      require("debugging.prompts").condition()
    end,
  },
  {
    label = "Edit Log Message…",
    when = function(c)
      return c.bp
    end,
    run = function()
      require("debugging.prompts").log_point()
    end,
  },
  {
    label = "Add Conditional Breakpoint…",
    when = function(c)
      return not c.bp
    end,
    run = function()
      require("debugging.prompts").condition()
    end,
  },
  {
    label = "Add Log Point…",
    when = function(c)
      return not c.bp
    end,
    run = function()
      require("debugging.prompts").log_point()
    end,
  },
  {
    label = "Run Test",
    extra = true,
    when = in_test_file,
    run = function()
      test_action("run_test")
    end,
  },
  {
    label = "Debug Test",
    when = in_test_file,
    run = function()
      test_lang().debug_test()
    end,
  },
  {
    label = "Run File Tests",
    extra = true,
    when = in_test_file,
    run = function()
      test_action("run_file")
    end,
  },
  {
    label = "Show Test Output",
    extra = true,
    when = in_test_file,
    run = function()
      test_action("show_output")
    end,
  },
  -- Test <-> implementation jump (testing/jump.lua, also <leader>tj). One entry per direction,
  -- shown in Go / JS/TS / Python buffers when no debug session runs.
  {
    label = "Go to Test",
    extra = true,
    when = function(c)
      return c.jump == "test"
    end,
    run = function()
      require("testing.jump").jump()
    end,
  },
  {
    label = "Go to Implementation",
    extra = true,
    when = function(c)
      return c.jump == "impl"
    end,
    run = function()
      require("testing.jump").jump()
    end,
  },
}

-- Test Results panel (testing/panel.lua): its own entries, shown only in that panel (see the
-- `results` branch in on_popup), like Add to Watches in dap-ui's Variables panel.
for _, entry in ipairs({
  { "Jump to Code", "jump" },
  { "Show Output", "output" },
  { "Full Output", "full_output" },
  { "Rerun Test", "rerun" },
  { "Rerun Failed", "rerun_failed" },
}) do
  table.insert(ITEMS, {
    label = entry[1],
    extra = true,
    results = true,
    when = function()
      return false -- never in code buffers
    end,
    run = function()
      require("testing.panel").actions[entry[2]]()
    end,
  })
end

local function path(item)
  return "PopUp." .. item.label:gsub(" ", "\\ ")
end

function M.run(i)
  ITEMS[i].run()
end

local function on_popup()
  for _, item in ipairs(ITEMS) do
    vim.cmd("amenu disable " .. path(item))
  end
  pcall(vim.cmd, "aunmenu " .. SEP)

  if vim.bo.filetype == "dapui_scopes" then
    vim.cmd("amenu enable PopUp.Add\\ to\\ Watches")
    vim.cmd(("anoremenu 1.%d %s <Nop>"):format(LAST, SEP))
    return
  end
  if vim.bo.filetype == "testing-results" then
    for _, item in ipairs(ITEMS) do
      if item.results then
        vim.cmd("amenu enable " .. path(item))
      end
    end
    vim.cmd(("anoremenu 1.%d %s <Nop>"):format(LAST, SEP))
    return
  end
  if vim.bo.buftype ~= "" then
    return -- other panels, terminals, pickers: no debug entries
  end
  local s = stopped_session()
  local ctx = {
    stopped = s ~= nil,
    idle = not (package.loaded["dap"] and require("dap").session()),
    bp = has_bp(),
    expr = evaluable() ~= nil,
  }
  local lang = ctx.idle and test_lang()
  ctx.test = lang and lang.is_test_file(vim.api.nvim_buf_get_name(0)) or false
  local jump = ctx.idle and require("testing.jump")
  if jump and jump.supported(vim.bo.filetype) then
    ctx.jump = jump.is_test(vim.api.nvim_buf_get_name(0), vim.bo.filetype) and "impl" or "test"
  end
  local shown, any = 0, false
  for _, item in ipairs(ITEMS) do
    if (item.extra or shown < MAX) and item.when(ctx) then
      vim.cmd("amenu enable " .. path(item))
      if not item.extra then
        shown = shown + 1
      end
      any = true
    end
  end
  if any then
    -- Same priority as the last item; Neovim inserts after equal priorities,
    -- so it lands below our entries and above the LSP ones (1.10).
    vim.cmd(("anoremenu 1.%d %s <Nop>"):format(LAST, SEP))
  end
end

function M.setup()
  -- Priorities 1.1..1.9 sort above the LSP entries at 1.10+ in options.lua.
  -- Items past the 9th share priority 9 (equal priorities keep insertion
  -- order), so they never reach the LSP entries at 1.10.
  for i, item in ipairs(ITEMS) do
    vim.cmd(("anoremenu 1.%d %s <Cmd>lua require('debugging.menu').run(%d)<CR>"):format(math.min(i, LAST), path(item), i))
  end
  local group = vim.api.nvim_create_augroup("debugging_menu", { clear = true })
  vim.api.nvim_create_autocmd("MenuPopup", { group = group, callback = on_popup })
end

return M
