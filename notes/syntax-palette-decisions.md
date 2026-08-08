# Syntax palette: decisions and measurements

Reasoning behind the values in `lua/colorschemes/solarized-osaka-palette.lua`.
It lives here rather than in the Lua file so the config stays readable — that
file is a data table, not a document.

Read this before changing a colour. Most obvious ideas have already been tried,
measured, and rejected for a recorded reason.

## Method

- Measure against **Ghostty's `#031219`**, not nvim's `#001419`. `transparent =
  true` leaves `Normal` bg = `NONE`, so the terminal's colour is what shows.
- Score candidates with **dE2000 against the whole palette**, never by eye alone.
  Under 10 is confusable on small glyphs, 10–20 is distinguishable but tiring,
  over 20 is unambiguous.
- Judge in **every language you use**. Binding neighbours differ: TSX is
  property-dense, Go and Python are string-dense, Lua is keyword- and
  operator-dense.

## Four rules that keep being relearned

1. **Two roles must not share a hue band.** Every collision in this palette
   turned out to be two roles within a few degrees of hue, split by lightness
   alone. Lightness is the axis this setup reads worst and the one Ghostty's
   rasterizer erodes.
2. **Tune hue and chroma, not lightness.** Lightness-only moves on text glyphs
   fall under the ~5 L\* perceptual floor and return no signal. One hex step is
   0.28 L\*, about 18× below that floor.
3. **Frequency is inversely related to brightness.** A colour on nearly every
   line cannot also be the brightest thing on screen. Types can sit at L\* 80
   because they are rare landmarks; properties and keywords cannot.
4. **When a colour looks right in some files and wrong in others, the value is
   not the variable — coverage is.** Dimming the hex makes the good files worse
   to fix the bad ones. Move the role instead.

## Keyword colour (2026-08-08, reopened 2026-08-09 — still open)

**Current value is `#849900` olive, and it is provisional.** The olive/yellow
call is parked as a todo in `todos/syntax-palette-followups.md`; do not treat
either value as settled and do not silently move it back.

The 2026-08-09 reversal: the yellow is good in ordinary files and only reads
*loud* where keywords cluster densely. That is rules 3 and 4 landing on the
keyword role itself — a role on nearly every line cannot be the brightest thing
on screen, and when a colour works in some files and not others the variable is
coverage, not the value.

The lever is lightness, not saturation. Chroma is 67.0 (olive) against 67.4
(yellow), which is far under the perceptual floor, so the entire difference is
L\* 59.6 vs 65.4 plus 13 degrees of hue. Contrast falls 7.16:1 → 5.92:1, both
clear of the WCAG AA 4.5 floor. This is the one place rule 2 does not apply:
between these two candidates lightness *is* the axis carrying the difference,
because a 5.8 L\* gap clears the ~5 floor that rule 2 warns about.

The original 2026-08-08 pass landed on `#aea10c` (hue 98, L\* 65.4, C\* 67.4,
7.16:1) after four rejections:

| value | hue | L\* | C\* | verdict |
| --- | --- | --- | --- | --- |
| `#849900` | 111 | 59.6 | 67 | "gold/yellowish", disliked — **reinstated 2026-08-09** |
| `#8c9644` | 111 | 59.7 | 44 | "too fade" |
| `#5da100` | 125 | 59.7 | 75 | "dracula green, ugly" |
| `#b99004` | 86 | 61.9 | 66 | excluded by hand — the theme's own gold |

Two findings worth keeping:

- **Chroma is read as presence here, not as glare.** The 2026-07-22 benchmark
  concluded high chroma on near-black is what glares, and that is true for the
  palette in aggregate — but lowering *this* colour's chroma just removed the
  thing that made it register. Do not retry that axis downward.
- **Every reject sat at L\* 59.6**, which is why none of them read as yellow at
  all. Yellow is the one hue that only reads as itself when it is light; below
  about L\* 62 it is khaki. Going to L\* 65 also buys ~7 points of chroma from
  the gamut, so brightness and saturation move together rather than trading.

The green→yellow move only became possible on 2026-08-07. The old note said
green could not move because it collided with yellow; `Type` moved to cyan and
`@tag.tsx` to terracotta, so nothing was left painting yellow and the constraint
was void. **Rejections are only valid against the palette that existed when they
were made** — this is why they carry dates.

## Operators are not keywords (2026-08-08)

The theme paints `Operator` with `green500`, the same colour as keywords, so
every `=` and `..` counted as a keyword. Measured coverage of the keyword colour
by treesitter capture:

