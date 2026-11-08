-- Test runner + coverage — the WebStorm "test tool window + gutter coverage" equivalent.
--
-- Two independent pieces, both 100% on-demand: nothing loads at startup, nothing runs on
-- the typing/scroll hot path. The only CPU work is the external test process, run async
-- via nvim-nio — same cost as a terminal, so the UI stays responsive.
--
--   1. neotest — runs tests, inline ✓/✗ virtual text, results summary, output float.
--      Enabled via LazyVim's `test.core` extra (see lazyvim.json), which also AUTO-wires
--      adapters from your already-enabled lang extras — you get these for free:
--          • Go     → neotest-golang   (+ DAP debug on <leader>td)
--          • Python → neotest-python
--          • Rust   → rustaceanvim (adapter off below until rust-analyzer is installed)
--      This file only adds the TS/JS adapters (the typescript extra ships none) and tightens
--      two defaults below. Core keymaps come from test.core, all under <leader>t:
--          tr run nearest · tt run file · tT run all · ts summary · to output · tw watch · td debug
--      Added here: tF rerun failed · tD discover project tests (full tree in ts).
--      Right-click in a test file also has Run Test / Debug Test /
--      Run File Tests / Show Test Output (debugging/menu.lua).
--
--   2. nvim-coverage — paints covered/uncovered lines in the sign column from a REPORT your
--      test runner produced. It does NOT run anything itself — generate the report first:
--          • TS/JS (Vitest): npx vitest run --coverage    → coverage/lcov.info
--          • Go:             go test -coverprofile=cover.out ./...
--      then <leader>tcc (or :Coverage) to load + show. lcov/coverprofile parse natively;
--      no luarocks needed.

-- Directories never searched for tests by <leader>tD (dependencies and build output). Adapters
-- skip some of these already; this covers the rest so large repos stay quick.
local SKIP_DIRS = {
  [".git"] = true,
  node_modules = true,
  vendor = true,
  dist = true,
  build = true,
  target = true,
  bin = true,
  obj = true,
  venv = true,
  [".venv"] = true,
  __pycache__ = true,
}

