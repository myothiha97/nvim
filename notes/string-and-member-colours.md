# String, key and member colours (2026-09-24)

Decision record for the session that split strings from object keys and members.

> **STATUS: PARKED WORK IN PROGRESS (evening, 2026-09-24).** No colour pair was
> settled. Live `custom-latest` went back to cyan strings and the `brighter`
> yellow; it keeps only the `brighter` body and the `tinted` file names from this
> day, plus violet imports (made live separately the same evening: a tie with
> the yellow beside cyan paths, but no two-colour keyword runs and a calmer
> import block). Everything below is preserved and loadable: `custom-v4` is the day's final
> custom-latest (green strings, vivid yellow, orange escapes and interpolation,
> violet imports), and `custom-swap` .. `custom-swap-6` are the A/B builds, now
> built from `custom-v4`. Bug fixes from the day stay live: the Lua key query
> (surface 19) and the `@markup.raw` pin (surface 20, only active with green
> strings).
Code comments point here; the numbers live here so the comments can stay short.

Live values are decided by `custom-latest` in
`lua/colorschemes/solarized-osaka/variants.lua`. Read the truth from a running
editor: `:lua =vim.api.nvim_get_hl(0,{name='@string',link=false})`

All separations are dE2000, the smaller of the sRGB and the Ghostty (P3) reading.
Rough scale on small glyphs: under 10 reads as one colour, 15+ is safe.

## What changed

| role | before | after |
| --- | --- | --- |
| strings, every language (`String`, `@string.documentation`, `Character`) | `#29a298` | `#96bc67` (`string.vivid`) |
| object keys (`@variable.member.key`) | linked to `@string` | linked to `@variable.member` (still `#29a298`) |
| member access (`@variable.member`) | `#29a298` | unchanged |
| escapes `\n \t \"` (`@string.escape`) | accent yellow `#baac0d` | literal orange `#ed8e55` (`palette.boolean`) |
| `import` `export` `from` `as` `package` `use` `mod` (`@keyword.import`) | accent yellow | keyword violet `#a17bcc` |
| body text (`Normal`, `@variable`, tag wrappers) | `tinted` `#a0b6b8` | `brighter` `#b1bebf` |
| file/folder names (snacks, oil) | `base0` `#9eabac` | `tinted` `#a0b6b8` |
| interpolation `${}` `{}` (`@punctuation.special`) | accent yellow | literal orange `#ed8e55` |
| accent yellow (punctuation, parameter, fields, JSX tags, builtins) | `brighter` `#baac0d` | `vivid` `#c7b903`, chosen by eye |

Plus one bug fix in `after/queries/lua/highlights.scm`, see below.

## The gap

In TS/JS, a key, a member access and a string were all `#29a298` (dE 0.0), so
`url: 'x'` and `apptId: values.apptId` read as one colour. The reference that
showed the fix was WebStorm's TokyoDark Islands (plugin file
`themes/TokyoDarkIslands.xml`): green strings `#9ece6a`, teal members `#65beb0`,
dE 22.8 apart. Our cyan is already dE 9.3 from that teal, so only strings moved.

## The string value

Stop rule used for every candidate: dE >= 15 from the member cyan, >= 10 from
every other role, not brighter than body text (L* 72.5).

| candidate | Ghostty L* C* h | vs member | worst neighbour | verdict |
| --- | --- | --- | --- | --- |
| `#96bc67` `vivid` | 71.4 55.3 126.8 | 25.2 | 16.4 yellow | **live**. WebStorm's hue and chroma, 6 L* darker |
| `#8eaa67` `tokyodark` | 65.8 44.0 126.0 | 22.5 | 16.8 yellow | ran a few hours; good in TSX, dull in Go |
| `#8ca369` `soft` | 63.7 38.1 125.4 | 21.5 | 17.5 yellow | dE 2.6 from `tokyodark`: invisible, never compare |
| `#9ece6a` TokyoDark as shipped | 77.1 64.8 127.9 | 29.6 | 22.0 | above body text; P3 makes it louder |

**Why `tokyodark` read dull in Go:** measured from screenshots, strings were 9.7%
of the coloured ink in a TSX view but 49.1% in Go, where they became the page's
main colour at the lowest chroma on screen (C* 44 against the other accents'
C* 54). Same hex, different dose.

**`vivid` is the ceiling.** Brighter at the same hue and chroma: +4 L* is dE 3.0
(invisible), +8 L* is dE 5.8 but puts strings 7.3 L* above body text. Other
nearby greens (`#93bd6c`, `#91be65`, `#8dbb63`) are dE 1.3-1.6 away.

