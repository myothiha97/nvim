# File-tree icon legibility (`<leader>r`)

Raised 2026-08-22. **Built, rejected on sight, reverted the same session.** Kept
here for the measurements, which are the expensive part and are worth not
redoing. Reference the user pointed at: Zed's file tree.

## Status

- Nothing is in the config. `lua/config/snacks-file-tree.lua` was written and
  deleted; the two hooks in `lua/plugins/snacks.lua` were reverted to HEAD.
- The complaint stands: folder and file icons in the `<leader>r` tree read as
  too small to scan and track.
- The build was verified working (scoping, per-row cost, glyph swaps all
  confirmed) and then judged **not good** visually. So the open question is not
  "does the mechanism work" but "is a glyph swap the right answer at all".

## Root cause, measured

Maple Mono NF (the Ghostty font), unitsPerEm 1000, cell advance 600, cap height
750, x-height 570.

Every nerd-font glyph in this font is patched to a **single-cell advance (600)**,
but the ink of most of them is **750-1000 units wide**. The terminal fits a glyph
inside one cell, so it scales the whole thing by `600 / ink_width`. The icons are
**width-constrained**, and the height you see is collateral damage.

Rendered ink height of the glyphs mini.icons hands this tree:

| target | codepoint | rendered | note |
| --- | --- | --- | --- |
| `.go` | U+F07D3 | 224 | 39% of x-height |
| `.md` | U+F0354 | 361 | |
| `.mod` | U+F0AFA | 418 | |
| `Dockerfile` | U+F0868 | 431 | |
| `.json` | U+F0626 | 450 | |
| directory | U+F024B | 482 | |
| open directory | U+F0770 | 454 | snacks `icons.files.dir_open` |
| `.tsx` / `.jsx` | U+E7BA / U+E625 | 536 | |
| `.ts` `.py` `.js` `.lua` | | 600 | |
| `.tf` `.sql` `.html` | | 672-682 | |
| dotfiles | U+F0214 | 747 | |
| `.sh` `.yaml` `LICENSE` | U+E691 / U+E6A8 / U+E60A | 879-880 | above cap height |

The absolute size is only half of it. The **4x spread** is the other half: the
eye cannot use icon shape as an anchor when a Go file's mark is a third the size
of a shell script's.

## What was built, and can be rebuilt in ~20 minutes

A per-row pass over the four glyphs measured below 500, swapping each for a
same-meaning glyph whose ink is narrow enough to survive the fit, plus one extra
cell between the icon and the filename:

| file | old | new | rendered |
| --- | --- | --- | --- |
| `.go` | U+F07D3 | U+E627 gopher | 224 -> 809 |
| `.md` | U+F0354 | U+F0219 document | 361 -> 747 |
| `.mod` | U+F0AFA | U+EBD3 layers | 418 -> 626 |
| `.json` | U+F0626 | U+E60B braces | 450 -> 626 |

Stop rule it carried, so the table could not grow on vibes: substitute only a
glyph rendering **below 500**, only for a replacement landing in **560-820**.
Keyed on the glyph and not on the filetype, so a file whose icon is already in
band keeps it (`README.md` resolves to U+F4ED at 600, not the `.md` badge).

Likely reasons it read badly, for whoever picks this up: the gopher at 809 is
*taller than cap height*, so `.go` rows sat heavier than their neighbours; and
swapping four filetypes while leaving folders, Docker, yaml and sh alone made
the spread **less** uniform in the middle of the list, not more. If this is
retried, the honest options are all-or-nothing: normalise **every** glyph into
560-750 including pulling the 880s down, or leave the glyphs alone entirely.

## Measured and rejected

- **Folders.** Every folder glyph in the font is ink-wide, so they all land
  454-535. Best closed is U+F4D4 at 535 against the current 482 (**+11%**), best
  open is U+E5FE at 488 against 454 (**+7%**). Both under the threshold worth a
  config line.
- **Dockerfile.** Every docker whale in the font is 385-431; there is no tall
  one. U+F0AC7 (hexagon and cube, 666) fits the band but stops reading as
  docker, and a repo has one Dockerfile.
- **`adjust-icon-height` in Ghostty.** Raises the height ceiling. These glyphs
  are constrained by **width**, so it does nothing here. Verified against the
  option's own docs (Ghostty 1.3.1).

## The one lever that actually changes icon SIZE

The cell is the ceiling, and the cell is the font size. Nothing inside Neovim
can exceed it. The real fix is to stop using a mono-patched nerd font for the
icon range, in `~/.config/ghostty/config`:

```
font-codepoint-map = U+E000-U+F8FF,U+F0000-U+FFFFD=FiraCode Nerd Font
```

`FiraCode Nerd Font` (already installed, the non-Mono variant) patches icons at
~1.5 cells, so they are not shrunk to fit. **This is global to every terminal
app and every plugin's icons**, which is why it was not done: the ask was
explicitly scoped to the `<leader>r` tree. It is also the option most likely to
actually satisfy the complaint, so it should be evaluated on its own terms
rather than as a fallback. Test it in a scratch Ghostty config first.

Cheaper variant worth trying at the same time: bump `font-size` from 12.5. Also
global, also affects text, but it is one number and instantly reversible.

## Implementation note worth keeping

`<leader>e` (`lua/plugins/snacks-file-browser.lua`) opens through
`Snacks.explorer.open` -> `Snacks.picker.explorer`, so it runs on the **same
`explorer` source** and inherits anything set under `picker.sources.explorer`.
Confirmed by reading the merge order in
`snacks.nvim/lua/snacks/picker/config/init.lua:60-72`: defaults, user, source,
then per-call opts, later winning.

So tree-only UI changes cannot be configuration. `formatters.file.icon_width`
or `icons.files.dir` would reach the browser too. The way that worked was a pass
called by hand from the sidebar's own `format` in `snacks.lua`, because the
browser passes its own per-call `format`, which replaces the source's outright.
Verified: sidebar got the tuned function, browser kept `format == its own`, the
`files` picker stayed on the string `"file"`, `icon_width` stayed 2 everywhere.

## Gate

Aesthetic polish, non-blocking, inside the freeze window. Deferred by the
change-gate; the build itself was a signed override on 2026-08-22 and is now
reverted. Do not reopen this before the next freeze checkpoint, and when it is
reopened, start with the Ghostty font question, not with glyph tables.
