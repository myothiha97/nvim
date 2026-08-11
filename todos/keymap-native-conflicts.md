
# Keymap Native Conflicts

> **Priority: MEDIUM.** High-impact conflicts are resolved. The remaining insert-mode
> cases are deferred to a planned config session.

## Goal
Resolve custom keymaps that shadow native Vim bindings in normal / insert / visual mode,
**preserving native behavior** instead of silently overwriting it.

## Guiding Principle
When a map conflicts with a native binding, choose the *safest* resolution, not the newest map:

- **Fallback** — for plugin maps only meaningful in a transient state (completion menu or
  suggestion open): add `"fallback"` so the key falls through to native when that state is
  absent. Reference: `lua/plugins/blink-cmp.lua`
  `["<C-f>"] = { "show_documentation", "hide_documentation", "fallback" }`.
- **Relocate** — for unconditional function maps on native keys (no state to gate on): move
  the custom feature to a free key and reclaim the native binding.

## 🔴 High-impact (native command fully shadowed → relocate)

| Key | Native meaning (previously lost) | Former override | Current resolution |
|-----|----------------------|------------------|-----------------|
| `gi` ✅ | Resume insert at last edit position | Line diagnostics float | Moved to `<leader>cd` in `keymaps.lua`; native `gi` reclaimed |
| `ge` ✅ | Motion: back to end of previous word | Next error | Disabled in `diagnostics-keymaps.lua`; use `]e` |
| `gp` ✅ | Paste with cursor after text | Previous error | Disabled in `diagnostics-keymaps.lua`; use `[e` |
| `gf` ✅ | Go to file under cursor | Function start | Disabled in `treesitter-keymaps.lua`; use `]f` / `[f` |
| `gh` ✅ | Start Select mode | Function end | Disabled in `treesitter-keymaps.lua`; use `]F` / `[F` |
| `<C-k>` (insert) ✅ | Digraph entry | Copilot toggle | Moved to `<M-k>` plus the Neovide `<D-k>` mirror |

## 🟡 Medium

- `<C-i>` / `<Tab>` (insert): `blink-cmp.lua:44` `["<C-i>"] = { "show", "hide" }` has no
  `"fallback"`. `<Tab>` has its own fallback, but terminal encoding and snippet indentation
  still need an empirical menu-open/menu-closed test before changing this.
- `<S-h>` / `<S-l>` ✅: LazyVim's buffer maps are deleted in `keymaps.lua`; native `H`/`L`
  are reclaimed. The parked static-tabline experiment must not reintroduce them silently.
- `<C-j>` (insert): Copilot trigger (`copilot.lua:162`) shadows native newline. Low harm;
  move to `<M-j>` if needed.

## 🟢 Low / keep as-is
- `K`, `gd` — LSP overrides, intentional and standard.
- `zm`, `zn` — ufo fold toggles, intentional (shadow native fold-level commands).
- visual `s` — vim-surround; `s` ≡ `c` in visual, so no real loss.
- normal `<Esc>` — clear highlights / close floats; only a tiny pending-count edge case.
- `<S-arrows>` — resize; shadows rarely-used native scroll/word-motion.
- Arrow keys — intentionally scroll normal editor viewports one line/column for ergonomic
  code review; special/plugin and floating windows keep native cursor movement.

## ⚠️ Non-native but real self-collisions (fix in the same pass)
- ✅ `<leader>m`: Resolved. Quickfix "Add line to Quickfix" (`keymaps.lua:807`) is the
  owner. Harpoon is `enabled = false`, so no live clash; a CONFLICT comment at
  `harpoon.lua:76` flags it to relocate (→ `<leader>ha`) if harpoon is ever re-enabled.
- ✅ `<M-i>`: verified to exist only in `keymaps.lua`; mouse-hover defines no mapping.

## Notes
- Reconciled with the live config on 2026-08-11. Re-verify line numbers before editing.
- Leader maps never conflict with native Vim, so only bare keys and `<C->/<M->/<S->` chords
  are in scope here.
