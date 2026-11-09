-- Run with Coverage inside nvim (<leader>tcf file, <leader>tca all), the JetBrains / VS Code
-- "Run with Coverage" equivalent. A neotest consumer (registered in plugins/testing.lua):
-- neotest runs the tests as usual (inline ✓/✗, output, summary), with the adapter's
-- coverage flag added; when the run ends the report is loaded into nvim-coverage's gutter.
--
-- Every report is converted to one lcov file with ABSOLUTE paths and loaded with
-- nvim-coverage's filetype-independent load_lcov. That avoids two traps: nvim-coverage's Go
-- parser strips the module name with a plain gsub (on an absolute path that also contains the
-- module name, e.g. ledgerflow/backend, it cuts the path apart), and it matches files relative
-- to nvim's cwd, which is not the Go module root in a monorepo.
--
-- Reports live in stdpath("state")/test-coverage/<project>/, never in the repo. The manual
-- flow (CLI report, then <leader>tcc) is untouched.
--
-- WARNING: Vitest and Python need one coverage package per project: @vitest/coverage-v8
-- (npm i -D @vitest/coverage-v8) and pytest-cov (pip install pytest-cov). Without it the run
-- still works but produces no report, and a warning names the missing package.
-- Python: coverage.py also writes its data file `.coverage` in the project (usually ignored).
--
-- Cost: nothing at startup or while typing. Work happens only on the keys: the test process
-- (same as <leader>tt / tT) plus one read + write of the report when it ends.

local M = {}

local nio = require("nio")
local uv = vim.uv

-- Per adapter: extra test arguments for a report written into `dir`, the report file, and
-- what to tell the user when no report appears.
local ADAPTERS = {
  ["neotest-golang"] = {
    -- WARNING: neotest-golang's extra go_test_args REPLACE its defaults instead of adding to
    -- them, so its defaults (-v -race -count=1) are repeated here. Keep them in sync if
    -- go_test_args is ever configured, or -race silently disappears from coverage runs.
    args = function(dir)
      return { go_test_args = { "-v", "-race", "-count=1", "-coverprofile=" .. dir .. "/go.coverprofile" } }
    end,
    report = "go.coverprofile",
    missing = "Go wrote no coverage profile; check the test output (<leader>to)",
  },
  ["neotest-jest"] = {
    args = function(dir)
      return { "--coverage", "--coverageReporters=lcov", "--coverageDirectory=" .. dir }
    end,
    report = "lcov.info",
    missing = "Jest wrote no lcov report; check the test output (<leader>to)",
  },
  ["neotest-vitest"] = {
    args = function(dir)
      return { "--coverage.enabled=true", "--coverage.reporter=lcov", "--coverage.reportsDirectory=" .. dir }
    end,
    report = "lcov.info",
    -- WARNING: checked BEFORE the run, not after. Without a coverage provider Vitest asks
    -- "Do you want to install @vitest/coverage-v8?" when stdout is a TTY, and neotest runs
    -- tests in a pty, so the run would hang on that hidden prompt. CI=true would avoid the
    -- prompt but also changes snapshot behaviour, so the run is skipped instead.
    precheck = function(root)
      for _, pkg in ipairs({ "@vitest/coverage-v8", "@vitest/coverage-istanbul" }) do
        if #vim.fs.find("node_modules/" .. pkg, { upward = true, path = root, type = "directory" }) > 0 then
          return true
        end
      end
      return false
    end,
    missing = "Vitest coverage needs its coverage package. Install it once in this project: "
      .. "npm i -D @vitest/coverage-v8",
  },
  ["neotest-python"] = {
    args = function(dir)
      return { "--cov", "--cov-report=lcov:" .. dir .. "/lcov.info" }
    end,
    report = "lcov.info",
    missing = "pytest wrote no coverage report. Install the coverage package once in this project: "
      .. "pip install pytest-cov",
  },
}

local function notify(msg, level)
  vim.schedule(function()
    vim.notify(msg, level or vim.log.levels.INFO, { title = "Coverage" })
  end)
end

local function read(path)
  local f = io.open(path, "r")
  if not f then
    return nil
  end
  local data = f:read("*a")
  f:close()
  return data
end

local function write(path, data)
  local f = assert(io.open(path, "w"))
  f:write(data)
  f:close()
end

-- One report folder per project root, outside the repo.
local function report_dir(root)
  local name = vim.fs.basename(root):gsub("[^%w%-_.]", "_")
  local dir = vim.fs.joinpath(vim.fn.stdpath("state"), "test-coverage", name .. "-" .. vim.fn.sha256(root):sub(1, 8))
  vim.fn.mkdir(dir, "p")
  return dir
end

