# Copilot NES tuning (handoff, updated 2026-10-04)

Read this before touching `lua/plugins/copilot.lua`. It started as a handoff from a
claude.ai chat and now records what actually shipped.

Commits on `trial-config-before-01-Jan-2027`:

- `ef76029` fix(copilot): drop the insert-mode esc map that broke macro replay
- `388a9f4` feat(copilot): keep copilot off .env and secret files
- `314807c` feat(copilot): tune nes and request it without typing
- `6b4a4e0` fix(copilot): cancel pending ghost-text requests on toggle-off

## Goal

Get Copilot NES (Next Edit Suggestions) in Neovim close to VS Code: frequent,
precise "tab-through" edits. Suggestion quality and frequency matter; GUI polish
does not.

## Accepted limitation

VS Code's NES runs in the Copilot Chat extension with richer context (edit
history, diagnostics, more triggers). Neovim goes through
`copilot-language-server` + `copilot-lsp`, which upstream still calls in
progress. The remaining gap is structural, not a config bug.

## Plugins

- `zbirenbaum/copilot.lua`: main plugin, runs the native Copilot language server.
- `copilotlsp-nvim/copilot-lsp`: the NES engine (dependency of copilot.lua).

## Verified from plugin source (do not re-litigate)

1. copilot.lua's `nes` opts only read `enabled` and `keymap`. Unknown keys are
   silently ignored, so `nes.auto_trigger` or thresholds there do nothing.
2. NES tuning lives in copilot-lsp:
   - Debounce: `vim.g.copilot_nes_debounce`, read ONCE when the LSP starts
     (default 500 ms).
   - Thresholds: `require("copilot-lsp").setup({ nes = { ... } })`
     (defaults 3 moves / 40 lines / clear far / count horizontal / reset on approach).
3. `copilot-lsp/nes/ui.lua` copies the config table when it loads, and `setup()`
   REPLACES that table. So `copilot-lsp.setup()` must run BEFORE anything
   requires `copilot-lsp.nes`. Called later, it is silently ignored.
4. copilot-lsp requests NES on `TextChanged` + `TextChangedI` through a debounced
   function that grabs `require("copilot-lsp.nes").request_nes` at LSP init.
   Wrapping `nes.request_nes` BEFORE `require("copilot").setup()` therefore gates
   every request, including the debounced one.
5. NES display has no mode check (shows in insert and normal mode). copilot.lua
   binds its NES keys (`<Tab>` accept, `<Esc>` dismiss) in normal mode only, with
   passthrough when no NES is showing.
6. `suggestion.debounce` only delays when a ghost-text request starts. Higher
   means fewer requests, not more time for multi-line completions.
7. `:Copilot disable` / `:Copilot enable` stop and restart the server in place
   (`client:stop()` + autocmd teardown). No Neovim restart is needed.

## What is live now

- `vim.g.copilot_nes_debounce = 150` at the top of the file; ghost-text
  `suggestion.debounce = 250`.
- `event = { "BufReadPost", "BufNewFile" }` (was `InsertEnter`), so normal-mode
  NES and `CursorHold` work from the first file.
- `filetypes = { ["*"] = true, text = false }`. Note: `"*"` also turns off
  copilot.lua's built-in exclusions (yaml, markdown, gitcommit, help, ...).
- `should_attach` keeps the default buflisted/buftype check and skips any file
  whose lowercased name starts with `.env` or contains `secret`.
- `config` order (the order is load-bearing, see facts 3 and 4):
  1. `copilot-lsp.setup()` with `move_count_threshold = 10`,
     `distance_threshold = 100`, `count_horizontal_moves = false`, the other two
     at their defaults.
  2. Wrap `nes.request_nes` with `if not vim.g.copilot_enabled then return end`.
  3. `require("copilot").setup(opts)`.
- Extra NES triggers without typing: `InsertEnter` and `CursorHold`, in augroup
  `CopilotNesTriggers`. Skipped when the toggle is off or an NES is showing.
  `CursorHold` only fires a request when `changedtick` or the cursor LINE changed
  since the last successful request in that buffer (`vim.b.copilot_nes_last`).
  - Why: `CursorHold` re-arms after ANY key, including the `<Esc>` that dismissed
    an NES, so without this check the same edit came back ~400 ms later
    (`updatetime = 400`).
  - Why line, not column: `<Esc>` moves the cursor one column left, so a column
    key would bring a dismissed NES straight back.
  - The spot is marked only when the request call succeeds, so an attempt that
    fails because the server is still starting is retried.
