# Hunk preview colours (`ghp`), tested 2026-11-13

The `ghp` popup marks the changed words inside a changed line. This note records
every colour tried for those marks, so the choice can be revisited without
re-testing.

The code lives in `lua/colorschemes/solarized-osaka/init.lua`, in the GitSigns
block of `on_highlights`. Switch between the two kept variants with
`GITSIGNS_WORDS` at the top of that file (`"dark"` or `"bright"`), then restart
nvim.

## Groups involved

| Group | What it paints | Default |
| --- | --- | --- |
| `GitSignsDeletePreview` | whole deleted line | links `DiffDelete`, `red950` `#380605` |
| `GitSignsAddPreview` | whole added line | links `DiffAdd`, `cyan900` `#103a3c` |
| `GitSignsDeleteInline` | changed words on the deleted line | `reverse = true` |
| `GitSignsAddInline` | changed words on the added line | `reverse = true` |

`DiffAdd` / `DiffDelete` are never changed here: they also drive vimdiff and
other diff views. Only the `GitSigns*Preview` / `*Inline` groups are touched.

## How to read the numbers

- **Contrast**: WCAG ratio of the text colour on the band. 4.5:1 is the usual
  readability target, 3:1 the floor.
- **L\***: lightness, 0 = black, 100 = white. The editor background is about 7.7.
- **Chroma**: how much colour a band carries. Higher reads as more vivid.
- **dE**: CIEDE2000 colour difference. About 2 is the smallest visible step.
  "Word vs line" is how far the changed words stand out from their line band.

Measured against `Normal` bg `#171716` and the live syntax colours on
2026-11-13. Weakest code colours are keyword `#a17bcc` and operator `#7f9195`.

## Every variant tried

| # | Deleted words | Added line | Added words | Result |
| --- | --- | --- | --- | --- |
| 0 | `reverse` | `#103a3c` | `reverse` | gitsigns default. Very visible, but one block per token in its own syntax colour (orange, grey, blue...) at L* 58-78: noisy and glaring |
| 1 | `#570f0e` (`red900`) | `#103a3c` | `#1a6265` (`cyan700`) | body text only 3.7:1 on the added words. Dropped |
| 2 | `#570f0e` | `#103a3c` | `#154e51` (cyan700/900 mix) | keyword 2.8:1, operator 2.9:1. Added words L* 29.9 vs deleted 17.5: lopsided |
| A | `#570f0e` | `#031b1c` (darkened `cyan950`) | `#0b3032` | mirrors the red side's lightness, keyword 4.2:1. Added LINE too faint against the editor |
| B | `#570f0e` | `#042122` (`cyan950`) | `#0d3436` | line OK, keyword 4.0:1. Added WORDS faded: word vs line dE 5.9 |
| **Dark** | `#570f0e` | `#042122` | `#0e3606` (true green) | **PRIMARY.** Word vs line dE 19.5 (red side 7.7). Keyword 4.0:1, body 7.1:1. Syntax colours kept |
| Bright (pink) | `#f7768e` + dark text | `#042122` | `#9ece6a` + dark text | dark text 6.8:1, but the red read as pink. Dropped |
| **Bright** | `#ff6b6b` + dark text | `#042122` | `#9ece6a` + dark text | **BACKUP.** As visible as the default without its colour mix. Dark text 6.5:1 (red) / 9.8:1 (green). Changed words lose syntax colours; blocks glare (L* 64-78) |

Considered but not built:

- Lighter teal word band `#093e3a`: dE 10 from its line, but keyword drops to 3.5:1.
- Underline or bold on the changed words, bands unchanged: no contrast cost, but
  subtler than a colour band.

## Why the add side is green, not teal

At the darkness these bands need (L* ~19), teal can carry very little colour:
the most saturated teal reaches chroma ~13-20, against ~38 for the red word band.
So a teal word band always looked fainter than the red one. A true green
(hue ~110) at the same lightness reaches chroma ~34, so it reads as strongly as
the red without any loss of text contrast.

The theme's own green ramp is olive (hue 68, the `DiffText` band), which is why
the green is a hard-coded hex.

## Why the bright red is `#ff6b6b`, not the theme red

The theme's `red500` `#db302d` is too dark for dark text on top (3.8:1). The
first lighter red tried, `#f7768e`, leans pink. `#ff6b6b` is a true red at about
the same brightness as the green block (L* 64 vs 78), with dark text at 6.5:1.

## Stop rule

Both kept variants are measured and settled. Retune only if a code colour falls
below 4.0:1 on a dark word band, or below 4.5:1 for the dark text on a bright
block.
