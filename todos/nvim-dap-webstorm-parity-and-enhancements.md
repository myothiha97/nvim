# nvim-dap / dap-ui: Progressive Enhancement Toward IDE Parity

## Status
DAP is set up through LazyVim's `lazyvim.plugins.extras.dap.core` extra
(`nvim-dap`, `nvim-dap-ui`, `mason-nvim-dap`, `nvim-dap-virtual-text`, `nvim-dap-go`).

**2026-08-28: Go pass done** (`lua/plugins/dap.lua`, branch
`feat/go-dap-goroutines`). The core loop already worked; what was missing was the
Go-specific half of Delve, which the stock config never switched on. Now enabled:
goroutine inspection, package globals, deeper stacks, function breakpoints, log
points, hit-count breakpoints, restart, and exception-filter control.

Python support is installed through the Python extra (`debugpy` and
`nvim-dap-python`). Rust is configured through rustaceanvim and codelldb but
dormant (no system `rustup`). Node's js-debug adapter is installed; project launch
and browser attach still need real-project verification.

## Measured Delve capabilities (dlv 1.27.0, verified 2026-08-28)
Probed the adapter directly over DAP, not guessed:

- `threads` returns **every goroutine**, running or parked, named
  `[Go 9] main.worker (Thread 3796317)`; the current one is prefixed `*`.
- `stackTrace` / `scopes` / `variables` work on **any** goroutine id, so a
  goroutine parked in `runtime.chansend` can be opened and its frame locals read
  (that is where `waitReason = waitReasonChanSend` shows up).
- Capabilities reported: conditional breakpoints, **hit-conditional** breakpoints,
  **function breakpoints**, **log points**, data breakpoints, restart,
  `setVariable`, exception filters (`unrecovered-panic`, `runtime-fatal-throw`),
  disassemble, read/write memory, stepping granularity.
- `setExpression` is **not** implemented. `setVariable` is, and dap-ui's `e` on a
  variable uses it.
- The REPL accepts Delve's own commands: `dlv help`, `dlv config -list`,
  `dlv config <name> <value>` (live, no restart), `dlv sources`, `dlv examinemem`,
  and `call f(x)` to invoke a function.

## Remaining Work

### Adapters
- [x] Go: delve configured, core workflow verified, Go-specific options wired up.
- [x] Python: debugpy and nvim-dap-python installed through the Python extra.
- [x] Rust editor config: rustaceanvim and codelldb installed.
- [ ] Python: verify interpreter selection, launch, stepping, variables in a real
  virtualenv project.
- [ ] Rust: install `rustup`, then verify Cargo launch and codelldb.
- [ ] Node/TS: verify project launch and browser attach through js-debug.

### Workflow / convenience
- [x] Project `.vscode/launch.json` support: nvim-dap now reads it on demand,
  `dap.ext.vscode.load_launchjs` is deprecated and no longer needed.
- [ ] `persistent-breakpoints.nvim`: keep breakpoints across close / restart.
  Still open; breakpoints vanish when the buffer closes.
- [ ] `telescope-dap`: parked with telescope itself (not installed).
- [ ] Remote attach config for a containerised Go process
  (`dlv --headless --listen=:2345 --api-version=2` in the container, then a
  `type = "server"` adapter with no `executable`, plus `substitutePath` to map
  the container path back to the local checkout). nvim-dap-go's own `Attach`
  entry is local-process only, so this needs its own adapter.

### dap-ui
- [x] `layouts` tuned: Stacks (the goroutine list) raised to 35% of the sidebar.
- [x] Auto open/close listeners: LazyVim wires them, verified.
- [x] Inline values via `nvim-dap-virtual-text`, with long Go struct values
  truncated to 60 chars.
- [x] `wrap = true` + `expand_lines = false`. A `sync.WaitGroup` renders as a
  169-char line; the defaults cut it at the panel edge and, on cursor, opened a
  borderless float as wide as the whole value that painted over the editor.

### JS/TS/React specifics
- [ ] Add a `.tsx` launch config (Node attach + Chrome attach via `js-debug-adapter`).
- [ ] Document the pairing workflow: nvim-dap for logic + Chrome DevTools for the
  DOM/network/React-tree side.

## Known Ceiling (NOT closeable, outside the DAP protocol)
These are missing in VS Code + Go too, not just here. Do not spend effort on them.

- **Deferred calls.** No DAP request exposes a frame's defer stack. Delve's own
  CLI has `stack -defer` / `deferred <n> <cmd>`; the workaround is a terminal
  `dlv attach <pid>` or `dlv debug` next to the editor session.
- **Blocking/select detail per goroutine.** Available only indirectly: open the
  parked goroutine's `runtime.chansend`/`runtime.selectgo` frame and read its
  locals (`waitReason`, `c`, `sg`). No dedicated view.
- Rich data viewers (array-as-table, "View as JSON", image/color previews,
  DataFrame grids). Workaround: REPL eval + pretty-print.
- Smart Step Into (choose which call on a line to enter).
- "Auto" smart-relevant variable filtering; dap-ui shows every in-scope local.
- Drop-frame re-execution.

## Keys added or changed (`lua/plugins/dap.lua`)
| Key | Action |
|---|---|
| `<leader>dG` | Focus the Stacks panel (goroutines + call stack), float if closed |
| `<leader>dv` | Focus Scopes (variables) |
| `<leader>dW` | Focus Watches |
| `<leader>dp` | Focus Breakpoints |
| `<leader>do` | Step over (**swapped** with LazyVim's default) |
| `<leader>dO` | Step out (**swapped** with LazyVim's default) |
| `<leader>dB` | Clear breakpoints in current file (**replaces** LazyVim's default) |
| `<leader>dN` | Breakpoint condition (**moved** off `<leader>dB`) |
| `<leader>dH` | Breakpoint hit condition |
| `<leader>dL` | Log point |
| `<leader>dF` | Toggle function breakpoint by name |
| `<leader>dR` | Restart session |
| `<leader>dx` | Exception breakpoint filters |

Inside Stacks: `o` on a frame jumps to it and repoints Scopes at that frame,
`t` toggles the runtime-internal frames. `<leader>dj` / `<leader>dk` walk the
call stack without leaving the source window.

## Notes
- Keep all changes additive to the LazyVim DAP extra; don't fight its defaults.
- Delve binary: Neovim uses **Mason's** `dlv` (mason prepends its `bin` to `PATH`),
  not `~/go/bin/dlv` and not a Homebrew one. Check with `:echo exepath('dlv')`.
- Verify enhancements on a sandbox program before committing.
