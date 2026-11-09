# Testing in Neovim with neotest

Nov 8, 2026 · @Myo Thiha Kyaw

## How close we are to JetBrains / VS Code

The everyday loop (run, see result, inspect, debug, rerun) is fully covered. In-editor coverage and test history are now covered too. Jump test ↔ code and Go test generation are covered too. The remaining gaps are polish features: a failure diff viewer, saved run configurations and benchmarks (both designed, filed in the backlog). Two "gaps" are on purpose: no gutter icons and no auto-discovery, both by your choice for a clean gutter and zero background cost.

| Feature | GoLand / Rider / WebStorm | VS Code / Visual Studio | Your Neovim | How |
| --- | --- | --- | --- | --- |
| Run nearest test | Gutter ▶ / Ctrl+Shift+R | CodeLens "run test" | Yes | `<leader>tr`, right-click Run Test |
| Run file / all | Yes | Yes | Yes | `<leader>tt` file, `<leader>tT` all |
| Debug a test | Yes | Yes | Yes | `<leader>td`, right-click Debug Test (your dap-ui) |
| Pass/fail shown in code | Gutter icon | Gutter icon | Yes, end of line | ✓ / ✗ / ▶ after the test name |
| Failure message inline | Yes | Peek box | Yes | Red text + underline on the failing line, `]d` to jump |
| Test tree / explorer | Test tool window | Test Explorer | Yes | `<leader>ts`; Enter jumps, `r` runs, `d` debugs |
| Whole-project tree | Auto | Auto | On demand | `<leader>tD` (fidget shows progress) |
| Output per test | Yes | Yes | Yes | `<leader>to` popup, `<leader>tO` panel |
| Rerun failed | Yes | Yes | Yes | `<leader>tF` |
| Rerun last | Yes | Yes | Yes | `<leader>tl` |
| Stop run | Yes | Yes | Yes | `<leader>tS` |
| Run selected set | Multi-select | Multi-select | Yes | In summary: `m` marks, `R` runs marked |
| Next / previous failure | Yes | Yes | Yes | In summary: `J` / `K` |
| Auto-rerun on save | Toggle auto-test | Continuous run | Yes | `<leader>tw` (watch; heaviest option) |
| Coverage in editor | Run with Coverage | Coverage gutters | Yes | `<leader>tcf` file / `<leader>tca` all: runs with coverage, colours appear when done. Vitest needs `@vitest/coverage-v8`, Python `pytest-cov` |
| Click gutter icon to run | Yes | Yes | No, on purpose | Gutter click stays breakpoint toggle |
| Expected vs actual diff | "Click to see difference" | Some extensions | No | Read it in the output popup |
| Jump test ↔ implementation | Ctrl+Shift+T | Extensions | Yes | `<leader>tj`, or right-click Go to Test / Go to Implementation |
| Generate a test | Generate → Test | Go ext. "Generate unit tests" | Yes (Go) | `<leader>ca` on a Go function → "Add test for \<func>" (gopls 0.24, verified on your Mac). JS/TS and Python: `<leader>tj` creates the empty test file |
| History, durations, sort | Yes | Partial | Yes | `<leader>th` past runs (date, counts, duration, new failures), `<leader>tH` one test's history. Go, JS/TS, Python; not C# |
| Saved run configs (env, args, tags) | Run configurations | launch / settings | No | Use the terminal for special flags |
| Benchmarks / fuzz | Yes | Yes | No | `go test -bench .` in terminal |
| C# tests | Rider | Visual Studio Test Explorer | Yes, via easy-dotnet | Same `<leader>tr/td/tt/to` keys in .cs test files |

Worth adding later, in order: saved run profiles for DB integration tests (about 2 h), failure diff (medium, little value for Go because `t.Errorf` messages already show got/want). I'd skip the rest.

## Testing basics

A unit test is a small function that calls your code with known input and checks the output. If the check fails, the test fails. That is the whole idea; neotest only runs these functions and shows the results in the editor.

**Why bother:** tests let you change code without fear. You change `applyDebit`, run its tests in one key, and know in a second whether you broke something. As a backend engineer, this is what reviewers expect next to every change.

**Every test has three parts (Arrange, Act, Assert):**

```go
func TestApplyDebit_NormalDebit(t *testing.T) {
    balance, amount := int64(100), int64(30)   // Arrange: set up input
    got, err := applyDebit(balance, amount)    // Act: call the code
    if err != nil || got != 70 {               // Assert: check the result
        t.Errorf("got %d, %v; want 70, nil", got, err)
    }
}
```

**Table-driven tests** are the Go standard. One test function holds a list of cases, and each case runs as a named subtest via `t.Run`. Neotest shows each case as its own node, so you can run one case alone (see your `TestApplyDebit` in tmp\_test.go).

**What to test first, in order:**

1. The normal path (valid input, expected output).
2. Edge cases (zero, empty string, exact limits like balance == amount).
3. Error paths (invalid input returns the right error).

**Good habits:**

- Test behaviour, not internals: call the function, check what comes out.
- One reason to fail per case, with a clear name (`insufficient_funds`, not `case3`).
- Failure messages say got and want: `t.Errorf("balance = %d, want %d", got, want)`.
- Keep unit tests fast and offline. Tests that need Postgres or Docker are integration tests; mark them with `t.Skip` or a build tag so the fast loop stays fast.
- Write the failing test first when fixing a bug, then fix the code until it passes. The test now guards against that bug forever.

**Words you'll see:** pass ✓, fail ✗, skip (test chose not to run), assertion (the check), fixture (prepared test data), mock / fake (a stand-in for a database or API), coverage (which lines the tests executed).

