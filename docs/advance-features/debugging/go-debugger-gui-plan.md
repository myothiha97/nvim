# Go-first GUI debugger for Neovim: findings and plan

Date: 2026-11-04 · Config: `~/.config/nvim` (LazyVim, branch `main`, Neovim 0.12.2) · Status: **proposal, nothing edited yet**

Freeze status: Myo overrode the rules.md freeze and the keymap deferral for this work on 2026-11-04. Per rule 4 the work goes on a branch (`feat/debugger-gui`), and the first commit adds the override trace `todos/freeze/freeze-override-2026-11-04-debugger-gui.md`.

---

## 1. Bottom line

- **Go debugging capability is already near VS Code level.** Delve over DAP gives goroutines, conditional/hit/log/function breakpoints, set-variable, exception filters, restart. Your `lua/plugins/dap.lua` already turns most of that on. The engine is not the problem.
- **What's missing is the mouse layer and stability, not features.** You cannot click the gutter to set a breakpoint, there is no right-click debug menu, hovering a variable with the mouse shows LSP docs instead of its value, breakpoints vanish on restart, and the panels make the editor jump when a session starts and ends.
- **All of that is buildable** with ~400 lines of your own Lua in a new `lua/debugging/` folder, plus one small plugin (or ~60 lines) for persistent breakpoints. No new UI framework needed.
- **Keep nvim-dap-ui** (multi-panel, closest to the GoLand/VS Code layout). nvim-dap-view is the fallback if dap-ui breaks (reasons in §4).
- **Honest ceiling:** Neovim cannot match GoLand's pixel-level UI: no drag-and-drop panel docking, no single-click disclosure triangles in trees, no execution-pointer drag (Delve doesn't support "set next statement" either), no code completion in breakpoint-condition dialogs. In terminal it will feel ~85% of VS Code; in Neovide ~90%.
- **Effort:** about 3 focused sessions of 1.5–2 hours for Go + mouse layer, 1 more for the other languages.

---

## 2. What's wrong with the current setup

Read from `lua/plugins/dap.lua`, `lazyvim.json`, `lua/config/options.lua`, `lua/config/mouse-hover.lua`, `lua/plugins/folding.lua`, and `todos/languages/nvim-dap-webstorm-parity-and-enhancements.md`.

| # | Problem | Impact | Severity |
|---|---|---|---|
| 1 | **No click-to-toggle breakpoints in the gutter.** `statuscol.nvim` (which has click handlers) is `enabled = false` in `folding.lua`; LazyVim's snacks statuscolumn has no breakpoint click handler. | The single most-used mouse action in GoLand/VS Code does nothing. | High |
| 2 | **No right-click debug actions.** `mousemodel=popup_setpos` and a custom PopUp menu exist, but only with LSP entries. | Condition, log point, run to cursor, add watch all need leader keys + typing. | High |
| 3 | **Mouse hover never shows variable values.** `mouse-hover.lua` always sends LSP hover, even while stopped at a breakpoint. | VS Code/GoLand's main inspection gesture is missing. | High |
| 4 | **Breakpoints are not persisted.** Line breakpoints die with the buffer/Neovim; function breakpoints (`fn_breakpoints`) are a Lua table lost on restart and not shown in the Breakpoints panel. | You re-place breakpoints every session. | High |
| 5 | **Layout jumps.** LazyVim's dap.core opens dap-ui on `event_initialized` and closes it on `event_terminated`/`event_exited`. The left sidebar (46 cols) and bottom tray (12 rows) push the editor around twice per run, and the final output disappears as soon as the program exits. With `equalalways` on, your other splits are re-equalised too. | The "not smooth" feeling. | High |
| 6 | **Prompts use `vim.fn.input`** (`<leader>dN`, `dL`, `dH`). It's the bottom cmdline, blocking, no float, and pressing Esc returns `""`, which still calls `set_breakpoint` (likely leaves a breakpoint with an empty condition/log message). | Clunky and error-prone. | Medium |
| 7 | **The control-bar patch is brittle.** `patch_controls` wraps `dapui.controls.controls` and rewrites its output with `gsub("  %%#", "   %%#")`. Any upstream formatting change makes the gsub match nothing, silently. Also the comment says gaps widen "2 to 3", the todo says "2 to 4". | Breaks quietly on a dap-ui update. | Medium |
| 8 | **No remote/container attach.** Listed as open in the todo; nvim-dap-go's built-in `Attach` is local-process only. | Can't debug Go in Docker/K8s. | Medium (depends on your work) |
| 9 | **Program stdin not supported.** Delve sends program output as DAP `output` events into the console/REPL; it doesn't run the program in a terminal, so `fmt.Scan` etc. can't receive input. | Interactive CLIs can't be debugged with plain Launch. Workaround: headless dlv in a terminal + attach (§5). | Low–Medium |
| 10 | **Delve version drift.** Neovim uses Mason's `dlv` (1.27.0 measured 2026-08-28). Delve warns or fails when Go is newer than it supports, and Mason doesn't update it automatically. | Sudden "version too new" failures after a Go upgrade. | Low |
| 11 | **Other languages unverified or absent.** Node (js-debug) and Python (debugpy) installed but never verified on a real project; Rust dormant (no `rustup`); **C/C++ and C# have no debug setup at all** (no `lang.clangd` / `lang.omnisharp` extra). | Only Go is proven. | Medium |

