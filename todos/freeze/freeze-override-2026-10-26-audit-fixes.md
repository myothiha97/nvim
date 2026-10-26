# Freeze-override trace — 2026-10-26 Sept/Oct audit fixes

Required by rule 10 in [`discipline-stop-rules.md`](../process/discipline-stop-rules.md).

**The change (one line):** eight small fixes from the Sept/Oct commit audit, picked
by the user from its "Before November" list, so the config is settled before
production work starts in November.

**Why it did not wait:** M1 is a security fix (a data-leak risk), not an
override. The rest are minor bugs the gate defers to the 2026-12-31 checkpoint.
They were overridden by explicit confirmation ("ok proceed with these fixes").

| id | file | fix |
| --- | --- | --- |
| M1 | `lua/plugins/copilot.lua` | secret filter also blocks `*.env`, `secret(s)/` folders, `kubeconfig`, `.pgpass`, `.vault-token`, `*.jks`, `*.keystore`, `*.ovpn`, `.dev.vars`, `service-account*.json` (security, not an override) |
| L1 | `lua/plugins/copilot.lua` | no NES request while a macro replays |
| L7 | `lua/plugins/copilot.lua` | NES on `CursorHold` marked done only once sent to an attached client |
| L6 | `lua/plugins/copilot.lua` | toggle-off clears NES in every buffer, not only the current one |
| M2 | `lua/plugins/git.lua` | `]]`/`[[` hunk maps removed; ftplugin section jumps are back, `]c`/`[c` stay for hunks |
| L2 | `lua/config/keymaps.lua` | insert `<M-h>`/`<M-j>`/`<M-l>` (Cmd+H/J/L) are `<Nop>` instead of acting as `<Esc>` + key |
| L3 | `lua/config/keymaps.lua` | arrow keys no longer inverted: Up scrolls up, Down scrolls down |
| L5 | `lua/plugins/markdown-preview.lua` | `<leader>ui` no longer errors on a readonly buffer |
| L8 | `lua/plugins/trouble.lua` | outline folds the outlined buffer, not whichever buffer is current |

**Validated:** each fix tested in a real UI instance with a control
(tmux for Cmd+J, stubs for Copilot and `open`); keymap diff against the phase-0
baseline shows only the intended changes; startup A/B against `main` is
52.83 ms vs 52.96 ms median (noise).

**Follow-up the same day (regression fix, not an override):** the L2 `<Nop>`
maps made a quick `<Esc>` then `j`/`h` (under `ttimeoutlen`, 50 ms) read as
`<M-j>`/`<M-h>`, losing both keys. `ttimeoutlen` is now 10 in
`lua/config/options.lua`: fixed at every gap tested (5 to 50 ms), Cmd+J still a
no-op, and `<Esc>` to normal mode went from 61 to 22 ms.
