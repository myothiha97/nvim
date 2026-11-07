# Debugger maintenance: when you need to touch this, and what to do

Normally you never need to. nvim-dap and nvim-dap-ui are `pin = true`, so
`:Lazy update` can't break anything here. Everything else uses public APIs.
Find your situation below; each one says what to do and which file, if any.

| Situation | Touch the config? | Go to |
|---|---|---|
| Upgraded Go | No | [1](#1-you-upgraded-go) |
| A project needs args, env, build tags, another `main` | No | [2](#2-a-project-needs-its-own-launch-settings) |
| Server with hundreds of goroutines | No | [3](#3-too-many-goroutines-in-call-stack) |
| Something misbehaves mid-debug | No, collect info first | [4](#4-something-misbehaves) |
| Breakpoints missing or on wrong lines | No | [5](#5-breakpoints-missing-or-on-the-wrong-line) |
| Upgraded Neovim | No, smoke test | [6](#6-you-upgraded-neovim) |
| Want a newer nvim-dap / nvim-dap-ui | Yes, one line | [7](#7-you-want-a-newer-nvim-dap-or-nvim-dap-ui) |
| One custom feature breaks | Yes, one line | [8](#8-roll-back-one-feature) |
| Need the stock LazyVim debugger back | Yes, one line | [9](#9-turn-the-whole-thing-off) |
| Adding Node / Python / Rust / C / C# | Yes | [10](#10-adding-another-language) |

## 1. You upgraded Go

Run `:MasonUpdate` (or `:Mason`, update `delve`). Delve must support your Go
version; an old Delve fails at session start with a Go-version error. No
config change.

## 2. A project needs its own launch settings

Put a `.vscode/launch.json` in the project root. nvim-dap reads it, and our
Delve defaults (`delve.lua`) still apply unless the file sets them. Pick it
from `<leader>dc`.

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Server (dev)",
      "type": "go",
      "request": "launch",
      "mode": "debug",
      "program": "${workspaceFolder}/cmd/server",
      "args": ["--port", "8080"],
      "env": { "APP_ENV": "dev" },
      "buildFlags": "-tags=integration"
    }
  ]
}
```

For a test package use `"mode": "test"` and `"program": "${workspaceFolder}/pkg/x"`.

## 3. Too many goroutines in Call Stack

Per project, add to that launch.json configuration:
`"goroutineFilters": "-with userloc main"` (only goroutines running your code).
Live, in the REPL: `dlv config goroutineFilters -with userloc main`.
Runtime goroutines are already hidden (`hideSystemGoroutines`, `delve.lua`).

## 4. Something misbehaves

Collect before changing anything:

1. `:DapSetLogLevel TRACE`, reproduce, then read `~/.local/state/nvim/dap.log`
   (not `~/.cache`). Set it back with `:DapSetLogLevel INFO`; TRACE grows fast.
2. `:checkhealth dap` for adapter problems.
3. Note the exact steps and take a screenshot of the panels.

Known Delve behaviour, not bugs:
- A conditional breakpoint on a `for` header stops early. Put it on the first
  line of the loop body.
- "could not find statement": the line has no code (comment, blank, `}`).
- Calling your own functions in Evaluate / Watches fails; type `call f(x)` in
  the REPL instead.
- Set next statement, restart frame, smart step into: Delve can't, in any IDE.

## 5. Breakpoints missing or on the wrong line

Saved per project (the directory nvim was started in) at
`~/.local/share/nvim/debugging/breakpoints/<cwd with / as %>.json`.
- Started nvim from another directory: they're in that directory's file.
- File edited outside nvim: lines shift; saved breakpoints keep their old
  line numbers. Fix them in the gutter; they save immediately.
- To start clean for a project: `<leader>dX` (clears loaded, unloaded and
  function breakpoints).

## 6. You upgraded Neovim

Low risk (public APIs only). One Go session, check: gutter click toggles a
breakpoint, right-click shows the debug entries, hover shows a value while
stopped, `<leader>de` opens Evaluate.

## 7. You want a newer nvim-dap or nvim-dap-ui

1. Delete the `pin = true` line in `plugins/core.lua` (nvim-dap) or
   `plugins/ui.lua` (nvim-dap-ui).
2. `:Lazy update` that plugin.
3. Run one Go session and do the checks in README.md, "Upstream internals".
4. All good: put `pin = true` back and commit `lazy-lock.json`.
   Something broke: `:Lazy restore` that plugin (back to the lock file), put
   the pin back. Fix later or use the rollback in section 8.

## 8. Roll back one feature

Each custom piece can be switched off by deleting one line; the rest keeps
working. The README "Upstream internals" table lists the line for: collapsible
Call Stack, control bar, goroutine refresh, right-click menu, debugger hover.
Others:
- Gutter click: remove `require("debugging.mouse").setup()` in `plugins/core.lua`.
- Breakpoint persistence: remove `require("debugging.breakpoints").setup()` there.
- Watches auto-open / duplicate skip: remove the `watches.add` wrapper in `layout.lua`.

## 9. Turn the whole thing off

Comment out `{ import = "debugging.plugins" }` in `lua/config/lazy.lua`.
You get LazyVim's stock `dap.core` debugger back; nothing else changes.

## 10. Adding another language

Planned as Phase 4 (plan: `/mnt/project-files/go-debugger/go-debugger-gui-plan.md`).
Layout, bar, menu, hover, breakpoints and Evaluate are language-neutral; a new
language needs only its adapter (LazyVim `lang.*` extra) and, if wanted, a
`delve.lua`-style options file. The name check (`hover.is_name`) works for any
language with a tree-sitter parser.