| file | real keywords | symbolic operators | total |
| --- | --- | --- | --- |
| `ai-prompts.lua` | 5.4% | 2.1% | **8.0%** |
| `solarized-osaka.lua` | 0.2% | 0.5% | **0.7%** |

An 11× spread between two Lua files in the same repo, with the same colour — the
variation was density, not value. Symbolic operators were 26% of it in the dense
file and 74% in the config-style one, because every `key = value` line pays for
one. Dropping them to `base0` cuts the dense file to 5.9% and flattens the
difference between files instead of dimming the colour everywhere.

`and`, `or` and `not` are restored to the keyword colour explicitly: they are
keywords spelled as operators, and they chain `@keyword.operator → @operator →
Operator`, so they would otherwise go neutral with the `=` signs.

## Type colour (2026-08-07)

`#7dcfff` (hue 249, L\* 79.7, 11.08:1). Moved off the theme's `Type = yellow500`
because every type in Go/TS/Python read as gold.

This is *not* the type colour in either Tokyo Night — it is `Keyword` in
tokyonight.nvim. Their real type colours measure tighter here because this
background is darker and cyan-tinted rather than navy: `#2ac3de` scored 15.2
from function and 16.4 from string, `#0db9d7` scored 11.9 from `#7dcfff`.

Known weak pair: `Type` and `Function` sit at hue 249 and 250, split by 20.6 L\*,
dE2000 **16.2**. That is rule 1 being broken knowingly. It also means Function
cannot be brightened without collapsing into Type — measured, L\* 71 drops the
pair to 6.5.

## Fields and properties — currently off

The overrides are commented out in `solarized-osaka.lua`, so `@variable.member`
uses the theme's `cyan500` (identical to `String`) and `@property` uses
`blue500` (identical to `Function`). Both are exact duplicates at dE2000 0.0.
That is deliberate as of 2026-08-09; re-enabling is a two-line uncomment.

`@variable.member` briefly carried the rose below and it was removed on
2026-08-09: rose won on measurement but had never been judged on looks the way
the other roles were, and it did not hold up in large files. Living with the
key-vs-value collision was preferred to keeping it. Rule 4 again — the value was
not the problem, the coverage was.

Candidates measured on 2026-08-07/08, if it is ever reopened:

| value | hue | L\* | note |
| --- | --- | --- | --- |
| `#b67faf` rose | 330 | 60.1 | peer of the accent band, worst neighbour 21.4 |
| `#73daca` teal | 182 | 80.8 | what both Tokyo Nights use; 5° from string cyan, dE 15.7 |
| `#9b9fec` violet | 293 | 67.9 | reads as a near neighbour of the blue family |

The teal is the instructive one. It kept winning on looks and failing on
measurement, and the reason was rule 1, not brightness: at hue 182 it is five
degrees from string cyan, so its entire separation was the lightness gap. A mint
at hue 150 — brighter still, at L\* 82 — did not read as drowning anything.
"Too bright" was a hue collision wearing a disguise.

Making the teal work needs strings out of the cyan band, and that cascades:
green strings then collide with the olive keyword (dE 16.6), because Tokyo Night
only gets away with green strings by having a *purple* keyword (dE 67.4 from its
string, against 16.6 here). Adopting tokyonight's layout wholesale measures worse
than the current one — 11.1 Keyword/Type, 14.8 Keyword/Function — because it
packs five roles into one blue-cyan band. Borrow its colours, not its layout.

That whole exploration is parked in a git stash from 2026-08-08 if it is ever
worth revisiting.

## Green and yellow (2026-07-22, now historical)

The old palette's green `#849900` and yellow `#aea10c` collided at dE2000 9.9 and
that was accepted knowingly, because nothing that separated cleanly looked as
good. It is moot now: yellow no longer paints anything, and `#aea10c` became the
keyword colour itself.

Kept for one reusable finding: **green reads on hue, not chroma.** Below ~122 it
reads warm olive, above ~130 it reads vivid kelly green, and dropping chroma does
not undo that — `clover` at C\* 53.8 read too bright while `solarized` at C\* 66.9
read calm. Confirmed again on 2026-08-08 when hue 125 at C\* 75 was rejected as
"dracula green".

## The one sub-AA colour

`@variable.parameter` terracotta `#b55f4a` sits at **4.26:1**, under the WCAG AA
4.5 floor, and dE2000 **10.1** from the error red — the tightest pair in the
palette, and the thing the "keep punctuation red clear of diagnostics" rule was
written about. `#f7768e` (tokyonight's red) measures 7.19:1 and 21.3, fixing both
at once. Untried in place; it is saved as `punctuation.tokyonight`.
