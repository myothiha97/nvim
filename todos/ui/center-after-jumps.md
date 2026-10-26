# Centre the screen after `]c`/`[c` and `n`/`N`

Status: open. Filed 2026-10-26 by the change gate (keymap preference, not blocking).

**Idea:** add `zz` after hunk jumps (`]c`/`[c`) and search jumps (`n`/`N`), the
same way `<C-d>`/`<C-u>`/`<C-f>`/`<C-b>` already recentre in `lua/config/keymaps.lua`.

**Notes for when it is done (~15 min):**

- `n`/`N`: LazyVim maps them as expr `'Nn'[v:searchforward].'zv'`. Keep the
  fold-opening `zv` and the search-direction fix. **Centre only when the match
  was off-screen** (compare the new `line(".")` with the old `line("w0")`/`line("w$")`):
  an unconditional `zz` scrolls the whole screen even when the next match is
  5 lines down, so `n n n` through nearby matches keeps jumping the text.
- Gain is modest: `scrolloff = 12` already keeps 12 lines of context around any
  jump target; `zz` only moves it from ~12 lines off the edge to the middle.
- `]c`/`[c` (`lua/plugins/git.lua`, `next_hunk`/`prev_hunk`): `gs.nav_hunk` is
  async, so a `zz` right after the call runs before the cursor moves. Use the
  callback form `gs.nav_hunk("next", {}, function() vim.cmd("normal! zz") end)`.
  Inside a diff split, append `zz` to the `normal! ]c` branch instead.
- Leave the buffer-local `n`/`N` in the `ghp` hunk preview alone; they are hunk
  moves, not search.
