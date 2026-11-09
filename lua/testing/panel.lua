-- Test Results panel (<leader>tO), modelled on the JetBrains / Visual Studio test results view.
-- Replaces neotest's raw output stream as the <leader>tO view; the raw output stays reachable
-- (O on a test, P for neotest's raw panel, <leader>to).
--
-- Newest run on top, older runs collapsed below (last 10 kept in memory):
--    ▾ backend/tmp_test.go   12:40:31                          ✓ 7  ✗ 2  ⊘ 1   648 ms
--      │ ✗ TestNormalizeCurrency › lowercase with spaces                tmp_test.go:68  <1 ms
--      │     normalizeCurrency("  usd ")
--      │       got:  "USD"
--      │       want: "usd"
--      │ ⊘ TestSlowIntegration                                          tmp_test.go:83  <1 ms
--      │     tmp_test.go:84: needs a database
--      │ ▸ ✓ TestApplyDebit  (3)                                                        <1 ms
--
-- Failures show their full assertion message: Go got / want split onto aligned lines, Jest
-- Expected / Received diffs as written, library stack frames dropped.
-- Keys: <CR> jumps to a test (or folds a run / group), o or za on a test shows its own output
-- inline (ANSI stripped, first 300 lines), O opens its full raw output in a float, ]f / [f
-- next / previous failure, r reruns the test under the cursor, R reruns failed tests, P
-- toggles neotest's raw output panel, q closes. Mouse: click ▾ / ▸ to fold, double-click a
-- run / group to fold, a test to show its output, its file:line (right edge) to jump; the
-- right-click menu has Jump to Code / Show Output / Full Output / Rerun Test / Rerun Failed.
--
-- Built only from public neotest data: the run / results listeners, client:get_position, and
-- each result's status, errors, short and output. Anything missing falls back to "(no
-- message)"; the raw output stays one key away.
--
-- Cost: nothing on keystrokes, cursor moves or redraws. Each finished run is summarised once
-- (a walk over the run's tests); the buffer is rendered only when the panel is open (on open,
-- on a run finishing, on a fold toggle).

local M = {}

local MAX_RUNS = 10
local ns = vim.api.nvim_create_namespace("testing_results")

local runs = {} -- newest first
local state = { buf = nil, win = nil, rows = {} }
local client_ref

-- Colours follow the theme at normal strength, like code in a buffer: test names Function,
-- file:line Directory, run title Title, status icons and expected / actual the diagnostic
-- colours (foreground only). Comment only for times, guides and separators. No backgrounds,
-- no bold, no new colours.
local ICON = { passed = "\u{f00c}", failed = "\u{f00d}", skipped = "\u{f05e}" }
local ICON_HL = {
  passed = "TestingResultsIconPass",
  failed = "TestingResultsIconFail",
  skipped = "TestingResultsIconSkip",
}

local function define_highlights()
  local function link(name, to)
    vim.api.nvim_set_hl(0, name, { link = to, default = true })
  end
  local function fg_of(name, from)
    local hl = vim.api.nvim_get_hl(0, { name = from, link = false })
    vim.api.nvim_set_hl(0, name, { fg = hl.fg, default = true })
  end
  fg_of("TestingResultsIconPass", "DiagnosticOk")
  fg_of("TestingResultsIconFail", "DiagnosticError")
  fg_of("TestingResultsIconSkip", "DiagnosticWarn")
  fg_of("TestingResultsExpected", "DiagnosticOk")
  fg_of("TestingResultsActual", "DiagnosticError")
  link("TestingResultsName", "Function")
  link("TestingResultsPath", "Directory")
  link("TestingResultsTitle", "Title")
  link("TestingResultsText", "Normal")
  link("TestingResultsDim", "Comment")
end

local function strip(text)
  return (text or ""):gsub("\27%[[%d;]*m", ""):gsub("\r", "")
end

local function rel(path)
  return vim.fn.fnamemodify(path, ":~:.")
end

-- Readable name: everything after the file, joined with › (Go subtests, describe blocks).
local function name_of(id)
  local parts = vim.split(id, "::", { plain = true })
  table.remove(parts, 1)
  return (table.concat(parts, " › "):gsub('"', ""))
end

local INLINE_MAX = 300 -- output lines shown inline per test; O shows the rest

