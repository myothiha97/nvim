# Neovim test running: JetBrains gap report

Date: 2026-11-08

## Bottom line

Most of a JetBrains-style test workflow is already installed in your config; it is just not very visible. `lua/plugins/testing.lua` and LazyVim's `test.core` extra already give you neotest with adapters for Go (neotest-golang), Python (neotest-python), Vitest and Jest, plus nvim-coverage. C# has its own Rider-style runner through easy-dotnet, which you already use for debugging.

Recommendation: do not add a new framework. Do one small phase that makes the existing setup mouse-friendly and closes three gaps: right-click Run Test / Run File / Show Output beside the existing Debug Test item, an optional project-wide test tree per project, and a Rerun Failed action. Estimated size is about 40 to 60 lines across `menu.lua` and `testing.lua`, on its own branch.

Basis: source review of the pinned commits in `lazy-lock.json` (neotest 27bf921, neotest-golang 65b2be6, easy-dotnet d8e5970) and main at b63f090. Nothing here was run in Neovim yet.

## Feature comparison with JetBrains

Go, Python and Node/TS share one neotest UI; C# uses easy-dotnet's runner with the same `<leader>t` keys.

| JetBrains feature | Go / Python / Node-TS today | C# today | Gap |
|---|---|---|---|
| Run nearest / file / all | `<leader>tr` / `tt` / `tT`, rerun last `tl` | `<leader>tr` / `tt` (easy-dotnet buffer keys) | None |
| Gutter icons per test | neotest status signs: test icon before a run, then pass / fail / running | easy-dotnet gutter signs after its discovery | Icons are not clickable (see Proposed phase) |
| Pass / fail inline | Virtual text and diagnostics at the failing line | Flash on result, peek stack trace | None |
| Test tree window | Summary `<leader>ts`; double-click expands, `r` runs, `i` jumps | Runner window (`:Dotnet testrunner`), whole solution | Neotest tree lists only files you opened or ran (`discovery = false` for speed) |
| Output of a test | Float `<leader>to`, panel `<leader>tO` | Stack trace peek | None |
| Debug test | `<leader>td` and right-click Debug Test, through your dap-ui | Same | None |
| Rerun failed only | Not built in; summary has `J` / `K` failed jumps and `m` + `R` (mark, run marked) | Not built in; `]f`/`[f` jumps | Small helper |
| Watch / auto-rerun | `<leader>tw` | No | Fine as is |
| Coverage | `<leader>tcc` loads an existing lcov / coverprofile | Same via report | No one-click Run with Coverage |
| Stop run | `<leader>tS` | `<C-c>` in runner | None |

## Proposed low-effort phase

Three changes, one branch (`feat/test-runner`), no new plugins.

1. **Right-click test actions.** Add Run Test, Run File Tests and Show Test Output to the existing popup menu in `lua/debugging/menu.lua`, shown only in test files, next to Debug Test. Go, Python and Node call neotest; C# calls the easy-dotnet buffer action, the same way `csharp.lua` already does for Debug Test. Reuses `TEST_LANGS` and each language's `is_test_file()`, so no new detection code. About 30 lines.
2. **Project-wide test tree, opt-in per project.** Keep `discovery = false` globally, and turn it on only for chosen roots through neotest's `projects` table. About 5 lines per project.
3. **Rerun Failed.** A `<leader>tF` action that collects failed positions from neotest's results and runs them. About 15 lines in `testing.lua`. Uses neotest's client state, which is semi-internal; it would get a WARNING comment like the existing upstream-internals notes.

### Drawbacks to know before approving

- **Gutter icons stay non-clickable.** A gutter click already toggles a breakpoint (`debugging/mouse.lua`). Making the test icon a run button would give one cell two meanings, so the run action goes in the right-click menu instead. GoLand puts its run icon in a separate column; copying that needs a custom statuscolumn, which I don't recommend.
- **Sign overlap.** `signcolumn = "yes"` is one cell wide. Neotest signs use priority 1000, so on a test's first line a breakpoint sign is hidden behind the test icon (the breakpoint still works). Fix if it bothers you: set neotest `status.signs = false` and keep virtual text, or widen to `yes:2`.
- **Discovery cost.** When enabled for a project, neotest parses every test file with treesitter on first use and watches the tree. Fine for normal services, slow on large monorepos, which is why it stays per project.
- **Rerun Failed** depends on neotest internals that could change on update; neotest is not pinned today.
- **Not tested yet.** I can verify the menu and rerun logic headlessly with the existing rig before you try it on your Mac.

## Options not recommended

| Option | Why not |
|---|---|
| vim-test, overseer.nvim or a second runner | Duplicates neotest, which is already wired to your adapters and dap-ui |
| Switch C# to neotest (`easy-dotnet.neotest`, `neotest_integration = true`) | Unifies the tree, but turns off easy-dotnet's own signs and buffer keys and breaks the Debug Test lookup in `csharp.lua`. The Rider-style runner you have is richer. Worth revisiting only if one tree for all languages matters to you |
| Global `discovery = true` | Background parse of every test file in every repo you open; per-project opt-in gives the same tree where you want it |
| One-click Run with Coverage | Needs a per-language command and report path (Go coverprofile, Vitest lcov, coverage.py, coverlet). Medium effort for modest gain; generating the report in a terminal and `<leader>tcc` works today |
| Clickable gutter run icon | Conflicts with click-to-toggle breakpoint; see drawbacks |
| gotestsum runner for Go | Cleaner output, but an extra binary to install; default `go test -json` works. Add later only if Go output looks garbled |