What is already good and stays: Delve options (`showGlobalVariables`, `hideSystemGoroutines`, `stackTraceDepth=100`), applied via `on_config` so they also cover `.vscode/launch.json`; panel-focus keys; inline virtual text with 60-char cap; `wrap=true` / `expand_lines=false`; the mason-nvim-dap duplicate-config fix; `<leader>td` test debugging via neotest-golang.

---

## 3. GoLand and VS Code: the mouse-driven workflow to match

| Action | GoLand | VS Code (Go ext.) | Neovim today | Neovim after plan |
|---|---|---|---|---|
| Toggle breakpoint | Click gutter | Click gutter | `<leader>db` only | **Click gutter** |
| Conditional / log / hit breakpoint | Right-click dot → dialog | Right-click gutter → inline editor | `<leader>dN/dL/dH` + cmdline | **Right-click gutter → menu → float input** |
| Disable breakpoint without deleting | Middle-click / checkbox | Checkbox in Breakpoints view | `t` in Breakpoints panel (keyboard) | Same + menu entry |
| Start / continue / step | Toolbar, F8/F7/Shift-F8/F9 | Floating toolbar, F5/F10/F11/Shift-F11 | Clickable winbar on repl pane | Clickable bar (rebuilt, not patched) + optional F-keys |
| Run to cursor | Click line number while suspended | Right-click → Run to Cursor | Control-bar button | **Right-click → Run to Cursor** |
| Inspect value | Hover → expandable tree; inline values | Hover → expandable tree; inline values | Inline values; `<leader>de` eval | **Mouse hover → expandable value float** |
| Add to watches | Right-click → Add to Watches | Right-click → Add to Watch | Type in Watches panel | **Right-click → Add to Watches** |
| Edit a variable | Right-click → Set Value | Double-click value | `e` in Scopes | Same (`e`); double-click expands |
| Goroutines | Frames + Goroutines view, grouped by state/label | Listed as threads in Call Stack | Stacks panel (all goroutines, system hidden) | Same + pprof labels + filters |
| Debug a test | Gutter ▶ icon | CodeLens "debug test" | `<leader>td` | Same + right-click "Debug Test" |
| Remote/container | Run config "Go Remote" | `launch.json` attach + `substitutePath` | None | `.vscode/launch.json` template + attach config |
| Persistent breakpoints | Yes | Yes | **No** | **Yes** |
| Evaluate expression | Alt-F8 dialog with completion | Debug Console with completion | REPL (`dlv` commands, `call f()`) | Same; completion limited by Delve |
| Set next statement / drop frame | Not for Go | Not for Go | No | No (Delve limit) |
| Dependent breakpoints, "remove once hit" | Yes | Triggered breakpoints | No | No (not in DAP for Delve) |

---

## 4. Plugin options: what each can do

**nvim-dap (core, keep).** DAP client: breakpoints (line/conditional/hit/log/function/exception), stepping, run to cursor, restart, REPL, `widgets` (hover/scopes/frames floats), `.vscode/launch.json` loaded automatically. No GUI of its own and no mouse bindings.

**nvim-dap-go (keep).** Starts Delve, ships default configs (Debug, Debug with args, Debug test, Attach…), `debug_test()` / `debug_last_test()` via treesitter, `delve.build_flags`, `delve.port`, and remote attach via a config with `mode = "remote", request = "attach"` against `dlv … --headless -l 127.0.0.1:PORT`. Build flags must go in `build_flags`/`buildFlags`, not `args`.

