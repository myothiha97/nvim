-- Test History (<leader>th runs, <leader>tH the test under the cursor), the JetBrains "Test
-- History" equivalent: past neotest runs survive across sessions, days and weeks.
--
-- A neotest consumer (registered in plugins/testing.lua) on two public events: `run` (start
-- time, what was run) and `results` (final statuses). One JSON line per finished run is
-- appended to stdpath("state")/test-history/<project>.jsonl, project = nvim's cwd. Every run
-- is recorded, whatever started it (tr, tt, tT, right-click, tF, coverage, summary).
--
-- WARNING: C# runs aren't recorded in history: they run in easy-dotnet's runner, not neotest.
-- Like the IDEs, history starts empty and only holds runs made after it was installed.
--
-- Limits: newest 500 runs, 60 days and ~20 MB per project, trimmed on the first record of a
-- session. Errors and output are kept for failed tests only, capped per test and per run
-- (neotest deletes its own output files when nvim exits).
--
-- Cost: nothing at startup or while typing. Work happens once per finished run (build one
-- record, one async append) and when a history picker is opened (read + decode the file).

local M = {}

local uv = vim.uv

local KEEP_RUNS = 500
local KEEP_SECONDS = 60 * 24 * 3600
local KEEP_BYTES = 20 * 1024 * 1024
local MAX_TEST_TEXT = 4000 -- error + output kept per failed test
local MAX_RUN_TEXT = 64 * 1024 -- all failed-test text kept per run

local ICONS = {
  passed = { "✓", "NeotestPassed" },
  failed = { "✗", "NeotestFailed" },
  skipped = { "⊘", "NeotestSkipped" },
}

local function history_file(cwd)
  local name = vim.fs.basename(cwd):gsub("[^%w%-_.]", "_")
  local dir = vim.fs.joinpath(vim.fn.stdpath("state"), "test-history")
  vim.fn.mkdir(dir, "p")
  return vim.fs.joinpath(dir, name .. "-" .. vim.fn.sha256(cwd):sub(1, 8) .. ".jsonl")
end

