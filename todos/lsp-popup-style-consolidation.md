# LSP Popup Style Consolidation

## Goal
Single source of truth for LSP doc-popup styling (`border`, `max_width`, `max_height`) so hover, signature help, mouse hover, and the right-click PopUp menu all render with identical dimensions.

## Problem
Four entry points each carry their own copy of `{ border, max_width, max_height }`, with diverging values. A popup looks different depending on how it was opened.

| Entry point | File:line | border | max_width | max_height |
|---|---|---|---|---|
| `<leader>k` (LSP buffer-local) | `lua/plugins/lsp.lua:3-8` | rounded | 65 | 20 |
| `K` (global mapping) | `lua/config/keymaps.lua:213-223` | rounded | 80 | 30 |
| `<M-i>` signature | `lua/config/keymaps.lua:213-216, 446-449` | rounded | 80 | 30 |
| Mouse hover | `lua/config/mouse-hover.lua:283-288` | rounded | 80 | 20 |
| Right-click PopUp menu | `lua/config/options.lua:57-64` | rounded | 80 | 30 |

## Out of scope (intentionally separate)
- **Diagnostic floats**: `lua/config/options.lua` and `lua/config/keymaps.lua`.
  Their short messages and source/header/prefix options justify a separate config.
- **Universal LSP-float wrapper**: `lua/config/keymaps.lua`. It adds a conditional
  three-cell gutter only when documentation wraps, then applies the shared doc-float
  surface. It does not replace the caller-specific width and height options.
- **Bespoke command floats**: Git Who, Git Blame Line, and Unsaved Files in
  `lua/config/keymaps.lua`. Their sizing is content-driven.
- **Plugin popup systems**: blink.cmp, Oil, Snacks, and fidget use their own renderers.

## Plan
1. Create `lua/config/lsp-popup.lua` returning a single table:
   ```lua
   return { border = "rounded", max_width = 80, max_height = 30 }
   ```
2. Replace the four duplicates above with `require("config.lsp-popup")`.
3. Special-case `options.lua:57`: it embeds a Lua table as a string literal inside
   an `:anoremenu` Vim command. Either:
   - Serialize the table back to a string at load time (`string.format`); or
   - Pre-build the string once after requiring the shared table.
4. Decide which key owns hover dimensions. `<leader>k` currently uses the LSP table,
   while global `K` uses the keymaps table. Repoint both at the shared table if the
   intended dimensions are identical.

## Risks / things to verify
- `mouse-hover.lua` currently sets `max_height = 20` deliberately because mouse
  popups feel intrusive when tall. Decide whether to keep this per-caller override.
- `<leader>k` currently uses `65x20`, while `K` uses `80x30`. Confirm whether that
  difference is intentional before flattening it.
- The right-click PopUp menu opts live in a string-cmd context; after the change, reproduce `mouseright` on a symbol → "Show Hover Docs" / "Show Signature Help" and confirm sizing matches `K`.

## Future extension
If diagnostic floats are also consolidated, do it as a *second* shared table (`lsp-diag-popup.lua`) — don't bundle the two together. They share `border` but nothing else.