return {
  -- TS/JS adapter + two safety/perf overrides on the neotest provided by test.core.
  {
    "nvim-neotest/neotest",
    optional = true, -- only applies if test.core is enabled (it is)
    dependencies = {
      "marilari88/neotest-vitest",
      "nvim-neotest/neotest-jest",
    },
    opts = {
      -- Both can stay on: each only claims test files of a project whose
      -- package.json depends on its runner (hasVitestDependency /
      -- hasJestDependency). <leader>td debugs the nearest test with js-debug.
      adapters = {
        -- Off: LazyVim's rust extra registers this adapter, so the first neotest use in ANY
        -- project (<leader>to, tr, right-click Run Test…) required it, which loaded rustaceanvim
        -- and raised "rust-analyzer not found in PATH" when rust-analyzer isn't installed.
        -- rustaceanvim still loads in .rs files. Set back to {} when you do Rust and have
        -- rust-analyzer installed (rustup component add rust-analyzer).
        ["rustaceanvim.neotest"] = false,
        ["neotest-vitest"] = {},
        ["neotest-jest"] = {
          -- Replaces neotest-jest's own check, which also reads the package.json
          -- of the directory nvim started in and, when there is none, calls
          -- vim.notify from an async context: that error aborts the whole
          -- neotest run, vitest files included. Same rule, without that read:
          -- a jest dependency (or a "jest" script) in any package.json from the
          -- test file upward, which also covers a monorepo root.
          isTestFile = function(file)
            if not require("neotest-jest.util").defaultTestFileMatcher(file) then
              return false
            end
            local found = vim.fs.find("package.json", { upward = true, path = vim.fs.dirname(file), limit = math.huge })
            for _, path in ipairs(found) do
              local f = io.open(path)
              local ok, pkg = pcall(vim.json.decode, f and f:read("*a") or "")
              if f then
                f:close()
              end
              if ok and type(pkg) == "table" then
                for _, field in ipairs({ "dependencies", "devDependencies" }) do
                  if type(pkg[field]) == "table" and pkg[field].jest then
                    return true
                  end
                end
                if type(pkg.scripts) == "table" and vim.tbl_contains(vim.tbl_values(pkg.scripts), "jest") then
                  return true
                end
              end
            end
            return false
          end,
        },
      },
      -- PROTECT your curated/persisted quickfix pins. neotest defaults quickfix.enabled=true,
      -- which repopulates the live list on every run — and the VimLeavePre persistence
      -- (config/quickfix-persistence.lua, via autocmds.lua) would then bake test failures
      -- into the saved pins. Results still arrive via virtual text, the output panel, and the
      -- summary, so nothing is lost by turning this off.
      quickfix = { enabled = false },
      -- Test status only as text at the end of the test's line, not in the gutter: the gutter's
      -- sign cell shows one sign per line and neotest's (priority 1000, hardcoded) hid
      -- breakpoints on a test's `func` line. Not-yet-run tests get a play icon in the
      -- diagnostic info colour (follows the colorscheme) instead of the default grey flask;
      -- passed / failed / running keep neotest's green / red / yellow. The same highlight
      -- colours test names in the summary tree.
      status = { signs = false, virtual_text = true },
      -- Output / attach popups (<leader>to, ta, right-click Show Test Output) look like LSP hover
      -- docs: same rounded border and the same LspDocFloat surface (config/keymaps.lua,
      -- colours in the theme), so they stand out from the editor background. Size stays
      -- neotest's (60% of the editor): test output has long lines.
      floating = {
        border = "rounded",
        options = {
          winhighlight = "Normal:LspDocFloat,NormalFloat:LspDocFloat,FloatBorder:LspDocBorder,FloatTitle:LspDocTitle",
        },
      },
      -- Summary tree (<leader>ts), JetBrains-style: Enter jumps to the test in the code (on any
      -- node: file, test, subtest). Double-click expands / collapses like every other panel;
      -- Tab does the same from the keyboard. Neotest's defaults put Enter on expand, which did
      -- nothing on a test with no children. Other keys unchanged (r run, d debug, o output, ? help).
      summary = { mappings = { expand = { "<Tab>", "<2-LeftMouse>" }, jumpto = { "<CR>", "i" } } },
      icons = { test = "\u{f04b}", namespace = "\u{f04b}" },
      highlights = { test = "DiagnosticInfo", namespace = "DiagnosticInfo" },
      -- PERFORMANCE: skip project-wide discovery / file-watching. Running nearest/file/cwd
      -- still works; the summary just lists tests from files you've opened or run, not the
      -- whole tree. Flip to { enabled = true } if you want auto-populated project discovery.
      discovery = { enabled = false },
      -- Rerun Failed (<leader>tF): reruns the tests whose last result is failed, one at a time,
      -- in the order neotest returns them. A consumer is neotest's public extension point (the
      -- trouble consumer in LazyVim's test.core is one); it uses only documented Client methods
      -- (get_adapters, get_position, get_results, run_tree). It runs nothing until the key is
      -- pressed. Caveats: each test is its own run (Go compiles each package once, then hits the
      -- cache), and C# is not covered: its tests run in easy-dotnet's runner, not neotest.
      consumers = {
        -- A failed test's error shows the way VS Code and JetBrains show it: the message inline at
        -- the failing line, underlined, with no gutter sign (gutter stays as before neotest).
        -- Runs once at neotest setup (not at startup), after LazyVim's test.core sets this
        -- namespace's virtual_text format; per-namespace keys merge, so that format is kept.
        -- Also: `q` closes the <leader>ta attach window (leave terminal mode first with
        -- <C-\><C-n>). Closing only detaches the view; the test keeps running.
        ui = function()
          vim.diagnostic.config({ signs = false }, vim.api.nvim_create_namespace("neotest"))
          vim.api.nvim_create_autocmd("FileType", {
            pattern = "neotest-attach",
            callback = function(ev)
              vim.keymap.set("n", "q", "<Cmd>close<CR>", { buffer = ev.buf, desc = "Detach (close window)" })
            end,
          })
        end,
        -- Discover Tests (<leader>tD): the project-wide test tree, on demand only. Nothing is
        -- discovered at startup or on first neotest use (discovery = false above); this key
        -- finds every test file under each adapter's root (skipping SKIP_DIRS), parses them in
        -- neotest's child process so the UI stays responsive, and shows progress in fidget like
        -- an LSP: "Discovering tests  N files" → "N tests in M files", or an error. After it, that project stays
        -- discovered for the session (new test files are picked up).
        -- WARNING: upstream internals. neotest has no public "discover now" call, so this uses
        -- Client._adapters (all adapters, not only those with tests already loaded) and
        -- Client:_update_positions (the method neotest's own discovery runs). Checked on neotest
        -- 27bf921. If an update renames them, the key reports "needs updating" and does nothing;
        -- the rest of neotest is unaffected. Rollback: delete this consumer and the tD key.
        discover = function(client)
          local handle, files, last = nil, 0, 0
          -- Live "N files" count while discovering; idle (handle == nil) otherwise. Reports at
          -- most every 100 ms so a large repo doesn't flood fidget.
          client.listeners.discover_positions = function(_, tree)
            if handle and tree:data().type == "file" then
              files = files + 1
              local now = vim.uv.now()
              if now - last > 100 then
                last = now
                local h, n = handle, files
                vim.schedule(function()
                  h:report({ message = n .. " files" })
                end)
              end
            end
          end
          return {
            run = function()
              if handle then
                return -- already discovering
              end
              local ok_fidget, progress = pcall(require, "fidget.progress")
              files = 0
              handle = ok_fidget
                and progress.handle.create({
                  title = "Discovering tests",
                  message = "searching…",
                  lsp_client = { name = "neotest" },
                })
                or nil
              local function finish(msg, level)
                local h = handle
                handle = nil
                vim.schedule(function()
                  if h then
                    h:report({ message = msg })
                    if level == vim.log.levels.ERROR then
                      h:cancel()
                    else
                      h:finish()
                    end
                  end
                  if level == vim.log.levels.ERROR or not h then
                    vim.notify(msg, level, { title = "neotest" })
                  end
                end)
              end
              local nio = require("nio")
              nio.run(function()
                local ok, err = pcall(function()
                  client:get_adapters() -- public; starts the client if this is the first neotest use
                  if type(client._adapters) ~= "table" or type(client._update_positions) ~= "function" then
                    error("neotest internals changed; the <leader>tD helper in testing.lua needs updating")
                  end
                  local tests = 0
                  for adapter_id in pairs(client._adapters) do
                    local root = adapter_id:match(":(.*)$")
                    if root then
                      nio.scheduler()
                      require("neotest").setup_project(root, {
                        discovery = {
                          enabled = true,
                          filter_dir = function(name)
                            return not SKIP_DIRS[name]
                          end,
                        },
                      })
                      client:_update_positions(root, { adapter = adapter_id })
                      local tree = client:get_position(nil, { adapter = adapter_id })
                      for _, pos in (tree and tree:iter() or function() end) do
                        if pos.type == "test" then
                          tests = tests + 1
                        end
                      end
                    end
                  end
                  local msg = tests > 0 and (tests .. " tests in " .. files .. " files") or "No tests found"
                  finish(msg, vim.log.levels.INFO)
                end)
                if not ok then
                  finish("Test discovery failed: " .. tostring(err), vim.log.levels.ERROR)
                end
              end)
            end,
          }
        end,
        rerun_failed = function(client)
          return {
            run = function()
              require("nio").run(function()
                local count = 0
                for _, adapter_id in ipairs(client:get_adapters()) do
                  local tree = client:get_position(nil, { adapter = adapter_id })
                  local results = tree and client:get_results(adapter_id) or {}
                  for id, result in pairs(results) do
                    local node = result.status == "failed" and tree:get_key(id)
                    -- Tests only (files/namespaces fail with their tests), and a failed Go
                    -- subtest is skipped when its parent test is rerun anyway.
                    local parent = node and node:parent()
                    local parent_failed = parent
                      and parent:data().type == "test"
                      and (results[parent:data().id] or {}).status == "failed"
                    if node and node:data().type == "test" and not parent_failed then
                      count = count + 1
                      client:run_tree(node, { adapter = adapter_id })
                    end
                  end
                end
                if count == 0 then
                  vim.schedule(function()
                    vim.notify("No failed tests to rerun", vim.log.levels.INFO)
                  end)
                end
              end)
            end,
          }
        end,
      },
    },
    -- stylua: ignore
    keys = {
      { "<leader>tF", function() require("neotest").rerun_failed.run() end, desc = "Rerun Failed (Neotest)" },
      { "<leader>tD", function() require("neotest").discover.run() end, desc = "Discover Project Tests (Neotest)" },
    },
  },

  -- Gutter coverage. Lazy: loads only when a Coverage command/keymap is invoked.
  {
    "andythigpen/nvim-coverage",
    main = "coverage",
    dependencies = { "nvim-lua/plenary.nvim" },
    cmd = {
      "Coverage",
      "CoverageLoad",
      "CoverageShow",
      "CoverageHide",
      "CoverageToggle",
      "CoverageClear",
      "CoverageSummary",
    },
    -- stylua: ignore
    keys = {
      { "<leader>tc",  "",                          desc = "+coverage" },
      { "<leader>tcc", "<cmd>Coverage<cr>",         desc = "Coverage: load & show" },
      { "<leader>tct", "<cmd>CoverageToggle<cr>",   desc = "Coverage: toggle signs" },
      { "<leader>tcs", "<cmd>CoverageSummary<cr>",  desc = "Coverage: summary" },
      { "<leader>tcx", "<cmd>CoverageClear<cr>",    desc = "Coverage: clear" },
    },
    -- Minimal setup: signs + summary only, no background watcher. Set `auto_reload = true`
    -- if you want loaded signs to refresh when the report file changes on the next run.
    opts = {},
  },
}