**nvim-dap-ui (keep, recommended).** Multi-panel sidebar + tray (Scopes, Stacks, Watches, Breakpoints, REPL, Console), clickable control bar, `eval()` hover float, `float_element`. Mouse: expand is `<CR>` or double-click; everything else is keyboard (`e`, `o`, `d`, `t`). Development is slow (100+ open issues), and the control bar has no extension API, hence your monkey-patch.

**nvim-dap-view (alternative).** Actively developed, Neovim 0.11+. One tabbed window (Watches, Scopes, Exceptions, Breakpoints, Threads, REPL, optional Console), clickable control bar with a **real custom-button API** (`render(session)` + `action(clicks, button, modifiers)`), hover with set-value, built-in virtual text on 0.12. Downside for you: one view at a time, so you can't see Scopes and Goroutines simultaneously like GoLand. Use it only if dap-ui breaks.

**persistent-breakpoints.nvim (add) or ~60 lines of own code.** Saves/restores line breakpoints (with conditions/log messages) per project. Own code is preferred if you also want function breakpoints persisted.

**Not recommended:** `go.nvim` (ray-x) — brings its own DAP UI layer and overlaps with LazyVim's Go extra; telescope-dap (you don't use Telescope; snacks picker can list breakpoints if needed).

---

## 5. How experienced Go developers debug inside Neovim

This is common community practice (LazyVim/kickstart configs, nvim-dap-go README, Delve docs), not a survey.

