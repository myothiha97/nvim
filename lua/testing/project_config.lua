-- Project test settings: a project's own, editor-neutral test config overrides nvim's
-- defaults (like conform + a project .prettierrc). With none of these files, nothing changes.
--
--   .envrc, .env.test         KEY=value lines (incl. GOFLAGS) -> env of every test run, any
--                             language. .env.test wins over .envrc. Never executed: lines with
--                             $(...), `...`, $VAR or shell logic are skipped.
--   package.json scripts.test "jest ..." / "vitest ..." -> the Jest / Vitest command, with its
--                             flags and leading KEY=value env. Wrappers (&&, |, npm-run-all,
--                             scripts) are skipped: neotest must add its own per-test arguments.
--   Makefile, Taskfile.yml,   the `test` target's plain `go test ...` line -> its literal flags
--   justfile                  are added to Go runs. Lines with variables are skipped (STRICT on
--                             purpose: Makefile parsing is where upkeep would grow).
--   Python                    nothing here: neotest-python already picks the project's .venv /
--                             poetry / pipenv / uv, and pytest reads pytest.ini / pyproject.toml.
--   Jest / Vitest config      jest.config.* / vitest.config.* are read by the tools themselves.
--
-- Files are searched from the test file's folder up to the git root; the nearest one wins.
-- One file per kind is used (never merged), except the two env files, which combine.
--
-- SAFETY: these come from the repo, so a cloned project could set anything. Each file is
-- used only after Neovim's own trust prompt (vim.secure.read, as for .nvim.lua): asked the first
-- time and again whenever the file changes. Deny = nvim defaults for that file.
-- The answer is remembered per file version for the session: after changing your mind with
-- :trust, edit the file or restart nvim for it to apply.
--
-- Cost: nothing at startup or while typing. On a test run: a few fs_stat calls per folder up to
-- the git root, and a read + parse only when a file is new or changed (cached by mtime + size).
--
-- LIMIT (known): Go flags from a Makefile are not applied to Debug Test (<leader>td): dap-go
-- builds its own command. Env files still apply there.

local M = {}

local uv = vim.uv

local ENV_FILES = { ".envrc", ".env.test" } -- later wins
local GO_TASK_FILES = { "Makefile", "makefile", "GNUmakefile", "Taskfile.yml", "Taskfile.yaml", "justfile" }

-- Go flags that take their value as the next word ("-tags integration").
local GO_VALUE_FLAGS = {}
for f in
  ("tags timeout count p parallel coverpkg covermode cpu skip run ldflags gcflags asmflags mod vet bench benchtime shuffle exec o coverprofile cpuprofile memprofile blockprofile mutexprofile trace outputdir"):gmatch(
    "%S+"
  )
do
  GO_VALUE_FLAGS[f] = true
end
-- Dropped: neotest / coverage / this run control them, or they make `go test` do something else.
local GO_DROP = {}
for f in
  ("run json v c o exec coverprofile bench benchtime benchmem cpuprofile memprofile blockprofile mutexprofile trace outputdir list"):gmatch(
    "%S+"
  )
do
  GO_DROP[f] = true
end

local SHELL_LOGIC = { "&&", "||", ";", "|", "`", "$(", ">", "<" }

local function notify(msg, level)
  vim.schedule(function()
    vim.notify(msg, level or vim.log.levels.INFO, { title = "Test settings" })
  end)
end

local function has_shell_logic(s)
  for _, t in ipairs(SHELL_LOGIC) do
    if s:find(t, 1, true) then
      return true
    end
  end
  return false
end

