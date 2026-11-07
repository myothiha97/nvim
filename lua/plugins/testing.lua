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
--          • Rust   → rustaceanvim
--      This file only adds the TS/JS adapters (the typescript extra ships none) and tightens
--      two defaults below. Core keymaps come from test.core, all under <leader>t:
--          tr run nearest · tt run file · tT run all · ts summary · to output · tw watch · td debug
--
--   2. nvim-coverage — paints covered/uncovered lines in the sign column from a REPORT your
--      test runner produced. It does NOT run anything itself — generate the report first:
--          • TS/JS (Vitest): npx vitest run --coverage    → coverage/lcov.info
--          • Go:             go test -coverprofile=cover.out ./...
--      then <leader>tcc (or :Coverage) to load + show. lcov/coverprofile parse natively;
--      no luarocks needed.

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
      -- PERFORMANCE: skip project-wide discovery / file-watching. Running nearest/file/cwd
      -- still works; the summary just lists tests from files you've opened or run, not the
      -- whole tree. Flip to { enabled = true } if you want auto-populated project discovery.
      discovery = { enabled = false },
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
