-- Test <-> implementation jump (<leader>tj, right-click Go to Test / Go to Implementation), the
-- JetBrains Ctrl+Shift+T equivalent for Go, JS/TS and Python. Same key both ways.
--
-- Found by naming convention, not imports:
--   Go      foo.go <-> foo_test.go (same folder, exact)
--   JS/TS   foo.ts <-> foo.test.ts / foo.spec.ts, same folder or __tests__/ (any of
--           ts tsx js jsx mts cts); files inside __tests__/ count as tests
--   Python  foo.py <-> test_foo.py / foo_test.py, same folder, then tests/ folders up to the
--           project root
-- JS/TS and Python then search the project (nvim's cwd) by file name, skipping dependency
-- and build folders. Several matches -> a picker. None -> asks, then opens a NEW UNSAVED
-- buffer at the conventional path (Go: with the source's package line); nothing is written
-- to disk until you :w.
--
-- Limit: an unusually named test (handlers_test.go testing router.go) is not found; use the
-- file picker as before.
--
-- Cost: only on the key / menu entry: a few file-existence checks, and for JS/TS/Python a
-- project walk by name when the direct paths miss. Nothing at startup or while typing.

local M = {}

local uv = vim.uv

local JS_EXTS = { "ts", "tsx", "js", "jsx", "mts", "cts" }
local SKIP_DIRS = {
  [".git"] = true,
  node_modules = true,
  vendor = true,
  dist = true,
  build = true,
  coverage = true,
  venv = true,
  [".venv"] = true,
  __pycache__ = true,
  [".mypy_cache"] = true,
  [".pytest_cache"] = true,
}
local LANG = {
  go = "go",
  javascript = "js",
  typescript = "js",
  javascriptreact = "js",
  typescriptreact = "js",
  python = "python",
}

local function exists(path)
  local stat = uv.fs_stat(path)
  return stat and stat.type == "file"
end

-- Every file in the project (cwd) whose name is in `names`, skipping SKIP_DIRS.
local function search(names, exclude)
  local wanted, found = {}, {}
  for _, n in ipairs(names) do
    wanted[n] = true
  end
  local root = uv.cwd()
  for name, type in
    vim.fs.dir(root, {
      depth = math.huge,
      skip = function(dir)
        return not SKIP_DIRS[vim.fs.basename(dir)]
      end,
    })
  do
    if type == "file" and wanted[vim.fs.basename(name)] then
      local full = vim.fs.joinpath(root, name)
      if full ~= exclude then
        found[#found + 1] = full
      end
    end
  end
  return found
end

-- foo.test.ts / foo.spec.ts, or any file inside a __tests__ folder.
local function is_js_test(path)
  return path:match("%.test%.[%w]+$") ~= nil
    or path:match("%.spec%.[%w]+$") ~= nil
    or vim.fs.basename(vim.fs.dirname(path)) == "__tests__"
end

-- Paths that exist, without duplicates and without the current file (`exclude`).
local function existing(paths, exclude)
  local out, seen = {}, {}
  for _, p in ipairs(paths) do
    p = vim.fs.normalize(p)
    if not seen[p] and p ~= exclude and exists(p) then
      seen[p] = true
      out[#out + 1] = p
    end
  end
  return out
end

-- { is_test, candidates (existing files), create (path offered when none) }
local RULES = {}

function RULES.go(_, dir, name)
  local base = name:match("^(.+)_test%.go$")
  if base then
    return true, existing({ vim.fs.joinpath(dir, base .. ".go") }), nil
  end
  local test = vim.fs.joinpath(dir, (name:gsub("%.go$", "_test.go")))
  return false, existing({ test }), test
end

function RULES.js(path, dir, name)
  local base = name:match("^(.+)%.test%.[%w]+$") or name:match("^(.+)%.spec%.[%w]+$")
  local in_tests_dir = vim.fs.basename(dir) == "__tests__"
  if base or in_tests_dir then
    base = base or name:match("^(.+)%.[%w]+$")
    local dirs = { dir }
    if in_tests_dir then
      dirs[2] = vim.fs.dirname(dir)
    end
    local paths, names = {}, {}
    for _, e in ipairs(JS_EXTS) do
      names[#names + 1] = base .. "." .. e
      for _, d in ipairs(dirs) do
        paths[#paths + 1] = vim.fs.joinpath(d, base .. "." .. e)
      end
    end
    local found = existing(paths, path)
    return true, #found > 0 and found or search(names, path), nil
  end
  local ext
  base, ext = name:match("^(.+)%.([%w]+)$")
  local paths, names = {}, {}
  for _, e in ipairs(JS_EXTS) do
    for _, k in ipairs({ "test", "spec" }) do
      local n = ("%s.%s.%s"):format(base, k, e)
      names[#names + 1] = n
      paths[#paths + 1] = vim.fs.joinpath(dir, n)
      paths[#paths + 1] = vim.fs.joinpath(dir, "__tests__", n)
    end
    names[#names + 1] = base .. "." .. e -- kept below only when inside a __tests__ folder
    paths[#paths + 1] = vim.fs.joinpath(dir, "__tests__", base .. "." .. e)
  end
  local found = existing(paths, path)
  if #found == 0 then
    for _, p in ipairs(search(names, path)) do
      if is_js_test(p) then
        found[#found + 1] = p
      end
    end
  end
  return false, found, vim.fs.joinpath(dir, ("%s.test.%s"):format(base, ext))
end

function RULES.python(path, dir, name)
  local base = name:match("^test_(.+)%.py$") or name:match("^(.+)_test%.py$")
  local root = uv.cwd()
  if base then
    local src = base .. ".py"
    local paths = { vim.fs.joinpath(dir, src), vim.fs.joinpath(vim.fs.dirname(dir), src) }
    local found = existing(paths, path)
    return true, #found > 0 and found or search({ src }, path), nil
  end
  base = name:match("^(.+)%.py$")
  local names = { "test_" .. base .. ".py", base .. "_test.py" }
  local paths = {}
  -- Same folder, then a tests/ folder in this folder and every parent up to the root.
  local d = dir
  while d do
    for _, n in ipairs(names) do
      if d == dir then
        paths[#paths + 1] = vim.fs.joinpath(d, n)
      end
      paths[#paths + 1] = vim.fs.joinpath(d, "tests", n)
    end
    if d == root or vim.fs.dirname(d) == d or not vim.startswith(d, root) then
      break
    end
    d = vim.fs.dirname(d)
  end
  local found = existing(paths, path)
  return false, #found > 0 and found or search(names, path), vim.fs.joinpath(dir, names[1])
end

-- Go/JS/TS/Python buffer? Used by the right-click menu to decide which entry to show.
function M.supported(filetype)
  return LANG[filetype] ~= nil
end

local function open_new(path, source)
  local lines = {}
  if path:match("_test%.go$") then
    for line in io.lines(source) do
      local pkg = line:match("^package%s+([%w_]+)")
      if pkg then
        lines = { "package " .. pkg, "" }
        break
      end
    end
  end
  vim.cmd.edit(vim.fn.fnameescape(path))
  if #lines > 0 and vim.api.nvim_buf_line_count(0) == 1 and vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] == "" then
    vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  end
end

function M.jump()
  local lang = LANG[vim.bo.filetype]
  local path = vim.api.nvim_buf_get_name(0)
  if not lang or path == "" then
    vim.notify("Test jump works in Go, JS/TS and Python files", vim.log.levels.INFO)
    return
  end
  local is_test, found, create = RULES[lang](path, vim.fs.dirname(path), vim.fs.basename(path))
  local open = function(p)
    vim.cmd.edit(vim.fn.fnameescape(p))
  end
  if #found == 1 then
    open(found[1])
  elseif #found > 1 then
    vim.ui.select(found, {
      prompt = is_test and "Go to implementation" or "Go to test",
      format_item = function(p)
        return vim.fn.fnamemodify(p, ":~:.")
      end,
    }, function(choice)
      if choice then
        open(choice)
      end
    end)
  elseif is_test then
    vim.notify("No implementation file found for " .. vim.fs.basename(path), vim.log.levels.INFO)
  else
    local rel = vim.fn.fnamemodify(create, ":~:.")
    vim.ui.select({ "Create " .. rel, "Cancel" }, { prompt = "No test file found" }, function(choice)
      if choice and choice ~= "Cancel" then
        open_new(create, path)
      end
    end)
  end
end

-- Right-click label: which way the jump goes from this buffer.
function M.is_test(path, filetype)
  local lang = LANG[filetype]
  if not lang then
    return false
  end
  local name = vim.fs.basename(path)
  if lang == "go" then
    return name:match("_test%.go$") ~= nil
  elseif lang == "python" then
    return name:match("^test_.+%.py$") ~= nil or name:match("_test%.py$") ~= nil
  end
  return is_js_test(path)
end

return M