**Against popular schemes** (string chroma on each scheme's own background):
Gruvbox 70.4, Carbonfox 65.3, Tokyo Night 55.0, Dracula 54.7, Material 48.5,
**ours 47.4**, Rose Pine 45.5, Kanagawa wave 44.1, One Dark 42.7, Catppuccin 41.3,
Nord 28.8. Upper middle of the pack.

**Scoping tried and dropped:** green only in languages that paint members cyan
(JS/TS/TSX/Lua/Python/Terraform/HCL), cyan elsewhere. Cyan avoided no collision
in Go/YAML/bash, but lost on legibility everywhere: 6.19:1 vs 8.93:1, 12 L*
below body text, 16.4 from types against green's 37.2.

**Rejected: swapping (green members, cyan strings).** Same separation, but
members are the larger role in TS logic files (21.6% of glyphs vs strings 9.0%),
and they sit next to yellow parameters, where green is 16.4 and cyan 35.7.

## Escapes and imports

Both sat on the accent yellow, 16.4 from the new green, right next to strings.

| role | yellow | new | new value's other numbers |
| --- | --- | --- | --- |
| escape inside a string | 16.4 | orange 39.6 | 7.93:1, 22.2 from the error red |
| `from` beside its import path | 16.4 | violet 63.6 | same colour as every other keyword |

- Escapes share the orange with numbers and booleans on purpose: all literals, no
  new hue. Rejected: `copper_mid` (4.64:1, 14.2 from the orange), `terracotta`
  (10.0 from the error red).
- `${}` (`@punctuation.special`) stays yellow: moving it splits bash `${HOME}`
  into orange `${`, yellow `HOME`, orange `}`.
- Violet imports lift keyword ink to 7.4-8.2% of a TS file, past the ~7%
  re-measure mark, but the ink moved from the loudest colour (yellow, C* 92 in
  Ghostty) to a quieter one (C* 52). Catppuccin, One Dark and VS Code do the same.
- Covers TS/TSX (`import export from as require`), JS, Go (`package import`),
  Python (`from import as`), Rust (`use mod as`). Keyword runs such as
  `export default function` and `pub use` are now one colour instead of two.
- Known speck: `import * as X` keeps a yellow `*` (`@character.special`) between
  violet words. 123 of 16,461 import lines in business-portal-js; left alone.
- Rejected: a second, lighter violet for imports (`#bb9af7`, WebStorm's split).
  It is only 10.1 from the keyword violet, a near-miss pair right beside
  `function` in `export function`. Italic already marks `type` and `const`.

## Body text: back to `brighter`

`custom-latest` moved `body` from `tinted` `#a0b6b8` to `brighter` `#b1bebf`. The
2026-09-09 "too bright" verdict on `brighter` was made while strings were the
cyan at L* 60, 12 below body. The green strings rose to body level, so the
balance changed. Perceived lightness (Helmholtz-Kohlrausch, as Ghostty draws it):

| | tinted | base1 `#adb7b7` | brighter |
| --- | --- | --- | --- |
| L* / C* | 72.5 / 8.0 | 73.7 / 3.7 | 76.0 / 4.7 |
| perceived | 73.6 | 74.1 | 76.6 |
| contrast | 9.11:1 | 9.44:1 | 10.13:1 |
| vs file names (`base0`) | 4.1 | 3.7 | 5.3 |
| vs delimiter grey | 11.2 | 12.4 | 13.8 |
| vs type cyan | 15.6 | 19.1 | 18.3 |
| vs module names | 18.7 | 15.8 | 15.2 |
| vs completion menu text | 4.4 | 0.0 | 2.1 |

Accents perceived: string 76.3, type 78.5, yellow 75.8. With `tinted` the body
read dimmer than all three; `brighter` sits level. `base1` is out: identical to
the completion menu text and off the grey axis. The step is only dE 4.1, close
to invisible, so do not test anything between the two.

Against popular themes (body contrast on their own background), `brighter`
ranks 14th of 21 at 10.13:1, just under Tokyo Night (10.59) and above Nightfox
(10.06) and Nord (9.25). `tinted` was 17th. WebStorm's TokyoDark is 18th with
body 5.9 perceived below its strings, so that balance is not a readability
problem on its own.

**File and folder names moved up with it**, `base0` -> `tinted`, so the step
below body stays the approved one. Against the new body: `base0` 5.3 (perceived
gap 6.8, past halfway to the rejected `faded` 8.6), `tinted` 4.1 (3.0, the same
dE step as the approved base0/tinted pair), `midpoint` 2.7 (invisible), `base1`
2.1 (identical to the completion menu text). Hidden entries stay 20.3 away,
floor 12.6. LSP doc prose (`faded`) is the same open question: gap 7.3 -> 9.2.

## Interpolation and the yellow trial

After escapes and imports moved, a census of real files (yellow glyph within 2
spaces or punctuation of a green one) found the last contacts were all
`@punctuation.special`: TS `${}` (7 in `RecurringSlotEditDrawer.tsx`) and Python
f-string `{}` (103 in `palette.py`). Go was already at 0. With the old yellow
escapes and imports the counts would have been: `demo.go` 54 -> 6,
drawer 26 -> 11, TS hook 9 -> 0, JSX footer 3 -> 0. Interpolation moved to the
orange too (39.6 from the green). Known cost: bash `${HOME}` reads orange `${`,
yellow `HOME`, orange `}`.

The yellow then went to `vivid` `#c7b903` as a trial, by choice. Measured before
it: `brighter` sat level with the new body text (perceived -0.8), `vivid` reads
+3.3 above it, which is the 2026-09-08 rejection reason. `vivid` vs green 17.0,
vs body 30.4, vs orange 30.8. Revert: `parameter` and `punctuation` back to
`keyword.brighter` in `variants.lua`.

**Dropped the same day** after side-by-side screenshots (TS templates, Go
structs, Go errors). On screen the two yellows were `#bdab00` vs `#cab800` in P3,
dE 3.7 apart: C* 96 -> 101, L* 69 -> 74. So the visible part of the change was
the orange interpolation, not the yellow; and what the yellow did add was
brightness above body text on the densest accent (Go fields, TS params).

**Then kept after all, by eye.** Recommended `brighter` on the numbers above; the
user preferred `vivid` on real files, on the condition that the difference is
small and costs nothing structural. Both hold: dE 3.7, every neighbour >= 17.0.
The only cost is the +3.3 perceived lift over body text, accepted as a looks
call. Settled: do not re-open the yellow.

## Bug fixed: Lua table values captured as keys

`after/queries/lua/highlights.scm` matched every `(string)` inside a `field`,
values included, so `desc = "Open file"` and positional `{ "folke/x" }` were
tagged `@variable.member.key`. Invisible while keys linked to `@string`; exposed
when keys moved to the member colour. Fixed by matching `name: (string)` only.
Listed as surface 19 in `notes/silent-failure-surfaces.md`.

## External monitor: green and yellow look muddled

Real, but it is pixel density, not the hex. Screenshots from the MacBook XDR
(254 ppi) and the AOC 27G2G3 (81 ppi) carry identical colour values. On the AOC
~55% of every glyph's pixels are blended edges against ~30% on the MacBook, and
the pair converges at the edges:

| part of the glyph | yellow vs green | orange vs green | violet vs green |
| --- | --- | --- | --- |
| core | 23.0 | 53.1 | 74.9 |
| half blended | 16.7 | 36.5 | 39.7 |
| 30% blended | 12.6 | 29.5 | 31.4 |

Do not retune the palette for the external monitor; it would make the MacBook
worse.

## How this was verified

- A treesitter probe per language (`vim.inspect_pos`, last capture with a
  defined fg wins), run first against the broken state to prove it can tell the
  two apart.
- A snapshot of all ~680 highlight groups before and after, diffed.
- Tool caveat: `scripts/palette/census.lua` credits string and comment glyphs to
  a colourless `@spell` capture in Lua, Python and Go, so its numbers there are
  wrong. TS/TSX are unaffected. Not fixed yet.

## A/B build: `custom-swap`

`:lua require("colorschemes.solarized-osaka.variants").load("custom-swap")` (the
A/B builds have no `colors/` entry, to keep them out of the picker) runs custom-v4 with the two warm
accents swapped: punctuation, parameters, Go fields, JSX tags and builtins take
the orange `#ed8e55`; booleans, numbers and constants take the yellow `#c7b903`.
Escapes and interpolation stay orange through their own `escape` role, which
follows `boolean` in every other build, so custom-latest is unchanged (verified
by an identical highlight snapshot).

What the swap trades: the dominant accent drops from C* 100 to C* 66 (Ghostty)
and sits 1.7 below body text instead of 3.3 above, and it moves 39.6 from the
green strings instead of 17.0. The literal colour becomes the loud one, but it
is the low-dose role. Orange is 22.2 from the error red.

`custom-swap-2` is custom-swap with the literals on `member.rose_soft`
`#e197a3`. Best non-yellow literal colour measured next to the orange: vs orange
22.7, error red 26.3, keyword 23.7, green 48.1; zero weak contacts across the
real-file census. Red/salmon (`#fe7f88`) scored similar but sits 20.5 from the
error red; violet, lavender and magenta collide with the keyword violet.

`custom-swap-3` is custom-swap-2 (all orange, edited by hand) with Go fields on
the member cyan `#29a298` (`member.theme_cyan`). Go scores on `demo.go`: all
orange 65.1 (11 merged `Width: 3`), yellow fields 81.5 (rejected on looks: two
warm hues side by side), cyan fields 74.4 (10 field/type contacts at 16.4 in
struct definitions), plain body 93.1 (drops the field marker entirely).

`custom-swap-6` is custom-swap-2 (all orange) for every language, plus Go-only
values through the new `go` role table: cyan strings (`member.theme_cyan`) and
the old `brighter` yellow on parameters, fields and escapes. Go `nil`, numbers
and booleans stay orange; imports stay violet.

Bug found the same day: `@markup.raw` links to `String` in the theme, so doc
code blocks turned green with the strings (Lua hovers). Pinned back to cyan;
surface 20 in `notes/silent-failure-surfaces.md`.
