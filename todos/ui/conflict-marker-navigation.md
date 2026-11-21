# Jump between git conflict markers

Status: done (2026-11-20, `lua/config/keymaps.lua`; made by choice on request,
the change gate had deferred it as a new keymap)

Idea: `]x` / `[x` jump to the next / previous `<<<<<<<` conflict marker in any
buffer, not only inside Diffview's merge view.

Before: no key did this in a normal buffer. `/^<<<<<<<` with `n` / `N`, and
Diffview's own `]x` / `[x` in its merge view, were the only ways.

Decisions:

- Plain `vim.fn.search` on key press, no autocmd, so no hot-path cost.
- Respects `'wrapscan'` and a count (`2]x`). The `s` flag sets the `'` mark,
  so `<C-o>` returns to where the jump started. `zv` opens a fold that hides
  the marker, as `/` does.
- Avante and Diffview set `]x` / `[x` buffer-locally, so they still win in
  their own buffers.

Verified in a full UI nvim on an isolated tmux server (headless never loads
`keymaps.lua`): next, previous, count, wrap both ways, fold opened, `<C-o>`,
no-conflict buffer leaves the cursor and notifies. Negative control: with the
map deleted, the same key presses leave the cursor where it was.

Testing trap: mini.pairs pairs `[` in the command line, so a typed
`:nunmap [x` becomes `:nunmap [x]` and fails. Build the key with
`string.char(91)` when driving tests through `send-keys`.
