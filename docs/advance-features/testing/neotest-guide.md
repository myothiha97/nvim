# Testing in Neovim with neotest: setup, config and daily use

Covers Go, Node.js (Jest / Vitest) and Python. Written 2026-11-09 against the `nvim` repo,
branch `feat/test-coverage-history` (PR #33) plus `feat/test-project-config` (project test
settings, not merged yet; marked **[branch]** below).

Contents

1. How neotest is wired into Neovim
2. How the config is structured, and how to change it yourself
3. How to test Go, Node and Python files: flows and examples
4. Troubleshooting

---

## 1. How neotest is wired into Neovim

### 1.1 The idea in one picture

```
 you press a key  ──►  neotest (core)  ──►  adapter for the language  ──►  real test tool
 (<leader>tr ...)      finds the test        builds the command            go test / jest /
                       under the cursor      (neotest-golang, -jest,       vitest / pytest
                                             -vitest, -python)                  │
                                                                                 ▼
 ✓ / ✗ in the code  ◄──  consumers (UI)  ◄──  adapter parses the results  ◄──  output (JSON)
 panels, history,        summary, output,
 coverage, ...           your own modules
```

- **neotest does not test anything itself.** It asks an *adapter* to build a command, runs that
  command in the background (async, so the editor never freezes), and shows the results. If a
  test fails in a terminal, it fails in neotest too. If it passes in a terminal, it passes here.
- **Adapters** know one language/tool: how to find tests in a file (with treesitter), how to
  build the command for "this test / this file / everything", and how to read the results.
- **Consumers** are neotest's extension point: modules that react to runs and results (the
  summary tree, the output popup, and all the custom modules in `lua/testing/`).

### 1.2 Which adapter runs which language

| Language | Adapter | Test tool it runs | Where it comes from |
|---|---|---|---|
| Go | `neotest-golang` | `go test -json` (defaults `-v -race -count=1`) | LazyVim `lang.go` extra |
| JS/TS (Jest) | `neotest-jest` | `node_modules/.bin/jest --json ...` | `lua/plugins/testing.lua` |
| JS/TS (Vitest) | `neotest-vitest` | `vitest --reporter=json ...` | `lua/plugins/testing.lua` |
| Python | `neotest-python` | `pytest` (inside the project's venv) | LazyVim `lang.python` extra |
| C# | not neotest | easy-dotnet's own runner, same keys | `lua/debugging/csharp.lua` |
| Rust | adapter off | — | turned off until rust-analyzer is installed |

How the right adapter is picked for a file:

- **Go**: any `*_test.go` file. The adapter's *root* is the folder with `go.mod` (in ledgerflow:
  `backend/`), even when nvim is opened at the repo root.
- **Jest vs Vitest**: both are on. Jest only claims a test file when a `package.json` from the
  file upward lists `jest` in dependencies / devDependencies or a script. Vitest does the same
  for `vitest`. A project normally has one of them, so only one adapter answers.
- **Python**: `test_*.py` or `*_test.py`. neotest-python finds the interpreter itself:
  `$VIRTUAL_ENV`, then a `.venv` / `venv` folder with `pyvenv.cfg`, then pipenv, poetry, uv.

### 1.3 What loads when (performance)

