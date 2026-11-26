# Debugger panels: display polish (plan, 2026-11-26)

Branch `feat/debugger-ui-polish`.

**Decision (Myo, 2026-11-26): build items 1–5 (the core rows) only; the sidebar stays at
46 columns. Items 6–8 are not chosen and stay as they are: channel children keep all
of Go's `hchan` fields, goroutine rows keep Delve's names, inline values stay inline (F4
open).** What shipped is described in `lua/debugging/README.md`, "Variables and Watches
rows".

Goal (Myo, 2026-11-26): features are done; what is left
is **how information is shown** in Variables, Watches, Call Stack / goroutines and the
other panes, with GoLand as the main reference and VS Code second.

## 1. What the panels show today (measured, not guessed)

Neovim 0.12.6 + this config + Delve 1.27.2 + Go 1.26.3, sidebar at its fixed 46 columns,
stopped in a small server-style program (channel, mutex, context, error, slice of structs).
Captured from the real TUI.

```
 VARIABLES  dbl-click expand · e edit
     Locals:
      cancel context.CancelFunc = context.
    WithDeadlineCause.func3
      ctx context.Context(*context.timerCtx)
    = context.Context(*context.timerCtx) *
    {cancelCtx: context.cancelCtx {Context:
    context.Context(context.backgroundCtx) *(*
    context.Context)(0x3b935116070), mu: (*
    sync.Mutex)(0x3b935116080), done: (*"sync/
    atomic.Value")(0x3b935116088), children:
    map[context.canc...
      jobs chan main.Order = chan main.Order
    3/8
      srv *main.Server = *main.Server {mu:
    sync.Mutex {_: sync.noCopy {}, mu: (*
    ... (srv 7 lines, orders 6 lines; err and wg are pushed off the panel: @@@)
```

Expanding the channel `jobs` adds 13 rows of Go runtime internals (`qcount = 3 = 0x3`,
`elemsize`, `elemtype *internal/abi.Type {Size_: 48, …}`, `sendx`, `recvx`, `lock`,
`timer`, `bubble`, …), and `buf` alone wraps to 9 lines.

```
 CALL STACK  dbl-click expand/open/switch
     * [Go 1] main.main (Thread 9540)
     main.main main.go:58
     [Go 21] main.main.gowrap1
     [Go 22] main.main.gowrap1
```

### Causes (from the raw DAP data Delve sends)

| Problem | Cause |
|---|---|
| Type printed twice | Delve starts every compound value with its type (`chan main.Order 3/8`, `*main.Server {…}`); dap-ui prints `name type = value` |
| 6–9 lines per variable | Delve sends up to 256 characters per value; `wrap = true` folds them into the 46-column sidebar |
| `3 = 0x3` | Delve appends hex to every unsigned integer |
| Channel noise | Delve exposes Go's `hchan` struct as the channel's children |
| Two or three clicks to reach fields | A pointer expands to one unnamed child; an interface (`ctx`, `err`) to a `data` child, then the unnamed one |
| `* [Go 1] … (Thread 9540)` | Delve's goroutine name; `*` = selected, `(Thread N)` = was on an OS thread |

## 2. The references

