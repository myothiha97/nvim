> Policies and personal rules for editing this config live in [`rules.md`](../rules.md).
> The freeze policy (2026-05-24) is the active one — read it before opening any plugin file.

## May 2026 change summary

### Runtime and performance
- Optimized runtime behavior for large projects by trimming expensive UI/background work, reducing Treesitter usage on large files, and keeping fold behavior on UFO's async/manual path instead of global synchronous `foldexpr`.
- Disabled or deferred nonessential plugins/features such as gitsigns, bufferline, some Treesitter-heavy helpers, and unused UI integrations where the runtime cost was higher than the current value.
- Tuned completion and LSP debounce behavior, including Copilot debounce adjustments and LSP diagnostic/update settings.

### Copilot, blink.cmp, and AI workflow
- Stabilized Copilot ghost text by preventing LazyVim/mason-lspconfig from auto-starting the standalone `copilot-language-server`, so `copilot.lua` owns the Copilot client slot.
- Upgraded Neovim from the broken 0.12.0 changetracking path to 0.12.2, removing the need for previous Copilot restart/workaround logic.
- Reworked Copilot and blink.cmp coexistence: manual ghost-text flow, cleaner accept/cancel keymaps, and later a master toggle that silences Copilot NES with the same switch as ghost text.
- Migrated Avante toward the Codex ACP provider with reasoning-effort configuration and buffer auto-sync, while keeping notes for future UI/UX refinement.

### Folding
- Added and refined `nvim-ufo` workflows, including `zv` for toggling all function folds via Treesitter queries with fallback behavior.
- Re-enabled scoped Treesitter fold providers for JS/TS/JSX/TSX/Lua while keeping `indent` fallback and a large-file guard at `200KB`.
- Preserved a follow-up note to revisit the current auto-fold-imports-on-open block in `lua/plugins/folding.lua`.

### Mouse and popup workflow
- Added `lua/config/mouse-hover.lua` for delayed LSP hover docs on mouse movement, while preserving native right-click popup behavior.
- Fixed conflicts where hover popups could close right-click menus, steal focus unexpectedly, or prevent clicking into the hover popup.
- Kept double-click/tap behavior on Neovim defaults after testing instant hover-on-double-tap and finding the UX worse.

### UI, theme, and editor ergonomics
- Refined solarized-osaka and tokyonight highlight overrides, including selection contrast, diagnostic virtual text, blink.cmp menu colors, and disabled CursorLine background while leaving previous color values commented for easy restore.
- Added statusline visibility for unsaved buffers and a popup workflow for jumping/saving unsaved files.
- Adjusted explorer, surround, right-click menu, jumplist, Harpoon/which-key visibility, and Neovide-specific configuration.

### Config organization and repository cleanup
- Extracted Neovide-specific setup into `lua/config/neovide.lua`.
- Updated plugin lockfile pins and removed the old `oil.lua.popup-backup`.
- Split TODO-style planning notes out of `journal.md` into `todo.md`.

## AI integration updates
Feature -  custom popup for ai agents 
Feature - async ai agents completions without blocking the UI
~~fix - the current avante.nvim ai chat feature is not working well when using co pilot as provider~~
~~its taking too much time to complete the task - which is not even complex~~
✅ Fixed: switched to Claude (claude-sonnet-4) as provider with proper model ID, timeout, and max_tokens

## Disable blink.cmp completions inside comments (TS/TSX)
✅ Resolved: due to performance bottleneck, we disabled the comments check  functions
- blink.cmp `enabled` function with `vim.treesitter.get_captures_at_pos` is not suppressing completions in comments for TypeScript/TSX files
- Treesitter comment detection works for some filetypes but not TS/TSX — likely because vtsls injects grammars or the capture name differs (`comment` vs `comment.line`, etc.)
- Needs investigation: check actual capture names via `:lua print(vim.inspect(vim.treesitter.get_captures_at_pos(0, vim.fn.line('.')-1, vim.fn.col('.')-1)))`
- Alternative approaches to explore: blink.cmp `sources` per-filetype override, or checking `vim.bo.commentstring` against current line content

## LSP autocompletion
~~fix - currently lsp display snippets at first , this can be convenience for some cases but sometime it can be annoying when you want to see the completions list of lsp suggestions.  so we need to enhance the blink cmp a little bit~~
✅ Fixed: added `fuzzy.sorts = { "exact", "score", "sort_text" }` and disabled default snippet penalty via `sources.transform_items`. Exact prefix matches now surface first (VSCode-like behavior).

