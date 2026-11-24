# Indent guide and matching-bracket colours, tested 2026-11-20

Colours for the indent guides (indent-blankline) and the matching-bracket box
(`lua/config/bracket-match.lua`). This note records every value tried, so the
choice can be revisited without re-testing.

The highlights are set in the `init` of `lua/plugins/indent-blank-line.lua`.
The values are read by role from `surface` in `lua/config/ui.lua`, so they move
with the background. None of them are syntax colours, so none live in
`palette.lua`.

## Groups involved

| Group | What it paints | Role | Value |
| --- | --- | --- | --- |
| `IblIndent` | idle indent guides | `surface.raised` | `#2c2c2b` |
| `IblScope` | the active scope's guide | `surface.guide_active` (new, `lift(bg, 0.26)`) | `#535353` |
| `MatchParen` | the bracket under the cursor and its pair | `surface.guide` as `bg`, `bold`, no `fg` | `#434342` |

`MatchParen` sets no `fg`, so the bracket keeps its syntax colour inside the box.

## How to read the numbers

- **Contrast**: WCAG ratio. For a guide or box it is against the background; for
  "bracket on box" it is the bracket text on the box. 4.5:1 is the usual text
  target, 3:1 the floor.
- **L\***: lightness, 0 = black, 100 = white.

Measured against `Normal` bg `#171716` (L\* 7.7). Comments `#5f767d` sit at
3.74:1, L\* 48: guides must stay well under that or they compete with text.

## Indent guides

| Idle | Active | Result |
| --- | --- | --- |
| `#2c323c` (1.39:1) | `#4b5263` (2.29:1) | old fixed hexes from a onedark-era setup, not tied to the background. Replaced |
| `#2c2c2b` raised (1.28:1, L\* 18) | `#434342` guide (1.81:1, L\* 28) | first role-based pair. Active read too faint beside the idle guides |
| `#2c2c2b` raised | **`#535353` guide_active (2.33:1, L\* 35)** | **chosen**. 17 L\* gap to idle, 13 under comments |

Active ladder on `lift(bg, n)`, for later tuning:

| n | value | contrast | L\* | note |
| --- | --- | --- | --- | --- |
| 0.19 | `#434342` | 1.81:1 | 28.4 | too faint |
| 0.24 | `#4f4f4e` | 2.19:1 | 33.6 | the scrollbar `thumb_hover` value |
| **0.26** | **`#535353`** | **2.33:1** | **35.3** | **live** |
| 0.28 | `#585857` | 2.52:1 | 37.4 | |
| 0.30 | `#5d5d5c` | 2.72:1 | 39.5 | **ceiling**: keep at least ~9 L\* under comments |

## Matching-bracket box (`MatchParen`)

Bracket colour at decision time: `kanagawa_mid` `#96abd3` (7.74:1 on the
background). The earlier grey `#7f9195` is listed for comparison.

| Box | Box vs bg | `kanagawa_mid` on box | `#7f9195` on box | Result |
| --- | --- | --- | --- | --- |
| theme default: `fg #ffa099` on `bg #db302d` | n/a | n/a | n/a | white on alarm red, the same red as errors. Rejected |
| `#333332` selection (0.12) | 1.42:1 | 5.46:1 | 3.85:1 | box too close to the background |
| `#3c3c3b` (0.16) | 1.62:1 | 4.77:1 | 3.36:1 | **fallback** if the box feels heavy |
| **`#434342` guide (0.19)** | **1.81:1** | **4.27:1** | 3.01:1 | **chosen** |
| `#4a4a49` (0.22) | 2.02:1 | 3.83:1 | 2.70:1 | |
| `#535353` (0.26) | 2.33:1 | 3.32:1 | 2.34:1 | rejected: lowers bracket readability, and equals the active guide colour so the two blur |

Re-checked 2026-11-25 with the bracket colour `bracket.pale_yellow_dim`
`#a9a88b`: 4.08:1 on the chosen `#434342` box, so the box needs no change.

A brighter box always lowers the bracket's contrast inside it. If it feels too
faint, add `underline` rather than raising the box.

Checked against the other background highlights, so a matched bracket is never
mistaken for one of them: Visual `#24275a` (navy), LSP references `#541131`
(maroon), CurSearch `#c94c16` (orange), CursorLine (no background).
