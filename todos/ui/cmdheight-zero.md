# Remove the blank row between the nvim statusline and the tmux bar

Filed 2026-11-13. Status: record (decided: keep the gap).

The blank row is Neovim's command line (`cmdheight = 1`, the default). Setting
`vim.o.cmdheight = 0` removes it.

Check before doing it: noice has `messages = { enabled = false }`
(`lua/plugins/performance.lua`), so with `cmdheight = 0` ordinary messages
(`:w` "written", errors, `recording @q`) may turn into "Press ENTER" prompts.
Either enable noice messages or confirm Neovim 0.12 handles them without the
prompt, then test `:w`, an error message, a macro recording and `/` search.

## Tested 2026-11-13: kept the gap

With `cmdheight = 0` and noice messages off: `:w` shows nothing, `print()` and
errors stop at "Press ENTER", and `qq` shows no "recording @q". Decided to keep
`cmdheight = 1`. Only revisit together with turning noice messages back on.
