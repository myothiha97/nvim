# Deep config review: findings

Findings only, no fixes. Format from `deep-config-review.md` section 6:
`<file>:<line> — <what is wrong> → <when it breaks> → <cheapest fix>`, then
`[verified | unverified] [change-gate: pass | fail | n/a]`.

## Phase 0 — baseline (2026-10-26)

Done. See `deep-config-review-baseline/README.md`. Clean boot, startup
47 to 49 ms, zero per-keystroke handlers.

## Carried in from the Sept/Oct commit audit (2026-10-26)

Found by reading every Sept and Oct commit, not by the phase reads. Do not
re-derive; confirm in the matching phase and fold in.

Medium:

- `lua/plugins/copilot.lua:8-24` — secret filter misses `prod.env`, `*/secrets/*`, `kubeconfig`, `.pgpass`, `.vault-token`, `*.jks`, `*.ovpn`, `.dev.vars` → those files reach Copilot once the toggle is on → add the patterns, match `secrets?` on the path [verified] [change-gate: pass, data leak]
- `lua/plugins/git.lua:264-265` — buffer-local `]]`/`[[` hunk maps shadow the built-in ftplugin section jumps (markdown headers, Go/Python sections); the comment says nothing else claims them → `]]` in a tracked `.md` jumps to a hunk → deliberate choice, fix the comment and `notes/git/git-keymaps.md` [verified] [change-gate: pass for docs only]
- `lua/config/keymaps.lua:388-406` — `scroll_popup_or` picks a focusable `snacks_notif` toast (z 100) → `<C-e>`/`<C-y>` scroll the toast while one is visible → skip `snacks_notif`/`snacks_notif_history` [verified] [change-gate: pass]
- `lua/colorschemes/solarized-osaka/variants.lua:155,158` — duplicate `member` key in `custom-latest`, the second wins → member colour applies to every language, docs say Go only → keep one line (breakage only, no colour choice) [verified] [change-gate: pass]
- `variants.lua` `M.load` + `palette.lua:472` — `member` is nil in the base, so the restore never runs; `override_go` is global → numbered builds `custom-v1..v4` no longer reproduce → uncomment `member = false` in the base [verified] [change-gate: fail until checkpoint, palette closed]

Low-Medium and Low:

- `copilot.lua:138-163` — `InsertEnter` NES has no macro guard → `100@a` sends ~100 requests → return when `reg_executing() ~= ""` [unverified] [change-gate: pass]
- `keymaps.lua:588` — insert `<M-j>`/`<M-h>` unmapped → Cmd+J while typing exits insert and moves a line → map to `<Nop>` [verified] [change-gate: pass]
- `keymaps.lua:430-431` — arrow fallback in panels is inverted → `<Up>` moves down in help/quickfix/oil → make the fallback the pressed key, unless intended [verified by reading] [change-gate: pending user confirm]
- `git.lua:247-258` — `]c` in a diff split drops the count → `3]c` moves one → prefix `vim.v.count1` [verified by reading] [change-gate: fail until checkpoint]
- `lua/plugins/markdown-preview.lua:33` — `silent update` errors on a readonly buffer → `<leader>ui` raw error → `pcall` [unverified] [change-gate: fail until checkpoint]
- `copilot.lua:330` — toggle-off clears NES in the current buffer only → stale NES in another split, `<Tab>` applies it → clear every buffer with `nes_state` [verified by reading] [change-gate: fail until checkpoint]
- `copilot.lua:154-157` — NES marked done before the buffer attaches → no retry right after load → mark only when attached [unverified] [change-gate: fail until checkpoint]
- `lua/plugins/trouble.lua:573` — outline fold uses the current buffer → async reply can fold the wrong buffer → use `filter_memo.result[1].buf` [unverified] [change-gate: fail until checkpoint]
- Root `CLAUDE.md` — untracked since 5ccaec4 with local-only edits; tracked files link to it → track it again or merge into `docs/CLAUDE.md` [verified] [change-gate: pass, backup]
- Stale docs: `README.md` (`<leader>ui`, Copilot, CodeCompanion), `neovide.lua:58-63`, `notes/copilot-nes.md:59`, `CLAUDE.md` Go member and LSP doc rows, `copilot.lua:42` comment [verified] [change-gate: pass, text only]
- `lua/plugins/snacks.lua` dead explorer-input code and `transparent = true` comments after 94eb3e0; `lua/config/picker-size.lua` unused `compact` [verified] [change-gate: fail until checkpoint]

## Found while validating the audit fixes (2026-10-26)

- todo-comments `TODO` keyword highlight — `TodoFgTODO`/`TodoBgTODO`/`TodoSignTODO` resolve to a different fg from one start to the next with identical code (2 of 4 captures `#268bd3`, 2 of 4 `#29a298`) → load-order race: the colour depends on which group exists when todo-comments sets up → pin the `TODO` colour to a fixed group or set it after the colorscheme; breakage only, no colour choice [verified, 4 captures] [change-gate: fail until checkpoint]

## Phase 1 — `lua/config/keymaps.lua`

Not started.
