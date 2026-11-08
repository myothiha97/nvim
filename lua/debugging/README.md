# Debugging (DAP)

Everything debugger-related lives here. Imported from `lua/config/lazy.lua`
as `{ import = "debugging.plugins" }`. Built on LazyVim's `dap.core` and
`lang.*` extras; nothing extra is installed.

**Need to change or fix something? Start with `MAINTENANCE.md`** (situations, steps, rollbacks).

Plan and research: `/mnt/project-files/go-debugger/go-debugger-gui-plan.md`
(project files), freeze trace: `todos/freeze/freeze-override-2026-11-04-debugger-gui.md`.

## Files

| File | What |
|---|---|
| `plugins/core.lua` | nvim-dap spec: keys, session listeners, Delve config hook, breakpoint restore at startup |
| `plugins/ui.lua` | nvim-dap-ui spec (replaces LazyVim's open/close listeners) + inline values |
| `plugins/go.lua` | mason-nvim-dap Delve handler (no duplicate Go configs) |
| `plugins/node.lua`, `node.lua` | Node/JS/TS: `npm script…` and `Attach to port 9229` configs (nvim-dap config provider) on top of LazyVim's js-debug setup; Debug Test via neotest |
| `plugins/csharp.lua`, `csharp.lua` | C# / .NET: easy-dotnet.nvim (native arm64 netcoredbg, builds first, launchSettings.json profiles); `<leader>dc` entries that Restart / Run Again can repeat; Debug Test via its test keys |
| `plugins/python.lua`, `python.lua` | Python: `Module… (python -m)` and `Django: runserver` configs on top of LazyVim's nvim-dap-python/debugpy; Debug Test via neotest |
| `delve.lua` | Delve launch options, function breakpoints |
| `breakpoints.lua` | Persistence per project: line (+condition/hit/log) and function breakpoints |
| `prompts.lua` | Floating prompts for condition / hit count / log message; Esc cancels |
| `controls.lua` | The control bar, built in full (no patching of dap-ui's string) |
| `layout.lua` | When panels open/close, which panels, titles, fixed sizes |
| `mouse.lua` | Click the gutter (sign area or line number) to toggle a breakpoint without moving the cursor; fold cells still fold |
| `menu.lua` | Right-click menu: debug entries for the clicked line, at most 5, chosen per state (stopped / breakpoint / test file) |
| `hover.lua` | While stopped, mouse hover shows the value of the hovered expression (called from `config/mouse-hover.lua`; LSP hover is the fallback) |
| `copy.lua` | Copy Value: `y` or right-click in Variables / Watches copies the full value (adapter's clipboard context) |
| `repl_complete.lua` | REPL completion: blink source fed by the adapter's `completions` request (dap-repl only) |
| `list.lua` | Breakpoint list picker (`<leader>dm` file, `<leader>dM` project), same look as `<leader>xd` |

## How a session looks

1. **Start** (`<leader>dc`): only the bottom tray opens: REPL/output with the
   control bar (Continue/Pause · Step Over · Step Into · Step Out · Restart · Stop).
2. **First stop**: the left sidebar opens: VARIABLES + CALL STACK (goroutines).
   Nothing else moves for the rest of the session.
3. **Watches** join the sidebar only while you have at least one watch
   (`<leader>dW` opens them as a float until then).
4. **Breakpoints list** is never in the layout: `<leader>dp` opens it as a float.
5. **Terminal pane** joins the tray only if the adapter runs the program in a
   terminal (Python, Rust, C/C++ do; Delve sends output to the REPL instead).
6. **Several sessions** (Node runs the program in a child session): a list of
   sessions heads the CALL STACK panel; double-click (or `<CR>` / `o`) one to
   switch to it. With one session (Go always) nothing is added.
7. **End**: panels stay; the bar shows `Run Again · Close  exited (code N)`.
   Click Close (or `<leader>du`) to close everything.

Run to Cursor is `<leader>dC` (right-click menu in phase 2).

## Keys (changed or added vs LazyVim)

| Key | Action |
|---|---|
| `<leader>du` | Toggle debug panels (tray + sidebar) |
| `<leader>db` | Toggle breakpoint (saved immediately) |
| `<leader>dB` | Clear breakpoints in this file |
| `<leader>dX` | Clear all breakpoints in this project (incl. function breakpoints) |
| `<leader>dm` / `dM` | Breakpoint list (current file / project) in a picker with preview; `<CR>` jumps |
| `<leader>dN` / `dH` / `dL` | Condition / hit count / log message for the line's breakpoint (float; empty answer clears that field) |
| `<leader>dF` | Toggle function breakpoint by name (saved) |
| `<leader>do` / `dO` | Step over / step out (swapped vs LazyVim) |
| `<leader>dR` / `dt` | Restart / Terminate the top-level session (Node runs the program in a child session; identical to LazyVim's for Go) |
| `<leader>dl` | Run last: reruns the file you originally debugged (the bar's Run Again does the same) |
| `<leader>dx` | Exception breakpoint filters |
| `<leader>dd` | Disable / enable the line's breakpoint (kept as a grey sign, saved; condition/hit/log kept). Also right-click → Disable / Enable Breakpoint. A click or `<leader>db` on a disabled one removes it |
| `<leader>dD` | Mute / unmute all breakpoints (line + function). Not saved; breakpoints added while muted are active |
| `<leader>dI` | Smart Step Into: pick which call on the line to step into (Python, Node; elsewhere a plain Step Into). Also right-click on the current line |
| `<leader>dg` | Jump to Line (LazyVim's; Python only). Also right-click while stopped |
| `<leader>de` | Evaluate the name under the cursor or the selection (keywords, operators, literals are skipped, as in the right-click menu) |
| `<leader>dv` `dG` `dW` `dp` | Focus Variables / Call Stack / Watches / Breakpoints |

In the REPL: completion from the adapter while typing (blink menu). Delve
has no completion support, so in Go the menu offers words from the REPL
buffer, as before.

In panels: double-click expands, `e` edits a value, `w` (or right-click →
Add to Watches) watches a variable, `y` (or right-click → Copy Value) copies
the full value to the clipboard (Variables, Watches; `v`/`V` then `y` still
yanks panel text), `o` opens a frame,
`t` toggles runtime-internal frames (Call Stack) or enables/disables (Breakpoints).
In Call Stack, `y` (or right-click → Copy Stack) copies the stopped thread's
frames as text; right-click → Reset Frame re-runs the current frame (Node only;
double-click a frame first to reset another one).

Two kinds of "disabled": `t` in the Breakpoints panel is dap-ui's own,
kept only in memory (no sign, lost on restart); `<leader>dd` / right-click is
ours (grey sign, saved, listed as "disabled" in `<leader>dm`), and those do
not appear in the Breakpoints panel.

## Languages

| Language | Adapter (installed by) | Start | Tests |
|---|---|---|---|
| Go | Delve (LazyVim `lang.go`) | `<leader>dc` → Debug / Debug Package / Attach | right-click Debug Test, `<leader>td` |
| Node / JS / TS | js-debug (LazyVim `lang.typescript`) | `<leader>dc` → npm script… (e.g. `dev`), Launch file (scripts; TS via `tsx`, `npm i -g tsx`), Attach, Attach to port 9229 | vitest + jest via neotest: right-click Debug Test, `<leader>td` |
| Python | debugpy (LazyVim `lang.python`; interpreter from `<leader>cv` venv, else ./venv / ./.venv) | `<leader>dc` → file, file:args, Module… (`uvicorn main:app`, `flask run`), Django: runserver, attach | pytest via neotest: right-click Debug Test, `<leader>td`; `<leader>dPt` / `dPc` method / class |
| C# / .NET | netcoredbg bundled with easy-dotnet's server (`dotnet tool install -g EasyDotnet`, done on first use) | `<leader>dc` → Debug startup project, Debug project… (pick project + launch profile), Attach to .NET process… | xUnit / NUnit / MSTest: right-click Debug Test, `<leader>td` (easy-dotnet's in-file test keys) |

Each language lives in its own file; shared code (panels, bar, menu, hover,
breakpoints) has no language-specific branches except two lookup tables
that only map to that language's file: the menu's Debug Test table (by
filetype) and controls.lua's Restart / Run Again table (by adapter type, C#
only, because its sessions attach to a one-off debug server).

Stop ends the debuggee for attached processes too (nvim-dap sends
`terminate`), except Node, whose js-debug only detaches. GoLand / VS Code
detach instead.

Per-project settings (args, env, a different entry point): `.vscode/launch.json`, see MAINTENANCE.md §2.

## Goroutine list freshness

nvim-dap only refetches the thread list when the adapter sends `thread`
events, and Delve never does. `plugins/core.lua` marks it stale before every
stop and refetches on Delve's `invalidated` event, so new goroutines appear
and `dlv config hideSystemGoroutines false` takes effect immediately.

## Breakpoint persistence

Saved to `stdpath("data")/debugging/breakpoints/<cwd>.json` on every
breakpoint key, on buffer unload, at session start and on exit. Restored when
a file is opened. Opening a file that has saved breakpoints loads nvim-dap at
that moment (its signs must exist); files without breakpoints cost one table
lookup.

## Upstream internals we depend on (check after plugin updates)

These use plugin internals, not public APIs. nvim-dap and nvim-dap-ui are
`pin = true` (plugins/core.lua, plugins/ui.lua), so `:Lazy update` never moves
them; nothing here changes until you unpin one on purpose. After updating nvim-dap or
nvim-dap-ui, run one Go debug session and check each item (easy-dotnet is not
pinned; check its row after `:Lazy update`):

| File | Internal used | Check | Rollback |
|---|---|---|---|
| `stacks.lua` + `plugins/ui.lua` | replaces `dapui.components.threads` | Call Stack shows goroutines, click/za collapses | delete the `package.loaded[...]` line in `plugins/ui.lua` |
| `controls.lua` | replaces `dapui.controls.controls` | bar shows 6 buttons; after exit shows Run Again + exit code; after Close -> Run Again the first stop shows Continue (not Pause) | remove `require("dapui.controls").controls = M.render` |
| `plugins/core.lua` | nvim-dap `session.dirty`, `session:update_threads` | `dlv config hideSystemGoroutines false` updates Call Stack at once | delete the two `debugging_threads` listeners |
| `layout.lua` | dap-ui `require("dapui.windows").layouts[i]:is_open()` (no public "is this layout open") | first stop opens the sidebar once; first watch swaps in the Watches variant; `<leader>du` toggles | none short of rewriting the open/close logic; if it breaks, panels may open twice or not swap |
| `menu.lua`, `hover.lua` | nvim-dap `session.stopped_thread_id`, `session.current_frame` (fields, not functions; nvim-dap's own `run_to_cursor` uses the first) | right-click while stopped shows Run to Cursor; hovering a variable shows its value | hover: delete the `package.loaded["dap"]` block in `config/mouse-hover.lua`; menu: remove `require("debugging.menu").setup()` in `plugins/core.lua` |
| `copy.lua` | dap-ui's rendering: highlight groups `DapUIVariable` / `DapUIScope` / `DapUIWatchesValue` / `DapUIWatchesError` / `DapUIDecoration` and `dapui.render.canvas`.namespace, to tell which variable a row shows | `y` on a nested variable in Variables and on a watch copies its value | delete `require("debugging.copy").setup()` in `plugins/ui.lua` (if it breaks, `y` only says "Nothing to copy here") |
| `stacks.lua` (sessions list), `breakpoints.lua` (`each_session`) | nvim-dap `session.children` (undocumented field; `dap.sessions()` returns top-level sessions only; nvim-dap's own breakpoint commands walk it too) | Node: Call Stack lists the parent and child session; double-click switches | the list is drawn only with 2+ sessions; delete `render_sessions(canvas)` in `stacks.lua` |
| `plugins/csharp.lua` | wraps easy-dotnet `terminal.tabline.destroy` (it deletes the global `<LeftMouse>` / `<2-LeftMouse>` maps) | after `:Dotnet run` and closing its panel, a gutter click in a Go file still toggles a breakpoint | delete the `tabline.destroy` block (gutter clicks then stop working after that panel closes, until restart) |

## Known limits

See "Known Ceiling" in `todos/languages/nvim-dap-webstorm-parity-and-enhancements.md`
and §7 of the plan. In short: no deferred-call view, no set-next-statement,
no single-click tree expansion, no draggable panels.

- Run to Cursor (nvim-dap) clears all breakpoints until the next stop, then puts them back. Saving is paused in that window (breakpoints.lua), so quitting or closing a buffer then can't persist the cleared state.
- Copy Value: netcoredbg (C#) has no clipboard context, so it copies the value as the panel shows it (long strings may be shortened by the adapter).
- REPL completion: none from Delve (Go); buffer words remain.
- Smart Step Into: Python, Node only (Delve's DAP server lacks it, though GoLand has it; netcoredbg too). Reset Frame: Node only. Jump to Line: Python only. Menu entries for them appear only where supported.
- Hover shows a one-line value; nested values are expanded with right-click → Evaluate.
