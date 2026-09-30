## Goal

- `Ctrl+Space` then `h/j/k/l` moves focus across nvim splits AND tmux panes as
  one grid, so the same keys work everywhere.
- Filed 2026-09-30. Estimate: 30-45 min including a live test.

## Why it needs a bridge

- `Ctrl+Space` is the tmux prefix (`~/.tmux.conf` -> `~/.dotfiles/tmux/.tmux.conf`),
  so tmux eats it and nvim never sees it.
- Today `prefix + h/j/k/l` is plain `select-pane`, and nvim uses `<C-h/j/k/l>`.

## Plan

1. tmux: make `prefix + h/j/k/l` check whether the pane runs nvim
   (the usual `ps -o state= -o comm= -t '#{pane_tty}'` check). Not nvim:
   `select-pane` as now. nvim: forward a spare key, e.g. `C-M-h`.
2. nvim: map the spare keys (`<C-M-h/j/k/l>`) in n, i, v and t modes to one
   small function: `wincmd <dir>`, and if the window did not change and `$TMUX`
   is set, run `tmux select-pane -L/-D/-U/-R`.
3. Keep `<C-h/j/k/l>` inside nvim as they are.

## Traps to check

- Do NOT forward `<C-h/j/k/l>` themselves: in insert mode `<C-j>` is Copilot,
  `<C-l>` is blink accept, and snacks/oil bind `<C-l>` too.
- tmux has `extended-keys on`; confirm `send-keys C-M-h` arrives in nvim as
  `<C-M-h>` (check with `:echo getcharstr()`), not as `<Esc><C-h>`.
- Ghostty owns `super+ctrl+l` globally (quick terminal), unrelated here but
  do not pick Cmd-based keys.
- Test the edge case: at the leftmost nvim split, `h` must hop to the tmux pane.