- Toggle `vim.g.copilot_enabled` (default false, `<leader>ad` / `<M-k>`) is synced
  to `vim.b.copilot_suggestion_auto_trigger` on `BufEnter`. On toggle-off it
  ALWAYS calls `suggestion.dismiss()` (cancels the debounce timer and any
  in-flight request and resets the request context) and `nes.clear()`.
  - Before 6b4a4e0, dismiss only ran when ghost text was visible. A leftover
    context then made copilot.lua keep requesting on every `CursorMovedI` until
    `InsertLeave`.
- Render gate on `copilot-lsp.nes.ui._display_next_suggestion` stays as a safety
  net for responses that arrive just after toggle-off.
- No insert-mode `<Esc>` map. Native `<Esc>` fires `InsertLeave`, where both our
  autocmd and copilot.lua dismiss ghost text. The old map re-fed `<Esc>` with
  `feedkeys`, which appends AFTER pending typeahead, so the macro
  `ihello<Esc>oworld<Esc>` replayed as `hellooworld`.
- NES survives leaving insert mode on purpose: `<Esc>` to normal mode, then
  `<Tab>` accepts or `<Esc>` dismisses.
- Manual keys (`<C-j>`, `<M-]>`, `<M-[>`) are not gated by the toggle, by choice.

## What "off" means

- Off: no ghost-text auto requests and no NES requests. The server keeps running
  and still gets document sync (`didOpen`/`didChange`) and `didFocus` on
  `BufEnter`. That traffic generates no suggestions and does not count toward
  the Free plan quota.
- Kept running on purpose (decided 2026-10-04): the server already knows every
  open buffer when you turn Copilot on, which gives better context. Stopping it
  on toggle-off was considered and rejected.
- Free plan: the 2,000/month limit counts generated suggestions, accepted or not.
  Assume NES requests count too (not confirmed). If the quota runs out early,
  raise `nes_debounce` first.

## Compared with VS Code (read from `inlineEditTriggerer.ts`, 2026-10-04)

VS Code triggers NES on edits always, but on cursor moves only if the file was
edited in the last 10 s, at most once per line per 5 s, and not at all after a
rejection until the next edit. Ours is looser: a rest on any new line triggers,
even with no recent edit. Matching VS Code's "only after a recent edit" rule was
offered and declined; current behaviour is good enough.

## Verify after restart

1. `:lua print(vim.g.copilot_nes_debounce)` prints 150.
2. Ghost text disappears on `<Esc>`.
3. An NES dismissed with `<Esc>` in normal mode does not come back until you edit
   or change line.
4. Trigger an NES, move the cursor 4 or 5 lines: it survives.
5. Open a `.env` file, `:Copilot status`: not attached.

To measure NES latency (runtime only, gone on restart):

```lua
:lua local c=vim.lsp.get_clients({name="copilot"})[1]; local r=c.request; c.request=function(s,m,p,h,...) if m=="textDocument/copilotInlineEdit" then local t=vim.uv.hrtime(); local f=h; h=function(...) vim.notify(("NES %d ms"):format((vim.uv.hrtime()-t)/1e6)); return f(...) end end; return r(s,m,p,h,...) end
```

## After every `:Lazy update`

The request wrap and the render gate patch internal copilot-lsp functions
(`nes.request_nes`, `nes.ui._display_next_suggestion`) and fail SILENTLY if they
are renamed. Re-check that the toggle still silences NES.

## Open

- `lua/plugins/blink-cmp.lua:45` comment still says the second `<Esc>` goes
  "via copilot's handler"; it is native `<Esc>` now. Comment only.
- `README.md` still describes copilot.lua as `enabled = false`.

## Sources

- https://github.com/zbirenbaum/copilot.lua
- https://github.com/copilotlsp-nvim/copilot-lsp
- https://github.com/microsoft/vscode-copilot-chat/blob/main/src/extension/inlineEdits/vscode-node/inlineEditTriggerer.ts
- copilot.lua: `lua/copilot/nes/init.lua`, `lua/copilot/suggestion/init.lua`,
  `lua/copilot/client/init.lua`, `lua/copilot/command.lua`
- copilot-lsp: `lua/copilot-lsp/config.lua`, `lua/copilot-lsp/nes/init.lua`,
  `lua/copilot-lsp/nes/ui.lua`