## Theme highlight tweaks (2026-05-07)
✅ Updated: solarized-osaka `on_highlights` overrides to match tokyonight-night selection contrast, refine blink.cmp menu colors, and tune LSP diagnostic virtual text (bright red error, info bg removed).


## ✅ To show save/unsave status in the status line for current file and also the custom pop-up menu for all the unsaved files
✅ Fixed: bright red "● unsaved" in lualine_b; `<leader>bu` opens unsaved files popup with jump/save/save-all actions.


## ✅ Copilot lua issues (RESOLVED 2026-05-04)

**Symptom:** ghost text never appeared on TS/TSX buffers; intermittent dropouts in
prior sessions. `:Copilot status` showed `Online` + `Buffer status: attach not yet
requested`. Statusline showed `? Copilot` (status unknown).

**Root cause: TWO independent bugs masquerading as one.**

1. **nvim 0.12.0 changetracking bug** — assertion in `_changetracking.lua:299`
   ("changetracking.init must have been called for all LSP clients") fired when
   multiple LSP clients (vtsls + copilot + emmet) attached to one buffer. The
   unhandled error escaped through `send_changes` and tore down copilot's LSP
   client mid-edit. Caused the *intermittent* dropouts the TODO was tracking.
   Confirmed via diff of `runtime/lua/vim/lsp/_changetracking.lua` between
   v0.12.0 and v0.12.2 (+53/−9, new `_send_did_save` "Sends didOpen/didClose/
   didSave to all client groups", commit `fe09c71c` / fix #37454).

2. **mason-lspconfig auto-enabled the binary `copilot-language-server`** —
   leftover Mason install (probably from a past `copilot-native` extra) was
   auto-enabled by LazyVim's lspconfig setup at
   `lazyvim/plugins/lsp/init.lua:271-275`
   (`mason-lspconfig.setup({ automatic_enable = { exclude = mason_exclude } })`).
   Servers only land in `mason_exclude` if listed in `opts.servers` with
   `enabled = false` — `copilot` wasn't there, so it was auto-enabled via
   `vim.lsp.enable("copilot")`, which started nvim-lspconfig's stock
   `lsp/copilot.lua` (the binary). When `zbirenbaum/copilot.lua` plugin loaded
   on InsertEnter, both fought for the `name = "copilot"` client slot.
   nvim-lspconfig kept winning (since `vim.lsp.enable` re-attaches), so the
   plugin's per-buffer state (extmark namespace, `set_keymap`) never
   initialized. Caused the *always-broken* ghost text — the user-visible
   symptom that hid behind the TODO's intermittent-bug framing.

**Fixes applied:**

- `brew unpin neovim && brew upgrade neovim` → 0.12.0 → 0.12.2 (resolved bug #1).
  The Homebrew pin was silently keeping nvim stuck on 0.12.0 across upgrades.
- `lua/plugins/lsp.lua`: added `copilot = { enabled = false }` to the servers
  table so mason-lspconfig's `automatic_enable` excludes it. Now only the
  `zbirenbaum/copilot.lua` plugin manages copilot — no client-slot fight
  (resolved bug #2).
- `lua/plugins/performance.lua`: removed invalid `show_delay_ms = 0` field
  from `completion.trigger`. The field never existed on `trigger` in
  blink.cmp 1.10.2 (only `auto_show_delay_ms` on `completion.menu` /
  `documentation`). blink's strict validator was rejecting the field and
  short-circuiting setup, which prevented the BlinkCmp* events copilot.lua
  coordinated with.

**Workarounds removed (no longer needed):**

- `lua/plugins/lsp.lua`: dropped the `pcall`-wrap of
  `vim.lsp._changetracking.send_changes` (added to swallow the 0.12.0 assertion
  — now fixed upstream in 0.12.2).
- `lua/plugins/copilot.lua`: dropped the LspDetach auto-restart loop with
  3-per-60s rate limiting (added to self-heal when the client died — client no
  longer dies). Reverted LspDetach handler to a simple disconnect notification.
- `lua/plugins/copilot.lua`: dropped the `<C-g>` manual trigger keymap (added
  as a fallback when auto-trigger missed — auto-trigger now reliable).

**Verification:** `:checkhealth vim.lsp` now shows copilot running NodeJS
`language-server.js` from the plugin (not the Mason binary), `Buffer status:
attached`, statusline shows plain `Copilot`, ghost text renders on auto-trigger.

**Notes for future:**

- Mason still has `copilot-language-server` installed but no longer auto-enabled.
  Remove with `:MasonUninstall copilot-language-server` if desired (not required).
- `lua/plugins/copilot.lua` comments mention Blink coexistence via `BlinkCmp*`
  autocmds, but those autocmds are currently commented out. Functionally this is
  fine if Copilot/Blink overlap is not happening, but the comment should be
  cleaned up if this area is touched again.
- If anything else is later introduced that calls `vim.lsp.enable("copilot")`
  directly (e.g. re-enabling `sidekick.nvim`'s `init` block at
  `lua/plugins/sidekick.lua:21`), expect the same client-slot fight to return.
  The `enabled = false` in `lsp.lua` only blocks LazyVim's auto-enable path,
  not arbitrary direct calls.

### NES (Next Edit Suggestions) — still deferred

Only ghost-highlight is stable, NES disabled. Future goal: combine
ghost-highlight + NES into a Cursor-tab style UX. Path forward is re-enabling
`folke/sidekick.nvim` (already in `lua/plugins/sidekick.lua`, `enabled = false`).
Past attempt failed because sidekick's copilot LSP client and copilot.lua's
suggestion module fought for the same client slot — same root-cause shape as
fix #2 above. Re-enabling sidekick will require disabling copilot.lua's plugin
or carefully sequencing which one owns the client.


## Advance refactoring for large codebases
currently if the codebase is too large, i found difficult to refactor some parts of the codebase, like extracting some code to a separate file
so we need to enhance the refactoring process by adding some features like :
- extract code to a separate file and update the imports accordingly
- rename variables and functions across the codebase
- automatic generating getter and setter for classes
- automatic generating documentation for functions and classes
- automatic generating tests for functions and classes
- code coverage analysis and reporting 


## Refactoring for current Neovim configs
- currently, the lua configuration is a bit messy and hard to maintain, so we need to refactor it to make it more organized and maintainable,
by splitting it into multiple files and folders.
- might need to simplify some configurations by removing some unnecessary plugins and configurations that are not being used or not providing much value.
- need to re-analyze the current plugins and prune the unnecessary ones and only leaves the most essential ones

## ✅ Complete Avante AI agents integrations (RESOLVED 2026-05-04)

Re-enabled avante.nvim in agentic mode with Cursor-style diff acceptance keymaps.

**Key fixes:**
- Removed `providers.copilot = { model = "..." }` — this causes `model_not_supported`; model is persisted to `~/.local/state/nvim/avante/config.json` by avante, set once with `:AvanteModels`
- Added `behaviour.auto_set_keymaps = false` so manually-defined keymaps take full effect
- Added `cmd` list for lazy-loading

**Performance note:**
- `lua/plugins/avante.lua` still has `event = "VeryLazy"`, so Avante loads on `VeryLazy` even though a `cmd = { ... }` list exists. Current performance is fine, but if startup/runtime cost becomes a concern later, remove `event = "VeryLazy"` to make Avante truly command-lazy.

**Keymaps:**
- `<leader>aa` — AvanteAsk (also works in visual mode)
- `<leader>ac` — AvanteChat
- `<leader>ae` — AvanteEdit (visual selection)
- `<leader>at` — AvanteToggle (sidebar)
- `<leader>ar` — AvanteRefresh / `<leader>as` — Stop / `<leader>am` — Models
- In diff view: `A` apply all, `a` apply at cursor, `co`/`ct` ours/theirs, `]x`/`[x` navigate

**First-run required:** `:AvanteModels` → select a model (e.g. `claude-sonnet-4-5`).

## ✅ Folding — toggle all function folds (RESOLVED 2026-05-04)

`zv` — toggle fold/unfold all functions in the current file.

Uses treesitter to locate function nodes (ts/tsx/js/jsx/lua/python/go/rust). Falls back to top-level folds for other languages. Toggle: any function open → close all; all closed → open all. Cursor restored after. Added to nvim-ufo keys in `lua/plugins/folding.lua`.

## ✅ Copilot + blink.cmp coexistence + manual-only copilot mode (RESOLVED 2026-05-05)

Resolved long-running mental overhead of fighting two completion systems at once.
Copilot ghost text now strictly opt-in; blink.cmp owns the autocomplete loop.

**Root cause of the conflict:**
- Copilot's built-in `hide_during_completion` checks `vim.fn.pumvisible()`, which
  is always `0` for blink.cmp's custom floating window (not the native pum). The
  guard never fired, so ghost text overlapped the menu.
- `suggestion.dismiss()` alone isn't enough — it only clears the *currently
  rendered* ghost. In-flight LSP responses (~200ms latency) still drew on top
  of an already-open blink menu. Fix: also set `vim.b.copilot_suggestion_hidden = true`,
  which is checked at *render time* in `copilot/suggestion/init.lua:257`.

**Mode change — copilot is now manual-only:**
- `auto_trigger = false` in copilot opts. No more per-keystroke LSP requests.
- `<C-j>` (insert) — manually trigger or cycle copilot suggestion. Closes blink
  menu first if open, clears the hidden guard, then `suggestion.next()`.
- Big perf win: copilot LSP no longer fires on every `TextChangedI`.

**Shared keymap layout (consistent semantics across both popups):**
- `<C-j>` — invoke copilot
- `<C-l>` — accept (blink first via `select_and_accept`, copilot via blink's
  `fallback` mechanism if menu is closed)
- `<Esc>` — cancel blink menu (stays in insert) OR dismiss copilot ghost +
  exit insert (depending on which is active). Original behavior preserved.
- `<M-]>` / `<M-[>` — cycle copilot variants
- `<M-w>` / `<M-l>` — accept word / line
- `<leader>ad` (normal) — escape hatch back to auto-trigger mode

**Files touched:**
- `lua/plugins/copilot.lua` — `auto_trigger = false`, `BlinkCmpMenuOpen/Close`
  autocmds with `vim.b.copilot_suggestion_hidden`, `<C-j>` manual trigger,
  `<C-l>` accept (replaces previous `<C-o>`)
- `lua/plugins/performance.lua` — no functional change to blink keymap (kept
  `<ESC>` as cancel + fallback)

**Performance:** all autocmds fire on discrete events (menu open/close), not
on `TextChangedI`/`CursorMoved`. Net runtime cost is negative — disabling
copilot auto-trigger eliminates the per-keystroke LSP request loop.



**Goal:** Re-enable `akinsho/bufferline.nvim` as a *favorites bar*, not a VSCode-style "every visited buffer becomes a tab" bar. Use case: as the project grows, jumping back-and-forth via snacks picker is tedious — pin 3–5 actively-used files, cycle between them with `<S-h>`/`<S-l>` or `<leader>1..9`, ignore everything else.

**Status:** disabled (`enabled = false` in `lua/plugins/bufferline.lua`). Config preserved in the file so we can iterate later.

**Designed behavior (already in the disabled config):**
- Path-keyed `pinned` table inside the plugin's config closure (survives `:bd` + reopen in same session, NOT persisted across nvim restarts).
- `custom_filter` returns true for the current buffer + any pinned buffer; everything else is hidden from the bar.
- `always_show_bufferline = true` so the current file's name is always visible (VSCode-like).
- Soft warning at >5 pins (not a hard cap).
- `<leader>bb` toggle pin, `<leader>bj` pick by letter, `<leader>bx` unpin+close, `<C-q>` close current buffer (won't conflict with `<C-w>` window prefix), `<S-h>`/`<S-l>` cycle pinned, `<leader>1..9` jump to Nth.

**What broke / open questions:**
- After enabling with `lazy = false` + `priority = 900`, tab DID render but layout looked wrong: tab squashed into the top-left over the neo-tree column, with a misaligned diagonal artifact across the screen. Suspected `offsets` neo-tree integration + `indicator = { style = "underline" }` + `separator_style = "thin"` interaction with the active theme (tokyonight). Removing those (current state of the disabled file) was untested before disabling.
- Need to verify on a clean restart whether the simplified config (no offsets, `indicator = { style = "icon" }`, default separator) actually renders cleanly. If yes, just flip `enabled = true`. If no, the issue is deeper (theme highlight groups, terminal font, etc.).

**Coordinated state:**
- `lua/config/keymaps.lua` re-applies `vim.keymap.del("n", "<S-h>")` / `<S-l>` since LazyVim's default `:bnext`/`:bprev` cycles ALL loaded buffers, which is the opposite of the pinned-only workflow. When re-enabling bufferline, those `del` calls become redundant (bufferline's mappings will overwrite anyway) but don't conflict.
- `<C-q>` is currently unbound (it was set inside the disabled plugin's config). Free for future use or re-mapping when bufferline returns.

**Next time this is picked up:**
1. Flip `enabled = true` and restart nvim.
2. Open a file → confirm tabline shows `1.  filename.ext` at the top with a `▎` indicator.
3. If layout is still broken, capture `:messages` + `:hi BufferLineFill BufferLineBackground BufferLineBufferSelected` output to debug highlight resolution.
4. If layout is fine, optionally restore the neo-tree `offsets` block as a separate iteration.

