# Freeze-override trace — 2026-11-04 debugger GUI

Required by rule 10 in [`discipline-stop-rules.md`](../process/discipline-stop-rules.md).

**The change:** all DAP config moved from `lua/plugins/dap.lua` into a new
`lua/debugging/` folder (imported from `lua/config/lazy.lua`), then phase 1 of
the debugger plan: persistent breakpoints, floating prompts (Esc cancels), a
control bar built in full instead of gsub-patching dap-ui, a minimal layout
(tray on start, Variables + Call Stack on first stop, panels stay after exit,
Watches only when used, Breakpoints as float), Delve `showPprofLabels`.

**Why it did not wait:** Myo is moving to serious Go work and the debugger was
known-incomplete (`todos/languages/nvim-dap-webstorm-parity-and-enhancements.md`).
Overridden knowingly on 2026-11-04: "since this is important features for
development and continuation of prev unfinished go debugger or debugger set up
in neovim bypass the rule". The override covers the freeze and the keymap
deferral for this debugger work only.

**Keys added/changed:** `<leader>du` (now our layout toggle), `<leader>db`
(same action + save), `<leader>dX` (new: clear project breakpoints),
`<leader>dN/dH/dL` (same keys, float prompts). Later phases: gutter click,
right-click Debug menu, hover values while stopped.

**Scope:** debugger only. Plan: project file
`go-debugger/go-debugger-gui-plan.md`. Branch: `feat/debugger-gui`.

**Phase 2 (branch `feat/debugger-phase2`, Myo asked 2026-11-04):** right-click
debug entries (MenuPopup), hover values while stopped (`config/mouse-hover.lua`
asks `debugging.hover` first), `<leader>dm` / `<leader>dM` breakpoint list
picker, and snacks' Lua profiler moved from `<leader>dpp/dph/dps` to
`<leader>uPp/uPh/uPs` so `<leader>d` is debugger-only (Myo: "move to different
suitable place").
