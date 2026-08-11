
# nvim-dap / dap-ui: Progressive Enhancement Toward WebStorm Parity

## Status
DAP is set up and working via LazyVim's `lazyvim.plugins.extras.dap.core` extra
(`nvim-dap`, `nvim-dap-ui`, `mason-nvim-dap`, `nvim-dap-virtual-text`, `nvim-dap-go`).
Core debugging loop verified working on Go (breakpoints, stepping, call stack,
locals, continue).

Python support is also installed through the Python extra (`debugpy` and
`nvim-dap-python`). Rust support is configured through rustaceanvim and codelldb,
but remains dormant because the system `rustup` toolchain is not installed. Node's
js-debug adapter is installed; project launch and browser-attach workflows still
need real-project verification.

Goal: progressively close the convenience/UX gap with WebStorm without expecting
to match its proprietary features outside the DAP protocol.

## Goal
Get the everyday debugging experience as close to WebStorm-level smoothness as the
DAP protocol allows (~85-90% parity). Enhance incrementally — one plugin/config at
a time — verifying each before moving on.

## Remaining Work

### Adapters — wire up the full stack

- [x] Go: delve configured and core workflow verified.
- [x] Python: debugpy and nvim-dap-python installed through the Python extra.
- [x] Rust editor config: rustaceanvim and codelldb installed.
- [ ] Python: verify interpreter selection, launch, stepping, and variables in a
  real virtual-environment project.
- [ ] Rust: install `rustup`, then verify Cargo launch and codelldb.
- [ ] Node/TS: verify project launch and browser attach through js-debug.

### Workflow / convenience plugins
- `telescope-dap` — fuzzy-find breakpoints, frames, and launch configurations.
- `persistent-breakpoints.nvim` — keep breakpoints across buffer close / Neovim
  restart (currently they vanish on close — known limitation discussed).
- Project `.vscode/launch.json` support — nvim-dap can read these natively;
  enable so per-project run configs "just work" like an IDE.

### dap-ui polish
- Tune `layouts` (panel sizes/placement for variables, stacks, watches, repl).
- Confirm auto open/close `listeners` on session start/stop (LazyVim wires a
  default — verify and adjust).
- Consider an inline-values style pass for `nvim-dap-virtual-text` (already
  installed; this is the inline-values equivalent of WebStorm).

### JS/TS/React specifics
- Add a `.tsx` launch config (Node attach + Chrome attach via `js-debug-adapter`).
- Document the pairing workflow: nvim-dap for logic + Chrome DevTools for the
  visual/DOM/network/React-tree side.

## Known Ceiling (NOT closeable — beyond the DAP protocol)
These are JetBrains proprietary renderers/engine features. Do not spend effort
trying to replicate; document the workaround instead.
- Rich data viewers: array-as-table, "View as JSON", color/image previews,
  Python DataFrame grids. Workaround: REPL eval + pretty-print.
- Smart Step Into (choose which call on a line to enter).
- "Auto" smart-relevant variable filtering (dap-ui shows all in-scope locals).
- Drop-frame re-execution (partial/adapter-dependent at best).

## Notes
- Keep all changes additive to the existing LazyVim DAP extra; don't fight its
  defaults. New plugin specs go under `lua/plugins/` (e.g. a new `dap.lua`).
- Verify each enhancement on the `~/dap-practice/main.go` sandbox (or per-language
  equivalent) before committing.
- Core daily keys stay the same: `<leader>db` toggle bp, `<leader>dc` start/continue,
  `<leader>dO` step over, `<leader>di` step into, `<leader>dt` terminate.
