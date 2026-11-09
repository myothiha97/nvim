# Neovim Go debugger review

Date: 2026-11-07

## Verdict

The debugger is sound: I found no bug that can crash a session or corrupt program state, and nothing runs on keystrokes. There is one real risk, which can wipe your saved breakpoints, and four small fixes worth making. Review covers all 13 files in `lua/debugging/` plus the hover hook in `config/mouse-hover.lua`, read against the pinned nvim-dap, nvim-dap-ui and LazyVim sources.

Fix first, in this order:

1. **Breakpoints can be lost during Run to Cursor.** nvim-dap clears every breakpoint until the next stop, and our auto-save can write that empty state to disk (issue 1 below).
2. **The breakpoint file is rewritten on every buffer unload,** including picker previews and dap-ui buffers. It's cheap, but pointless disk writes (issue 2).
3. **Hover still evaluates keywords and numbers** while stopped, unlike the new right-click rule (issue 3).
4. **Two small gaps:** one internal is undocumented, and Remove Breakpoint can drop off the right-click menu (issues 4 and 5).

The biggest feature gap compared with GoLand and VS Code is **enabling or disabling a breakpoint without deleting it**, plus **muting all breakpoints**. Both IDEs have this, and nvim-dap doesn't.

## Issues in the current code

Five issues, none of which breaks a running session. Only issue 1 can lose data.

| # | Severity | Where | What happens | Proposed fix |
|---|---|---|---|---|
| 1 | Medium: data loss | `breakpoints.lua` save | Run to Cursor clears all breakpoints until the next stop. If anything triggers a save in that window (closing any buffer, a picker preview, quitting nvim), every file's breakpoints are written to disk as cleared, and they're gone next session. | Skip saving while nvim-dap's own `dap.run_to_cursor` listener is registered (a one-line check on a public listeners table). |
| 2 | Low: performance | `breakpoints.lua` BufUnload | Once nvim-dap is loaded, every buffer unload re-encodes and rewrites the JSON file. That includes picker previews, dap-ui and terminal buffers. It's a few ms each, not a hot path, but repeated while browsing a picker. | Only save for real file buffers, and skip the write when the JSON hasn't changed. |
| 3 | Low: consistency | `hover.lua` | While stopped, hovering `for`, `:=` or `0` asks Delve to evaluate it. It shows `0 = 0` or falls back to LSP after a wasted request. | Reuse the menu's name-only check, so non-names go straight to LSP hover. |
| 4 | Low: maintenance | `layout.lua` | It uses dap-ui's internal `dapui.windows.layouts[i]:is_open()`, which the README's "Upstream internals" table doesn't list. | Add the row, with a check and rollback. No code change. |
| 5 | Low: UX | `menu.lua` | When stopped on a line with a breakpoint and the cursor is on a name, the 5-entry cap fills with Run to Cursor, Evaluate, Add to Watches, Edit Condition and Edit Log Message, so Remove Breakpoint is cut. A gutter click still removes it. | Rank Remove above Edit Log Message, or raise the cap to 6. |

Checked and fine:

- Evaluate and hover always use the frame selected in Call Stack (nvim-dap adds `frameId`).
- Function breakpoints are sent before the program starts.
- Call Stack only fetches frames for expanded goroutines, so it's lighter than stock dap-ui on servers with many goroutines.
- The duplicate-watch check only runs on add.
- Nothing runs on keystrokes or cursor moves. Per-event work is limited to filetype checks on BufWinEnter/BufLeave and a window scan on DAP events.

Minor nits, not worth their own row:

- Call Stack loops threads with `pairs` rather than `ipairs`. This is safe in LuaJIT, and the order comes from Delve.
- `equalalways` is restored only by our own close (Stop or `<leader>du`). If you close panels another way, it stays off until you restart.
- `controls.lua` keeps one global status, so two simultaneous debug sessions would share the exit code and Run Again. That's rare for Go.

## Workarounds and internals

Four places depend on plugin internals. All are pinned by `lazy-lock.json`, so nothing changes until you update a plugin. None can break your program; the worst case is a panel losing a feature.

| Where | What it relies on | Why there's no public API | If it breaks after an update | Risk |
|---|---|---|---|---|
| `stacks.lua` | Replaces dap-ui's Call Stack renderer (`dapui.components.threads`) | dap-ui can't fold threads | Call Stack empty or errors; delete one line in `plugins/ui.lua` to get the stock view back | Highest: a full module swap |
| `controls.lua` | Replaces dap-ui's bar renderer (`dapui.controls.controls`) | dap-ui's bar has no extension point and its redraw keeps a stale window id | Stock bar comes back without an error; Run Again and the exit code disappear | Medium |
| `plugins/core.lua` | nvim-dap's `session.dirty` and `update_threads` | nvim-dap never refetches goroutines after the first stop | Guarded no-op; Call Stack goes back to missing new goroutines | Low |
| `layout.lua` | dap-ui's `windows.layouts[i]:is_open()` | dap-ui has no public "is this layout open" | Panels may open twice or not swap to the Watches variant | Low; missing from the README table (issue 4) |