1. **Debug through tests first.** `debug_test()` on the nearest test, `debug_last_test()` to rerun. Reproduce the bug as a test, then step. You already have this on `<leader>td`.
2. **nvim-dap + nvim-dap-go + dap-ui (or dap-view) + virtual text** is the standard stack. Same as yours.
3. **Delve CLI next to the editor for advanced cases.** `dlv` in a tmux pane for what DAP doesn't expose: deferred calls (`stack -defer`), goroutine detail (`goroutines -group`, `-with`), `examinemem`, core files. Your REPL already accepts `dlv <cmd>` for many of these.
4. **Headless + attach for servers and containers.** `dlv debug --headless --listen=:2345 --api-version=2 --accept-multiclient ./cmd/api`, then attach from Neovim with `substitutePath` mapping container paths to the checkout. Same trick solves stdin: run the program headless in a terminal (it gets the terminal's stdin), attach from Neovim.
5. **Log points over print statements** for hot paths; conditional breakpoints with goroutine-aware conditions.
6. **pprof labels** (`showPprofLabels`) to identify which request a goroutine belongs to in servers.
7. Keyboard-heavy users map F5/F10/F11/F12 to VS Code's scheme so muscle memory carries over.

---

## 6. UX design: minimal by default, everything else on demand

Principle (your rule): show only what a typical debug session uses. GoLand's 20-button toolbar and 8 panels are the anti-model. VS Code's default (one small toolbar, 4 sidebar panels, a console) is closer, and we go one step leaner.

### What is on screen by default
| Element | Shown | Why |
|---|---|---|
| Sidebar: **Variables** (top, ~60%) + **Call Stack / Goroutines** (bottom, ~40%) | When stopped | The two things you read on every stop |
| Bottom tray: **Console** (program output) + REPL in one 10-row pane | When stopped or output arrives | Output and ad-hoc eval |
| Control bar: **Continue/Pause · Step Over · Step Into · Step Out · Restart · Stop** (6 buttons) | On the tray's winbar | The only buttons used every session |
| Inline values + current-line highlight + hover values | Always while stopped | Zero-click inspection |
| Panel titles (VARIABLES, CALL STACK, CONSOLE) in each panel's winbar | With the panels | You always know what you're looking at; dap-ui shows none today |

### What is on demand (not on screen)
- **Watches**: appears only after you add one (right-click → Add to Watches), disappears when the list is empty.
- **Breakpoints list**: `<leader>dp` or right-click → "All Breakpoints…" opens it as a float. You manage breakpoints in the gutter 95% of the time.
- **Run to Cursor, Evaluate, Conditional/Log/Hit breakpoints, Disable**: right-click menu only. Run to Cursor moves off the bar to the menu, which keeps the bar at 6 buttons and puts the action where the cursor already is.
- **Exception filters, Delve config, remote attach**: keys/commands only.

### The flow, start to end
1. **Set breakpoints**: click the gutter (red dot). Right-click the dot for condition/log/hit/disable. Breakpoints survive restarts.
2. **Start**: `<leader>dc` (or F5), or right-click → "Debug Test" inside a `_test.go` test. If the project has one config (or you ran one before) it starts immediately; the picker appears only the first time. Restart reruns the last config without asking.
3. **Running, not stopped**: nothing opens. The editor doesn't move. Program output goes to the console in the background; lualine shows the session status (LazyVim already does).
4. **First stop**: sidebar + tray open once, current line highlighted, inline values shown. This is the only layout change in the session.
5. **Inspect**: hover a variable for its value (double-click to expand structs/maps), read Variables, click a goroutine/frame in Call Stack to switch context. Edit a value with `e`.
6. **Step**: click bar buttons (or F10/F11/Shift-F11). Panels stay put; only contents update.
7. **Program ends or you click Stop**: panels **stay open** with the final output, and the bar shows "exited (code N)" with a single ▶ Run Again button. Your editor layout doesn't jump back.
8. **Close**: click Stop again (or `<leader>du`) to close the panels. Starting a new session reuses the same layout.

### Consistency across languages
Same layout, bar, right-click menu, hover, panel titles and breakpoint persistence for Go, Node, Python, Rust, C/C++ and C#. Only the adapter and config names differ. "Call Stack" shows goroutines for Go and threads for everything else, under the same title. Language-specific extras (Go function breakpoints, Delve `dlv` commands, Python "Debug Method") live in the right-click menu only when that language's session is active.

### Discoverability without clutter
- Right-click menu items are context-sensitive: at most 5 entries in any given state (e.g. on a breakpoint while not debugging: Edit Condition, Log Message, Disable, Remove, Debug Test).
- Each panel's title bar ends with a short dim hint, e.g. `VARIABLES  dbl-click expand · e edit`, which is the one thing the panel needs you to know. No help popups.
- Terminal winbars can't show tooltips, so button icons stay the standard VS Code codicons (familiar shapes) rather than custom glyphs.

---

## 7. Smoothness: what we can fix and what we can't

**Fixable**
- **Stable layout (biggest win).** Option A (recommended, used in §6): open dap-ui on the **first stop** instead of on session start, and keep it open after the program ends, so it changes layout once per debugging block instead of twice per run. Option B: open the debugger in its own **"Debug" tab** like GoLand's Debug tool window, so the editor tab never reflows. A is less disruptive; B is the most IDE-like. Also set `equalalways = false` while the debugger is open and `winfixwidth`/`winfixheight` on dap-ui windows so other splits don't resize.
- **No cmdline prompts.** Replace `vim.fn.input` with `vim.ui.input` (LazyVim routes it to snacks' floating input), and cancel = no-op.
- **Rebuild the control bar** from our own function (play, pause, step over/into/out, run to cursor, restart, stop) instead of `gsub`-patching dap-ui's string. Same look, no silent breakage.
- **Fewer redraw spikes.** Keep `hideSystemGoroutines`; add `goroutineFilters` when a server has hundreds of goroutines; keep virtual-text truncation. Stacks rendering with hundreds of goroutines is the slowest panel.
- **Mouse resize already works** (`mouse=a`, tmux `mouse on` in your dotfiles): drag the window separators.

**Terminal (Ghostty → tmux → nvim) vs Neovide**
- Terminal: everything clickable works (winbar `%@…@` buttons, statuscolumn clicks, PopUp menu, double-click). Every mouse event and redraw passes through tmux, which adds a small but noticeable delay on fast hover/scroll. Icons are font glyphs, one cell wide.
- Neovide: no tmux hop, smooth scroll, floating windows rendered with shadows/blur, `<D-…>` keys native. This is the closest Neovim gets to a GUI debugger. Recommendation: use the same config in both; prefer Neovide for long debugging sessions if the tmux delay bothers you.

**Not fixable (accept)**
- Panels are character grids: no drag-and-drop docking, no pixel icons, no variable-width fonts.
- Tree expand is double-click (a single click only moves the cursor). Making single click expand is possible but conflicts with selecting/copying values; I'd keep double-click.
- No floating draggable toolbar.
- No execution-pointer drag, drop frame, smart step into, dependent breakpoints, defer-stack view, rich data viewers (table/JSON). Several of these are missing in VS Code for Go too.

---

## 8. Proposed structure: `lua/debugging/`

`lua/config/lazy.lua` gets one line: `{ import = "debugging.plugins" }` after `{ import = "plugins" }`. `lua/plugins/dap.lua` is moved into it and deleted.

```
lua/debugging/
  plugins/
    core.lua          -- nvim-dap spec: keys, listeners, on_config hooks (from plugins/dap.lua)
    ui.lua            -- nvim-dap-ui + virtual-text specs, layout, open/close policy
    go.lua            -- nvim-dap-go + mason-nvim-dap delve handler, remote attach config
    languages.lua     -- js-debug, debugpy, codelldb (Rust/C/C++), netcoredbg (C#) tweaks
  delve.lua           -- Delve launch options, function breakpoints (moved from dap.lua)
  breakpoints.lua     -- persistence (line + function breakpoints, per project JSON in stdpath("data"))
  controls.lua        -- own clickable control bar (replaces patch_controls)
  mouse.lua           -- gutter click handler + right-click PopUp "Debug" entries
  hover.lua           -- value-on-hover, called from config/mouse-hover.lua while stopped
  layout.lua          -- open/close policy, equalalways/winfix handling, optional Debug tab
  prompts.lua         -- vim.ui.input wrappers for condition / hit / log point
  README.md           -- keys, mouse actions, per-language setup, known limits
```

Everything stays lazy: modules load on first debug key/click or session start. The only always-on piece is the gutter `<LeftMouse>` check, which is one `getmousepos()` call per click (not per move), so no hot-path cost per rule 7.

---

## 9. Plan

### Phase 0 — System tools (no config change, ~20 min)
See §10. Verify `dlv version` supports your `go version`.

### Phase 1 — Go reliability (session 1, ~1.5 h)
1. Create `lua/debugging/`, move `plugins/dap.lua` into it unchanged, confirm nothing regressed.
2. Persistent breakpoints (line + conditions + log messages + function breakpoints); show function breakpoints in notifications/picker.
3. `vim.ui.input` prompts; Esc cancels cleanly.
4. Own 6-button control bar replacing `patch_controls` (Run to Cursor moves to the right-click menu); end-of-session state with Run Again; panel titles + hints.
5. Layout policy per §6: open on first stop, stay open after exit, Variables + Call Stack sidebar, Watches only when non-empty, Breakpoints as float.
6. Delve extras: `showPprofLabels = true`; document `goroutineFilters`.

### Phase 2 — Mouse layer (session 2, ~2 h)
1. **Left-click gutter** (sign/number column) toggles a breakpoint on that line.
2. **Right-click gutter or code** → context-sensitive Debug entries (max 5 visible at once, see §6): breakpoint edit/disable/remove on a breakpoint; Run to Cursor, Evaluate, Add to Watches while stopped; Debug Test in a test. Built in a `MenuPopup` autocmd that adds/removes entries per state.
3. **Hover value**: while a session is stopped, `mouse-hover.lua` asks `debugging.hover` first (DAP `evaluate` with context `hover`); falls back to LSP hover otherwise. Float is expandable with double-click.
4. Test in Ghostty+tmux and Neovide; check no conflict with mouse-hover's `<LeftMouse>` guard.

### Phase 3 — Containers and stdin (session 3, ~1 h, only if you debug Go in Docker)
1. `go.lua`: a "Go: Attach remote (dlv headless)" config with host/port prompt and `substitutePath`.
2. `.vscode/launch.json` template for per-project ports/paths.
3. A command that runs `dlv debug --headless` for the current package in a snacks terminal and attaches (fixes stdin).

### Phase 4 — Other languages (session 4, ~1.5 h)
| Language | Adapter | How | Status / action |
|---|---|---|---|
| Node/TS | `js-debug-adapter` (vscode-js-debug, `pwa-node`/`pwa-chrome`) | LazyVim `lang.typescript` (already on) | Verify Launch file + Attach `--inspect` on a real project; add Chrome attach for React |
| Python | `debugpy` + nvim-dap-python | LazyVim `lang.python` (on) | Verify venv selection, launch, test debug |
| Rust | `codelldb` via rustaceanvim | LazyVim `lang.rust` (on) | Install rustup; `:RustLsp debuggables` |
| C/C++ | `codelldb` | Enable LazyVim `lang.clangd` extra | New: compile with `-g -O0`; CMake projects via launch.json |
| C# | `netcoredbg` (`coreclr`) | Enable LazyVim `lang.omnisharp` extra | New: check Mason's netcoredbg runs on Apple Silicon; Microsoft's `vsdbg` is licensed for VS/VS Code only, so not an option |

All languages get the same mouse layer, breakpoints persistence, control bar and layout for free; only adapters differ.

### Phase 5 — Optional F-key layer
VS Code scheme: F5 continue, Shift-F5 stop, Cmd-Shift-F5 restart, F9 toggle breakpoint, F10 over, F11 into, Shift-F11 out. Needs macOS "use F1, F2 as standard function keys" or Fn. Skip if leader keys + mouse are enough.

### Changes that need your keymap/freeze override
You already gave it on 2026-11-04 for this work; listed so the trace file records them.
- New mouse mapping: `<LeftMouse>` in the gutter (all buffers, normal mode).
- New PopUp menu entries (Debug group).
- Changed hover behaviour in `config/mouse-hover.lua` while a session is stopped.
- Changed prompt UI for `<leader>dN`, `<leader>dL`, `<leader>dH` (same keys).
- New key for remote attach / headless run (proposed `<leader>dA`; LazyVim doesn't use it).
- Optional F-keys (Phase 5).
- Layout change: dap-ui opens on first stop, no longer auto-closes on exit, default panels reduced to Variables + Call Stack + one tray.

---

## 10. System tools to install (macOS)

| Tool | For | Install | Notes |
|---|---|---|---|
| Xcode Command Line Tools | Delve (uses `debugserver`), lldb, clang | `xcode-select --install` | Required for Go debugging on macOS |
| Developer mode | Avoid auth prompts when Delve attaches | `sudo DevToolsSecurity -enable` and add yourself to `_developer` group: `sudo dscl . append /Groups/_developer GroupMembership $USER` | One-time |
| Go | Go | `brew install go` (or official pkg) | |
| Delve | Go | Mason `delve` (current) or `go install github.com/go-delve/delve/cmd/dlv@latest` | Must support your Go version; update after each Go minor release |
| Docker (optional) | Remote attach | Docker Desktop / OrbStack | Container image needs `dlv` and `-gcflags="all=-N -l"` builds |
| Node.js | js-debug | already installed | `js-debug-adapter` via Mason |
| Python 3 + venv | debugpy | already installed | `debugpy` via Mason; project venv needs nothing extra |
| rustup | Rust | `brew install rustup && rustup-init` | `codelldb` via Mason |
| CMake / make (optional) | C/C++ | `brew install cmake` | Build with debug symbols |
| .NET SDK | C# | `brew install --cask dotnet-sdk` | `netcoredbg` via Mason |

GoLand-only features with no install path: rr record/replay (Linux only), GoLand's own dialogs/UI.

---

## 11. Decisions for you

1. **dap-ui (recommended) or dap-view?** dap-ui keeps the multi-panel GoLand-like layout.
2. **Layout: keep-open (recommended) or a dedicated Debug tab?**
3. **Folder name:** `lua/debugging/` (used above) or `lua/debugging/`.
4. **Phases 3 and 5:** do you debug Go in containers, and do you want F-keys?

Reply with choices (or "go with recommendations") and I'll start Phase 1 on `feat/debugger-gui`.

---

Sources: [nvim-dap-go README](https://github.com/leoluz/nvim-dap-go) · [nvim-dap-ui README](https://github.com/rcarriga/nvim-dap-ui) · [nvim-dap-view](https://github.com/igorlfs/nvim-dap-view), [control bar](https://igorlfs.github.io/nvim-dap-view/control-bar), [configuration](https://igorlfs.github.io/nvim-dap-view/configuration) · [dap-view discussion #200 on Go stdout](https://github.com/igorlfs/nvim-dap-view/discussions/200) · [vscode-go: Delve `console` discussion](https://github.com/golang/vscode-go/discussions/1626) · Local: `lua/plugins/dap.lua`, `todos/languages/nvim-dap-webstorm-parity-and-enhancements.md`, `~/.dotfiles/tmux/.tmux.conf`.
