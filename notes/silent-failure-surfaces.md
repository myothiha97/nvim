# Silent-failure surfaces in this config

Places where a wrong value **does nothing** instead of raising an error. Every one
of these was hit for real on 2026-09-04/05, and each cost time precisely because
nothing complained — the config looked correct and simply did not work.

Each site carries a `-- WARN: SILENT FAILURE` comment in the code. To list them
all: `:TodoLocList keywords=WARN`, or `rg "WARN: SILENT" lua/`.

## Why this file exists

A normal bug announces itself. These do not. The failure modes below share one
shape: **a name or a value is accepted, stored, and then ignored.** So the usual
loop — change it, look, move on — reports success while the change has no effect.

Two consequences worth internalising:

- **A clean test result proves nothing here unless the test can also detect the
  broken state.** Several checks during that session reported "working" for both
  the fixed and the broken config. Always run the check once against a
  deliberately broken version first; if it cannot tell them apart, it is useless.
- **Prefer reading the value the code actually consults at runtime** (e.g.
  `win.opts.actions`) over a module that merely looks authoritative
  (e.g. `snacks.picker.actions`).

## The surfaces

### 1. Unresolved picker action names are TYPED as keystrokes
`Snacks.win:action()` looks in `win.opts.actions`, then for a `Snacks.win` method,
and **otherwise returns the name — which is then fed back as keys.** A typo in an
action name therefore does nothing visible, and never errors.
*File:* `lua/plugins/snacks.lua`

### 2. An action name matching a snacks built-in REPLACES it, everywhere
Defining `list_scroll_down` in the picker-wide `actions` table silently replaced
snacks' own, turning `<C-d>`/`<C-u>` from a page scroll into a one-line scroll in
**every** picker. Check new names against `snacks/picker/actions.lua` (68 built-ins)
and `snacks/explorer/actions.lua`.
*File:* `lua/plugins/snacks.lua`

### 3. Spelling out a layout `box` REPLACES the preset
Snacks skips preset resolution once `layout.layout[1]` exists. Every override the
preset carried is dropped without warning. This is how the explorer picked up
`preview = "main"` from the sidebar preset instead of the explorer source's
`preview = false`, and started loading a file into the right pane on every `j`/`k`.
*File:* `lua/plugins/snacks.lua`

### 4. `win.<name>.wo` loses to snacks' own defaults
Snacks builds each window as `Snacks.win.resolve(opts.win.<name>, { ...defaults })`
and the DEFAULTS win. A `winhighlight` set there is discarded silently. It must go
on the **layout box entry** instead.
*File:* `lua/plugins/snacks.lua`

### 5. Writes to `win.opts` in `on_show` are undone
`snacks/layout.lua:update_win` snapshots `win.opts` when it adopts a window and
restores that snapshot on every update. Anything assigned in `on_show` is reverted
on the next redraw.
*File:* `lua/plugins/snacks.lua`

### 6. A picker has TWO windows; list keys are unreachable from the input
After typing a filter, focus sits in the input. Snacks binds `j`/`k` there but not
`h`/`l`, so the tree walked while `h`/`l` moved the prompt's text cursor. Bind tree
keys on **both** windows, normal mode only, so filtering still types the letters.
*File:* `lua/plugins/snacks.lua`

### 7. Native `<C-e>`/`<C-y>` are inert in a picker list
A picker list is **virtually scrolled** — the buffer holds only the visible rows
and `list.top` maps a row to an item, so there is no text below the last line to
scroll to. The keys are not swallowed; they have nothing to move. Bind them to
`list:scroll()`, which is what the mouse wheel already calls.
*File:* `lua/plugins/snacks.lua`

### 8. lazy.nvim keeps only the LAST fragment's `init` / `config` / `enabled`
Fragments of one plugin are chained through `__index`, ordered by module name.
`snacks-file-browser.lua` sorts after `snacks.lua`, so its `init` killed
snacks.lua's outright — no `SnacksPickerMatch`, indent guides stuck on the theme's
colour, and `SnacksExplorerActiveFile` undefined, for two weeks. An `init` that
merely returns early **still wins the lookup**; the key must be ABSENT
(`init = FLAG and function() … end or nil`). `enabled = false` in a second
fragment disables the whole plugin.
*Files:* `lua/plugins/snacks-file-browser.lua`, `lua/plugins/snacks.lua`

### 9. A backdrop above another float HIDES it rather than dimming it
`winblend` does not composite over a lower FLOAT the way it does over a split. At
zindex 40 the oil backdrop blanked the snacks explorer sidebar — measured, its text
pixels fell from 14.8% of the region to 0.8%. Kept at 40 deliberately (the
full-screen dim is wanted); 30 fixes the sidebar but loses the dim.
*File:* `lua/plugins/oil.lua`

### 10. Oil re-applies `float.win_options` on every navigation
Anything per-directory placed there is overwritten. Constants are fine; the path
label is not.
*File:* `lua/plugins/oil.lua`

### 11. Oil applies the top-level `win_options` AFTER the float's
So a value set only in `float.win_options` is silently overwritten.
`OIL_WINHIGHLIGHT` must be in both.
*File:* `lua/plugins/oil.lua`

### 12. `virt_lines_above` on the FIRST buffer line is never drawn
Neovim does not render it, yet `nvim_win_text_height` counts it — so the extmark
looks applied and even measures correctly while showing nothing. Same limitation
gitsigns hits with deleted-line markers at the top of a file. Use a `winbar` row.
*File:* `lua/plugins/oil.lua`

### 13. `transparent` defaults to `true` inside the colorscheme
Deleting or commenting out `transparent = false` re-enables transparency rather
than disabling it. It must be an explicit `false`.
*File:* `lua/colorschemes/solarized-osaka/init.lua`

### 14. `bg_popup` is not the key `Pmenu` reads
The theme writes `Pmenu = { bg = c.base02 }` directly, so overriding `bg_popup` in
`on_colors` changes nothing. The completion menu is actually moved by this repo's
own `on_highlights`. Likewise `bg_statusline` is not the StatusLine/WinBar key.
*File:* `lua/colorschemes/solarized-osaka/init.lua`

## Related

- Structural traps and the parked-plugin rule: repo-root `CLAUDE.md`
- Backdrop measurements: `notes/popup-backdrop-darkening-investigation.md`
- Background ladder and its measured constraints: `lua/config/ui.lua`