Also touched, but through public APIs: the watch wrapper (`elements.watches.add`), the menu calling dap-ui's own `w` key, and the hover and evaluate calls. These carry no update risk beyond normal API changes.

After any `:Lazy update` that touches nvim-dap or nvim-dap-ui, run one Go session and check: the Call Stack fold, the bar's 6 buttons plus Run Again, and the Watches panel appearing on the first `w`.

## Features compared with GoLand and VS Code

Of the 23 IDE features below that Delve supports, we have 15, have 4 partly, and are missing 4. Three more (set next statement, restart frame, smart step into) are missing in every Go IDE because Delve can't do them. Of the missing ones, mute-all and disable matter most day to day, and remote attach matters once you debug services in containers.

| Area | Feature | Status | Notes |
|---|---|---|---|
| Breakpoints | Line breakpoint by gutter click | Have | Persisted per project |
| Breakpoints | Condition, hit count, log point | Have | Right-click or `<leader>dN` / `dH` / `dL` |
| Breakpoints | Function breakpoint by name | Partial | Works and is saved, but isn't listed in `<leader>dm` / `dM` or the Breakpoints panel |
| Breakpoints | Disable a breakpoint without deleting it | Partial | Only in the Breakpoints float (`<leader>dp`, `t`). A disabled breakpoint loses its gutter icon and isn't saved. |
| Breakpoints | Mute all breakpoints | Missing | GoLand "Mute breakpoints", VS Code "Deactivate breakpoints" |
| Breakpoints | Breakpoint list with preview | Have | `<leader>dm` / `dM` |
| Run control | Continue, pause, step over/into/out, restart, stop | Have | Control bar plus keys |
| Run control | Run to cursor | Have | Issue 1 applies |
| Run control | Set next statement, restart frame, smart step into | Delve can't | Not available in any Go IDE through Delve |
| Inspection | Variables and globals, set a value | Have | `e` in Variables |
| Inspection | Hover values and inline values | Have | |
| Inspection | Watches, from code or Variables | Have | Duplicates skipped |
| Inspection | Evaluate popup | Have | GoLand Quick Evaluate behaviour |
| Inspection | Call a function while stopped | Have | Type `call f(x)` in the REPL, the same as VS Code's Go extension |
| Inspection | Copy value / copy as expression | Missing | Both IDEs have it on the Variables right-click menu |
| Inspection | Debug console completion | Partial | `Ctrl-X Ctrl-O` only. nvim-dap can show completions as you type. |
| Goroutines | Goroutine list, hide runtime goroutines | Have | Collapsible, double-click |
| Goroutines | Switch goroutine or frame | Have | `o` or double-click |
| Goroutines | Search or filter goroutines in big servers | Partial | Only through `goroutineFilters` in launch.json or `dlv config`. GoLand can search and group. |
| Launch | Debug test or subtest at cursor | Have | Right-click Debug Test, neotest `<leader>td` |
| Launch | Configs with args, env, build flags | Have | dap-go's configs and `.vscode/launch.json` |
| Launch | Attach to a local process | Have | dap-go's "Attach" config |
| Launch | Remote or container attach | Missing | Deferred by you on 2026-11-04 |
| Launch | Disassembly view | Missing | Rarely needed for Go |

## Recommended next steps

Fix the five issues first, in one small commit: each is a few lines and needs no new workaround. Then add the two breakpoint features that are missing.

1. **Fix issues 1 to 5** (about 25 lines in total, no new internals).
2. **Disable and mute breakpoints.** Make disabling a first-class state: a grey gutter icon, saved to disk, a right-click "Disable Breakpoint", and a "Mute All" key. nvim-dap has no disabled state, so we'd keep the disabled list ourselves and send only the enabled ones to Delve. This is about 60 lines. I'd mark it as our own state, not a plugin internal.
3. **Copy Value / Copy as Expression** on the Variables right-click menu (small).
4. **REPL completion as you type,** using nvim-dap's built-in completion helper (one line).
5. **Show function breakpoints** in `<leader>dm` / `dM` (small).
6. **Later:** a goroutine search picker for large servers, and remote/container attach when you need it.

Still to test from Phase 2: the breakpoint items on the right-click menu, Debug Test, and Neovide.
