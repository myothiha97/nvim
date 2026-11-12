# Safe Config Editing — Performance & Behavior Guidelines

How to add or modify this Neovim config **without** breaking existing behavior
or hurting edit speed, snappiness, and responsiveness.

> **Project priority #1:** every config must be performance-safe — zero
> hot-path cost. Runtime speed is non-negotiable, above features and polish.
> When in doubt, do less. A feature that adds 2ms to every keystroke is worse
> than no feature.

> Read [`rules.md`](../rules.md) first — the config freeze policy decides
> *whether* you should be editing at all. This file is about *how* to edit
> safely once you've decided to.

---

## Table of Contents

1. [The Mental Model: the Hot Path](#1-the-mental-model-the-hot-path)
2. [Red-Flag Autocmd Events](#2-red-flag-autocmd-events)
3. [Autocmd Best Practices](#3-autocmd-best-practices)
4. [Red-Flag Functions & Patterns](#4-red-flag-functions--patterns)
5. [Red-Flag Options & Settings](#5-red-flag-options--settings)
6. [Plugin Loading Rules](#6-plugin-loading-rules)
7. [Safe-Modification Workflow](#7-safe-modification-workflow)
8. [Measuring & Profiling](#8-measuring--profiling)
9. [Pre-Commit Checklist](#9-pre-commit-checklist)
10. [What This Config Already Does Right](#10-what-this-config-already-does-right)

---

## 1. The Mental Model: the Hot Path

Neovim performance problems almost never come from *startup* or from a plugin
"being heavy." They come from code that re-runs on **every keystroke, cursor
move, or screen redraw**. That set of events is the **hot path**.

The single question to ask before adding anything:

> **"How often does this code run, and is it synchronous?"**

| Frequency tier | Examples | Budget |
|---|---|---|
| **Hot path** (per keystroke / cursor move / redraw) | `CursorMoved`, `TextChanged`, statusline draw, `<expr>` maps, `foldexpr` | **Near zero.** Microseconds. Anything heavier = visible lag. |
| **Warm path** (per buffer / window / mode change) | `BufEnter`, `WinEnter`, `LspAttach`, `ModeChanged` | Small. A few ms is OK if not nested in a loop. |
| **Cold path** (on demand / once) | keymaps, user commands, `VimEnter`, `VeryLazy` | Can do real work. Still prefer async for I/O. |

Everything below is an application of this one rule.

---

## 2. Red-Flag Autocmd Events

These events fire on the hot path. **Attaching synchronous work to them is the
#1 cause of a sluggish Neovim.** Treat each as a request to justify the cost.

| Event | Fires | Risk | Safe approach |
|---|---|---|---|
| `CursorMoved` / `CursorMovedI` | every `j`/`k`/`h`/`l`, every cursor shift | **Extreme** — thousands/session | Avoid. If unavoidable, dedup on position (see `mouse-hover.lua` cell-dedup) and never parse treesitter or call LSP inside. |
| `TextChanged` / `TextChangedI` | every edit / keystroke in insert | **Extreme** | Debounce (timer), never run formatters/linters/treesitter queries directly. |
| `<MouseMove>` (`mousemoveevent`) | every pixel of mouse motion | **Extreme** | Throttle to ~60Hz + position dedup + one reused `uv` timer. Pattern already in `lua/config/mouse-hover.lua`. |
| `BufEnter` / `WinEnter` | every buffer/window switch | High | Keep O(1). Don't loop all windows/buffers. Don't re-read files. |
| `CursorHold` / `CursorHoldI` | after `updatetime` (400ms here) idle | Medium | Fine for *light* idle work (e.g. `checktime`). Don't stack many — they all fire together. Keep each cheap. |
| `BufReadPost` | every file open | Medium | OK for setup, but guard large files (`getfsize`) before treesitter/regex work — see `large_file` group in `autocmds.lua`. |
| `ColorScheme` | every theme switch | Low (rare) | Fine, but keep idempotent — fires again on every `:colorscheme`. |
| `InsertCharPre` | every typed character | **Extreme** | Almost never justified. Avoid. |

**Rule of thumb:** if the event name contains `Cursor`, `Text`, `Char`, or
`Mouse`, assume the callback runs hundreds–thousands of times per session and
budget accordingly.

---

## 3. Autocmd Best Practices

1. **Always wrap in a named augroup with `clear = true`.** This is the one
   community-standard deviation currently present in this config. Without it,
   re-sourcing (`:source`, `:Lazy reload`, repeated init) stacks *duplicate*
   callbacks that all fire forever.

   ```lua
   local grp = vim.api.nvim_create_augroup("my_feature", { clear = true })
   vim.api.nvim_create_autocmd("BufReadPost", { group = grp, callback = ... })
   ```

2. **Scope to filetype/pattern** instead of running globally then checking
   inside:

   ```lua
   -- Good: kernel filters before your code runs
   vim.api.nvim_create_autocmd("FileType", { pattern = "typescript", ... })
   -- Worse: fires for every filetype, you filter manually every time
   vim.api.nvim_create_autocmd("FileType", { callback = function() if vim.bo.ft == "typescript" ... end })
   ```

3. **Buffer-local where possible** (`buffer = args.buf`) so the callback only
   lives as long as the buffer.

4. **Defer heavy work off the event** with `vim.schedule()` / `vim.defer_fn()`
   so the triggering action (open, move, type) isn't blocked. The fold
   auto-import logic in `folding.lua` does this (`defer_fn` + retry).

5. **Bail early and cheaply.** First lines of a hot callback should be the
   fastest rejects (position unchanged? wrong filetype? buffer invalid?).

---

## 4. Red-Flag Functions & Patterns

| Pattern | Why it's dangerous | Safer alternative |
|---|---|---|
| `vim.fn.system()` / `io.popen()` on a hot path | Blocks the UI thread for the whole subprocess. Even 20ms = jank. | Run on keymap/command only (like `<leader>gw` git blame), or use `vim.system()` async with a callback. |
| Synchronous treesitter parse (`get_parser():parse()`, `query:iter_captures`) per move/edit | Re-parses the tree; scales with file size. | Run only on demand (keymap) or once on `BufReadPost` with a large-file guard. |
| `vim.lsp.buf_request` / blocking LSP calls on cursor move | Network/IPC latency on the hot path. | Debounce + request-token cancellation (see `mouse-hover.lua` `request_id` pattern). |
| Looping all buffers/windows in a frequent callback | O(n) every time; grows with session. | Cache, or only run on cold-path events. |
| Monkey-patching plugin/Neovim internals | Fragile — silently breaks on update. Already used here (`open_floating_preview`, `document_color.enable`, copilot `nes.ui`, avante sidebar, `lazy.manage`). | Acceptable *only* when version-frozen (`lazy-freeze.lua`). Prefer public APIs/`opts`. Document the exact internal you depend on. |
| Building strings / tables inside statusline functions | Statusline redraws often. | Cache the value; recompute on a throttle (lualine `refresh` is 1000ms here) or on specific events. |
| `vim.notify` inside a hot callback | Triggers UI work + history. | Notify only on user actions. |
| Recursive `vim.schedule` without a bound | Can pin a core if the condition never clears. | Always cap iterations (see sidekick "apply all" `count > 100` guard). |

**Always wrap fragile/optional calls in `pcall`** so a missing plugin or a
nil internal can't break the whole config load. The config does this
consistently — keep it up.

---

## 5. Red-Flag Options & Settings

| Setting | Verdict | Reason |
|---|---|---|
| `lazyredraw` | **Do NOT enable** | Already tried & reverted — causes async UI freezes with LSP. See comment in `options.lua:153`. |
| `foldmethod = "expr"` **globally** | **Avoid** | Triggers a synchronous per-line treesitter scan on every buffer open, blocking render. UFO handles folds async/per-buffer instead — see the long comment in `options.lua:161`. |
| `updatetime` very low (<300ms) | Careful | Drives `CursorHold` frequency. 400ms here is a deliberate balance. Lowering it multiplies all CursorHold work. |
| LSP `semantic tokens` | Keep disabled | Computes/sends token payloads per change. Nil'd at `LspAttach` in `lsp.lua`. |
| LSP `inlay_hints` | On since 2026-11-12 (was off) | A whole-buffer hint request after every change. Kept cheap by sending parameter names only; `<leader>uh` turns them off per buffer. Measured cost is in `lsp.lua`. |
| `diagnostics.update_in_insert` | Keep `false` | Recomputing diagnostics on every insert keystroke is brutal. |
| `vim.lsp.document_color` (0.12+) | Disabled here | Polls colors; `enable` is stubbed in `lsp.lua:140`. |
| `synmaxcol` high / unset | Keep low (300) | Syntax-highlighting very long lines is expensive. |
| `relativenumber` + huge files | Minor | Renders line-number column each move; fine normally, can matter on 10k+ line files. |
| Tree-sitter `highlight`/`indent` on giant files | Guard it | Stop treesitter above a byte threshold — `large_file` guard (100KB) in `autocmds.lua`, fold guard (200KB) in `folding.lua`. |

When adding an LSP server: set `flags.debounce_text_changes` (300ms convention
here) and disable features you don't use (the `vtsls` block disables
`completeFunctionCalls`, package.json auto-imports, node_modules watching).

---

## 6. Plugin Loading Rules

- **Lazy-load by default.** Use `event` / `ft` / `cmd` / `keys`. Only set
  `lazy = false` when the plugin *must* be present at startup (here: `snacks`,
  `oil`, colorscheme). Each eager plugin adds to startup directly.
- **Prefer `VeryLazy`** for anything not needed for the first painted frame.
- **`event = "BufReadPost"`** for buffer-feature plugins (folding/ufo).
- **`cmd`/`keys`** for on-demand tools (diffview, neogit, grug-far, trouble).
- **Disable, don't delete,** unused plugins with `enabled = false` so the spec
  stays documented (flash, avante, bufferline, etc. are disabled this way).
- **Respect the version freeze.** New installs/clean still work, but
  `:Lazy update/sync/restore` is blocked (`lazy-freeze.lua`). Adding a plugin
  spec is fine; updating existing ones needs `NVIM_LAZY_UNLOCK=1 nvim`.

---

## 7. Safe-Modification Workflow

1. **Additive over invasive.** New keymap/command/feature in its own block or
   file beats editing a working one. Lower blast radius.
2. **One change at a time.** Make it, test it, then move on. Don't batch
   unrelated edits — if something breaks you won't know which.
3. **Reuse an existing safe pattern** from Section 10 rather than inventing.
4. **Guard new buffer/file work** with a size check before treesitter/regex.
5. **`pcall` anything optional** (plugin requires, internal access).
6. **Check for keymap/autocmd collisions** before adding (`:verbose map <lhs>`,
   `:au <Event>`). This config overrides several LazyVim defaults (`gd`, `gf`,
   `K`, `<Tab>`, `<Esc>`, `<C-e>/<C-y>`) — don't silently shadow them.
7. **Test the reload case.** If you add an autocmd, `:source %` twice and
   confirm behavior doesn't double (proves your augroup is correct).
8. **Verify in a real file**, not an empty buffer — open a large TS/TSX file
   and a small one; type, scroll, move, switch buffers.

---

## 8. Measuring & Profiling

**Startup time** (baseline is ~40ms; investigate if you push past ~70ms):

```sh
nvim --headless --startuptime /tmp/st.log +q && sort -k2 -nr /tmp/st.log | head -20
```

**Hot-path lag** — profile a suspicious session:

```vim
:profile start /tmp/profile.log
:profile func *
:profile file *
" ... reproduce the lag: scroll, type, move ...
:profile pause
:qa
```

Then read `/tmp/profile.log` — sort by total/self time; the function at the
top of a laggy session is your culprit.

**Quick checks:**
- `:LazyHealth` / `:checkhealth` — config sanity.
- `:Lazy profile` — per-plugin load cost.
- `:verbose set <option>?` — find what set an option.

---

## 9. Pre-Commit Checklist

Before committing any config change, confirm:

- [ ] New autocmds are in a **named augroup** with `clear = true`.
- [ ] No synchronous `system()` / treesitter / LSP call on a `Cursor*`,
      `Text*`, `Char*`, or `Mouse*` event.
- [ ] Heavy/idle work is **deferred** (`vim.schedule` / `defer_fn`) or
      **debounced**.
- [ ] New buffer/file logic has a **large-file size guard**.
- [ ] Optional `require`s and internal access are **`pcall`-wrapped**.
- [ ] New plugins are **lazy-loaded** unless startup-critical.
- [ ] No **keymap/autocmd collision** with existing overrides.
- [ ] Startup time still ~40ms (`--startuptime`).
- [ ] Tested by typing/scrolling/switching in a **large real file**.
- [ ] Behavior survives **re-sourcing** the config (no duplicate effects).

---

## 10. What This Config Already Does Right

Copy these proven patterns instead of inventing new ones:

- **Disable hot-path features wholesale** — `snacks` `words`/`scope`/`indent`/
  `scroll`/`animate` off; `treesitter-context` off; lualine git-diff stripped;
  `loaded_matchparen = 1` (kills ~1200 calls/session).
- **Throttle + dedup + reuse timer** for `MouseMove` — `lua/config/mouse-hover.lua`
  (the reference implementation for any high-frequency handler).
- **Large-file guards** — `autocmds.lua` (`large_file`, 100KB → stop
  treesitter) and `folding.lua` (200KB → fall back to `indent`).
- **Async folds, not global `foldexpr`** — UFO on the manual/async path; see
  the rationale comment in `options.lua`.
- **LSP trimming** — semantic tokens nil'd, `document_color` stubbed,
  `update_in_insert = false`, per-server `debounce_text_changes = 300`,
  `vtsls` auto-import/watcher disabling.
- **Throttled statusline** — lualine `refresh = 1000ms`, copilot indicator
  behind a cheap `package.loaded` check.
- **Bounded I/O off the hot path** — quickfix persistence reads once on
  `VimEnter`, writes once on `VimLeavePre`, capped at 200 items.
- **`pcall` everywhere** for optional plugin access.
- **Version freeze** to contain the risk of the internal monkey-patches.

> Known cleanup item (non-urgent, batch it): ~29 autocmds lack an augroup.
> Not a runtime cost in normal use, but the one best-practice gap — wrap them
> when you next touch each file. See Section 3.
