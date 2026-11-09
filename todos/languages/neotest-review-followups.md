# neotest review follow-ups (2026-11-08)

From a review of `lua/plugins/testing.lua`. None of these blocks work today, so
they wait for the checkpoint. Run the ROI test on each before building.

1. **Rerun Failed (`<leader>tF`) is slow after a big break.** It reruns each
   failed test as its own run, so 20 Vitest/Jest failures start the runner 20
   times (~1-3 s each). Fix: group failures by file and run each file once.
   Drawback: that also reruns the passing tests in those files. Do it only if
   this is actually felt.
2. **jest `isTestFile` override has no cache.** For each candidate file it reads
   and JSON-decodes every `package.json` up to `/`. Fine day to day; during
   `<leader>tD` in a large monorepo it may cause a short stutter. Fix: cache the
   answer per `package.json` path, keyed by mtime. Also: a script is only
   matched when its whole value is `"jest"` (`"jest --ci"` is missed; rare,
   since jest is almost always in devDependencies).
3. **neotest-vitest may print "cannot read package.json"** when nvim is started
   in a folder with no `package.json` and a non-vitest test file is checked
   (`hasRootProjectVitestDependency` reads `cwd/package.json`). Not reproduced.
   A print only, so runs are not affected. Reproduce first; a fix means
   wrapping the adapter's `is_test_file` like the jest override.
4. **Run with Coverage inside nvim**: done 2026-11-08 on `feat/test-coverage-history`
   (`<leader>tcf` / `tca`, `lua/testing/coverage.lua`), together with Test History
   (`<leader>th` / `tH`, `lua/testing/history.lua`).

5. **Saved run profiles** (deferred 2026-11-08; worth it once DB integration tests
   run weekly). Optional `.nvim/test.json` in the project root: `default` env/args for
   every run, named `profiles` (e.g. `integration` with `DATABASE_URL` and
   `-tags=integration`) picked with `<leader>tR`, and `envFile` so secrets stay in an
   ignored file. Hook: neotest's public `run.augment`. Keep `-v -race -count=1` when
   setting `go_test_args` (they replace neotest-golang's defaults). ~1.5-2 h.
6. **Benchmarks / fuzz** (deferred 2026-11-08). neotest-golang only finds `Test*`.
   `<leader>tb`: run the Benchmark / Fuzz function at the cursor in a terminal split
   (`go test -run=^$ -bench=^BenchmarkX$ -benchmem ./pkg`, `-fuzz=^FuzzX$
   -fuzztime=30s`). ~30 min, Go only; vitest bench / pytest-benchmark could follow.

7. **Stopping a Go test leaves the test binary running** (found 2026-11-09, not fixed).
   `<leader>tS` stops `go test`, but the compiled `pkg.test` program it started keeps
   running until it finishes or hits Go's 10-minute timeout. Quick tests are unaffected;
   long or hanging ones keep using CPU. Fix idea: stop the whole process group. It
   touches how neotest starts processes, so it needs a separate, agreed change.

## Future: other languages

Scope today is Go, JS/TS and Python. The rest waits until a real project needs it.

- **C#**: tests run in easy-dotnet's own runner, so Rerun Failed, the summary,
  `<leader>tD`, coverage and history do not cover them. Options: switch to the
  `easy-dotnet.neotest` adapter, or bridge easy-dotnet's results into neotest.
  `lua/debugging/csharp.lua` depends on easy-dotnet's test keymaps (`test_map`),
  so change both together.
- **Rust**: set `["rustaceanvim.neotest"]` back to `{}` once rust-analyzer is
  installed (`rustup component add rust-analyzer`). Coverage: `cargo llvm-cov
  --lcov`, which `load_lcov` already reads.
- **C/C++**: no mature neotest adapter. A gtest adapter exists
  (`alfaix/neotest-gtest`); evaluate it when a C++ project comes up.
- **Bash**: not planned.