local function read_lines(path)
  local f = io.open(path, "r")
  if not f then
    return {}
  end
  local lines = {}
  for line in f:lines() do
    lines[#lines + 1] = line
  end
  f:close()
  return lines
end

-- Last `max` bytes of a file (output files can be large; only the end matters).
local function tail(path, max)
  local f = path and io.open(path, "r")
  if not f then
    return nil
  end
  local size = f:seek("end")
  f:seek("set", math.max(0, size - max))
  local data = f:read("*a")
  f:close()
  return data
end

-- Drop runs older than KEEP_SECONDS, then the oldest beyond KEEP_RUNS / KEEP_BYTES.
local function trim(path)
  local lines = read_lines(path)
  local cutoff, kept, bytes = os.time() - KEEP_SECONDS, {}, 0
  for i = #lines, 1, -1 do
    local t = tonumber(lines[i]:match('"time":(%d+)'))
    if t and t >= cutoff and #kept < KEEP_RUNS and bytes + #lines[i] <= KEEP_BYTES then
      table.insert(kept, 1, lines[i])
      bytes = bytes + #lines[i] + 1
    end
  end
  if #kept < #lines then
    local tmp = path .. ".tmp"
    local f = io.open(tmp, "w")
    if f then
      f:write(#kept > 0 and (table.concat(kept, "\n") .. "\n") or "")
      f:close()
      os.rename(tmp, path)
    end
  end
end

local function append(path, line)
  uv.fs_open(path, "a", 420, function(err, fd)
    if err or not fd then
      return
    end
    uv.fs_write(fd, line .. "\n", -1, function()
      uv.fs_close(fd)
    end)
  end)
end

-- Runs of this project, newest first.
local function load_runs(cwd)
  local runs = {}
  local lines = read_lines(history_file(cwd))
  for i = #lines, 1, -1 do
    local ok, run = pcall(vim.json.decode, lines[i])
    if ok and type(run) == "table" and run.tests then
      runs[#runs + 1] = run
    end
  end
  return runs
end

local function test_name(id)
  local parts = vim.split(id, "::", { plain = true })
  if #parts == 1 then
    return vim.fs.basename(id)
  end
  table.remove(parts, 1)
  return (table.concat(parts, " › "):gsub('"', ""))
end

local function test_file(id)
  return (id:match("^(.-)::") or id)
end

local function when(t)
  return os.date("%b %d %H:%M", t)
end

local function counts_text(n)
  return ("✓%d ✗%d ⊘%d"):format(n.passed or 0, n.failed or 0, n.skipped or 0)
end

local function failed_text(test)
  local parts = {}
  if test.err and test.err ~= "" then
    parts[#parts + 1] = test.err
  end
  if test.out and test.out ~= "" then
    parts[#parts + 1] = "── output ──\n" .. test.out
  end
  return #parts > 0 and table.concat(parts, "\n\n") or "(no error text recorded)"
end

-- Status icon + text chunks for snacks' format.
local function chunks(status, ...)
  local icon = ICONS[status] or { "·", "Comment" }
  local out = { { icon[1] .. " ", icon[2] } }
  for _, c in ipairs({ ... }) do
    out[#out + 1] = c
  end
  return out
end

function M.consumer(client)
  local pending = {} -- adapter_id -> root_id -> { start, time }
  local trimmed = {} -- history file -> true once trimmed this session

  local function record(adapter_id, root_id, results, run)
    local tree = client:get_position(root_id, { adapter = adapter_id })
    if not tree then
      return
    end
    local n, tests, budget = { passed = 0, failed = 0, skipped = 0 }, {}, MAX_RUN_TEXT
    for _, pos in tree:iter() do
      local result = pos.type == "test" and results[pos.id]
      if result then
        local status = result.status
        n[status] = (n[status] or 0) + 1
        local test = { id = pos.id, s = status, line = pos.range and pos.range[1] or 0 }
        if status == "failed" and budget > 0 then
          local errs = {}
          for _, e in ipairs(result.errors or {}) do
            errs[#errs + 1] = (e.line and ("line " .. (e.line + 1) .. ": ") or "") .. (e.message or "")
          end
          test.err = table.concat(errs, "\n"):sub(1, MAX_TEST_TEXT)
          local out = (result.short or tail(result.output, MAX_TEST_TEXT) or ""):gsub("\27%[[%d;]*m", "")
          test.out = out:sub(-math.max(0, math.min(MAX_TEST_TEXT - #test.err, budget)))
          budget = budget - #test.err - #test.out
        end
        tests[#tests + 1] = test
      end
    end
    if #tests == 0 then
      return
    end
    local root = tree:data()
    local line = vim.json.encode({
      v = 1,
      time = run.time,
      ms = math.floor((uv.hrtime() - run.start) / 1e6),
      adapter = adapter_id:match("^(.-):") or adapter_id,
      root = root.id,
      scope = root.type,
      n = n,
      tests = tests,
    })
    require("nio").scheduler()
    local path = history_file(uv.cwd())
    if not trimmed[path] then
      trimmed[path] = true
      trim(path)
    end
    append(path, line)
  end

  client.listeners.run = function(adapter_id, root_id)
    pending[adapter_id] = pending[adapter_id] or {}
    pending[adapter_id][root_id] = { start = uv.hrtime(), time = os.time() }
  end

  client.listeners.results = function(adapter_id, results, partial)
    if partial then
      return
    end
    for root_id, run in pairs(pending[adapter_id] or {}) do
      if results[root_id] then
        pending[adapter_id][root_id] = nil
        record(adapter_id, root_id, results, run)
      end
    end
  end

  -- Rerun ids one after another (sequential, like <leader>tF); ids gone from the code are skipped.
  local function rerun(ids)
    require("nio").run(function()
      local ran = 0
      for _, id in ipairs(ids) do
        local tree, adapter_id = client:get_position(id)
        if tree then
          ran = ran + 1
          client:run_tree(tree, { adapter = adapter_id })
        end
      end
      if ran < #ids then
        vim.schedule(function()
          vim.notify(("%d of %d tests no longer exist and were skipped"):format(#ids - ran, #ids), vim.log.levels.WARN)
        end)
      end
    end)
  end

  local function preview(ctx)
    local p = require("snacks.picker.preview")
    if ctx.item.preview then
      return p.preview(ctx)
    end
    return p.file(ctx)
  end

  -- Tests of one run: failed first. Enter jumps to the test, <C-r> reruns the selection.
  local function pick_run_tests(run)
    local items = {}
    for _, t in ipairs(run.tests) do
      local file = test_file(t.id)
      items[#items + 1] = {
        text = test_name(t.id) .. " " .. file,
        id = t.id,
        status = t.s,
        file = file,
        pos = { (t.line or 0) + 1, 0 },
        preview = t.s == "failed" and { text = failed_text(t), loc = false } or nil,
      }
    end
    table.sort(items, function(a, b)
      local order = { failed = 1, skipped = 2, passed = 3 }
      return (order[a.status] or 4) < (order[b.status] or 4)
    end)
    Snacks.picker.pick({
      title = ("Run %s · %s"):format(when(run.time), counts_text(run.n)),
      items = items,
      format = function(item)
        return chunks(item.status, { test_name(item.id) }, { "  " .. vim.fn.fnamemodify(item.file, ":~:."), "Comment" })
      end,
      preview = preview,
      confirm = "jump",
      actions = {
        rerun = function(picker)
          local ids = vim.tbl_map(function(i)
            return i.id
          end, picker:selected({ fallback = true }))
          picker:close()
          rerun(ids)
        end,
      },
      win = { input = { keys = { ["<c-r>"] = { "rerun", mode = { "n", "i" }, desc = "Rerun selected tests" } } } },
    })
  end

  -- <leader>th: past runs, newest first. Enter opens the run, <C-r> reruns its failed tests.
  local function runs()
    local list = load_runs(uv.cwd())
    if #list == 0 then
      vim.notify("No test runs recorded for this project yet", vim.log.levels.INFO)
      return
    end
    local items = {}
    for i, run in ipairs(list) do
      -- New failures: failed now, passed in the previous run of the same target.
      local before, new = {}, {}
      for j = i + 1, #list do
        if list[j].root == run.root then
          for _, t in ipairs(list[j].tests) do
            before[t.id] = t.s
          end
          break
        end
      end
      local failed = {}
      for _, t in ipairs(run.tests) do
        if t.s == "failed" then
          failed[#failed + 1] = t
          if before[t.id] == "passed" then
            new[#new + 1] = t
          end
        end
      end
      local lines = {
        ("%s · %s · %s · %.1f s"):format(
          os.date("%Y-%m-%d %H:%M:%S", run.time),
          run.scope,
          counts_text(run.n),
          run.ms / 1000
        ),
        "target: " .. vim.fn.fnamemodify(run.root, ":~:."),
        "",
      }
      if #new > 0 then
        lines[#lines + 1] = ("%d newly failing (passed in the previous run of this target):"):format(#new)
        for _, t in ipairs(new) do
          lines[#lines + 1] = "  ✗ " .. test_name(t.id)
        end
        lines[#lines + 1] = ""
      end
      for _, t in ipairs(failed) do
        lines[#lines + 1] = "✗ " .. test_name(t.id) .. "  (" .. vim.fn.fnamemodify(test_file(t.id), ":~:.") .. ")"
        lines[#lines + 1] = "  " .. (t.err or ""):gsub("\n", "\n  ")
        lines[#lines + 1] = ""
      end
      if #failed == 0 then
        lines[#lines + 1] = "All tests passed."
      end
      items[#items + 1] = {
        text = when(run.time) .. " " .. run.scope .. " " .. run.root,
        run = run,
        new = #new,
        failed_ids = vim.tbl_map(function(t)
          return t.id
        end, failed),
        preview = { text = table.concat(lines, "\n"), loc = false },
      }
    end
    Snacks.picker.pick({
      title = "Test History",
      items = items,
      format = function(item)
        local run = item.run
        local status = run.n.failed > 0 and "failed" or "passed"
        local out = chunks(
          status,
          { when(run.time) .. "  " },
          { ("%-9s"):format(run.scope), "Comment" },
          { counts_text(run.n) .. "  " },
          { ("%6.1f s  "):format(run.ms / 1000), "Comment" },
          { vim.fn.fnamemodify(run.root, ":~:.") }
        )
        if item.new > 0 then
          out[#out + 1] = { ("  +%d new"):format(item.new), "NeotestFailed" }
        end
        return out
      end,
      preview = "preview",
      confirm = function(picker, item)
        picker:close()
        pick_run_tests(item.run)
      end,
      actions = {
        rerun_failed = function(picker, item)
          picker:close()
          if #item.failed_ids == 0 then
            vim.notify("No failed tests in that run", vim.log.levels.INFO)
          else
            rerun(item.failed_ids)
          end
        end,
      },
      win = { input = { keys = { ["<c-r>"] = { "rerun_failed", mode = { "n", "i" }, desc = "Rerun failed tests" } } } },
    })
  end

  -- <leader>tH: every recorded result of the test (or group) under the cursor.
  local function test_history()
    local file = vim.api.nvim_buf_get_name(0)
    local row = vim.api.nvim_win_get_cursor(0)[1] - 1
    local cwd = uv.cwd()
    require("nio").run(function()
      local tree = client:get_nearest(file, row)
      require("nio").scheduler()
      if not tree then
        vim.notify("No test under the cursor", vim.log.levels.INFO)
        return
      end
      local target = tree:data().id
      local items, n = {}, { passed = 0, failed = 0, skipped = 0 }
      for _, run in ipairs(load_runs(cwd)) do
        for _, t in ipairs(run.tests) do
          if t.id == target or vim.startswith(t.id, target .. "::") then
            n[t.s] = (n[t.s] or 0) + 1
            items[#items + 1] = {
              text = when(run.time) .. " " .. t.s .. " " .. t.id,
              test = t,
              run = run,
              id = t.id,
              file = test_file(t.id),
              pos = { (t.line or 0) + 1, 0 },
              preview = t.s == "failed" and { text = failed_text(t), loc = false } or nil,
            }
          end
        end
      end
      if #items == 0 then
        vim.notify("No recorded runs for " .. test_name(target), vim.log.levels.INFO)
        return
      end
      Snacks.picker.pick({
        title = ("History: %s · %s"):format(test_name(target), counts_text(n)),
        items = items,
        format = function(item)
          return chunks(
            item.test.s,
            { when(item.run.time) .. "  " },
            { ("%-9s"):format(item.run.scope), "Comment" },
            { test_name(item.id) }
          )
        end,
        preview = preview,
        confirm = "jump",
        actions = {
          rerun = function(picker, item)
            picker:close()
            rerun({ item.id })
          end,
        },
        win = { input = { keys = { ["<c-r>"] = { "rerun", mode = { "n", "i" }, desc = "Rerun this test" } } } },
      })
    end)
  end

  return { runs = runs, test = test_history }
end

return M
