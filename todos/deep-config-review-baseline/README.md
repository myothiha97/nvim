# Deep review baseline (phase 0, 2026-10-26)

What "unchanged" means, so a later fix can be proven safe. Re-run the same
capture after a fix and `diff` against these files.

- **Neovim:** 0.12.5. **LazyVim:** v16.0.1 (commit `9997009`, same as upstream `main`).
- **Config size:** 14,821 lines in 61 Lua files under `lua/` (14,874 with `init.lua`).
- **Startup, headless, warm, 5 runs:** 47.1 to 49.3 ms. Slowest entry
  `require('config.lazy')` at 20.7 ms self (was 23.7 ms on 2026-09-09).
- **Startup with UI** (`require("lazy").stats().startuptime`): 57 to 75 ms,
  27 to 28 of 57 plugins loaded.
- **Hot-path handlers** after opening a Lua, Go and TS file: `CursorMoved`,
  `CursorMovedI`, `TextChangedI`, `InsertCharPre` = 0 each; `WinScrolled` = 1
  (todo-comments). A control with one injected `CursorMoved` handler reported 1.
- **Clean boot:** `XDG_STATE_HOME=<tmp> XDG_CACHE_HOME=<tmp> nvim --headless '+qa'`
  exits 0 with no output.

## Files

- `highlights.txt`: `nvim_get_hl` for every group (name lowercased) in
  `getcompletion("", "highlight")`, sorted. `lualine_[abcxyz]_<n>_*` groups are
  filtered out (with or without a suffix), because their numbers are allocation counters that shift without
  any colour changing.
- `keymaps.txt`: global (`g`) and buffer-local (`b`) maps for modes
  `n i v x s o t c`, sorted, as `mode scope lhs => rhs | desc`, with `<SNR>` numbers replaced by `N`.

Both were captured from a **non-headless** instance (run under `script` so the
TUI starts and `config/keymaps.lua` loads on `VeryLazy`), with a copy of
`lua/config/keymaps.lua` open as a normal file buffer. That file sat outside git,
so gitsigns buffer-local maps (`]]`, `[[`, `]c`, `ghp`, ...) are **not** in the
buffer-local rows.

## How to re-capture

`capture.lua` opens a file, waits 3 s for `VeryLazy`, writes the two lists and
quits. It reads three env vars: `BASE` (output dir), `SAMPLE` (file to open, keep
it outside the repo so a swap prompt cannot block), `DONE` (marker file).

```sh
BASE=/tmp/after SAMPLE=/tmp/sample.lua DONE=/tmp/done \
  script -q /dev/null nvim -n -c "luafile todos/deep-config-review-baseline/capture.lua" </dev/null
diff todos/deep-config-review-baseline/highlights.txt /tmp/after/highlights.txt
```