-- Output files already read, by path. Jest / Vitest give every test of a run the SAME output file
-- (the whole run's console), so it is read once, not once per test. Weak values: freed with the
-- runs that use them.
local files = setmetatable({}, { __mode = "v" })

-- Assertion text, one line per entry, with Go "x = got, want y" / "got X, want Y" split into
-- aligned got / want lines. Jest (Expected / Received) and pytest (assert, E lines) already
-- come one value per line and are kept as written.
local function message_lines(text)
  local out = {}
  for line in strip(text):gmatch("[^\n]+") do
    -- Stack frames from libraries and the runtime are noise here (JetBrains folds them too);
    -- frames in your own code stay. The full trace is in the test's output (o / O).
    local frame = line:match("^%s*at (.*)")
    local library = frame
      and (frame:find("node_modules", 1, true) or frame:find("node:internal", 1, true) or frame:match("^new Promise"))
    if library then
      goto continue
    end
    local expr, got, want = line:match("^(.-) = (.-), want (.+)$")
    if not expr then
      got, want = line:match("^got (.-), want (.+)$")
    end
    if got and want then
      if expr and expr ~= "" then
        out[#out + 1] = expr
      end
      out[#out + 1] = "  got:  " .. got
      out[#out + 1] = "  want: " .. want
    else
      out[#out + 1] = line
    end
    ::continue::
  end
  return out
end

-- A test's own output for inline display: the output file (ANSI stripped), else `short`.
local function test_output(t)
  if t.cache then
    return t.cache
  end
  local lines = t.output and files[t.output]
  if not lines then
    local text = t.short
    if t.output then
      local f = io.open(t.output, "r")
      if f then
        text = f:read("*a")
        f:close()
      end
    end
    lines = {}
    for line in strip(text or ""):gmatch("([^\n]*)\n?") do
      lines[#lines + 1] = line
    end
    while #lines > 0 and lines[#lines] == "" do
      lines[#lines] = nil
    end
    if t.output then
      files[t.output] = lines
    end
  end
  t.cache = #lines > 0 and lines or { "(the runner recorded no output for this test; P shows the raw panel)" }
  return t.cache
end

-- Useful lines of a test's output: drops the runner's own status lines.
local function output_lines(t, max)
  local lines = {}
  for _, line in ipairs(test_output(t)) do
    if not line:match("^%s*=== ") and not line:match("^%s*%-%-%- ") and not line:match("^%s*$") then
      lines[#lines + 1] = vim.trim(line)
      if #lines >= max then
        break
      end
    end
  end
  return lines
end

-- Duration from Go's own line ("--- PASS: TestX (0.12s)"), read when first shown. Go only:
-- other runners print no such line. Streams the test's own output file and stops at that line,
-- keeping nothing in memory (the full text is read only when o / O asks for it).
local function duration(t)
  if t.secs == nil then
    t.secs = false
    local f = t.go and t.output and io.open(t.output, "r")
    if f then
      for line in f:lines() do
        local secs = strip(line):match("^%s*%-%-%- %u+: .- %((%d+%.%d+)s%)$")
        if secs then
          t.secs = tonumber(secs)
          break
        end
      end
      f:close()
    end
  end
  return t.secs or nil
end

-- One finished run -> a compact record. Leaf failures only: a Go parent test that failed
-- because a subtest failed is not listed twice.
local function summarise(adapter_id, root_id, results, started)
  local tree = client_ref:get_position(root_id, { adapter = adapter_id })
  if not tree then
    return nil
  end
  local run = {
    time = started.time,
    ms = math.floor((vim.uv.hrtime() - started.start) / 1e6),
    label = rel(tree:data().path or root_id) .. (tree:data().type == "test" and (" › " .. name_of(root_id)) or ""),
    n = { passed = 0, failed = 0, skipped = 0 },
    failed = {},
    skipped = {},
    groups = {}, -- top-level passed tests with their passed subtests
    expanded = true,
  }
  local group_of = {}
  for _, node in tree:iter_nodes() do
    local pos = node:data()
    local result = pos.type == "test" and results[pos.id]
    if result then
      local status = result.status
      run.n[status] = (run.n[status] or 0) + 1
      local parent = node:parent()
      local top = not (parent and parent:data().type == "test")
      local child_failed = false
      if status == "failed" then
        for _, child in ipairs(node:children()) do
          local r = results[child:data().id]
          if r and r.status == "failed" then
            child_failed = true
            break
          end
        end
      end
      local item = {
        id = pos.id,
        name = name_of(pos.id),
        path = pos.path,
        line = (pos.range or {})[1] or 0,
        output = result.output,
        short = result.short,
        go = adapter_id:match("^neotest%-golang:") ~= nil,
      }
      if status == "failed" and not child_failed then
        local ok_err, err = pcall(function()
          return result.errors and result.errors[1]
        end)
        if ok_err and err then
          item.line = err.line or item.line
          item.detail = {}
          for _, e in ipairs(result.errors) do
            vim.list_extend(item.detail, message_lines(e.message or ""))
          end
        else
          item.detail = output_lines(item, 5)
        end
        if #item.detail == 0 then
          item.detail = { "(no message; o shows the output)" }
        end
        table.insert(run.failed, item)
      elseif status == "skipped" then
        item.reason = output_lines(item, 1)[1]
        table.insert(run.skipped, item)
      elseif status == "passed" then
        if top then
          item.subtests = {}
          item.expanded = false
          group_of[pos.id] = item
          table.insert(run.groups, item)
        else
          local p = parent
          while p and p:parent() and p:parent():data().type == "test" do
            p = p:parent()
          end
          local g = p and group_of[p:data().id]
          if g then
            table.insert(g.subtests, item)
          end
        end
      end
    end
  end
  return run
end

-- Which tint a message line gets: expected (want / Expected) or actual (got / Received).
local function message_hl(line)
  local l = vim.trim(line)
  if l:match("^want:") or l:match("^Expected") or l:match("^%- ") or l:match("^expected") then
    return "TestingResultsExpected"
  elseif l:match("^got:") or l:match("^Received") or l:match("^%+ ") or l:match("^actual") or l:match("^E%s") then
    return "TestingResultsActual"
  end
  return "TestingResultsText"
end

local function seconds(secs)
  if not secs then
    return nil
  end
  if secs < 0.001 then
    return "<1 ms"
  end
  return secs < 1 and ("%d ms"):format(secs * 1000) or ("%.1f s"):format(secs)
end

-- Render all runs. state.rows[line] = what that line is, for the keys.
local function render()
  local buf = state.buf
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    return
  end
  local lines, marks, rows = {}, {}, {}
  -- One line from { text, hl } chunks, plus optional right-aligned chunks (durations, paths).
  local function add(chunks, row, right)
    local text, col = "", 0
    for _, c in ipairs(chunks) do
      if c[2] then
        marks[#marks + 1] = { #lines, col, col + #c[1], c[2] }
      end
      text = text .. c[1]
      col = col + #c[1]
    end
    lines[#lines + 1] = text
    rows[#lines] = row or {}
    if right then
      marks[#marks + 1] = { #lines - 1, right = right }
    end
  end
  local G = "│ " -- tree guide
  local function add_output(t, indent)
    if not t.show_output then
      return
    end
    local out = test_output(t)
    for i = 1, math.min(#out, INLINE_MAX) do
      local row = { test = t, failed = t.failed_item }
      add({ { indent .. "┆ ", "TestingResultsDim" }, { out[i], "TestingResultsText" } }, row)
    end
    if #out > INLINE_MAX then
      local more = ("… %d more lines, press O for the full output"):format(#out - INLINE_MAX)
      add({ { indent .. "┆ ", "TestingResultsDim" }, { more, "TestingResultsDim" } }, { test = t })
    end
  end
  local function test_line(t, status, indent, name_hl, row)
    add(
      {
        { indent, "TestingResultsDim" },
        { ICON[status] .. " ", ICON_HL[status] },
        { t.name, name_hl },
      },
      row,
      {
        { (t.path and (vim.fs.basename(t.path) .. ":" .. (t.line + 1)) or ""), "TestingResultsPath" },
        { duration(t) and ("   " .. seconds(duration(t))) or "", "TestingResultsDim" },
      }
    )
  end

  if #runs == 0 then
    add({ { "  No test runs yet. Run tests with <leader>tr / tt / tT.", "TestingResultsDim" } })
  end
  for i, run in ipairs(runs) do
    if i > 1 then
      add({ { "" } })
    end
    local chunks = {
      { run.expanded and " ▾ " or " ▸ ", "TestingResultsDim" },
      { run.label, "TestingResultsTitle" },
      { "   " .. os.date("%H:%M:%S", run.time), "TestingResultsDim" },
    }
    local function count(status, pad)
      local hl = run.n[status] > 0 and ICON_HL[status] or "TestingResultsDim"
      return { ICON[status] .. " " .. run.n[status] .. pad, hl }
    end
    add(chunks, { kind = "run", run = run }, {
      count("passed", "  "),
      count("failed", "  "),
      count("skipped", "   "),
      { seconds(run.ms / 1000), "TestingResultsDim" },
    })
    if run.expanded then
      for _, t in ipairs(run.failed) do
        t.failed_item = true
        test_line(t, "failed", "   " .. G, "TestingResultsName", { kind = "test", test = t, failed = true })
        for _, d in ipairs(t.detail) do
          add({ { "   " .. G .. "    ", "TestingResultsDim" }, { d, message_hl(d) } }, { test = t, failed = true })
        end
        add_output(t, "   " .. G .. "    ")
      end
      for _, t in ipairs(run.skipped) do
        test_line(t, "skipped", "   " .. G, "TestingResultsName", { kind = "test", test = t })
        if t.reason then
          add({ { "   " .. G .. "    ", "TestingResultsDim" }, { t.reason, "TestingResultsText" } }, { test = t })
        end
        add_output(t, "   " .. G .. "    ")
      end
      for _, g in ipairs(run.groups) do
        local has_sub = #g.subtests > 0
        local fold = has_sub and (g.expanded and "▾ " or "▸ ") or "  "
        add({
          { "   " .. G, "TestingResultsDim" },
          { fold, "TestingResultsDim" },
          { ICON.passed .. " ", "TestingResultsIconPass" },
          { g.name, "TestingResultsName" },
          { has_sub and ("  (%d)"):format(#g.subtests) or "", "TestingResultsDim" },
        }, { kind = "group", test = g }, {
          { duration(g) and seconds(duration(g)) or "", "TestingResultsDim" },
        })
        add_output(g, "   " .. G .. "    ")
        if g.expanded then
          for _, sub in ipairs(g.subtests) do
            test_line(sub, "passed", "   " .. G .. "  " .. G, "TestingResultsName", { kind = "test", test = sub })
            add_output(sub, "   " .. G .. "  " .. G .. "  ")
          end
        end
      end
    end
  end
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  -- Right column (file:line, time) sits at the right edge when it fits; on a row too long for
  -- the window it follows the text instead, so it never covers the test name.
  local width = M.is_open() and vim.api.nvim_win_get_width(state.win) or math.huge
  for _, m in ipairs(marks) do
    if m.right then
      local right_w = 0
      for _, c in ipairs(m.right) do
        right_w = right_w + vim.fn.strdisplaywidth(c[1])
      end
      if vim.fn.strdisplaywidth(lines[m[1] + 1]) + 2 + right_w <= width then
        vim.api.nvim_buf_set_extmark(buf, ns, m[1], 0, { virt_text = m.right, virt_text_pos = "right_align" })
      else
        local chunks = { { "  ", "TestingResultsDim" } }
        vim.list_extend(chunks, m.right)
        vim.api.nvim_buf_set_extmark(buf, ns, m[1], 0, { virt_text = chunks, virt_text_pos = "eol" })
      end
    else
      vim.api.nvim_buf_set_extmark(buf, ns, m[1], m[2], { end_col = m[3], hl_group = m[4] })
    end
  end
  state.rows = rows
end

local function current()
  return state.rows[vim.api.nvim_win_get_cursor(0)[1]] or {}
end

local function jump(t)
  local target
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if win ~= state.win and vim.bo[vim.api.nvim_win_get_buf(win)].buftype == "" then
      target = win
      break
    end
  end
  if target then
    vim.api.nvim_set_current_win(target)
  else
    vim.cmd("aboveleft split")
  end
  vim.cmd.edit(vim.fn.fnameescape(t.path))
  pcall(vim.api.nvim_win_set_cursor, 0, { t.line + 1, 0 })
  vim.cmd("normal! zz")
end

local function rerender_keep_cursor()
  local cursor = vim.api.nvim_win_get_cursor(0)
  render()
  pcall(vim.api.nvim_win_set_cursor, 0, cursor)
end

-- o: show / hide the test's own output inline below it.
local function toggle_output()
  local row = current()
  if not row.test then
    return false
  end
  row.test.show_output = not row.test.show_output
  rerender_keep_cursor()
  return true
end

-- <CR> / za on a run or a group with subtests: fold it. za on a test: its output.
local function toggle_fold(test_output_too)
  local row = current()
  if row.kind == "run" then
    row.run.expanded = not row.run.expanded
  elseif row.kind == "group" and #row.test.subtests > 0 then
    row.test.expanded = not row.test.expanded
  elseif test_output_too then
    return toggle_output()
  else
    return false
  end
  rerender_keep_cursor()
  return true
end

local function move_failure(dir)
  local line = vim.api.nvim_win_get_cursor(0)[1]
  local count = vim.api.nvim_buf_line_count(state.buf)
  local i = line + dir
  while i >= 1 and i <= count do
    local row, prev = state.rows[i] or {}, state.rows[i - 1] or {}
    if row.failed and prev.test ~= row.test then
      vim.api.nvim_win_set_cursor(0, { i, 0 })
      return
    end
    i = i + dir
  end
end

local function set_keys(buf)
  local function map(lhs, fn, desc)
    vim.keymap.set("n", lhs, fn, { buffer = buf, nowait = true, desc = desc })
  end
  local function activate()
    if not toggle_fold() then
      local row = current()
      if row.test then
        jump(row.test)
      end
    end
  end
  map("<CR>", activate, "Jump to test / fold")

  -- Mouse, buffer-local only (global <LeftMouse> / <2-LeftMouse> maps stay in charge of
  -- every other window; the click itself still moves the cursor here as usual):
  --   click on ▾ / ▸        fold / unfold (on release, so the click lands first)
  --   double-click a run / group row   fold / unfold
  --   double-click a test row          show / hide its output (like o); on the file:line
  --                                    shown at the right edge, jump to the code
  local function arrow_clicked(pos)
    local text = vim.api.nvim_buf_get_lines(state.buf, pos.line - 1, pos.line, false)[1] or ""
    for _, arrow in ipairs({ "▾", "▸" }) do
      local s = text:find(arrow, 1, true)
      if s and math.abs(vim.fn.strdisplaywidth(text:sub(1, s - 1)) + 1 - pos.column) <= 1 then
        return true
      end
    end
    return false
  end
  -- Inside the panel a click is Neovim's own click, handled in order. The global
  -- <LeftMouse> (debugging/mouse.lua gutter click) re-sends clicks with feedkeys, which can
  -- land after the second click of a double-click and start a word selection; this panel
  -- has no gutter, so nothing is lost.
  vim.keymap.set("n", "<LeftMouse>", "<LeftMouse>", { buffer = buf, noremap = true, desc = "Click" })
  -- The release must still reach Neovim (an expr map returning it): swallowing it leaves
  -- Neovim thinking the button is held, and the next click becomes a drag / selection.
  vim.keymap.set("n", "<LeftRelease>", function()
    local pos = vim.fn.getmousepos()
    if pos.winid == state.win and pos.line > 0 and arrow_clicked(pos) then
      vim.schedule(function()
        vim.api.nvim_win_set_cursor(state.win, { pos.line, 0 })
        toggle_fold()
      end)
    end
    return "<LeftRelease>"
  end, { buffer = buf, expr = true, replace_keycodes = true, desc = "Fold / unfold (click on arrow)" })
  map("<2-LeftMouse>", function()
    local pos = vim.fn.getmousepos()
    if pos.winid ~= state.win or pos.line == 0 or arrow_clicked(pos) then
      return -- the arrow was already toggled by the first click
    end
    vim.api.nvim_win_set_cursor(state.win, { pos.line, 0 })
    local row = current()
    local text = vim.api.nvim_get_current_line()
    if row.kind == "run" or row.kind == "group" and #row.test.subtests > 0 then
      toggle_fold()
    elseif row.test and pos.column > vim.fn.strdisplaywidth(text) then
      jump(row.test)
    elseif row.test then
      toggle_output()
    end
  end, "Fold / show output / jump")
  map("za", function()
    toggle_fold(true)
  end, "Fold run / group, or show this test's output")
  map("]f", function()
    move_failure(1)
  end, "Next failure")
  map("[f", function()
    move_failure(-1)
  end, "Previous failure")
  map("r", function()
    local row = current()
    if row.test then
      require("neotest").run.run(row.test.id)
    end
  end, "Rerun test")
  map("R", function()
    require("neotest").rerun_failed.run()
  end, "Rerun failed tests")
  map("o", toggle_output, "Show / hide this test's output inline")
  map("O", function()
    local row = current()
    if row.test then
      require("neotest").output.open({ position_id = row.test.id, enter = true, auto_close = true })
    end
  end, "Full raw output of this test (float)")
  map("P", function()
    require("neotest").output_panel.toggle()
  end, "neotest's raw output panel")
  map("q", M.close, "Close")
end

-- Right-click menu entries (debugging/menu.lua); the cursor is already on the clicked row.
M.actions = {
  jump = function()
    local row = current()
    if row.test then
      jump(row.test)
    end
  end,
  output = toggle_output,
  full_output = function()
    local row = current()
    if row.test then
      require("neotest").output.open({ position_id = row.test.id, enter = true, auto_close = true })
    end
  end,
  rerun = function()
    local row = current()
    if row.test then
      require("neotest").run.run(row.test.id)
    end
  end,
  rerun_failed = function()
    require("neotest").rerun_failed.run()
  end,
}

function M.is_open()
  return state.win ~= nil and vim.api.nvim_win_is_valid(state.win)
end

function M.close()
  if M.is_open() then
    vim.api.nvim_win_close(state.win, true)
  end
  state.win = nil
end

function M.open()
  if M.is_open() then
    vim.api.nvim_set_current_win(state.win)
    return
  end
  if not (state.buf and vim.api.nvim_buf_is_valid(state.buf)) then
    state.buf = vim.api.nvim_create_buf(false, true)
    vim.bo[state.buf].filetype = "testing-results"
    vim.bo[state.buf].bufhidden = "hide"
    vim.api.nvim_buf_set_name(state.buf, "Test Results")
    set_keys(state.buf)
  end
  -- Right side, full height, like the JetBrains / VS test windows docked right: 40% of the
  -- columns, kept between 60 and 100. winfixwidth keeps it when other windows open or close.
  local width = math.max(60, math.min(100, math.floor(vim.o.columns * 0.4)))
  vim.cmd("botright " .. width .. "vsplit")
  state.win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(state.win, state.buf)
  local wo = vim.wo[state.win]
  wo.number, wo.relativenumber, wo.signcolumn, wo.foldcolumn = false, false, "no", "0"
  wo.statuscolumn, wo.colorcolumn, wo.list, wo.spell = "", "", false, false
  wo.wrap, wo.winfixwidth, wo.cursorline, wo.cursorlineopt = false, true, true, "line"
  render()
  vim.api.nvim_win_set_cursor(state.win, { 1, 0 })
end

function M.toggle()
  if M.is_open() then
    M.close()
  else
    M.open()
  end
end

function M.consumer(client)
  client_ref = client
  define_highlights()
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("TestingResults", { clear = true }),
    callback = define_highlights,
  })
  local started = {} -- adapter_id -> root_id -> { time, start }
  client.listeners.run = function(adapter_id, root_id)
    started[adapter_id] = started[adapter_id] or {}
    started[adapter_id][root_id] = { time = os.time(), start = vim.uv.hrtime() }
  end
  client.listeners.results = function(adapter_id, results, partial)
    if partial then
      return
    end
    for root_id, s in pairs(started[adapter_id] or {}) do
      if results[root_id] then
        started[adapter_id][root_id] = nil
        local ok, run = pcall(summarise, adapter_id, root_id, results, s)
        if ok and run then
          for _, old in ipairs(runs) do
            old.expanded = false
          end
          table.insert(runs, 1, run)
          runs[MAX_RUNS + 1] = nil
          vim.schedule(function()
            if M.is_open() then
              render()
            end
          end)
        end
      end
    end
  end
  return { toggle = M.toggle, open = M.open, close = M.close }
end

return M