- **At startup: nothing.** neotest and every module in `lua/testing/` load the first time you
  press a `<leader>t` key (or open the right-click menu's test entries).
- **While typing / scrolling: nothing.** No autocmd runs on keystrokes or cursor moves.
- **Discovery is off** (`discovery = { enabled = false }`). neotest only knows tests in files you
  opened or ran. `<leader>tD` builds the whole-project tree on demand.
- The only real cost is the test process itself, the same as running it in a terminal.

### 1.4 Where results and data live (never in your repo)

| Data | Location |
|---|---|
| Coverage reports | `~/.local/state/nvim/test-coverage/<project>-<hash>/` and `last.lcov` |
| Test history | `~/.local/state/nvim/test-history/<project>.jsonl` (500 runs / 60 days / ~20 MB) |
| Trusted project files **[branch]** | Neovim's trust store (`~/.local/state/nvim/trust`) |

Exception: Python coverage writes coverage.py's `.coverage` file in the project.

---

## 2. How the config is structured

### 2.1 The files

```
~/.config/nvim/
├── lazyvim.json                 enables LazyVim extras: test.core, lang.go, lang.python,
│                                lang.typescript, dap.core ...
├── lua/plugins/testing.lua      THE neotest spec: adapters, options, consumers, keys,
│                                nvim-coverage plugin
├── lua/testing/                 custom features, each one file, each a neotest consumer
│   ├── coverage.lua             <leader>tcf / tca: run with coverage, convert report, paint gutter
│   ├── history.lua              <leader>th / tH: test history across sessions
│   ├── panel.lua                <leader>tO: JetBrains-style Test Results panel
│   ├── marks.lua                <leader>tx: hide / show ✓ ✗ marks and close test panels
│   ├── jump.lua                 <leader>tj: jump test <-> implementation
│   ├── adapters.lua             fix: no duplicate adapter tree in the summary
│   └── project_config.lua       [branch] project test settings (.env.test, Makefile, package.json)
├── lua/config/keymaps.lua       <leader>tj (mapped here so it doesn't load neotest)
└── lua/debugging/menu.lua       right-click: Run Test / Debug Test / Run File Tests /
                                 Show Test Output / Go to Test (only in test files)
```

### 2.2 How the pieces load, step by step

1. `lazyvim.json` enables the **`test.core`** extra. It installs neotest, defines the base keys
   (`tr tt tT tl ts to tS tw ta td`) and, for every enabled `lang.*` extra, adds that language's
   adapter (Go and Python).
2. `lua/plugins/testing.lua` **adds to** that spec (it does not replace it): the Jest and Vitest
   adapters, option changes, extra consumers and extra keys. lazy.nvim merges the two specs.
3. When you first press a test key, lazy.nvim loads neotest. LazyVim's `config` turns the
   `adapters = { ["neotest-jest"] = {...} }` table into real adapter objects and calls
   `neotest.setup(opts)`.
4. neotest then starts every **consumer** listed under `consumers = { ... }`. Each custom module
   in `lua/testing/` is registered there with one line, for example:

   ```lua
   consumers = {
     coverage = function(client) return require("testing.coverage").consumer(client) end,
     history  = function(client) return require("testing.history").consumer(client) end,
     ...
   }
   ```

   That is also how the keys reach them: `require("neotest").coverage.run("file")` calls the
   `run` function the `coverage` consumer returned.

### 2.3 The options in `lua/plugins/testing.lua` and why

| Option | Value | Why |
|---|---|---|
| `adapters["rustaceanvim.neotest"]` | `false` | it loaded rustaceanvim and errored without rust-analyzer |
| `adapters["neotest-vitest"]` | `{}` | turn Vitest on with defaults |
| `adapters["neotest-jest"].jestConfigFile` | nearest `jest.config.{ts,js}` via `vim.fs.find` | the adapter's own lookup crashed (E5560 in an async context) |
| `adapters["neotest-jest"].isTestFile` | test-file name + jest in a `package.json` upward | the adapter's own check could abort whole runs |
| `quickfix.enabled` | `false` | keeps your saved quickfix pins clean |
| `status` | `signs = false, virtual_text = true` | gutter stays for breakpoints; ✓ ✗ ▶ at end of line |
| `floating` | rounded border, LSP hover colours | output popup looks like hover docs |
| `summary.mappings` | `<CR>` jumps, `<Tab>`/double-click folds | JetBrains-style tree |
| `icons`, `highlights` | play icon, `DiagnosticInfo` | follows your colourscheme |
| `discovery.enabled` | `false` | no background scanning; `<leader>tD` on demand |

### 2.4 How to adjust things yourself (recipes)

All edits go in `lua/plugins/testing.lua` unless noted. Restart nvim after editing (neotest reads
its config once).

**Change Go's default `go test` flags (every project)**

neotest-golang's `go_test_args` *replaces* its defaults, so repeat the ones you keep:

```lua
adapters = {
  ["neotest-golang"] = { go_test_args = { "-v", "-race", "-count=1", "-timeout=60s" } },
  ...
}
```

Also update the same list in two places so coverage runs and project settings match:
`lua/testing/coverage.lua` (the `neotest-golang` entry) and `M.GO_DEFAULT_ARGS` in
`lua/testing/project_config.lua` **[branch]**.

**Set env vars for every Go test run**

```lua
["neotest-golang"] = { env = { APP_ENV = "test" } },
```

For one project only, put them in that project's `.env.test` instead **[branch]** (see 2.5).

**Use testify suites in Go** (off on purpose: it scans every Go file when neotest starts)

```lua
["neotest-golang"] = { testify_enabled = true },
```

**Use a different Jest command**

```lua
["neotest-jest"] = { jestCommand = "npm test --", ... },
```

**Python: force pytest or a specific interpreter**

```lua
["neotest-python"] = { runner = "pytest", python = ".venv/bin/python", args = { "-q" } },
```

**Change coverage flags** (e.g. count code in other packages): edit the `args` function of the
`neotest-golang` entry in `lua/testing/coverage.lua`, e.g. add `"-coverpkg=./..."`.

**Add a key**: add a line to the `keys = { ... }` list of the neotest spec, for example
`{ "<leader>tR", function() require("neotest").run.run({ suite = true }) end, desc = "..." }`.

**Turn a custom feature off**: delete its line in `consumers = { ... }` and its key. Each module
is independent; removing one doesn't affect the others.

**Add a new adapter** (e.g. Rust later): set it in `adapters`, for Rust replace `false` with `{}`.

Every place that relies on a plugin internal has a `WARNING:` comment in the code and a row in
`lua/debugging/README.md` ("Upstream internals"). After a plugin update, check those first if
something breaks.

### 2.5 Project test settings **[branch: feat/test-project-config]**

A project's own, editor-neutral files override nvim's defaults (like a project `.prettierrc`
with conform). Without these files nothing changes.

| File (nearest from the test file up to the git root) | What nvim uses |
|---|---|
| `.envrc`, `.env.test` | `KEY=value` / `export KEY=value` lines as env for every test run, any language. `.env.test` wins over `.envrc`. Includes `GOFLAGS`. |
| `package.json` `scripts.test` | if it calls `jest` or `vitest` directly: that command, its flags, and leading `KEY=value` env |
| `Makefile`, `Taskfile.yml`, `justfile` | the literal flags of the plain `go test ...` line in the `test` target |
| `pytest.ini`, `pyproject.toml`, `setup.cfg`, `tox.ini` | read by pytest itself (always was) |
| `jest.config.*`, `vitest.config.*` | read by Jest / Vitest themselves (always was) |

Rules, so you can predict what happens:

- **Trust first.** Each file is used only after Neovim's trust prompt (the one `.nvim.lua` uses).
  It asks the first time and again whenever the file changes. Deny or ignore = nvim defaults.
  Manage it later with `:trust` / `:trust ++deny` / `:trust ++remove` on the open file.
- **Nothing is executed.** Shell lines in `.envrc` (`$(...)`, `$VAR`, `layout go`, `dotenv`) are
  skipped. A `package.json` script with `&&`, `|` or a wrapper script is skipped. A Makefile line
  with `$(VAR)` or `{{...}}` is skipped. Each skip shows one notification saying why.
- **Dropped flags.** From `go test`: `-run`, `-json`, `-v`, `-coverprofile`, `-o`, `-c`, bench
  and profile flags, and package paths (neotest decides what to run). From Jest/Vitest:
  `--watch`, `--coverage`, Vitest's `run`/`watch`/`dev` subcommand.
- **Order.** Project flags come after nvim's defaults, so the project's value wins
  (`-count=2` beats `-count=1`).
- **Notification.** When a file is used: `Using Makefile: -race -tags=integration`.
- **Limit.** Debug Test (`<leader>td`) gets the env files but not the Makefile flags.

Example: a team-shared ledgerflow setup that works in every editor and in CI:

```make
# backend/Makefile
test:
	go test -race -tags integration -timeout 120s ./...
```

```sh
# backend/.env.test
DATABASE_URL=postgres://localhost:5432/ledgerflow_test
APP_ENV=test
```

`<leader>tr` on a Go test then runs
`go test -json <pkg> -run ^TestX$ -v -race -count=1 -tags=integration -timeout=120s` with
`DATABASE_URL` and `APP_ENV` set.

---

## 3. How to test Go, Node and Python files

### 3.1 The daily loop (same for every language)

1. Open a test file. Each test shows a ▶ at the end of its line until it has run.
2. `<leader>tr` runs the test nearest the cursor (or right-click → Run Test).
3. Read the result: ✓ passed, ✗ failed. The failure message appears in red on the failing line.
   `]d` / `[d` jump between failures.
4. `<leader>tO` opens the Test Results panel: failures first with got / want, skips with reason.
   `<leader>to` shows the raw output of the test under the cursor.
5. Fix the code, then `<leader>tl` reruns the last run from anywhere.
6. Still stuck: set a breakpoint (click the gutter or `<leader>db`) and `<leader>td`.
7. Before committing: `<leader>tt` (file) or `<leader>tT` (everything), then `<leader>tF` to
   rerun only what failed.
8. `<leader>tx` hides all marks and closes test panels when you are done.

### 3.2 All keys

| Key | Does |
|---|---|
| `<leader>tr` | Run nearest test (cursor on a table row runs just that case) |
| `<leader>tt` | Run current file |
| `<leader>tT` | Run all test files in the project |
| `<leader>tl` | Rerun last run |
| `<leader>tF` | Rerun failed tests |
| `<leader>td` | Debug nearest test (dap-ui) |
| `<leader>tS` | Stop the run |
| `<leader>tw` | Watch file: rerun on every save (toggle) |
| `<leader>ta` | Attach to a running test's live output |
| `<leader>to` | Output popup for the test under the cursor |
| `<leader>tO` | Test Results panel |
| `<leader>ts` | Summary tree |
| `<leader>tD` | Discover all tests in the project into the tree |
| `<leader>tx` | Hide / show test marks, close test panels |
| `<leader>tj` | Jump test ↔ implementation (creates an unsaved test buffer if none) |
| `<leader>th` | Test history: past runs |
| `<leader>tH` | History of the test under the cursor (spot flaky tests) |
| `<leader>tcf` / `tca` | Run file / all with coverage, paint the gutter |
| `<leader>tcs` | Coverage summary popup |
| `<leader>tct` | Toggle coverage colours |
| `<leader>tcx` | Clear coverage |
| `<leader>tcc` | Load a coverage report you made in a terminal |

Test Results panel (`<leader>tO`): `<CR>` jump / fold, `o` inline output, `O` full output,
`]f` / `[f` next / previous failure, `r` rerun test, `R` rerun failed, `P` raw neotest panel,
`q` close. Mouse: click arrows, double-click, right-click menu.

Summary tree (`<leader>ts`): `<CR>` jump, `<Tab>` / double-click fold, `r` run, `d` debug,
`o` output, `J` / `K` next / previous failure, `m` mark then `R` run marked, `?` help.

### 3.3 Coverage, explained

Coverage answers: *which lines of my app code did the tests run?*

- `<leader>tcf` runs the current file's tests with coverage; `<leader>tca` runs everything.
  When the run ends, covered lines get a green bar in the gutter, missed ones red.
- `<leader>tcs` shows the table. For Go, **Statements** and **Coverage %** are Go statements
  and match `go test -cover` exactly. **Missing** counts uncovered *lines* (a plugin limit).
- Go never measures code inside `_test.go` files. If the code you test lives in the test file,
  the report is empty and you get "coverage report has no source files". Put code in `foo.go`,
  tests in `foo_test.go`.
- Go counts only the package being tested. To also count other packages your tests call, add
  `-coverpkg=./...` (section 2.4).
- Vitest needs `@vitest/coverage-v8`; Python needs `pytest-cov`. nvim tells you if one is missing.
- Use coverage to find untested branches, not as a score to chase.

### 3.4 Go

File and shape: `foo_test.go` next to `foo.go`, same package, `func TestXxx(t *testing.T)`.

**Table-driven test** (the Go standard; each row is runnable on its own):

```go
func TestApplyDebit(t *testing.T) {
	tests := []struct {
		name    string
		balance int64
		amount  int64
		want    int64
		wantErr bool
	}{
		{"normal debit", 100, 30, 70, false},
		{"exact balance", 50, 50, 0, false},
		{"insufficient funds", 10, 30, 10, true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := applyDebit(tt.balance, tt.amount)
			if (err != nil) != tt.wantErr || got != tt.want {
				t.Errorf("applyDebit(%d, %d) = %d, %v; want %d, err=%v",
					tt.balance, tt.amount, got, err, tt.want, tt.wantErr)
			}
		})
	}
}
```

| Scenario | How |
|---|---|
| One table row | cursor on the `{"exact balance", ...}` line, `<leader>tr` |
| Whole test (all rows) | cursor on `func TestApplyDebit`, `<leader>tr` |
| Whole package file | `<leader>tt` |
| All packages | `<leader>tT` |
| Skip slow / DB tests in the fast loop | `if testing.Short() { t.Skip("needs db") }` or a build tag (`//go:build integration`) |
| Run integration-tagged tests | project `Makefile` / `.env.test` with `-tags integration` / `GOFLAGS=-tags=integration` **[branch]**, or edit `go_test_args` |
| Test needs env vars | `.env.test` in the module **[branch]**, or `env` in the adapter options |
| Debug a failing row | breakpoint inside `t.Run`, cursor on the row, `<leader>td` |
| Create a test for a function | cursor on the function, `<leader>ca` → "Add test for X" (gopls), or `<leader>tj` |
| Coverage of a package | open its `_test.go`, `<leader>tcf`, then `<leader>tcs` |
| Race conditions | already on: `-race` is in the default flags |

Notes: testify `assert` / `require` work; testify *suites* need `testify_enabled = true`.
Stopping a Go run (`<leader>tS`) can leave the compiled test binary running until it finishes.

### 3.5 Node.js / TypeScript (Jest or Vitest)

File and shape: `foo.test.ts` / `foo.spec.ts` (or `.js`, `.tsx`), or files under `__tests__/`.

```ts
import { describe, it, expect } from "vitest"; // Jest: globals, no import needed
import { formatAmount } from "./money";

describe("formatAmount", () => {
  it("formats cents", () => {
    expect(formatAmount(1234)).toBe("12.34");
  });

  it.each([
    [0, "0.00"],
    [5, "0.05"],
    [-250, "-2.50"],
  ])("formats %i as %s", (cents, want) => {
    expect(formatAmount(cents)).toBe(want);
  });
});
```

| Scenario | How |
|---|---|
| One `it` / `test` | cursor inside it, `<leader>tr` |
| A whole `describe` group | cursor on the `describe` line, `<leader>tr` |
| File / everything | `<leader>tt` / `<leader>tT` |
| Project uses a special config | `jest.config.*` / `vitest.config.*` are picked up automatically; a `scripts.test` like `jest -c jest.unit.config.js` is used **[branch]** |
| Test needs env vars | `.env.test` **[branch]** or `NODE_ENV=test jest` in `scripts.test` **[branch]** |
| Async code | `it("...", async () => { await ... })`, nothing special |
| Debug | breakpoint, `<leader>td` (js-debug) |
| Coverage | `<leader>tcf`; Vitest needs `npm i -D @vitest/coverage-v8` once |
| Snapshot updated on purpose | run `npx jest -u` / `npx vitest -u` in a terminal |

Notes: watch mode is never used from nvim (`--watch` is dropped); use `<leader>tw` instead.
Each Jest/Vitest run starts the runner again (~1–3 s), so `<leader>tF` with many failures is
slower than rerunning the file.

### 3.6 Python (pytest)

File and shape: `test_foo.py` or `foo_test.py`, functions `def test_xxx():` with plain `assert`.

```python
import pytest
from ledger import apply_debit

def test_normal_debit():
    assert apply_debit(100, 30) == 70

@pytest.mark.parametrize("balance,amount,want", [
    (100, 30, 70),
    (50, 50, 0),
])
def test_apply_debit(balance, amount, want):
    assert apply_debit(balance, amount) == want

def test_insufficient_funds():
    with pytest.raises(ValueError):
        apply_debit(10, 30)
```

| Scenario | How |
|---|---|
| One test | cursor inside it, `<leader>tr` |
| Class of tests | cursor on `class TestX:`, `<leader>tr` |
| File / everything | `<leader>tt` / `<leader>tT` |
| Project options (markers, paths) | `pytest.ini` / `pyproject.toml` `[tool.pytest.ini_options] addopts = ...`, read by pytest |
| Venv / poetry / uv | picked automatically; no config needed |
| Test needs env vars | `.env.test` **[branch]** |
| Debug | breakpoint, `<leader>td` (debugpy) |
| Coverage | `pip install pytest-cov` once, then `<leader>tcf` |

Notes: pytest must be installed in the project's environment. Python support is configured but
was not yet tested end to end on your Mac.

---

## 4. Troubleshooting

| Symptom | Cause / fix |
|---|---|
| No ▶ marks in a test file | Adapter didn't claim it: wrong file name, or (JS) no jest/vitest in `package.json`. For Go, `:checkhealth neotest-golang`. |
| "No tests found" on `<leader>tr` | Cursor outside any test, or treesitter parser missing (`:TSInstall go`). |
| Works in terminal, fails in nvim | Usually a different env or flags than your terminal. Put them in `.env.test` / the Makefile `test` target **[branch]**, or the adapter options (2.4). |
| Coverage: "no source files" | Code under test is inside a `_test.go` file (Go never measures those). |
| Coverage % differs from CI | CI may use `-coverpkg` or another package set. |
| "X is not trusted" **[branch]** | You denied/ignored the trust prompt. Open the file and run `:trust`. |
| "Makefile not used: ..." **[branch]** | The `test` target uses variables or a shell chain; only literal `go test` flags are read. |
| Summary shows an adapter twice | Fixed by `lua/testing/adapters.lua`; restart nvim if it ever reappears. |
| Everything test-related looks stale | `<leader>tx` to clear marks; restart nvim for a full reset. |
