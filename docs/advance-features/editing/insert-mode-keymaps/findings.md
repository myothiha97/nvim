# Insert-mode navigation: findings and proposed edits

Status: read-only review, 2026-10-28. No files changed.

## Your actual setup

- **Chain:** Ghostty → tmux (`escape-time 0`, `extended-keys on`) → Neovim (LazyVim, `~/.config/nvim`). Neovide is also configured (`lua/config/neovide.lua`).
- **Ghostty already does Cmd→Alt translation** (option 1 from the handoff). `ghostty/config` has `macos-option-as-alt = false` and `keybind = super+<key>=esc:<key>` for: `h j k l d f i w n p [ ] / }` and `Shift+L`. So in the terminal, Cmd+X reaches nvim as `<M-x>`. `<D-x>` maps never fire in the terminal; they only matter in Neovide.
- **Option is not usable as Alt.** With `macos-option-as-alt = false`, Option+H types `˙`. Turning it on changes every pane (zsh, Claude, etc.), so I recommend staying Cmd-only.
- **tmux:** `bind -n M-h/j/k/l` forwards the key to nvim when the pane runs nvim, otherwise moves panes. Shifted `M-H/J/K/L` and other `M-` letters are not bound in the root table, so they pass straight through.
- **skhd / AeroSpace** only use Cmd+Ctrl combos. **Karabiner** has no Cmd/Option rules affecting Ghostty. No conflicts there.
- **`ttimeoutlen = 10`**: Ghostty sends ESC+key in one write, so `<M-x>` is recognized reliably (already verified in `options.lua` comments).
- **zshrc could not be read** (permission denied on the symlink from this session). Not reviewed.

## Conflicts with the proposed keymap

| Key (Cmd+) | Proposed | Already used in insert mode | Verdict |
|---|---|---|---|
| H | `<Left>` | `<Nop>` on purpose (stops Esc+h leak) | Free to take |
| J | `<Down>` | `<Nop>` on purpose | Free to take |
| K | `<Up>` | **Copilot toggle** (`plugins/copilot.lua`, Neovide `<D-k>` mirror) | Conflict |
| L | `<Right>` | **Copilot accept line** | Conflict |
| W | word fwd | **Copilot accept word** | Conflict, use F instead |
| [ / ] | `{` / `}` | **Copilot prev/next suggestion** | Conflict, drop |
| I | – | Signature help | Leave |
| D | delete word | Normal/visual = multi-cursor; insert unmapped | Free |
| F | – | Normal = highlight word; insert unmapped | Free |
| S | save | `<C-s>` already saves in insert | Drop, redundant |
| B E O U R Y X G 0 4 | various | Not translated by Ghostty; Cmd+0/4 are tmux session jumps | Need new Ghostty binds; skip 0/4 |
| Shift+L | – | Normal = VM Select All; insert unmapped | Free in insert |
| Shift+H | – | macOS menu "Hide Ghostty" (moved here earlier) fires first | Unusable |

Also: arrow keys in insert mode start a new undo block and break `.` repeat of the insert. That is the trade-off of any Left/Right approach (`<C-o>` has the same effect).

## Gate status (important)

Both rule sets say no:
- `~/.config/nvim/rules.md`: config freeze until **2026-12-31**; new or rebound keymaps defer by default.
- `~/.dotfiles/CLAUDE.md`: new or rebound keys defer.

Both allow an override if you confirm explicitly after reading the deferral. This would be a non-essential change made by choice, and it counts against the freeze-override tally in `rules.md`.

## Proposed edits (Option A, recommended)

Keep hjkl for movement (matches your goal), move the two Copilot keys to their Shift variants. Readline-style word keys (Cmd+F/B/D match Alt-f/b/d in zsh).

| Cmd+ | Insert action | rhs |
|---|---|---|
| H J K L | char left/down/up/right | `<Left>` `<Down>` `<Up>` `<Right>` |
| F / B | word forward / back | `<S-Right>` / `<S-Left>` (native, no mode flicker) |
| A / E | line start (first non-blank) / end | `<C-o>^` / `<End>` |
| D | delete word forward | `<C-o>dw` |
| Z / Shift+Z | undo / redo | `<C-o>u` / `<C-o><C-r>` |
| Shift+K | Copilot toggle (moved from Cmd+K) | existing function |
| Shift+L | Copilot accept line (moved from Cmd+L) | existing function |

Files touched:
1. `~/.config/nvim/lua/config/keymaps.lua`: replace the `<Nop>` loop for `<M-h>/<M-j>/<M-l>` with the insert maps above.
2. `~/.config/nvim/lua/plugins/copilot.lua`: `<M-k>` → `<M-K>`, `<M-l>` → `<M-L>` (both the `keys` claim and the `map(...)` calls).
3. `~/.config/nvim/lua/config/neovide.lua`: mirror the new maps as `<D-…>` and point the `<D-k>` forwarder at `<M-K>`.
4. `~/.dotfiles/ghostty/config`: add `super+shift+k=esc:K`, `super+b=esc:b`, `super+a=esc:a`, `super+e=esc:e`, `super+z=esc:z`, `super+shift+z=esc:Z`. Cmd+A loses Ghostty's select-all.

Cost: keymaps and Ghostty binds have no runtime cost; no hot path touched. About 30–45 min including a test pass in tmux + Neovide.

Leaks: the new Cmd keys also reach zsh and other panes as Alt keys. Alt-b/f/d are readline word moves (useful); Alt-a/e/z are mostly unbound in zsh emacs mode (unverified, zshrc unreadable).

## Option B (keep Copilot keys as they are)

Use Cmd+Shift+H/J/K/L for movement. Requires moving macOS "Hide Ghostty" off Cmd+Shift+H again, and Shift+hjkl is slower to hit than plain Cmd. Everything else as in A, minus the Copilot moves.