Confirmed from docs:
- **GoLand** ([Data Views settings](https://www.jetbrains.com/help/go/settings-debugger-data-views.html),
  [Variables](https://www.jetbrains.com/help/go/debug-tool-window-variables.html),
  [Examine suspended program](https://www.jetbrains.com/help/go/examining-suspended-program.html)):
  types shown by default, pointer addresses shown by default, integers in decimal by
  default, `String()` calls off by default (built-in formatting for `time.Time`,
  `time.Duration`, `net.IP`, `http.Request`), watches shown inside the Variables pane by
  default, "Hide Frames from Libraries" filter, goroutines listed by default, the goroutine
  dump labels entries `Goroutine 1 main.main`, inline values next to their usage, changed
  values change colour.
- **VS Code + vscode-go** ([debugging.md](https://github.com/golang/vscode-go/blob/master/docs/debugging.md),
  [VS Code debugging](https://code.visualstudio.com/docs/editor/debugging)): goroutines
  annotated with their ids, current one marked `*`, runtime frames greyed or collapsed,
  thread ids shown for scheduled goroutines, globals hidden unless `showGlobalVariables`.
  Variable values are Delve's strings (the same data we get), on one line per row.

Not documented anywhere reachable: GoLand's exact collapsed-row text for structs, slices,
maps and channels (the JetBrains blog refuses automated fetches). From GoLand's UI the row
reads `name = {type} value`; check that against your GoLand when you review the result.

## 3. What we can achieve

All of it sits on what Delve already sends; no new plugin. Real output of the prototype
formatter (`lua/debugging/values.lua`) on the data above, 46 columns:

```
 ▸ cancel = {context.CancelFu…} context.WithD…
 ▸ ctx = {*context.timerCtx} {…}
 ▸ jobs = {chan main.Order} len:0, cap:8
 ▸ srv = {*main.Server} {…}
 ▸ orders = {[]main.Order} len:3, cap:3
 ▸ wg = {sync.WaitGroup} {…}
 ▸ err = {*errors.errorString} "order rejecte…
```

| # | Item | Pane | Result |
|---|---|---|---|
| 1 | GoLand row `name = {type} value`, one line per variable | Variables, Watches | Type once; value without Delve's type prefix; cut to the panel width with `…` |
| 2 | Previews only when they fit whole | Variables, Watches | `{…}` / `[…]` instead of a half-cut struct; small values (`["go","nvim"]`, `{ID: 1}`) stay inline |
| 3 | Summaries | Variables, Watches | Slices `len:3, cap:3`; channels `len:3, cap:8`; errors show their message; decimals without `= 0x…` |
| 4 | Full value on demand | Variables, Watches | Double-click / `<CR>` on a cut value opens it whole in the Evaluate float (GoLand's "View") |
| 5 | Fields in one click | Variables, Watches | A pointer or interface expands straight to its fields (no unnamed / `data` level) |
| 6 | Channel internals hidden | Variables, Watches | Expanded channel keeps `qcount` (len), `dataqsiz` (cap), `closed`, `buf`, `recvq`, `sendq`; hides `elemsize`, `elemtype`, `sendx`, `recvx`, `lock`, `timer`, `bubble` (`p ch.elemtype` in the REPL still reads them) |
| 7 | Goroutine rows | Call Stack | `▾ Goroutine 1  main.main` (GoLand's wording), no `*`, no `(Thread N)`; pprof labels kept |
| 8 | Inline values at line end (F4) | Editor | `name: value` after the code, like GoLand; code no longer shifts |
| 9 | (optional) Wider sidebar, 46 → 56 columns | Layout | ~25% more room per row; editor 10 columns narrower while debugging |

How: 1–6 replace dap-ui's `variables` and `watches` row renderers, the same way
`debugging/stacks.lua` already replaces its goroutine list (nvim-dap-ui is pinned; a
README "Upstream internals" row and an e2e check cover it). 7 is a change inside
`stacks.lua`. 8 is one option. Work runs only when a panel re-renders (stop, expand), never
on keystrokes; 5 adds one request only when you expand a pointer.

Estimate: about 2–3 h including the e2e checks.

## 4. What we cannot achieve (and why)

| GoLand / VS Code feature | Why not |
|---|---|
| Goroutine state (Running, Waiting: chan receive, Syscall) and the "Async stack trace" (the `go` statement that started it) | Delve's DAP `threads` reply carries only an id and a name. GoLand uses Delve's JSON-RPC API, which nvim-dap doesn't speak. VS Code has the same limit |
| Pointer address on the row (`{*main.Server \| 0xc000…}`) | Delve's DAP value for a loaded pointer has no address |
| `String()` / `Error()` views for custom types | Delve's DAP server never calls methods for display (GoLand has it off by default too) |
| Map length on the collapsed row | Delve's map value has no length (slices and channels do) |
| Watches inside the Variables pane (GoLand's default) | dap-ui's panes are separate; merging means rewriting the scopes element |
| Group goroutines with the same stack (GoLand's dump) | Needs a stack request per goroutine on every stop; costly on servers with hundreds |
| Single-click expand, drag-and-drop panes, expandable hover trees, per-kind icons in colour | dap-ui / terminal ceilings (already in the e2e report §7); colours are closed |
| `gowrap1` names | It is Go 1.22+'s real name for a `go f(x)` wrapper; renaming it would be guessing |

## 5. Not in this plan

F8 (Node internal frames, Launch file / Attach / Debug Test) and F11 (F-keys) from the
2026-11-23 e2e report stay open unless chosen. F3 (Go panic message) is a behaviour fix, not
display.
