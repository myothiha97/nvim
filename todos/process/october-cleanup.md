# October cleanup: dead code, stale comments, trials

Status: open. Filed 2026-10-24 from the October review. Do at the 2026-12-31
checkpoint. Zero behaviour change except where a line says otherwise.

## Dead code
- `lua/plugins/indent-blank-line.lua` (disabled) and its `lazy-lock.json` entry
- `lua/plugins/rainbow-delimiters.lua` (disabled, parked in `todos/theme/`)
- `lua/plugins/folding.lua`: commented `fold_virt_text_handler`
- `lua/plugins/snacks.lua`: `scroll.animate` under `enabled = false`, empty `icons = {}`
- `lua/config/picker-size.lua`: `compact` no longer used
- `colorschemes/solarized-osaka/init.lua`: unused locals `olive_color`, `tokyodark`,
  `vivid_bush_green`; `@variable.parameter.go` set inside the loop on every pass
- `lua/config/ui.lua` + `init.lua`: `bg_statusline` likely does nothing (see CLAUDE.md trap)

## Noise and typos (keep palette history comments, see memory rule)
- `palette.lua`: pasted Gemini rationale; typos `tokyonitght`, `collor`, `daker`
- `variants.lua`: `field` really means "Go parameter colour"

## Stale comments
- `variants.lua`: "Go overrides members to Cyan #73daca"; "No red variant beat it"
- `keymaps.lua`: "turn on below lines if u dont use snacks scroll animation"
- `CLAUDE.md`: syntax palette table (yellow warm side) no longer matches live values

## Stale todos
- `theme/rainbow-brackets-and-operator-colours.md`: says plugin file is uncommitted
- `theme/palette-checkpoint-ideas.md`: parameter is coral now, not `_2` yellow
- `ui/markdown-preview-improvements.md`: "Until then, run it by hand" line
- `ui/nvim-smooth-scrolling.md`: `<C-b>` line number moved (~358)

## Trials committed as live: keep or revert
- `scroll_depth = 1`, mouse hover `DELAY_MS = 1000`, picker `standard` size,
  noice cmdline on, bg `#131312` + completion menu bg, float border, Oct 21-22 colours

## Process
- Root `CLAUDE.md` untracked since 2026-10-09: decide on a backup