-- Go coverprofile -> lcov with absolute paths. Profile lines are
-- "<module>/<file>.go:l1.c1,l2.c2 statements count"; the module path comes from root/go.mod.
local function go_to_lcov(profile, root)
  local gomod = read(vim.fs.joinpath(root, "go.mod")) or ""
  local module = gomod:match("^%s*module%s+(%S+)") or gomod:match("\nmodule%s+(%S+)")
  local files, order = {}, {}
  for line in profile:gmatch("[^\n]+") do
    local name, l1, l2, count = line:match("^(.+%.go):(%d+)%.%d+,(%d+)%.%d+ %d+ (%d+)$")
    if name then
      if module and name:sub(1, #module + 1) == module .. "/" then
        name = vim.fs.joinpath(root, name:sub(#module + 2))
      end
      local hits = files[name]
      if not hits then
        hits = {}
        files[name] = hits
        order[#order + 1] = name
      end
      for l = tonumber(l1), tonumber(l2) do
        hits[l] = (hits[l] or 0) + tonumber(count)
      end
    end
  end
  local out = {}
  for _, name in ipairs(order) do
    out[#out + 1] = "SF:" .. name
    local lines = vim.tbl_keys(files[name])
    table.sort(lines)
    for _, l in ipairs(lines) do
      out[#out + 1] = ("DA:%d,%d"):format(l, files[name][l])
    end
    out[#out + 1] = "end_of_record"
  end
  return table.concat(out, "\n") .. "\n"
end

-- lcov with relative SF paths (Vitest, pytest-cov) -> absolute. Tried against the adapter root,
-- then nvim's cwd; a path that exists in neither is kept as is.
local function absolute_lcov(lcov, root)
  local cwd = uv.cwd()
  return (
    lcov:gsub("SF:([^\n]+)", function(path)
      if path:sub(1, 1) == "/" then
        return "SF:" .. path
      end
      for _, base in ipairs({ root, cwd }) do
        local full = vim.fs.normalize(vim.fs.joinpath(base, path))
        if uv.fs_stat(full) then
          return "SF:" .. full
        end
      end
      return "SF:" .. path
    end)
  )
end

-- Line totals for the end-of-run message.
local function percent(lcov)
  local hit, found = 0, 0
  for count in lcov:gmatch("\nDA:%d+,(%d+)") do
    found = found + 1
    if count ~= "0" then
      hit = hit + 1
    end
  end
  return found > 0 and (hit / found * 100) or nil
end

function M.consumer(client)
  local running = false

  -- Trees to run: the current test file, or every active adapter's whole project.
  local function targets(scope, path)
    local list = {}
    if scope == "file" then
      local tree, adapter_id = client:get_position(path)
      if tree then
        list[1] = { tree = tree, adapter_id = adapter_id }
      end
    else
      for _, adapter_id in ipairs(client:get_adapters()) do
        -- The adapter's own root (e.g. the folder with go.mod), not neotest's tree root, which
        -- is nvim's cwd and breaks `go test` when go.mod sits in a subfolder (monorepo).
        local root = adapter_id:match(":(.*)$")
        local tree = client:get_position(root, { adapter = adapter_id })
          or client:get_position(nil, { adapter = adapter_id })
        if tree then
          list[#list + 1] = { tree = tree, adapter_id = adapter_id }
        end
      end
    end
    return list
  end

  local function run(scope, path)
    if running then
      notify("A coverage run is already in progress")
      return
    end
    local list = targets(scope, path)
    if #list == 0 then
      notify(
        scope == "file" and "Not a test file neotest knows" or "No test adapter is active yet: open a test file first",
        vim.log.levels.WARN
      )
      return
    end
    running = true
    notify("Running tests with coverage…")
    local merged = {}
    for _, t in ipairs(list) do
      nio.scheduler() -- back on the main loop before vim.fn calls (after neotest awaited)
      local kind, root = t.adapter_id:match("^(.-):(.*)$")
      local spec = ADAPTERS[kind]
      if not spec then
        notify("Coverage is not supported for " .. tostring(kind), vim.log.levels.WARN)
      elseif spec.precheck and not spec.precheck(root) then
        notify(spec.missing, vim.log.levels.WARN)
      else
        local dir = report_dir(root)
        local report = vim.fs.joinpath(dir, spec.report)
        os.remove(report) -- a report present after the run is a fresh one
        client:run_tree(t.tree, { adapter = t.adapter_id, extra_args = spec.args(dir) })
        nio.scheduler()
        local data = read(report)
        if not data or data == "" then
          notify(spec.missing, vim.log.levels.WARN)
        else
          merged[#merged + 1] = kind == "neotest-golang" and go_to_lcov(data, root) or absolute_lcov(data, root)
        end
      end
    end
    running = false
    nio.scheduler()
    if #merged == 0 then
      return
    end
    local lcov = table.concat(merged, "\n")
    local file = vim.fs.joinpath(vim.fn.stdpath("state"), "test-coverage", "last.lcov")
    local coverage = require("coverage")
    -- Clear first: load_lcov watches its file until cleared, so writing a new report while the
    -- old watcher is live would load it twice.
    coverage.clear()
    write(file, lcov)
    local pct = percent("\n" .. lcov)
    local covered = {}
    for sf in lcov:gmatch("SF:([^\n]+)") do
      covered[sf] = true
    end
    vim.schedule(function()
      coverage.load_lcov(file, true)
      -- nvim-coverage only paints buffers that are open when a report loads. Repaint when a
      -- covered file is opened later (what the IDEs do). Cost per file open: one table lookup;
      -- the report is re-read only for a file that is in it. Skipped while signs are hidden or
      -- cleared (<leader>tct / tcx). signs.is_enabled is nvim-coverage's own module function;
      -- if a plugin update renames it, the pcall makes this a no-op and nothing else breaks.
      local group = vim.api.nvim_create_augroup("TestingCoverage", { clear = true })
      vim.api.nvim_create_autocmd("BufReadPost", {
        group = group,
        callback = function(ev)
          if covered[vim.api.nvim_buf_get_name(ev.buf)] then
            local ok, enabled = pcall(function()
              return require("coverage.signs").is_enabled()
            end)
            if ok and enabled then
              coverage.load_lcov(file, true)
            end
          end
        end,
      })
      vim.notify(
        pct and ("Coverage loaded: %.1f%% of lines covered (<leader>tcs for details)"):format(pct) or "Coverage loaded",
        vim.log.levels.INFO,
        { title = "Coverage" }
      )
    end)
  end

  return {
    run = function(scope)
      local path = vim.api.nvim_buf_get_name(0)
      nio.run(function()
        local ok, err = pcall(run, scope, path)
        if not ok then
          running = false
          notify("Coverage run failed: " .. tostring(err), vim.log.levels.ERROR)
        end
      end)
    end,
  }
end

return M
