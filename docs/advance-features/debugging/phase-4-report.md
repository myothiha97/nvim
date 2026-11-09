# Neovim debugger: Phase 4 report

Date: 2026-11-07

## Summary

Go, Node/JS/TS, Python and C# debugging all work, checked end to end against the real debug adapters. Everything is merged into main and dev and pushed, and your Mac is on main. Go behaves exactly as before: the same 27-check Go suite gives identical results on the old Go-tested branch and on the final code.

- **Verified by me:** every scenario in the tables below passed, headless, against your real config, your lockfile plugin versions and the real adapters (js-debug, debugpy, Delve, easy-dotnet's netcoredbg).
- **Fixed on the way:** 2 real bugs, both in plugins. neotest-jest could abort every JS/TS test run, and easy-dotnet's terminal panel deleted the gutter-click breakpoint mapping for every language, Go included.
- **Not verifiable here:** anything you have to look at or click, such as layout, mouse and colours, plus the macOS arm64 C# debugger itself. All languages go through the same UI code as Go. Your checklist is below.
- **Merged:** main fast-forwarded to 8742581, dev got the usual merge commit (63cbea6), both pushed. Your uncommitted options.lua change is untouched.

## Progress

Phases 1, 2 and 4 (Node/JS/TS, Python, C#) are committed, pushed and merged. Phase 3 is skipped at your request; Rust and C/C++ are optional for later. Commit messages carry no AI attribution lines, per docs/CLAUDE.md.

| Phase | Scope | Branch | Commits | State |
|---|---|---|---|---|
| 1 | Mouse-driven GUI: panels, 6-button bar, gutter breakpoints | feat/debugger-gui | d61b3cc | Done, tested by you |
| 2 | Right-click menu, hover values, watches, Evaluate, review fixes, pinning, MAINTENANCE.md | feat/debugger-phase2 | 70d6d2e, 9c7f0c3, 8c36493, ca250bf | Done, tested by you |
| 3 | Docker / container debugging | none | none | Skipped (your call) |
| 4a | Node/JS/TS and Python, per-language files, child-session aware Restart/Stop/Run Again | feat/debugger-phase4 | 4085318 | Done, verified by me |
| 4b | C# | feat/debugger-phase4 | 8742581 | Done, verified by me (easy-dotnet) |
| 4c | Rust, C/C++ | none | none | Optional, later |

The branches stack in a straight line on the old main (3c20501), so feat/debugger-phase4 holds all three. It is merged into main (fast-forward) and dev, and all three branches are pushed.

## What I verified

Everything below passed on Neovim 0.12.6 with your config and lockfile versions of nvim-dap, nvim-dap-ui, neotest and the adapters' plugins. Each check started a real debug session, stopped at a breakpoint, checked the file and line, and evaluated a variable.

| Language | Scenario | What was checked | Result |
|---|---|---|---|
| Node/TS | Launch file (TS via tsx) | Breakpoint in .ts (source maps), evaluate, panels open, Restart, Stop ends parent and child | Pass |
| Node/TS | npm script… → `npm run dev` (Express, `tsx watch`) | Request hits handler breakpoint, evaluate, response after Continue, output in terminal pane, Restart, Stop, Run Again without re-asking, no orphan server | Pass |
| Node/TS | tsx watch reload | Edit file mid-session, server restarts, breakpoint still hits, new code served, no orphan | Pass |
| Node | Attach to port 9229 | Attach to `node --inspect`, stop, evaluate, detach | Pass |
| Node/TS | vitest Debug Test | Stops in source under test, evaluate, session ends | Pass |
| Node | jest Debug Test | Same as vitest | Pass |
| Python | Launch file | Breakpoint, evaluate, uses project `.venv`, Restart, Stop | Pass |
| Python | Module… (`python -m app myo`) | Args passed, Run Again keeps them, Esc at prompt aborts cleanly | Pass |
| Python | Django: runserver | View breakpoint via curl, evaluate, response, server gone after Stop | Pass |
| Python | FastAPI via Module… (`uvicorn api:app`) | Route breakpoint, evaluate, server gone after Stop | Pass |
| Python | pytest Debug Test, `<leader>dPt` | Stops in source under test, evaluate | Pass |
| All | Evaluate name detection | Shown on names (incl. `req.query`, params), hidden on `def`, `const`, `return`, `=`, `+` in TS, JS, Python | Pass |
| All | Right-click menu | Debug Test shown only on test files per language, hidden during a session; Evaluate/Watch on names only | Pass |
| Go | Regression | Launch, evaluate, single session, Restart, Stop, Run Again, Debug Test: unchanged | Pass |
| C# | Debug startup project (console) | Builds, stops, evaluate, panels open, Restart and Run Again without prompts, one session after Restart, Stop | Pass |
| C# | Debug project… (ASP.NET, launch profile http) | Profile env and URL applied, request hits handler breakpoint, response after Continue, server gone after Stop | Pass |
| C# | xUnit Debug Test | Right-click shows Debug Test, stops in code under test, evaluate, session ends | Pass |
| C# | Attach to .NET process… | Attach to running app, request hits breakpoint, Stop ends session (the app is killed, see Potential issues #8) | Pass |
| Go | Extended regression, other languages loaded in the same Neovim | 27 checks: only Go configs offered in Go files, conditional breakpoint, panels open on first stop, bar buttons, Step Into/Over/Out, menu (Evaluate, Run to Cursor, keyword hiding), Restart, Stop, Run Again, exit code in bar, Close, function breakpoint, Debug Package, Debug Test via menu and via neotest (<leader>td), attach, gutter-click mapping intact after C# use | Pass, identical to the old Go-tested branch |

Adapters used: js-debug 1.112.0, debugpy (latest pip), Delve 1.27.2. Mason on your Mac may install slightly different versions.

**Go impact check (your question).** Three parts. First, I read every change to shared code since the Go-tested Phase 2: Restart, Stop and Run Again now act on the top-level session and look up a C#-only replay table, and the menu routes Debug Test through each language's file. For a Go session (always one session, adapter type `go`) each of these does exactly what it did before. Second, the Node, Python and C# config providers return nothing for Go buffers, and easy-dotnet loads only for C#/F#/VB/Razor buffers or `:Dotnet`; its debugger listeners check for its own sessions first. Third, I ran the same 27-check Go suite on the old Go-tested branch and on the final code, with C#, Node and Python loaded first in the same Neovim: identical results. The one cross-language problem found (easy-dotnet deleting the gutter-click mapping) is fixed and covered by that suite.

## Bugs found and fixed

Two real bugs turned up, both in plugins rather than in our code. Each is fixed with a small, documented override.

- **neotest-jest aborted every JS/TS test run in some setups.** Its test-file check also reads `package.json` in the folder Neovim was started from. When that folder has none (a monorepo root, or `~`), it calls `vim.notify` from an async context, which throws `E5560` and kills the whole neotest run. Vitest tests broke too, not just jest ones. Upstream still has this bug.
   - Fix: `lua/plugins/testing.lua` passes neotest-jest its own `isTestFile`. The rule is the same (a jest dependency or a `jest` script), but it looks at every `package.json` from the test file upward and never calls `vim.notify`. It runs only for test-named files, inside neotest's async task, and reads one or two small files.
- **easy-dotnet removed gutter-click breakpoints for every language.** Its terminal panel (output of `:Dotnet run`, build or test) maps left-click and double-click globally while open, and deletes both mappings when it closes. That wiped our gutter-click mapping until restart, in Go files too. Fix: `lua/debugging/plugins/csharp.lua` puts our mapping back when that panel closes. It runs once per panel close and touches nothing else. It wraps an easy-dotnet internal, so it's listed in the README's "Upstream internals" table; if upstream renames it, the wrapper is skipped and only that one bug returns. While the panel is open, gutter clicks act as plain clicks.
- **Repo rule applied to history:** the six debugger commits had `Co-Authored-By` / `Claude-Session` lines, which docs/CLAUDE.md forbids. I rewrote them without those lines (same trees, same dates; nothing was pushed). The new hashes are in Progress above.

## Potential issues

None of these block normal use. Each is minor, or behaves this way on purpose.

| # | What you might see | Why | What to do |
|---|---|---|---|
| 1 | "No tests found" if you click Debug Test the instant a test file opens | neotest parses a newly opened file asynchronously, which takes about a second | Click again. No code change: making it wait would put work on the open path |
| 2 | Run Again reuses your last answers (npm script picked, module + args typed) | By design: it replays the exact config the adapter got | Pick the config from `<leader>dc` to be asked again |
| 3 | Evaluate showing on a keyword in a huge file you opened a moment ago | Name detection reads the tree-sitter tree, which the highlighter builds on first draw. Before that, a simple letter check is the fallback | None in practice: the visible area is parsed before you can click it |
| 4 | pytest Debug Test stops on `SystemExit` in `neotest.py` | Your tests failed to import (e.g. `src/` layout without `pythonpath`). debugpy stops on the uncaught exit, as PyCharm does | Same fix as plain `pytest`: set `pythonpath` in `pyproject.toml` or add a `conftest.py` |
| 5 | Several sessions listed while debugging Node | js-debug starts a child session per Node process (npm → tsx watcher → your server) | Normal. Restart, Stop and Run Again already act on the top-level one |
| 6 | Adapter versions differ from what I tested | Mason isn't pinned the way lazy.nvim plugins are | Only `:MasonUpdate` changes them. If something breaks after one, check MAINTENANCE.md |
| 7 | Go debugging fails with "Go version too old for this Delve" | Latest Delve needs Go 1.25+ | Keep Go current, or pin Delve. I hit this only in the test container |
| 8 | Stop on an ATTACHED process ends that process (Go, Python, C#). Node only detaches | nvim-dap's Stop sends the adapter a terminate request. This was already the case for Go before Phase 4 (same result on the old branch). GoLand and VS Code detach instead | Fine for local dev processes. If you attach to something that must keep running, say so and I'll add a detach-on-Stop for attach sessions (small change, but it changes Go behaviour, so your call) |
| 9 | "Roslyn requires dotnet 10 sdk" when opening a .cs file | easy-dotnet's C# language server needs the .NET 10 SDK. Debugging itself works with .NET 8 (what I tested) | Install the .NET 10 SDK for completion and go-to-definition in C# |
| 10 | "Run aborted" message when starting C# from <leader>dc | The entry hands over to easy-dotnet (build, then start its debugger), and nvim-dap reports that hand-over as an abort | Ignore it; the session starts a moment later |
| 11 | First C# use takes longer, or fails offline | easy-dotnet installs its server with dotnet tool install -g EasyDotnet on first use | One-time. Needs internet and a .NET SDK |
| 12 | Gutter clicks don't set breakpoints while easy-dotnet's terminal panel is open | That panel takes over left-click while it's open (see Bugs found). Ours comes back when it closes | Close the panel (q) or use <leader>db |
| 13 | C# breaks after :Lazy update | easy-dotnet isn't pinned (its plugin and server update together), so updates can move it | Run the easy-dotnet row of the README's "Upstream internals" check; roll back with the lockfile (d8e5970 is the tested commit) |

## Your test checklist (when you next use each language)

These cover what I can't check headless: how it looks, mouse behaviour and your Mac's adapters. Each takes about a minute. If anything's off, send me a screenshot and the tail of `~/.local/state/nvim/dap.log`.

**Once, first:** run `:Mason` and confirm `js-debug-adapter` and `debugpy` are installed. LazyVim installs them on first use, so give it a moment.

**Node / TS**

- In an Express/Nest project: `<leader>dc` → "npm script…" → `dev`. Hit an endpoint with a breakpoint set. Panels open, the line is highlighted, and hovering a variable shows its value.
- While stopped: right-click a variable → Evaluate and Add to Watches. Right-click `const` or `=`: neither item appears.
- Bar buttons: Restart brings the server back, and Stop leaves no server on the port (`lsof -i :<port>`).
- Save a file while the dev server runs under the debugger. It reloads and breakpoints still hit.
- One-off script: open a `.ts` file → `<leader>dc` → "Launch file".
- vitest or jest: right-click inside a test → Debug Test stops in your code.

**Python**

- Select your venv (`<leader>cv`), then `<leader>dc` → "file" on a script.
- Web app: "Module…" → `uvicorn main:app`, or "Django: runserver". I verified uvicorn without `--reload`. With it, your app runs in a child process; debugpy normally follows it, but I didn't test that, so try it once.
- pytest: right-click inside a test → Debug Test. Also try `<leader>dPt` on a test method.

**Go (spot check, nothing should have changed)**

- One normal debug session and one Debug Test, as before.

**C# / .NET** (first open of a .cs file installs easy-dotnet and its server; give it a minute)

- Console app: set a breakpoint, `<leader>dc` → "Debug startup project (.NET)". It builds, stops, panels open, hover shows values.
- ASP.NET: `<leader>dc` → "Debug project… (.NET)", pick the project and the `http` profile. Hit an endpoint; Restart and Run Again start it again without asking.
- This is the one thing I couldn't test: confirm it works at all on your Mac (native arm64 debugger). If it fails, send me the tail of `~/.local/state/nvim/dap.log`.
- xUnit/NUnit test file: right-click inside a test → Debug Test, or `<leader>td`.
- Run `:Dotnet run`, let its panel close, then click the gutter in a Go file: the breakpoint toggles.

## Limits vs Visual Studio and JetBrains

Day-to-day debugging is covered: breakpoints (conditional, log points), stepping, run to cursor, variables, watches, call stack, evaluate, exception breaks, test debugging and attach. What's missing comes from two ceilings. The DAP protocol and the open-source adapters (Delve, js-debug, debugpy, netcoredbg) expose less than the IDEs' own debug engines, and some features need IDE infrastructure that Neovim doesn't have.

**Can't be done (adapter or protocol ceiling)**

| Feature | Who has it | Status here |
|---|---|---|
| Edit and Continue / Hot Reload while paused | Visual Studio, Rider (.NET) | No. netcoredbg, Delve, js-debug and debugpy don't support it. Use `dotnet watch`, `tsx watch` or `--reload` outside the debugger |
| Set Next Statement (drag the execution pointer) | Visual Studio, Rider | No for Go, Node, C#. debugpy supports it, but it isn't wired to the menu |
| Historical debugging / IntelliTrace, step back | Visual Studio Enterprise | No. Delve can step back only with `rr` on Linux, not macOS |
| Mixed-mode (native + managed) debugging | Visual Studio | No |
| Decompile and step into code with no source (.NET) | Rider, Visual Studio | No. netcoredbg can't decompile |
| Full C# expression evaluation (lambdas, LINQ in Watch) | Visual Studio, Rider | Limited. netcoredbg evaluates simpler expressions than vsdbg; Microsoft's vsdbg is licensed for VS/VS Code only |
| Debug visualizers (DataTable, JSON, image, DataFrame viewers) | Visual Studio, Rider, PyCharm | No. Values show as text trees |
| Parallel Stacks / Tasks windows, concurrency diagrams | Visual Studio, PyCharm | No. Go has a goroutine list; Node shows async stacks |
| Live CPU/memory profiler during debug | Visual Studio Diagnostic Tools, Rider DPA | No. easy-dotnet has simple CPU/memory graph panels for C#, not added to our layout |
| Dump / core-file debugging | Visual Studio, GoLand | Not set up (Delve can open core files from the CLI) |
| Blazor WASM, MAUI, Unity device debugging | Visual Studio, Rider | No |

**Possible, but not built (only if you ever ask)**

| Feature | Who has it | Effort |
|---|---|---|
| Disable or mute breakpoints without deleting | All IDEs | Small (in the Phase 2 review gaps) |
| Hit-count breakpoints ("break on 5th hit") | All IDEs | Small: nvim-dap supports it, the menu doesn't offer it |
| Smart Step Into (pick which call on a line) | JetBrains, Visual Studio | Small, where the adapter supports step-in targets |
| Copy value, REPL autocomplete | All IDEs | Small (in the review gaps) |
| Exception settings per exception type | Visual Studio | Medium. Today it's filter level only (`<leader>dx`) |
| Compound / multi-project launch | VS Code compounds, Rider multi-run | Medium. nvim-dap runs several sessions, but there's no one-click compound |
| Remote / Docker debugging | All IDEs | Phase 3, skipped |
| Browser (Chrome) debugging for frontend | WebStorm, VS Code | Small: js-debug supports it. Left out on purpose, as you debug frontend in Chrome |

**Already at parity (for reference):** conditional and log breakpoints, function breakpoints (Go), run to cursor, Evaluate (GoLand style), watches, inline values, hover values, goroutine filtering, call stack navigation, Restart, Run Again, test debugging from the editor, attach, Django template debugging (debugpy `django: true`).

## C#: easy-dotnet

You chose easy-dotnet.nvim, and it's in. Mason's netcoredbg is an Intel-only build that can't debug arm64 .NET apps on your Apple Silicon Mac ([mason-registry #17681](https://github.com/mason-org/mason-registry/issues/17681)); easy-dotnet bundles a native arm64 netcoredbg (confirmed `Mach-O arm64` in EasyDotnet 3.4.36), builds before debugging and reads launchSettings.json profiles. Its sessions go through nvim-dap, so our panels, bar, menu, hover and Evaluate apply unchanged.

What I added, all in `lua/debugging/csharp.lua` and `lua/debugging/plugins/csharp.lua`: three `<leader>dc` entries (startup project, project + profile, attach), Restart and Run Again that call easy-dotnet again instead of re-attaching to a closed port, Debug Test routed to easy-dotnet's test keys (moved to `<leader>tr/td/tt/to` so they don't shadow your debug and test groups), and the gutter-click fix above. The only shared-code change is one lookup table in controls.lua keyed by adapter type, which doesn't match Go, Node or Python sessions.

**Verified:** console, ASP.NET with a launch profile, xUnit Debug Test and attach, on .NET 8 with the Linux build of the same debugger (results above). **N****ot**** verifiable here:** the macOS arm64 binary on a real Mac; it's the first item in your C# checklist.

## Merge plan

Done. Perf review passed on the C# commit (lazy-loaded only for C# files, nothing on keystrokes or redraws, syntax and boot checks clean). feat/debugger-phase4 (8742581) holds all three debugger phases; main was a strict ancestor, so main fast-forwarded to it with no conflicts possible, and dev (whose tree matched main) got the usual "Merge branch 'main' into dev" commit 63cbea6, with the same tree as main. All pushed. On your Mac, main, dev and feat/debugger-phase4 match origin and main is checked out.

Old unrelated branches on origin (theme trials, feat/go-dap-goroutines and similar, last touched July to September) were not merged: they predate the current main and the debugger replaces feat/go-dap-goroutines. Two sync bundles sit in your repo, `.git/claude-debugger.bundle` and `.git/claude-debugger-2.bundle`; they're safe to delete, and I'll leave that to you.

Your uncommitted `lua/config/options.lua` change stays untouched in the working tree throughout.

## Phase 5: dap-ui additions (2026-11-08)

You chose to stay on nvim-dap-ui and port the features nvim-dap-view has that we lacked. All three are on main (`b63f090`) and dev (`73f5ce3`), pushed, and your Mac is synced (options.lua still uncommitted).

- **Copy Value**: `y` or right-click → Copy Value on a row in Variables or Watches. The value is fetched again from the adapter with an `evaluate` in the "clipboard" context (as VS Code does), so long strings and whole structs/dicts come out in full, not the shortened panel text. Files: `copy.lua`, entry in `menu.lua`.
- **REPL completion**: a blink.cmp source fed by the adapter's `completions` request, active only in the debug REPL. Words from the REPL buffer stay as the fallback. File: `repl_complete.lua`, spec in `plugins/ui.lua`.
- **Sessions view**: with two or more sessions (Node's parent + child session) a sessions list heads the Call Stack panel; double-click, `<CR>` or `o` switches. With one session (Go always) nothing is added. File: `stacks.lua`.

| Adapter | Full value on copy | REPL completion |
|---|---|---|
| Go (Delve) | yes | no (Delve has none; buffer words remain) |
| Node (js-debug) | yes | yes |
| Python (debugpy) | yes | yes |
| C# (netcoredbg) | no, copies the panel value | yes |

**Verified headless:** copy of long strings, nested values and watches in Python, Node, Go, C#; completion replacing only the typed word, member completion (`config.ke` → keys), nvim-dap's `.commands` left alone; Node session switching both ways; list gone after Stop. Regressions unchanged: Go suite 27/27, menu routing 11/11, Node restart/stop 7/7. Startup unchanged: nothing debugger-related loads at boot.

**New upstream dependencies** (README "Upstream internals"): `copy.lua` reads dap-ui's highlight groups to know which variable a row shows (if dap-ui changes them, `y` only says "Nothing to copy here"); the sessions list uses nvim-dap's undocumented `session.children`. Both plugins are pinned.

**Check on your Mac:**

- Go: stop at a breakpoint, `y` on a long string in Variables, paste it elsewhere: whole string
- Python: right-click a nested dict entry → Copy Value
- Python or Node: type a few letters of a local in the REPL: the menu shows it
- Node: npm script session: Call Stack shows two sessions; double-click switches

A new bundle `.git/claude-debugger-3.bundle` sits next to the two older ones; all three can be deleted.

## Gaps vs JetBrains (checked 2026-11-08)

Method: the feature list of GoLand / PyCharm / WebStorm debuggers against our setup, plus a live dump of what each adapter actually supports (DAP capabilities, read from a running session in the test rig). JetBrains talks to Delve directly, not through DAP, so a GoLand feature is only possible here if Delve's DAP server exposes it.

**Already at parity:** line / conditional / hit-count / log breakpoints, function breakpoints, exception filters, persistence per project, Run to Cursor, step over / into / out, Restart, Run Again, Variables with set value, Watches, Evaluate (selection, hover, right-click), inline values, Call Stack with collapsible goroutines and hidden library frames, sessions view, Copy Value, REPL with completion, Debug Test from the editor, attach (Node, Python), exception details on stop (nvim-dap shows them as a diagnostic on the line; all four adapters support it).

**Missing, worth doing (small, ranked for Go / Node / Python work):**

| # | JetBrains feature | Adapters that support it | What it takes |
|---|---|---|---|
| 1 | Disable a breakpoint (keep it, greyed out) and Mute All Breakpoints | All (client side) | nvim-dap has no disabled state, and dap-ui's `t` in Breakpoints actually removes the breakpoint. Add a disabled list to `breakpoints.lua` (saved like the rest), a grey sign, a menu entry and one key. Touches Go-tested persistence code, so the Go suite gets rerun |
| 2 | Smart Step Into (pick which call on the line) | Python, Node. Not Go (Delve's DAP server lacks it, though GoLand has it), not C# | nvim-dap's `step_into({askForTargets = true})`; one menu entry, shown only when the adapter supports it |
| 3 | Reset Frame (re-run the current function) | Node only | nvim-dap's `restart_frame()`; one Call Stack menu entry, Node only |
| 4 | Jump to Line (set next statement) | Python only | nvim-dap's `goto_()`; one menu entry, Python only |
| 5 | Copy Stack (frames as text, for bug reports) | All (client side) | Small: format the current thread's frames to the clipboard from the Call Stack panel |

**Missing, possible but heavier (flagged):**

| JetBrains feature | Status |
|---|---|
| Watchpoint / break when a value changes | Delve supports it (DAP data breakpoints), js-debug, debugpy and netcoredbg don't. nvim-dap has no API for it, so we would send the requests and re-send them on restart ourselves. Medium; Go only |
| Exception breakpoint for one exception type, with a condition | debugpy (exception options) and js-debug (filter conditions) support it; today it's filter level only. Medium |
| Remove-once-hit and dependent breakpoints ("disable until X is hit") | Not in DAP; would be custom logic on every stop. Medium, low value |
| View as hex / value formatting | debugpy, js-debug only; not Delve. Low value |
| Disassembly / memory view | Delve supports both; would need the extra plugin nvim-dap-disasm. Low value for Go app work |

The "Can't be done" table above (Edit and Continue, step back, decompile, visualizers, profiler) still holds.

## Phase 6: JetBrains gaps closed (2026-11-08)

The five small gaps are on main (`5edc612`) and dev (`ea72529`), pushed. On your Mac, main and dev are updated; the checkout was left on `feat/db-tooling` (the database thread's branch).

| Feature | How | Where it works |
|---|---|---|
| Disable / enable a breakpoint | `<leader>dd` or right-click; grey sign, condition/hit/log kept, saved across restarts, shown as "disabled" in `<leader>dm`. A click or `<leader>db` on a disabled one removes it | All |
| Mute All | `<leader>dD`; line + function breakpoints. Not saved; breakpoints added while muted are active | All |
| Smart Step Into | `<leader>dI`, or right-click on the current line | Python, Node |
| Jump to Line | `<leader>dg` (LazyVim's), or right-click while stopped | Python |
| Reset Frame | right-click in Call Stack (re-runs the current frame) | Node |
| Copy Stack | `y` or right-click in Call Stack | All |

**Go stability:** every existing suite was rerun and compared line by line with the results from before: Go 10/10 and 27/27, menu 11/11, mouse, Node, Python, C#, attach and Phase 5 suites all identical. The Go-specific test shows the stopped right-click menu is exactly the same as before (Run to Cursor · Evaluate · Add to Watches · Remove Breakpoint · Edit Condition), and Smart Step Into / Jump to Line / Reset Frame never appear for Go because Delve doesn't support them. Startup: nothing debugger-related loads at boot; `breakpoints.lua` (loaded at startup) now parses in 0.29 ms instead of 0.19 ms.

**New features verified headless:** Python 22/22 (disable, save + reopen, menus, Smart Step Into into `add` skipping `double`, continue skips the disabled line, Jump to Line, Mute then run to end, Unmute keeps the disabled one, click / `<leader>db` / condition prompt on a disabled breakpoint), Go 11/11 (disable, continue skips it, Copy Stack, Mute incl. function breakpoints, Unmute), Node 8/8 (Smart Step Into, Copy Stack, Reset Frame back to the start of `add`). One bug found and fixed during testing: re-reading a file (`:e`) placed the grey sign twice.

**Caveat:** `t` in the Breakpoints panel is dap-ui's own disable (memory only, no sign, lost on restart) and our disabled breakpoints don't show in that panel. Use `<leader>dd` and `<leader>dm` for the saved kind. Unifying them would mean replacing another dap-ui internal, so I left it.

**Check on your Mac (2 minutes):**

- Go: `<leader>dd` on a breakpoint turns it grey; run: it doesn't stop there; restart Neovim: still grey
- Go: `<leader>dD` mutes, the run goes straight through; `<leader>dD` again brings them back
- `y` in Call Stack, paste: the frames as text
- Python: `<leader>dI` on `f(g(x))` asks which call to step into

The new bundle is `.git/claude-debugger-4.bundle`; all four bundle files there can be deleted.