## Your daily loop in Neovim

Neotest doesn't test anything itself. It runs your real tool (`go test`, Vitest, Jest, pytest) in the background and shows the results in the editor. If the tool fails in a terminal, it fails in neotest too.

1. **Write or open a test file.** Each test shows a play icon at the end of its line until it has run.
2. **Run one thing.** `<leader>tr` (or right-click Run Test) runs the test nearest the cursor. Cursor on the `func Test…` line runs the whole test. Cursor on a table row runs that one case.
3. **Read the result.** ✓ green = passed, ✗ red = failed. The failure message appears in red at the failing line. `]d` / `[d` jump between failures.
4. **See the details.** `<leader>to` opens the output popup (got/want, stack trace). Press `q` or move the cursor to close it.
5. **Fix and rerun.** Edit the code, then `<leader>tl` reruns the last test without moving the cursor back.
6. **Still stuck? Debug it.** Set a breakpoint (click the gutter or `<leader>db`), then `<leader>td` or right-click Debug Test. Your usual dap-ui opens.
7. **Before committing.** `<leader>tt` runs the file, `<leader>tT` runs all tests. Then `<leader>tF` reruns only what failed.

**All test keys**

| Key | Does |
| --- | --- |
| `<leader>tr` | Run nearest test |
| `<leader>tt` | Run current file |
| `<leader>tT` | Run all test files |
| `<leader>tl` | Rerun last run |
| `<leader>tF` | Rerun failed tests |
| `<leader>td` | Debug nearest test |
| `<leader>to` | Output popup for test under cursor |
| `<leader>tO` | Output panel (all output, scrollable) |
| `<leader>ta` | Attach to a running test's live output |
| `<leader>tS` | Stop the run |
| `<leader>tw` | Watch file: rerun on every save (toggle) |
| `<leader>ts` | Summary panel (test tree) |
| `<leader>tD` | Discover all tests in the project into the tree |
| `<leader>tcc` | Show coverage from a report (see below) |
| `<leader>tcf / <leader>tca` | Run file / all tests with coverage; colours appear when done |
| `<leader>th` | Test history: past runs; open one to see its tests, Ctrl-r reruns its failures |
| `<leader>tH` | History of the test under the cursor (spot flaky tests) |

**Summary panel keys** (`<leader>ts`)

| Key | Does |
| --- | --- |
| `Enter` / `i` | Jump to the test in the code |
| `Tab` / double-click | Expand or collapse |
| `r` / `d` | Run / debug that node |
| `o` | Output for that node |
| `J` / `K` | Next / previous failed test |
| `m`, then `R` | Mark several tests, run the marked ones |
| `M` | Clear marks |
| `u` | Stop |
| `?` | Show all summary keys |

**Coverage** (which lines your tests ran): run `go test -coverprofile=coverage.out ./...` (or `npx vitest run --coverage` --coverage.reporter=lcov) in a terminal, then `<leader>tcc`. Use it to find untested branches, not as a score to chase.

Easier: `<leader>tcf` (file) or `<leader>tca` (all) runs the tests with coverage inside Neovim and shows the colours when done. The terminal commands above remain the fallback.

## Per language

| Language | Test file name | Test shape | Runner | Notes |
| --- | --- | --- | --- | --- |
| Go | `*_test.go`, same package | `func TestXxx(t *testing.T)`, table cases with `t.Run` | `go test` via neotest-golang | Your main language. Each table row is runnable on its own. `t.Skip("reason")` skips. |
| TS / JS | `*.test.ts`, `*.spec.ts` | `describe` groups, `it` / `test` cases, `expect(x).toBe(y)` | Vitest or Jest, picked from the project's package.json | Cursor on a `describe` line runs the whole group. |
| Python | `test_*.py` or `*_test.py` | `def test_xxx():` with plain `assert` | pytest via neotest-python | Needs pytest installed in the project's venv. |
| C# | test project (`*Tests.csproj`) | `[Fact]` / `[Test]` methods | easy-dotnet's own runner, not neotest | Same `<leader>tr/td/tt/to` keys, but no `<leader>tF`, summary or `<leader>tD`. |
| Rust | — | — | Adapter off | Turns on when you install rust-analyzer. |

## Practice (20 minutes, in tmp\_test.go)

The sample file in ledgerflow/backend has two bugs planted on purpose. Work through these in order.

- [ ] Cursor on `func TestApplyDebit`, press `<leader>tr`. All 3 cases pass.
- [ ] Cursor on the `{"exact balance", ...}` row, press `<leader>tr`. Only that case runs.
- [ ] Press `<leader>tt` to run the file. `TestNormalizeCurrency` and `TestRejectsZeroAmount` fail, and `TestSlowIntegration` is skipped.
- [ ] On the red line in `TestNormalizeCurrency`, press `<leader>to` and read got vs want. The case expects `"usd"` but the function returns `"USD"`. The test is wrong: change the want to `"USD"`, then `<leader>tl`.
- [ ] Open `<leader>ts`, press `J` to land on the next failure, then `Enter` to jump to it.
- [ ] `TestRejectsZeroAmount`: set a breakpoint inside it and press `<leader>td`. Step through and find why it fails, then fix it.
- [ ] Press `<leader>tF`. Nothing should fail now, so you get "No failed tests to rerun".
- [ ] Write your own: a `TestApplyDebit` row for a negative amount that expects an error. Run it alone.
- [ ] Run `go test -coverprofile=coverage.out ./...` in the backend folder, then `<leader>tcc`. Look for lines no test reached.

Next step after this: pick one real function in ledgerflow (a handler helper or a service function with no database call) and write a table test for it using the same pattern.