-- Split on whitespace, keeping '...' / "..." together (quotes removed). nil on an open quote.
local function words(s)
  local out, cur, quote = {}, nil, nil
  for ch in s:gmatch(".") do
    if quote then
      if ch == quote then
        quote = nil
      else
        cur = cur .. ch
      end
    elseif ch == "'" or ch == '"' then
      quote, cur = ch, cur or ""
    elseif ch:match("%s") then
      if cur then
        out[#out + 1], cur = cur, nil
      end
    else
      cur = (cur or "") .. ch
    end
  end
  if quote then
    return nil
  end
  if cur then
    out[#out + 1] = cur
  end
  return out
end

-- Parsers: text -> value table, or nil (nothing usable), or { skip = "reason" }.

local function parse_env(text)
  local env, skipped = {}, 0
  for line in text:gmatch("[^\r\n]+") do
    local key, value = line:match("^%s*export%s+([%a_][%w_]*)=(.*)$")
    if not key then
      key, value = line:match("^%s*([%a_][%w_]*)=(.*)$")
    end
    if key then
      value = vim.trim(value)
      local q = value:sub(1, 1)
      if (q == '"' or q == "'") and value:sub(-1) == q and #value >= 2 then
        value = value:sub(2, -2)
      elseif value:find("%s#") then
        value = vim.trim(value:gsub("%s#.*$", ""))
      end
      if value:find("$", 1, true) or value:find("`", 1, true) then
        skipped = skipped + 1 -- needs the shell to expand; never run
      else
        env[key] = value
      end
    elseif not line:match("^%s*#") and vim.trim(line) ~= "" then
      skipped = skipped + 1 -- direnv commands (dotenv, layout, source_up, ...)
    end
  end
  if next(env) == nil then
    return nil -- only direnv commands (layout go, dotenv, ...): nothing to apply, no warning
  end
  local keys = vim.tbl_keys(env)
  table.sort(keys)
  local summary = table.concat(keys, ", ") .. (skipped > 0 and (" (%d shell lines skipped)"):format(skipped) or "")
  return { env = env, summary = summary }
end

-- package.json "scripts.test" -> { runner = "jest"|"vitest", flags = {...}, env = {...} }
local function parse_package_json(text)
  local ok, pkg = pcall(vim.json.decode, text)
  local script = ok and type(pkg) == "table" and type(pkg.scripts) == "table" and pkg.scripts.test
  if type(script) ~= "string" then
    return nil
  end
  if has_shell_logic(script) then
    return { skip = ('scripts.test "%s" is a shell chain; neotest needs a direct jest / vitest call'):format(script) }
  end
  local w = words(script)
  if not w then
    return { skip = "scripts.test has an unclosed quote" }
  end
  local env, i = {}, 1
  while w[i] and (w[i] == "cross-env" or w[i]:match("^[%a_][%w_]*=")) do
    local k, v = w[i]:match("^([%a_][%w_]*)=(.*)$")
    if k then
      env[k] = v
    end
    i = i + 1
  end
  if w[i] == "npx" then
    i = i + 1
  end
  local runner = w[i]
  if runner ~= "jest" and runner ~= "vitest" then
    return { skip = ('scripts.test "%s" does not call jest or vitest directly'):format(script) }
  end
  local flags = {}
  for j = i + 1, #w do
    local a = w[j]
    -- Watch mode would never end; coverage is <leader>tcf's job; vitest's subcommand (run /
    -- watch / dev) is replaced by the adapter's own --watch=false.
    local drop = a == "--watch"
      or a == "--watchAll"
      or a == "-w"
      or a:match("^%-%-watch=")
      or a:match("^%-%-watchAll=")
      or a == "--coverage"
      or a:match("^%-%-coverage")
      or (runner == "vitest" and j == i + 1 and (a == "run" or a == "watch" or a == "dev"))
    if a:find("%s") then
      return { skip = "scripts.test has an argument with spaces (not supported by the adapters)" }
    end
    if not drop then
      flags[#flags + 1] = a
    end
  end
  if #flags == 0 and next(env) == nil then
    return nil -- a bare "jest" / "vitest": nothing to apply
  end
  local parts = vim.deepcopy(flags)
  for k, v in pairs(env) do
    table.insert(parts, 1, k .. "=" .. v)
  end
  return { runner = runner, flags = flags, env = env, summary = runner .. " " .. table.concat(parts, " ") }
end

-- The `go test` line of the file's `test` target.
local function go_test_line(text, name)
  local lines = vim.split(text, "\r?\n")
  -- Taskfile: an indented "test:" key under tasks. Makefile / justfile: a "test" target at
  -- column 0 ("test:", "test: deps", just's "test *args:"), not "test-e2e:" or "tests:".
  local header = name:match("^Taskfile") and "^(%s+)test:%s*$" or "^()test%f[^%w_%-][^:=]*:"
  for n, line in ipairs(lines) do
    local indent = line:match(header)
    if indent then
      indent = type(indent) == "string" and indent or "" -- "()" captures a position
      for m = n + 1, #lines do
        local l = lines[m]
        local ind = l:match("^(%s*)%S")
        if ind and #ind <= #indent then
          break -- next target / task
        end
        if l:find("go test", 1, true) then
          return vim.trim(l)
        end
      end
      return nil
    end
  end
end

local function parse_go_task(text, name)
  local line = go_test_line(text, name)
  if not line then
    return nil
  end
  local cmd = line:gsub("^%- ", ""):gsub("^[\"']", ""):gsub("[\"']$", ""):gsub("^cmd:%s*", ""):gsub("^[@%-+]+", "")
  local rest = cmd:match("^go%s+test%s*(.*)$")
  if not rest or has_shell_logic(rest) or rest:find("$", 1, true) or rest:find("{{", 1, true) then
    return { skip = ('the test target runs "%s"; only a plain `go test` line with literal flags is used'):format(line) }
  end
  local w = words(rest)
  if not w then
    return { skip = "the go test line has an unclosed quote" }
  end
  local flags, j = {}, 1
  while j <= #w do
    local a = w[j]
    local name_ = a:match("^%-%-?([%w%.]+)")
    if name_ then
      local takes_next = not a:find("=", 1, true) and GO_VALUE_FLAGS[name_] and w[j + 1]
      if not GO_DROP[name_] then
        flags[#flags + 1] = takes_next and (a .. "=" .. w[j + 1]) or a
      end
      j = j + (takes_next and 2 or 1)
    else
      j = j + 1 -- package patterns (./...): neotest picks the package
    end
  end
  if #flags == 0 then
    return nil
  end
  return { flags = flags, summary = table.concat(flags, " ") }
end

-- path -> { stamp, value|false }
local cache = {}

local function stamp(path)
  local s = uv.fs_stat(path)
  return s and s.type == "file" and (s.mtime.sec .. "." .. s.mtime.nsec .. ":" .. s.size) or nil
end

-- Parsed, trusted content of `path`, or nil. Must run where vim.fn is allowed (not a fast event).
local function load(path, parse)
  local st = stamp(path)
  if not st then
    return nil
  end
  local c = cache[path]
  if c and c.stamp == st then
    return c.value or nil
  end
  local f = io.open(path, "r")
  local text = f and f:read("*a")
  if f then
    f:close()
  end
  local value = text and parse(text, vim.fs.basename(path)) or nil
  local short = vim.fn.fnamemodify(path, ":~:.")
  if value and value.skip then
    notify(("%s not used: %s"):format(short, value.skip), vim.log.levels.WARN)
    value = nil
  elseif value then
    -- Neovim's trust store: prompts the first time and after every change; nil = not trusted.
    if vim.secure.read(path) ~= text then
      notify(short .. " is not trusted: using nvim's test defaults for it", vim.log.levels.WARN)
      value = nil
    else
      notify(("Using %s: %s"):format(short, value.summary))
    end
  end
  cache[path] = { stamp = st, value = value or false }
  return value
end

-- Nearest file of each name list, from `dir` up to the git root (or home).
local function nearest(dir, names)
  local stop = vim.fs.root(dir, ".git") or uv.os_homedir()
  local d = dir
  while d do
    for _, n in ipairs(names) do
      local p = vim.fs.joinpath(d, n)
      if uv.fs_stat(p) then
        return p, n
      end
    end
    if d == stop then
      return nil
    end
    local parent = vim.fs.dirname(d)
    d = parent ~= d and parent or nil
  end
end

-- Settings for a test file: { env = {...}, go_flags = {...}|nil, js = {runner, flags}|nil }.
function M.for_path(path, kind)
  local dir = vim.fn.isdirectory(path) == 1 and path or vim.fs.dirname(path)
  local out = { env = {} }
  for _, name in ipairs(ENV_FILES) do
    local p = nearest(dir, { name })
    local v = p and load(p, parse_env)
    if v then
      out.env = vim.tbl_extend("force", out.env, v.env)
    end
  end
  if kind == "go" then
    local p = nearest(dir, GO_TASK_FILES)
    local v = p and load(p, parse_go_task)
    out.go_flags = v and v.flags
  elseif kind == "js" then
    local p = nearest(dir, { "package.json" })
    local v = p and load(p, parse_package_json)
    if v then
      out.js = v
      out.env = vim.tbl_extend("force", out.env, v.env)
    end
  end
  return out
end

-- Path of the node_modules/.bin/<runner> nearest to `dir`, else "npx <runner>".
local function js_binary(dir, runner)
  local found = vim.fs.find("node_modules/.bin/" .. runner, { upward = true, path = dir, type = "file" })[1]
  return found or ("npx " .. runner)
end

local KIND =
  { ["neotest-golang"] = "go", ["neotest-jest"] = "js", ["neotest-vitest"] = "js", ["neotest-python"] = "py" }

-- Same defaults as neotest-golang's go_test_args (extra go_test_args REPLACE them, so they are
-- repeated). The one copy: coverage.lua reads it too. Update it if neotest-golang's defaults change.
M.GO_DEFAULT_ARGS = { "-v", "-race", "-count=1" }

-- Wraps one adapter's build_spec (neotest's public adapter interface) to apply the settings.
local function wrap(adapter)
  local kind = KIND[adapter.name]
  if not kind or adapter.testing_project_config then
    return
  end
  adapter.testing_project_config = true
  local build_spec = adapter.build_spec
  adapter.build_spec = function(args)
    local ok, settings = pcall(function()
      local pos = args.tree and args.tree:data()
      if not pos or not pos.path then
        return nil
      end
      require("nio").scheduler() -- vim.fn / trust prompt need the main loop
      return M.for_path(pos.path, kind)
    end)
    if not ok then
      notify("Project test settings ignored: " .. tostring(settings), vim.log.levels.WARN)
      settings = nil
    end
    if settings and kind == "go" and settings.go_flags then
      args = vim.tbl_extend("force", {}, args)
      local extra = vim.deepcopy(args.extra_args or {})
      local go_args = vim.deepcopy(extra.go_test_args or M.GO_DEFAULT_ARGS)
      for _, f in ipairs(settings.go_flags) do
        if not vim.list_contains(go_args, f) then
          go_args[#go_args + 1] = f -- after the defaults, so the project's value wins (-count=2)
        end
      end
      extra.go_test_args = go_args
      args.extra_args = extra
    elseif settings and settings.js and adapter.name == "neotest-" .. settings.js.runner then
      args = vim.tbl_extend("force", {}, args)
      local dir = vim.fs.dirname(args.tree:data().path)
      local cmd = js_binary(dir, settings.js.runner) .. " " .. table.concat(settings.js.flags, " ")
      args[settings.js.runner == "jest" and "jestCommand" or "vitestCommand"] = vim.trim(cmd)
    end
    local spec = build_spec(args)
    if settings then
      local own_config = false
      for _, f in ipairs(settings.js and settings.js.flags or {}) do
        own_config = own_config or f == "-c" or f == "--config" or f:match("^%-%-config=") ~= nil
      end
      for _, s in ipairs(spec and (spec.command and { spec } or spec) or {}) do
        if next(settings.env) then
          -- Project env first, so a run's own env (e.g. coverage) still wins.
          s.env = vim.tbl_extend("force", settings.env, s.env or {})
        end
        if own_config and s.command then
          -- The script's own --config replaces the one the adapter found.
          s.command = vim.tbl_filter(function(a)
            return not a:match("^%-%-config=")
          end, s.command)
        end
      end
    end
    return spec
  end
end

-- Neotest consumer: wraps the configured adapters once neotest sets up.
-- WARNING: neotest.config.adapters (the adapter objects LazyVim passed to neotest.setup) is
-- neotest's config module, not a documented API. If it changes, nothing is wrapped and tests run
-- with nvim's defaults. Checked on neotest 27bf921. Rollback: remove the consumer line in
-- plugins/testing.lua.
function M.consumer()
  local ok, config = pcall(require, "neotest.config")
  for _, adapter in ipairs(ok and type(config.adapters) == "table" and config.adapters or {}) do
    if type(adapter) == "table" and type(adapter.build_spec) == "function" then
      wrap(adapter)
    end
  end
  return {}
end

-- For tests.
M._parse = { env = parse_env, package_json = parse_package_json, go_task = parse_go_task }

return M
