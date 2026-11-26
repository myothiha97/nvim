# Syntax palette: decisions and measurements

Reasoning behind the values in `lua/colorschemes/solarized-osaka/palette.lua`.
It lives here rather than in the Lua file so the config stays readable — that
file is a data table, not a document.

Read this before changing a colour. Most obvious ideas have already been tried,
measured, and rejected for a recorded reason.

> **HISTORICAL AS OF 2026-09-09.** This is the deep archive, session by session,
> and it stops at the salmon build that was frozen 2026-09-08 and replaced the
> next day. The arguments and measurements hold; the "currently selected" claims
> do not. For live values read a running editor or `CLAUDE.md`'s table:
> `:lua =vim.api.nvim_get_hl(0,{name='@boolean',link=false})`
>
> Note also that the Method below measures against `#000f13`. The live
> background is `#031219`. They sit within about one unit of each other, so the
> ratios hold, but check which number a figure used before extending it.

## Method

- Measure against Nvim's opaque **`#000f13`** background.
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

## Keyword: yellow → violet (SETTLED 2026-08-10)

`#aea10c` yellow → **`#a17bcc` warm violet**, and this is the current value. The
yellow-vs-olive argument that fills the rest of this section is history: it was
the right analysis of the wrong question, because both candidates lose to the
finding below. Read this part first.

**It moved because of dose, and the dose problem is only visible in P3.** This
slot paints the highest-frequency capture in the daily stack, so rule 3 —
frequency is inversely related to brightness — binds harder here than anywhere
else. Measured off a real Go capture, every other accent on screen arrives at
C\* 38–52 (Function 44.3, String 46.2, terracotta 52.0, Type 38.7) while yellow
and olive both arrive at **C\* ~88**. Neither was an accent among accents; each
was the only supersaturated colour in the field, and it was painting the densest
capture on screen.

Violet emits L\* 58.6, C\* 52.3, hue 312, 5.81:1 — inside the band its neighbours
occupy, and 10.3 L\* *below* body text, so keywords drop to a structural layer and
the eye lands on identifiers and call names instead. Share of total on-screen
visual pull at the measured dose (5.24% of ink in real Go): violet 7.0%, olive
8.7%, yellow 9.4%. The keyword falls from the 5th loudest thing on screen to the
7th of 9.

**Known cost, accepted:** worst-neighbour separation drops from yellow's 32.5 to
19.1, just under the unambiguous line — but that is against `base01`, which is
1.55% of ink. The roles that actually cover the screen still clear it (Comment
22.3, Normal 21.2) and the pairs that carry meaning are wide open (Function 37.8,
Type 38.1).

**Stop rule:** re-measure if keyword dose climbs past ~7% of ink. That is the
point where the separation yellow buys starts to be worth its loudness. The warm
option is not gone — `:colorscheme solarized-osaka-custom-v2` is yellow.

Purple candidates measured against violet on 2026-08-10 and not chosen, kept so
the band is not re-derived: `#957fb8` kanagawa (best minimum separation at 22.6,
but flat at C\* 33.5), `#9d7cd8` tokyonight (more vivid and cooler, moves toward
the blue family), `#b67faf` warm rose (clearest from blue, but reads rose rather
than keyword), `#bb9af7` and `#cba6f7` (L\* 69.7 and 74.0, above body text —
rule 3 again).

### The yellow-vs-olive argument, now historical

Kept because the display-stability and dose findings in it are reusable, and
because olive is still a named variant. Olive `#849900` held the slot for one day
and was reverted. Do not reinstate it without reading the two findings below.

**Olive lost on display stability, not on looks.** Ghostty runs
`window-colorspace = display-p3`, so between the MacBook XDR panel and an
sRGB-gamut external monitor olive shifts 4.2° toward green while yellow shifts
0.5°. Olive sits at hue 111, right where the gamut difference bites; yellow at
98 does not. Since the external monitor is the main work display, a value that
changes identity between the two cannot be the choice. Olive also lands dE ≈ 0.2
from the git-added green `#859900`, undoing what `bdb87f0` decoupled.

**Part of the original complaint was a rendering artifact.** P3 tagging emits
every accent roughly 20 C\* above its authored value, so the yellow that read
"loud" was drawn at C\* 87.9 rather than the authored 67.4. Confirmed from
screenshot pixels — see "What the screen actually shows" below.

The 2026-08-09 reversal that started it: the yellow is good in ordinary files and
only reads *loud* where keywords cluster densely. That is rules 3 and 4 landing
on the keyword role itself — a role on nearly every line cannot be the brightest
thing on screen, and when a colour works in some files and not others the
variable is coverage, not the value. That reading was right, and the resolution
was to accept the dose rather than change the value; see "Dose, not value".

Between these two specifically, the lever is lightness rather than saturation.
Chroma is 67.0 (olive) against 67.4 (yellow), far under the perceptual floor, so
the entire difference is L\* 59.6 vs 65.4 plus 13 degrees of hue, and contrast
5.92:1 vs 7.16:1. Both clear the WCAG AA 4.5 floor. This is the one place rule 2
does not apply: a 5.8 L\* gap clears the ~5 floor that rule 2 warns about. Note
this was the whole basis for preferring olive, and it was not enough — the hue
difference turned out to matter more than the lightness one, because 13 degrees
at hue 111 is what makes olive move between displays.

The original 2026-08-08 pass landed on `#aea10c` (hue 98, L\* 65.4, C\* 67.4,
7.16:1) after four rejections:

| value | hue | L\* | C\* | verdict |
| --- | --- | --- | --- | --- |
| `#849900` | 111 | 59.6 | 67 | "gold/yellowish", disliked — reinstated then **re-rejected 2026-08-09** |
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

## What the screen actually shows (2026-08-09)

**The hex values in this repo are not what the panel emits.** Ghostty is
configured with `window-colorspace = display-p3`, which tells macOS to interpret
these sRGB-authored numbers as Display P3. P3 has more saturated primaries, so
every accent is drawn more saturated than authored.

Confirmed by decoding a screenshot rather than by theory. `sips` strips the
profile when converting to BMP, so it converts P3 to sRGB, and every accent
landed on the value predicted for that conversion:

| authored | predicted in sRGB | measured from pixels |
| --- | --- | --- |
| yellow `#aea10c` | `#b1a000` | `#b1a000` |
| azure `#1d98cd` | `#009bd2` | `#009bd2` |
| cyan `#2aa298` | `#00a598` | `#00a598` |
| terracotta `#b55f4a` | `#c25944` | `#c25943` |

Azure's red channel goes 29 → 0 and cyan's 42 → 0, i.e. those accents sit well
outside sRGB. Practical consequences:

- **Accents are display-dependent, greys are not.** Neutral colours sit on the
  achromatic axis, which sRGB and P3 share exactly, so `base0` measured
  `#9eabac` → `#9bacac` and `Comment` `#576d74` → `#516e75`. A grey decision made
  on the laptop transfers to the external monitor; an accent decision does not.
- **The absolute chroma figures in the 2026-07-22 benchmark understate reality.**
  "Max C\* 67.4" is the authored number; the panel emits about 88. The *relative*
  comparison against tokyonight and catppuccin still holds, because those were
  measured through the same pipeline.
- The setting was left alone deliberately on 2026-08-09. Changing it to `srgb`
  would drop roughly 20 C\* off every accent at once, which is a far larger
  visual change than any hex edit in this file.

### The external monitor clips, and which channel it clips matters (2026-08-11)

The other half of the same mechanism, found when the same file read differently
on the Samsung than on the laptop. The XDR panel covers P3 and shows the authored
numbers as authored. An sRGB-gamut monitor cannot, so macOS converts and
**clips** anything outside sRGB. What arrives:

| authored | shown on an sRGB monitor | |
| --- | --- | --- |
| terracotta `#b55f4a` | `#c25944` | in gamut, all three channels intact |
| copper_mid `#be6421` | `#cc5e00` | **blue clipped to 00** |
| copper `#cb6001` | `#db5800` | blue clipped, −17 C\*, −8° hue |
| violet `#a17bcc` | `#a879d1` | in gamut |

**Read the channel, not just the dE.** Terracotta keeps `blue = 0x44`, and that
residual blue is what makes it an earthy red rather than an orange. Copper's blue
clips to zero, so on that monitor it stops being a burnt orange with depth and
becomes a flat pure orange. In Lab terms the shift is only dC\* −2.1 and 1.1° of
hue — under the perceptual floor — so a dE score does not see this at all. A
channel going to zero is a category change that dE understates.

Terracotta is the display-stable option and copper is not, which is the same test
that removed olive from the keyword slot. Copper was kept anyway on 2026-08-11,
knowingly: `custom-v3` is the terracotta fallback, one `:colorscheme` away.

**The confound worth remembering before blaming a display.** That comparison was
made in two different rooms — a cafe on the laptop, a desk on the monitor.
Ambient light moves perceived saturation on a dark theme more than a 2.1 C\* clip
does: bright surroundings raise the effective black floor and wash chroma out, so
a value that needed more chroma in a cafe reads hot at a dim desk. PPI compounds
it, and the base-text item in `todos/theme/syntax-palette-followups.md` already measured
stroke coverage worth 6.9 L\* on a byte-identical colour. **Judge two builds on
both displays in the same room before concluding the display is the variable.**

## Dose, not value (2026-08-09)

The most reusable result of the session. A colour is not loud or calm in the
abstract; it has a **dose** past which it stops being tolerable, and that dose is
lower the brighter and more saturated the colour is. This is rule 3 with numbers.

The evidence is an accidental controlled experiment. In a real TSX work file and
in a dense Lua file, two different colours came out with near-identical spatial
profiles:

| | area | separate marks | avg run |
| --- | --- | --- | --- |
| TSX terracotta `#b55f4a` | 12.7% | 947 | 2.3 ch |
| Lua yellow `#aea10c` | 11.6% | 660 | 2.3 ch |

Same run length, comparable area, terracotta with *more* marks — and terracotta
was judged fine while the yellow was rejected. Coverage and fragmentation cannot
be the difference, so the colour is: yellow is L\* 65.4 / C\* 67.4, terracotta is
L\* 50.1 / C\* 42.9. Empirically yellow is comfortable at 5.3% and rejected at
11.6%; terracotta is comfortable at 12.7%.

**Measure marks, not just area.** Area alone predicts the wrong thing. In the
same TSX file cyan covers 44.9% against terracotta's 12.7%, 3.5× more, yet both
produce about 950 separate marks, because cyan arrives as 8-character Tailwind
class strings and terracotta as 2.3-character fragments. Large contiguous blocks
read as one object; scattered fragments are counted individually. The reaction
"the whole screen is X" is a statement about mark count, not about coverage.

Method for reproducing either number: resolve each non-space glyph through
capture → `@capture.lang` → `fg`, then either tally by colour, or walk each line
left to right and start a new "mark" whenever the colour changes or whitespace
breaks the run.

## Grammar keywords: an experiment that failed twice (2026-08-09)

Quieting Lua's low-information keywords was built, measured and reverted in full.
Recorded so it is not attempted a third time.

The reasoning was sound and the mechanics worked. `local` is 240 of the 1125
keyword-painted glyphs in `ai-prompts.lua` and marks nothing; `end`, `then` and
`do` are 299 more, and `end` alone owns 52 whole lines with nothing else on them.
Cutting both would have taken keyword coverage from 8.6% to 4.6%.

It failed on looks, five colours in a row:

| candidate | why it failed |
| --- | --- |
| `base0` `#9eabac` | L\* 69.0, *brighter* than the keyword it defers to (65.4), and the only near-grey among C\* 67 neighbours. Advanced instead of receding. |
| bronze `#8b8465` | hue 98 at C\* 17.9 is a brown, not a dim yellow. Read as a fourth accent. |
| warm grey `#888474` | same hue at the theme's own grey chroma (C\* 9.3). Still read as bronze. |
| cool grey `#75878a` | belongs to the theme's grey axis, but "did not sync with the rest". |
| orange | measured, never applied. See below. |

**Two structural traps this surfaced**, both worth remembering for any future
"quiet" colour:

1. **Dimming a hue changes its category.** Yellow below L\* 62 is khaki; orange
   dimmed enough to recede is bronze. "Orange, but calm" and "the bronze I
   rejected" are the same colour. The only oranges that clear both terracotta
   and the keyword by ~20 dE sit at C\* 60, which is a fourth accent, and
   dropping them to C\* 30 lands on `#9c744c`.
2. **The neutral band is too narrow to be unambiguous.** `Comment` is L\* 44.6
   and body text is L\* 69.0, so any grey centred between them lands ~12 dE from
   both — "distinguishable but tiring", never clean. Hue is the only axis that
   buys separation there, and hue is what made every warm candidate read wrong.

Also learned: `local` sits against a variable name, where a muted colour reads as
dirt, while `end` sits alone on its line, where the same colour would read as
chrome. If this ever reopens, `end` is the better target and `local` is not.

Redoing the `end`/`then`/`do` half needs `after/queries/lua/highlights.scm`
(deleted 2026-08-09): `; extends`, then `[ "end" "then" "do" ] @keyword.structure`.
A highlight group alone cannot reach them, because the runtime query files each
token under the construct it closes — `end` lands in `@keyword.conditional` after
an `if` and `@keyword.function` after a `function`, so recolouring by group takes
`if` and `function` down with it. The query cost was measured at no detectable
difference over 50 full-file passes.

## Operators are not keywords (2026-08-08)

The theme paints `Operator` with `green500`, the same colour as keywords, so
every `=` and `..` counted as a keyword. Measured coverage of the keyword colour
by treesitter capture:

| file | real keywords | symbolic operators | total |
| --- | --- | --- | --- |
| `ai-prompts.lua` | 5.4% | 2.1% | **8.0%** |
| `solarized-osaka/init.lua` | 0.2% | 0.5% | **0.7%** |

An 11× spread between two Lua files in the same repo, with the same colour — the
variation was density, not value. Symbolic operators were 26% of it in the dense
file and 74% in the config-style one, because every `key = value` line pays for
one. Dropping them to `base0` cuts the dense file to 5.9% and flattens the
difference between files instead of dimming the colour everywhere.

`and`, `or` and `not` are restored to the keyword colour explicitly: they are
keywords spelled as operators, and they chain `@keyword.operator → @operator →
Operator`, so they would otherwise go neutral with the `=` signs.

## Logical operators are keywords too (2026-08-11)

The other half of the section above, and it sat unnoticed for three days. Sending
`Operator` to `base0` was right about `=`, `+` and `=>`. It also swept up `&&`,
`||`, `??` and `!`, which are not punctuation, and that produced a split the
palette could not justify:

| language | logical operators | capture | painted before |
| --- | --- | --- | --- |
| Python | `and` `or` `not` `in` `is` | `@keyword.operator` | keyword colour |
| Lua | `and` `or` `not` | `@keyword.operator` | keyword colour |
| Go, TS/TSX/JS, Bash | `&&` `\|\|` `??` `!` | `@operator` | `base0` |

So the two daily languages were the two that lost the accent, purely because they
spell the concept with symbols. `not x` was violet and `!x` was body text. This
is the same shape as the `@punctuation.delimiter` inconsistency closed the day
before, not a preference: nothing argued for the split, it was a side effect.

**No colour was added and no Lua was edited.** `@keyword.operator` is already
painted with `palette.keyword` in `solarized-osaka/init.lua`, so the whole change is
re-capturing four tokens into a group the theme already owns. The variant
colorscheme follows for free, verified: `:colorscheme solarized-osaka-custom-v2`
moves `@keyword.operator` to the yellow and back.

**Why it needs a query and not a highlight group.** The base queries file logical
and arithmetic operators in one flat list — `ecma/highlights.scm:224-265`,
`go/highlights.scm:55-94`, `bash/highlights.scm:22-47` all put `&&` next to `=`
and `+`. No group assignment can separate them. Five files under `after/queries/`
do it instead, each `; extends`, each ~4 lines. Same mechanism as the Lua `end`
experiment, whose query cost was measured at no detectable difference over 50
full-file passes.

**Two carve-outs, both found by parsing rather than by reading the grammar.** A
bare `"!"` is wrong in two of the five languages:

```
tsx:   !   parent=unary_expression      (!!d, both bangs)   -> moved
       !   parent=non_null_expression   (foo!.bar)          -> LEFT ALONE
bash:  !   parent=unary_expression      ([[ ! -f x ]])      -> moved
       !   parent=negated_command       (! cmd)             -> moved
       !   parent=expansion             (${!arr[@]})        -> LEFT ALONE
```

TypeScript's `foo!` asserts a type and bash's `${!ref}` is variable indirection;
neither is a negation. `!=` and `!==` are single tokens and never match. Go needs
no scoping at all — it has no non-null assertion and no `${}`. Re-run the probe
if these files are ever edited; a wrong node name makes the whole query file fail
to parse and silently breaks that language's highlighting.

**Why five files instead of one `after/queries/ecma/`.**
`vim/treesitter/query.lua:227-231` concatenates
`[inherited langs] → [this lang's base] → [this lang's extensions]`, so an
`ecma` extension is spliced in *before* tsx's and typescript's own base queries.
A file named for the language being edited always lands last and always wins.

**Dose.** Measured with the method below, before and after, on real files:

| file | glyphs | keyword area | marks | moved |
| --- | --- | --- | --- | --- |
| `index.tsx` (the file that raised it) | 7,028 | 2.65% → **3.53%** | 60 → 98 | 62 glyphs / 38 tokens |
| gin `context.go` | 38,402 | 4.92% → **5.01%** | 425 → 447 | 35 / 22 |
| rust `ci/run.sh` | 9,316 | 2.81% → **3.06%** | 91 → 103 | 23 / 12 |
| rust `install-template.sh` | 21,183 | 6.22% → **6.31%** | 395 → 411 | 20 / 16 |
| `free-disk-space-linux.sh` | 8,406 | 4.28% → **4.53%** | 110 → 122 | 21 / 12 |

Largest move is +0.88 points, on the TSX file, against the 7% stop rule on the
violet. Nothing is close.

**The prediction about bash was wrong and is worth recording.** Bash was expected
to be the risk, on the reasoning that `&&` chains on nearly every line of a
DevOps script. It moved the least of the three families: real scripts branch with
`if`/`then`/`fi` far more than they chain, and bash's keyword dose is already
dominated by those. `install-template.sh` is the highest number in the table at
6.31%, but 6.22 of that predates this change.

## Punctuation: terracotta → copper (2026-08-11)

`#b55f4a` → `#be6421` (`copper_mid`). L\* 50.1 → 52.0, C\* 42.9 → 60.0, hue 40 →
58. It fixes both of this role's recorded defects: contrast 4.26 → 4.56:1, which
clears the WCAG AA floor it had been under since it was chosen, and distance from
the error red 13.4 → 17.8, retiring what was the tightest pair in the palette.

**The complaint was structural, not cosmetic, and the diagnosis is worth keeping.**
Terracotta did not change; its context did. Count the hues after the keyword moved
to violet:

| role | hue | |
| --- | --- | --- |
| keyword violet | 310 | cool |
| func azure | 250 | cool |
| type sky | 249 | cool |
| string cyan | 187 | cool |
| **punctuation** | **40** | **warm — alone** |

Under the old yellow keyword (hue 98) there were *two* warm accents. Violet is
magenta-cool, so punctuation became the only warm colour on screen, carrying that
whole side of the palette at emitted C\* 52.0 — and it does not have the presence
for it. That is why the same value that worked beside yellow reads weak beside
violet, and it is why the fix was chroma rather than lightness.

**The pairing rule, found and then overruled the same day.** The observation:
keyword and punctuation want the same emitted chroma. Two balanced pairings exist
— upstream olive 87.3 / orange 90.6 (gap 3.2), and violet 52.3 / terracotta 52.0
(gap 0.4). Every candidate that raised only punctuation scored 26–45 and was
rejected on sight while it was being compared against terracotta.

It lost to the warm-anchor argument above, and the reasons are worth recording
because the rule is still useful otherwise: it rests on two data points, and it
cannot see temperature — it treats violet+terracotta (cross-temperature) and
olive+orange (both warm) as the same kind of pair. The selection carries a gap of
23.2, half of copper's 44.9. **If the screen ever reads punctuation-heavy, that
number is the first thing to look at.**

`copper_mid` was chosen over `copper_warm` `#c26116` on measurement, not looks:
the two are dE2000 **1.3** apart, at the just-noticeable threshold against the
"under 10 is confusable" line this file uses. They are the same colour and this
one carries 8 points less pairing damage. Do not re-run that comparison.

### "Brighter" meant chroma three times in one session

The most reusable result of the day, and it cost several rebuilt ladders.

| the request | the actual difference |
| --- | --- |
| "upstream has higher contrast in the reddish colours" | contrast was *lower* (5.69 vs 5.89:1); chroma was +19 |
| "copper is significantly brighter than terracotta" | +2.9 L\*, under the perceptual floor; chroma +29.7 |
| "v6 is a bit brighter than v5" | −0.1 L\*, i.e. darker; chroma +5.1 |

**Before building a ladder, measure which axis the complaint is actually on.**
The stated axis was wrong every time. A lightness ladder was built, measured and
discarded on looks ("too pink") because of this — and the reason it read pink is
the same effect from the other side: perceived saturation falls as lightness
rises, so holding C\* 43 while going to L\* 58 produces a pastel. **To stay earthy
while brightening, chroma has to rise with lightness.**

Every value measured that day is grouped under `variants.punctuation.explored`
in the palette file, by axis, with the reason each one lost.

## Where the palette landed, measured against upstream (2026-08-11)

Answering the question the whole rework was for: is it calmer, and is it still
Solarized? Weighted by real ink share on real files, emitted rather than authored.

| | upstream | ours | |
| --- | --- | --- | --- |
| chroma, weighted (TSX) | 48.8 | **40.7** | −17% |
| chroma, weighted (Go) | 26.1 | **20.2** | −23% |
| chroma, accents only | 63.9 | **53.0** | −17% |
| loudest accent | 90.6 | **75.5** | −17% |
| lightness, accents only | 56.3 | **59.6** | +3.3 |

**It is not a darker theme, it is a less saturated one**, and that is the right
axis: the 2026-07-22 benchmark concluded that high chroma against near-black is
what reads as glare. The composite glare proxy (ink × dE from background) is
essentially flat at 35.5 → 36.7; the whole win is in saturation.

The mean lightness went *up* because two roles left the accent set entirely —
`Operator` `#849900` (C\* 87.3) → `base0` (C\* 6.1) and `@module` `#db302d`
(C\* 93.6) → `base2` (C\* 11.7). Both are lighter and nearly achromatic now: they
joined body text instead of competing with it. That is about 160 points of chroma
removed from the screen, and it does not show up in a lightness average.

**Still Solarized**, in family if not in value. dE2000 to the nearest canonical
Solarized colour:

| role | nearest | dE | |
| --- | --- | --- | --- |
| string | cyan | 0.5 | identical |
| func | blue | 6.6 | same family |
| punctuation | orange | 8.4 | same family, −16 chroma |
| keyword | **violet** | 12.1 | same family, +8 L\* |
| type | blue | **20.0** | **imported** |

Comments, body and module sit on Solarized's own base tones. Even the keyword
lands on Solarized's *own* violet `#6c71c4`, just lighter — the palette did not
leave Solarized, it took a lighter and quieter reading of it. `Type` `#7dcfff` is
the single genuine outsider.

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

The overrides are commented out in `solarized-osaka/init.lua`, so `@variable.member`
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

## The 2026-09-05 rebuild

The largest change since the palette was written: five roles moved in one day,
two new roles created, and the warm accent replaced. `custom-latest` is the result;
`custom-v1` is the copper build it replaced and is still one `:colorscheme` away.

Ten builds existed at once during the day so they could be compared in real
files, then collapsed to the winner. **`custom-v5` through `custom-v10` no longer
exist** — they are named below only to say what was tried and why it lost. The
builds that ship are `custom-latest`, `custom-v1`, `custom-v2`, `custom-v3` and
`original`. That deliberately breaks the "builds are for
values worth living with" rule at the top of `variants.lua`. Do it the same way
next time: many builds while deciding, none afterwards.

### Where it started

`({ path, query, origin })` and `new URLSearchParams()` rendered in the same
copper as the brackets around them, so a signature read as one unbroken run.

Both were painted from `palette.punctuation` — the same role as
`@punctuation.bracket`, JSX tags, `Special` and `@variable.builtin` — so no value
could move one without all of them. That is why the day started with a role
split rather than a colour change, and it is the pattern for the whole rebuild:
**every complaint here turned out to be a grouping error, not a hex.**

Three new roles came out of it, all defaulting to their old value so nothing
moved until a build asked: `parameter` (`@variable.parameter`, `@constructor`),
`delimiter` (`Operator`, `@punctuation.delimiter`, `@tag.delimiter.*`) and
`bracket` (`@punctuation.bracket`).

### Two things the first split broke, both found by measuring

- Lua captures `{` as `@constructor` as well as `@punctuation.bracket`, so moving
  `parameter` turned every Lua table brace yellow. `@constructor.lua` is now
  pinned to follow `bracket`.
- `custom-v3` silently lost its parameters. It overrode `punctuation` alone, and
  `parameter` defaults to the punctuation **value**, not the **role**. Every
  build now names both. Nothing errors if a future one forgets.

### "Variables look faded next to upstream" — dose, not value

The variable colour had never changed: `Normal`, `@variable` and `@variable.lua`
were `#9eabac` in upstream and in every build. What changed was its neighbours.
Upstream paints operators and delimiters olive `#849900`; we moved them to base0
in 2026-08, which is the **same value as `@variable`**.

Measured on `lua/config/quickfix-persistence.lua`:

| | base0 coverage | separate base0 runs |
| --- | --- | --- |
| upstream | 32.0% | 272 |
| ours, before | 38.1% | 464 |

Every `=`, `.`, `,` around a name became the same grey as the name, so a variable
lost the coloured edge its operators used to give it. Rule 4, and the fix was to
move the punctuation, not to retune the variable.

### The grey is a maximin, not a preference

Punctuation has to stay clear of body text above it and Comment below it, and
those pull in opposite directions, so the best value is the crossover. Against
body `#b1bebf` and Comment `#576d74`:

| hex | L\* | contrast | dE body | dE comment | worst |
| --- | --- | --- | --- | --- | --- |
| `#798c91` | 56.9 | 5.54:1 | 15.7 | 12.4 | 12.4 |
| `#7f9195` | 58.9 | 5.93:1 | 13.8 | 14.4 | **13.8** |
| `#859699` | 60.9 | 6.33:1 | 12.1 | 16.2 | 12.1 |
| `#8b9b9e` | 62.8 | 6.75:1 | 10.4 | 17.9 | 10.4 |
| `#91a0a2` | 64.8 | 7.19:1 | 8.7 | 19.5 | 8.7 |

**"Brighter to distinguish it better" is false above 58.9** — every step past it
buys comment separation by spending body separation and the worst pair gets
worse. Do not rebuild this ladder. Brackets sit on the maximin rung and
delimiters one above it, because a bracket carries less than an operator does.

Body text went the other way, +7.0 L\* to `#b1bebf`. The theme's own next rung
(base1) is +4.6 and measured under the perceptual floor, i.e. invisible.

### Copper to yellow: harmony, measured

| accent set | hues | tightest gap | emitted chroma sd |
| --- | --- | --- | --- |
| copper | 58, 187, 250, 310 | 60° | 12.4 |
| **yellow** | 98, 187, 250, 310 | **60°** | **9.5** |
| copper + yellow | 58, **98**, 187, 250, 310 | **40°** | 12.4 |

Copper was the chroma outlier (emitted 75.5 against everything else's 38–52), so
dropping it tightens the accent spread from 31.2 to 24.0. That evenness is what
reads as "the yellow mixes with the cyan and violet".

The middle row is the trap: keeping copper for brackets *and* adding yellow for
names puts two warm hues 40° apart doing different jobs — the tightest gap in the
palette. It was built (`custom-v8`) and rejected for that.

Yellow also fixes two recorded defects: copper was the palette's **only** sub-AA
colour (4.56:1 → 7.37:1) and its tightest pair against the error red (dE 17.8).

### Brackets go grey — the decisive measurement

Across 237 real `.ts`/`.tsx`/`.lua`/`.go` files, 645,195 glyphs:

| brackets are… | accent coverage | accent marks | chars per mark |
| --- | --- | --- | --- |
| an accent | 7.51% | **21,518** | **2.25** |
| neutral | 4.31% | **5,887** | **4.72** |

Coverage falls 43% but marks fall **73%**, because a bracket is one character and
a name is five. On the accent, brackets are confetti; the same hex marking only
names averages 4.72 characters and reads as words. The scatter doesn't vanish, it
moves to the grey (39,817 marks at 1.22 chars), which is what chrome is for.

This also gives a yellow parameter an edge against its own brackets without a
second hue, which is what `custom-v7` could not do (`param` and `bracket` were
dE 0.0) and what `custom-v8` needed a 40° hue clump to buy.

Brackets are 3.21% of ink in 17,210 marks at 1.20 chars; plain variables are
14.94% in 18,300 marks at 5.27 chars. **Nearly the same mark count at four times
the run length** — which is also why body-coloured brackets were rejected
(`custom-v10`): it merges the most scattered thing on screen with the least.

### `${}` is a mode switch, not a bracket

Grouped with the brackets in the first cut and moved out the same day. It has to
be read *inside* the string colour, so what matters is separation from that cyan:
copper 46.9, the accent yellow 32.9, the neutral grey only **17.7**. Grey threw
away 63% of it and the interpolation marker merged into the text.

Note the side effect: in TypeScript `@punctuation.special` is also the optional
marker `?`, and that is the majority of the group (116 of 242 in `.ts`). So `?`
is an accent now. Kept — optionality is information, not structure, and it is
0.09% of glyphs.

### Rejected, with reasons

- **Body-coloured punctuation** (`custom-v10`). See the mark numbers above; it
  also re-creates a dE 0.0 name/symbol pair and pushes the brightest colour past
  51% of ink.
- **`punctuation.explored.balanced_amber` `#a67136`** for the warm accent: dE
  **8.5** from copper. Anything at hue 70 or below is the same colour as copper.
- **Un-greying type-level `&` and `|`.** A real inconsistency — `a && b` is
  `@keyword.operator` (violet) while `DateProps & {` is `@punctuation.delimiter`
  (grey) — but there is no capture to split on, so it needs an `after/queries`
  override for typescript *and* tsx, maintained across grammar updates, to move
  0.14% of `.ts` and 0.04% of `.tsx` glyphs and 0% of Go. Not worth it.
- **Yellow on the whole warm side** (`custom-v7`): 13.4% of TSX glyphs, past the
  ~10% discomfort line, and it leaves `param` = `bracket` at dE 0.0.

### Where it landed

| role | value | L\* | contrast |
| --- | --- | --- | --- |
| body / `@variable` | `#b1bebf` | 76.0 | 10.19:1 |
| names — params, `new X()`, tags, `${}` | `#aea134` | 65.5 | 7.37:1 |
| delimiters — `=` `,` `.` `:` | `#8b9b9e` | 62.8 | 6.75:1 |
| brackets — `(` `[` `{` | `#7f9195` | 58.9 | 5.93:1 |
| comments | `#576d74` | 44.6 | 3.57:1 |

> The delimiter row above was superseded the next day — see
> [2026-09-06: punctuation settles](#2026-09-06-punctuation-settles-closed) for
> the value that is actually live.

**Four lightness steps ordered by how much the thing means, and one warm accent
hue rather than two.** That is the shape to preserve if any single value is
retuned. Even on markup-heavy TSX the accent makes 1,994 marks at 5.37 chars
against `custom-v1`'s 5,867 at 2.65 — fewer, longer marks than the build that ran
for the previous month.

The known cost: brackets are no longer an accent, so bracket *matching* is by
shape and indent. `MatchParen` still colours the pair under the cursor.

---

## 2026-09-06: punctuation settles (CLOSED)

**Outcome: `delimiter` and `bracket` both hold `#7f9195` (L\* 58.9, 5.93:1), the
maximin rung. The palette is finished.** This section is the record of how three
separate proposals were tested and rejected in one session, so none of them gets
re-proposed.

### What changed

| role | was (2026-09-05) | is (2026-09-06) |
| --- | --- | --- |
| `delimiter` — `= == != > < + - * & . , ; :` | `#8b9b9e` (62.8) | **`#7f9195` (58.9)** |
| `bracket` — `( ) [ ] { }` | `#7f9195` (58.9) | `#7f9195` (58.9), unchanged |
| `@tag.delimiter.*` — JSX/HTML `<` `>` `/` | followed `delimiter` | **follows `bracket`** |

Everything else is untouched.

### Proposal 1: colour the delimiters (REJECTED)

The grey read as "faded and dark", so `delimiter` was set to the original
solarized olive `#849900`. It was live for about an hour and lost on three
independent measurements.

- **It collides with the yellow punctuation.** dE2000 **9.9** from `#aea134`.
  Below ~15 two colours read as the same family, which is exactly the "if it's
  too close with yellow the color can get mixed" report that came back from real
  use. Confirmed by eye before it was confirmed by number.
- **It re-couples git-added green.** dE2000 **0.2** from `#859900`, undoing what
  commit `bdb87f0` decoupled on purpose.
- **It is the wrong dose for any accent.** Measured on the real repos with
  comments and string bodies stripped: the delimiter role (`Operator` +
  `@punctuation.delimiter`) is **10.54% of code ink in 482,879 marks at 1.18
  chars/mark** across `business-portal-js`, and **14.6% in Go**. That is the
  highest dose of anything in the palette — higher than the brackets that were
  sent to grey the day before *for being too scattered to colour* (6.24%).
- **On this display it is the most saturated thing on screen.** Ghostty tags
  content display-p3, so authored chroma is not emitted chroma. Olive emits
  C\* **87.3** where every other accent arrives at 38–52 and the yellow
  punctuation at 68.4. That is the same rule-3 failure that moved the *keyword*
  off olive on 2026-08-10, now applied to a role with twice the dose.

**The wheel is full.** A sweep of every hue at 5-degree steps, chroma 6–45, over
L\* 50–68, scored on worst-case dE2000 against all twelve live colours, tops out
at **dE 23.3** (a warm tan around hue 50). There is no unoccupied band. Five
candidates were built as throwaway `delim-*` colorschemes and compared in real
files before the whole idea was dropped:

| candidate | hex | C\* | hue | dE yellow | dE git green | emits C\* |
| --- | --- | --- | --- | --- | --- | --- |
| olive | `#849900` | 67.0 | 111 | 9.9 | 0.2 | 87.3 |
| sage | `#989b73` | 22.1 | 111 | 13.7 | 15.2 | 24.9 |
| leaf | `#77a372` | 32.3 | 140 | 19.6 | 16.6 | 38.5 |
| taupe | `#b29183` | 15.9 | 50 | 24.5 | 30.4 | 19.2 |
| taupe_warm | `#b98f79` | 21.9 | 54 | 23.4 | 30.3 | 26.3 |

Lowering olive's chroma does not help: hue 111 and hue 98 stay 13 degrees apart
whatever the chroma, so `sage` is the *worst* of the four on the collision that
started this.

### Proposal 2: keep the two-rung split (REJECTED)

`delimiter` one rung above `bracket` cost the delimiter its best body separation
(worst pair **13.8 → 10.4**) and bought a gap of **dE 3.5**. This palette's own
precedent — the `base00` note in `variants.delimiter` — treats **dE 4.7** as the
point where two colours already read as one. It was paying a real property for an
invisible difference.

Collapsing both roles onto `mid_high` is the best score in the whole table:

| delimiter | bracket | gap | worst pair overall |
| --- | --- | --- | --- |
| `brightest` | `mid_high` (the split) | 3.5 | **3.5** |
| `brightest` | `mid_low` | 7.3 | 7.3 |
| **`mid_high`** | **`mid_high`** | 0.0 | **13.8** |
| `mid_high` | `mid_low` | 3.8 | 3.8 |

The two roles still exist separately in the palette, so a future build can split
them again. They just hold one value today.

### Proposal 3: "`mid_high` will hide the math symbols" (DISPROVEN)

The worry was that `+ - / * < >` are thin strokes and would wash out at 5.93:1.
Measured directly off screenshots of live Go, at native retina resolution:

| token | context | width | lit px | rendered | contrast |
| --- | --- | --- | --- | --- | --- |
| `==` | `if port == "" {` | 32px ligature | 222 | `#7f9195` | 5.93:1 |
| `:=` | `i := 1 + 2` | 6 + 14px | 56 + 96 | `#7f9195` | 5.93:1 |
| `>` | `if i > 3 {` | 14px | 105 | `#7f9195` | 5.93:1 |
| `*` | `func(c *gin.Context)` | 6px | **26** | `#7f9195` | 5.93:1 |
| `&` | `fmt.Println(&s)` | 17px | 208 | `#7f9195` | 5.93:1 |
| `!=` | `err != nil` | 32px ligature | 284 | `#7f9195` | 5.93:1 |
| `+` | `":" + port` | 14px | 96 | `#7f9195` | 5.93:1 |
| `.` | `r.Run` | 6px | 26 | `#7f9195` | 5.93:1 |

Zero variance. **The mechanism, so this is never re-tested:** antialiasing dims a
glyph's *edges*, never its core. Any stroke at least one device pixel wide keeps a
fully covered pixel at full colour, and at this font size on retina even a `-` is
several device pixels thick. Thin glyphs look fainter than letters because fewer
pixels are lit, not because those pixels are dimmer — and that is equally true at
every rung, so it is not an argument for or against any particular one.

**A measurement trap this session fell into and climbed back out of:** a
1920×1080 screenshot of a retina panel is *downscaled*, and downscaling really
does cost a thin stroke ~4.3 L\* of peak. An early pass measured those captures,
concluded antialiasing eats 4 L\*, and briefly reasoned from it. Native 3024×1964
captures show every glyph hitting its exact authored hex. **If you measure
rendered colour from a screenshot, check the pixel dimensions first.**

### Where the palette actually landed

Rendered contrast on a live Go screen, measured, not authored:

| role | value | L\* | contrast |
| --- | --- | --- | --- |
| type | `#7dcfff` | 79.7 | 11.36:1 |
| body / `@variable` | `#b1bebf` | 76.0 | 10.19:1 |
| names — params, `new X()`, tags, `${}` | `#aea134` | 65.5 | 7.37:1 |
| string | `#29a298` | 60.4 | 6.23:1 |
| function | `#1d98cd` | 59.1 | 5.96:1 |
| **punctuation — delimiters and brackets** | **`#7f9195`** | **58.9** | **5.93:1** |
| keyword | `#a17bcc` | 58.1 | 5.77:1 |
| comment | `#576d74` | 44.6 | 3.57:1 |

Punctuation sits sixth of eight: above the `if`/`for`/`var` violet you read all
day, well clear of comments. Its worst pair is dE 13.8, against body text.

**Three lightness steps ordered by how much the thing means — body 76.0, names
65.5, punctuation 58.9, comments 44.6 — and one warm accent hue, not two.** That
is the shape to preserve if any single value is ever retuned.

### Verified across the whole daily stack

Checked both by eye on real files and by measuring rendered pixels, in
**JSX/TSX**, **JS/TS**, **Go** and **Lua**. Two language-specific findings, both
now fixed or accepted:

- **JSX/TSX tag delimiters.** `<`, `>` and `/` around a tag name now follow
  `bracket` rather than `delimiter`. `<div>` is a name wrapped in punctuation
  exactly as `foo(bar)` is, so the wrapper belongs on the bracket rung. Routed as
  `palette.bracket or delimiter`, **not** through the `bracket` local in
  `init.lua`, because that one falls back to `palette.punctuation` and would drag
  `custom-v1`/`v2`/`v3` tag delimiters onto copper. Verified on the then-live
  build as `#7f9195`; custom-latest now overrides it to `#9eabac`.
- **TS with dense cyan** (a `yup` schema, a `faker` mock builder) is the one place
  punctuation recedes noticeably, because a C\* 7 grey next to C\* 38–52 cyan is
  suppressed by chromatic induction. This is a chroma effect, so no rung on the
  grey ladder fixes it and only colour would — which Proposal 1 above rules out.
  **Accepted, not a defect.** Go, the primary language, has sparse cyan and does
  not show it.

### Status: CLOSED. Do not reopen without a new constraint.

Every role in this palette has now been checked both by hand on real files and
programmatically against rendered pixels. There is no known improvement left on
the table — the remaining moves are all lateral, and the wheel is full. Further
tweaking is a time sink, not a gain. If a future session feels the urge, read
this section and `neovim-config-change-gate.md` first.

## 2026-09-07: final custom-latest override (CLOSED)

Dense JS/TS object literals exposed one final practical issue: cyan keys and
values mixed together, making object structure hard to scan. `custom-latest`
now overrides three base roles:

| role | current value | reason |
| --- | --- | --- |
| type | `#2ac3de` (`nvim_type`) | lower the former `#7dcfff` brightness peak |
| bracket | `#9eabac` (`body.base0`) | make object and call structure clearly visible |
| delimiter | `#7f9195` (`delimiter.mid_high`) | keep frequent operators and separators quiet |

The yellow warm side, violet keyword, raised body, and comment remain unchanged.
This supersedes the live-state claims in the 2026-09-06 section but preserves
that section as the measurement record. The palette is closed after this update.

## 2026-09-07: user-approved warm taupe trial

The user explicitly overrode the change gate and requested warm punctuation
because variables, brackets, and delimiters looked too similar in white/grey.
`custom-latest` now uses `delimiter.warm_taupe` (`#b98f79`) for brackets and
delimiters, including ordinary operators and JSX tag wrappers. Variables remain
`#b1bebf`; the user's vivid blue functions remain `#359ee9`. Parameters, tags,
and string interpolation markers retain yellow `#aea134`.

Warm taupe was previously tried and rejected. This trial revisits it for the
explicit hue-separation preference. Against the user's current `#031219`
background its authored sRGB contrast is 6.58:1; CIEDE2000 separation is 25.0
from variables and 23.4 from yellow parameters. These measurements do not
establish visual comfort. User acceptance in real files is pending.

To restore the preceding punctuation, set `custom-latest.delimiter` to
`palette.variants.delimiter.mid_high` and `custom-latest.bracket` to
`palette.variants.body.base0` in `variants.lua`.

## 2026-09-07: Kanagawa punctuation trial

The user rejected warm taupe's brown cast as muddy in the Go screenshot and
requested `#9cabca`, Kanagawa's `springViolet2`, after comparing other dark
themes. Both punctuation roles now use `delimiter.kanagawa`; variables remain
`#b1bebf` and functions remain vivid blue `#359ee9`. Taupe stays as a rejected
candidate. Visual acceptance of blue-lavender is pending.

Authored sRGB contrast against `#031219` is 8.23:1. Separation from variables
is lower than taupe's, so this trial prioritizes the preferred cool tint.

## 2026-09-07: user-proposed pale cyan trial

The user found Kanagawa `#9cabca` better than taupe, then requested a comparison
with `#9cc8ca`. Both punctuation roles now use `delimiter.pale_cyan`; variables
and vivid blue functions retain their values. Kanagawa remains available as
`delimiter.kanagawa`. Visual acceptance of pale cyan is pending.

Authored sRGB contrast against `#031219` is 10.44:1. It is brighter than
Kanagawa and closer to both variables (CIEDE2000 9.2) and cyan Type (12.1), so
it may reduce the separation this trial originally sought.

## 2026-09-07: user-proposed pale yellow trial

The user likes Kanagawa's tone and proposed `#cfcea7` as another promising
comparison. Both punctuation roles now use `delimiter.pale_yellow`. Variables
remain `#b1bebf` and functions remain `#359ee9`. Kanagawa is kept as the preferred
reference; visual acceptance of pale yellow is pending.

This changes hue as well as lightness and chroma: pale yellow has L* 81.9,
C* 20.5, and Lab hue 107.3, versus Kanagawa's 69.8, 17.6, and 275.0.
Authored sRGB contrast against `#031219` is 11.81:1. Punctuation is brighter
than variables, with CIEDE2000 separation 16.0 from variables and 18.3 from
yellow parameters. It is a warmer experiment, not a same-hue Kanagawa variant.

## 2026-09-07: saturated Kanagawa trial

The user preferred Kanagawa `#9cabca` but could barely see its blue hue.
Both punctuation roles now use `delimiter.kanagawa_saturated` (`#90abdd`).
This raises chroma from 17.6 to 28.4 while preserving lightness (69.8 to 69.7)
and approximately the same Lab hue (275.0 to 275.4). Variables remain
`#b1bebf` and functions remain `#359ee9`. Visual acceptance is pending.

Authored sRGB contrast against `#031219` is 8.20:1. CIEDE2000 separation from
variables improves from 13.7 to 17.7, while separation from vivid blue functions
falls from 16.2 to 12.6. The original `delimiter.kanagawa` remains the fallback.

## 2026-09-07: green hue comparison

The user liked `#90abdd` and requested a green version. Both punctuation roles
now use `delimiter.kanagawa_green` (`#8db488`), a local derivative rather than
an upstream Kanagawa color. The blue remains in `delimiter.kanagawa_saturated`
as the liked fallback. Variables and functions retain their colors.

The green changes Lab hue from 275.4 to 140.0 while keeping lightness and
chroma approximately equal (L* 69.5, C* 28.4). Authored sRGB contrast against
`#031219` is 8.16:1. CIEDE2000 separation is 18.4 from variables, 17.7 from
teal strings, and 19.8 from yellow parameters. Visual acceptance is pending.

## 2026-09-07: Kanagawa midpoint trial

The user rejected green and requested a color between original Kanagawa
`#9cabca` and the liked saturated blue `#90abdd`. Both punctuation roles now
use `delimiter.kanagawa_mid` (`#96abd3`), derived by averaging their LCh values
and converting back to RGB. Both blue endpoints remain available in the palette.

After RGB rounding, lightness is 69.7 and chroma 22.7, between the original's
17.6 and the stronger blue's 28.4. Authored sRGB contrast against `#031219` is
8.21:1. Variables and functions retain their colors. Visual acceptance is pending.

## 2026-09-07: midpoint review and neutral tag wrappers

The user likes the midpoint and requested an evidence-based comparison against
`body.base0` brackets and `delimiter.mid_high` separators, plus a decision on
whether variables need `body.brightest`. All 13 supplied screenshots were read:
Go, TypeScript, TSX logic, imports, type declarations, dense object literals,
and JSX markup. They are 1920x1080 with the `27G2G3` monitor profile. All contain
consistent body and punctuation core pixels. Raw screenshot RGB values differ
from authored hexes because of color management; they are not sRGB measurements.

The following comparisons use authored sRGB values against the current
`#031219` background, not the older `#000f13` background used in prior notes.

| punctuation | contrast vs background | CIEDE2000 from variables | from functions |
| --- | --- | --- | --- |
| previous brackets `#9eabac` | 8.04:1 | 5.26 | 21.62 |
| previous delimiters `#7f9195` | 5.78:1 | 13.84 | 19.33 |
| midpoint `#96abd3` | 8.21:1 | 15.69 | 14.16 |

The strongest improvement is variable/bracket separation at nearly unchanged
bracket brightness. Delimiters gain a smaller separation improvement and more
background contrast, but become more prominent. Separation from teal strings
also improves (26.04 versus 19.73 for old brackets and 17.54 for old delimiters).
The accepted cost is proximity to function blue. Screenshots show paler brackets
and more saturated function names; this remains a visual tradeoff, not a proof
that the midpoint is universally best. Color-distance cutoffs in older notes
are local heuristics, not validated readability or comfort thresholds.

Keep `body.brighter` (`#b1bebf`): contrast is already 9.95:1. `body.brightest`
(`#bcc9ca`) raises it to 11.18:1, but body/punctuation separation only improves
from 15.69 to 16.76. There is no observed variable-readability defect requiring
that increase. Object keys and string values still sharing teal is a separate
capture assignment; changing the plain variable color would not change them.

WCAG's [4.5:1 minimum](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html)
and [7:1 enhanced benchmark](https://www.w3.org/WAI/WCAG22/Understanding/contrast-enhanced.html)
provide background-contrast references, not a ranking of syntax palettes or a
guarantee of long-session comfort. Current body and code punctuation exceed both.

During review the user explicitly requested neutral HTML/JSX/TSX tag wrappers.
The existing scoped tag-delimiter block now uses `c.base0` (`#9eabac`), including
Vue. This colors `<`, `>`, and `/`; expression braces, comparisons, and division
remain blue. Real TSX, JavaScript/JSX, and HTML parser captures verified the split,
and a deliberate blue tag override was correctly rejected by the verification.
The numbered builds already used base0 tag wrappers, so their behavior is kept.

Recommendation: retain midpoint code punctuation and the existing variable
color. The new neutral tag wrappers still need a visual look in the next session.

### Function blue: retain vivid

The user also requested confirmation that vivid blue is sufficient after azure
looked faded. `#359ee9` raises authored sRGB background contrast from azure's
5.82:1 to 6.54:1, lightness from 59.1 to 62.6, and chroma from 38.5 to 46.4.
Separation from cyan Type improves from 15.2 to 17.8, and from teal strings
from 21.8 to 26.5. The supplied screenshots show saturated function names beside
paler blue punctuation. Keep vivid; this review found no need to brighten it.

### Cross-language audit and limits

The user expanded the review to JS, TS, CSS, HTML, JSX, TSX, Go, Bash, Lua,
YAML (including Docker Compose), TOML, and Dockerfiles. Representative snippets
were parsed through the installed grammars and resolved through actual Neovim
highlight groups, including embedded JavaScript in HTML and Bash in Dockerfiles.
The audit checked 2,647 token glyphs against the intended role colors across
the eleven languages with installed parsers, with zero mismatches. Spelling and
private query captures were excluded because they do not paint text; HTML's
intentional `@none` resolves to normal body text. This is representative coverage,
not a proof for every possible syntax construct or a reading-speed study.

Every contrast below uses current `Normal.bg = #031219`:

| role | color | authored sRGB contrast |
| --- | --- | --- |
| variables | `#b1bebf` | 9.95:1 |
| code punctuation | `#96abd3` | 8.21:1 |
| neutral tag wrappers | `#9eabac` | 8.04:1 |
| functions and properties | `#359ee9` | 6.54:1 |
| types | `#2ac3de` | 9.02:1 |
| strings, members, numbers, booleans | `#29a298` | 6.08:1 |
| keywords | `#a17bcc` | 5.63:1 |
| parameters, imports, special punctuation | `#aea134` | 7.20:1 |
| comments | `#576d74` | 3.48:1 |

Concrete findings to flag, rather than reopening the entire palette:

- CSS has no installed Tree-sitter parser. A real `.css` buffer uses native
  `syntax=css`. Its braces/commas use function blue, some punctuation falls back
  to body text, and at-rules/pseudo-classes use `#db302d` at 4.05:1. This is the
  clearest consistency gap and lies below the 4.5:1 text-contrast benchmark for
  those red tokens. Parser installation or narrow native CSS overrides need a
  separate decision; neither was performed during this review.
- Dockerfile `CMD ["node", "server.js"]` currently captures only the keyword;
  its `json_string_array` and `json_string` nodes receive no syntax capture from
  the installed query. They fall back to readable body text, but do not share
  the string/bracket distinction of JS or TOML. This is an upstream query gap,
  not a blue-palette failure. No Dockerfile query was changed.
- Comments remain below the 4.5:1 benchmark by existing preference. This is a
  readability compromise worth knowing, rather than a claim that every token
  meets AA contrast. No comment change was requested.
- Teal strings and member names still share a color intentionally. Brighter
  plain variables cannot alter those captures.

The selected core colors have adequate background contrast and the supplied
screenshots support their visual hierarchy. Retain them; future work should
address a concrete observed gap such as CSS rather than search for another
universally best shade. The current background is part of this decision.

### 2026-09-07: modest comment lift and native CSS corrections

The user requested slightly brighter comments without high contrast, and the
CSS corrections identified by the audit. The core palette stays unchanged.

`custom-latest` now uses `variants.comment.subtle` (`#637981`), the theme's
existing base00 tone, for `Comment`. Against actual background `#031219`, this
raises contrast from 3.48:1 to 4.15:1 and L* from 44.6 to 49.4. Hue and chroma
remain close to the original. Comments remain deliberately below the 4.5:1
benchmark and well below body text at 9.95:1; this is the modest increase the
user asked for, not a claim of full contrast compliance. Italic styling is
preserved. The palette's default `comment = false` keeps reference builds on
upstream comments and ensures the temporary build override restores correctly.
Only `Comment` is repainted, not the shared base01 UI ramp.

CSS remains on the installed native syntax engine. Existing CSS groups now
link to the established syntax roles in the colorscheme's `on_highlights`:

- Braces and math parentheses use the bracket role.
- Separators, selector operators, class dots and uncaptured operators inside
  function/math regions use delimiter/operator roles.
- At-rules, logical words and pseudo-classes use the violet keyword role,
  raising the former red tokens from 4.05:1 to 5.63:1.
- Nested properties, numbers, strings and function names retain their existing
  colors. Error highlights retain their diagnostic colors.

Explicit highlight links survive the runtime's later `hi def link` commands.
No parser, plugin, autocmd or syntax-matching rule was added. The only new work
is a bounded set of assignments during colorscheme loading.

Verification: a real CSS buffer confirmed comment text, braces, colons,
semicolons, class dots, selector operators, function commas, calc subtraction,
at-rules and pseudo-classes. Its property names, numbers, strings and function
names retained their colors. Comparing all existing highlight definitions
against the pre-change session found changes only in Comment and CSS groups.
Negative controls detected both the old comment color and old function-colored
braces. Switching through custom-v1, original and custom-latest confirmed the
comment override restores correctly. The previous cross-language audit was
rerun with the new comment expectation: all 2,647 checked token glyphs passed,
with updated comments in every sampled language and no missing foregrounds.

Remaining native grammar limits: `cssFunctionName` includes both the name and
its outer parentheses; some media-query punctuation inherits `cssAtRule`, and
some top-level separators have no syntax group. Highlight relinking cannot
separate glyphs that share a group or add missing captures. These limitations
are recorded rather than adding parsing work for cosmetic completeness.
Dockerfile capture gaps and shared teal roles were outside this change.

## 2026-09-08: the warm side moves to salmon (CLOSED, frozen to ~2027-04)

The last palette session before a 6-8 month freeze. Five changes shipped, four of
them fixing groups that resolved to a duplicate or to the error red.

**What changed.** `punctuation` + `parameter` + `member` moved from subdued yellow
`#aea134` to salmon `#cd735d`. `boolean` and `@constant` gained amber `#d19c59`.
`@attribute` and `@constant.macro` were taken off the alarm red. `@variable.member`
was enabled at all — its paint line in `init.lua` had been commented out since
2026-08-09, which made the whole `member` role a silent no-op.

**The collision that justified it.** Before this session one cyan `#29a298`
carried `variable.member` + `string` + `constant` + `number` + `boolean`, all at
dE2000 0.0, and it was the largest block in a real file: 30.48% of `api.ts`, of
which `variable.member` alone was 189 glyphs. In `cfg.ts` 48 of 64 cyan glyphs
were numbers, so the "string colour" was mostly not strings.

**Salmon vs the yellow it replaced, measured on the same Go/TS/TSX files.** The
new build wins 8 of 9 metrics — more distinct colours in all three files, lower
weighted chroma in two, loudest accent down 30.48% → 27.38% (TS) and 27.94% →
22.83% (TSX). The single loss was 0.1 weighted chroma, i.e. noise.

Judged as a bare value, though, **yellow is the better colour**: 7.20:1 against
salmon's 5.62:1, and worst-neighbour dE 25.9 against 20.0 in its own best
configuration. The upgrade came from the member split, not from the hue. What
justifies the hue is chroma: yellow is C\* 56.3 against salmon's 43.2, so at the
9-27% dose this role carries it costs +5.4% to +10.7% weighted chroma — the exact
metric the 2026-08 retune existed to reduce.

**One accent hue on the warm side, re-proven.** Yellow punctuation beside a salmon
`member` was rejected on sight. The census says it was not dose: total warm ink
was identical to two decimal places either way (`api.ts` 31.86% both ways,
`demo.go` 12.99% both ways, `Panel.tsx` 17.85/17.86%). Splitting one warm field
across three hues 58° apart is what reads as busy, and the boolean gets squeezed —
tightest warm pair 15.1-16.1 split, against 20.0 unified. Four configurations were
scored; the only one that beats the shipped build is yellow unified with a Tokyo
Night orange boolean (27.9 warm separation, 7.20:1), and it loses on weighted
chroma, so it was declined.

**`@attribute` was the error colour.** Decorators — Python `@dataclass`,
TS/NestJS/Angular `@Injectable()` — linked `@attribute` → `PreProc` → `#db302d`,
byte-identical to `DiagnosticError`, `DiagnosticSignError`, the error undercurl
and `ErrorMsg`. Measured at 8.9% of a decorated Python class and 12.4% of a NestJS
controller. Same defect and same fix shape as `@keyword.import` and `@module`
before it. Pointed at `palette.punctuation` because `@attribute.builtin` already
resolved there, so builtin and user decorators had been rendering differently.

**Boolean method.** Modelled on Tokyo Night's `orange` `#ff9e64` by reproducing
its *relationship* — there it sits 7.9 L\* below body text, so on our brighter
body the equivalent is L\* 68, not 74. Copying the hex verbatim sits 2.1 L\* under
body and reads hotter, because our background is 5.4 L\* darker. TN's hue then
lost anyway: at hue 55.6 it landed 16° from salmon and blurred into it in real
use, so the role moved to amber at hue 73.8 (dE 27.4 / 34°).

**Declined, with the measurement.** Moving `@number` onto the constant colour
would close the last literal duplicate and is what Tokyo Night does, but amber
rises from 8.3% → 21.7% of a numeric TS file and 2.7% → 16.2% of a Helm values
file, with average run dropping to 2.7-3.4 (fragmented). Amber was chosen bright
because it was rare, so the dose contradicts its own justification. If it is ever
taken, `#c2a079` (same hue, C\* 26) carries the dose better.

**Left open on purpose:** `@number` == `@string`, `@property` == `Function`
(59.3% of a YAML manifest renders function-blue), and body `#b1bebf` vs tag
wrapper `#9eabac` at dE 5.3 — the tightest pair in the palette and deliberate,
recorded so it is not rediscovered as a bug. Salmon sits dE2000 11.8 from the
error red, the tightest warm/error pair the palette has run; accepted because
diagnostics are toggled on manually, with `#c87655` as the invisible-cost fix
(13.7) if that ever changes.

## 2026-11-25: punctuation split into operators, separators and brackets

On the `#171716` background, after a contrast pass over the live build.

| role | groups | value | contrast | why |
| --- | --- | --- | --- | --- |
| `delimiter` | `Operator` (`:=` `!=` `==` `<`) | `warm_taupe` `#b98f79` | 6.21:1 | best worst-pair of every `delimiter.*` candidate (12.8, vs `nil`/numbers); the only one apart from both body and the separator grey |
| `separator` (new) | `@punctuation.delimiter` (`.` `,` `;` `:` `?.`) | `separator_neutral` `#8f9a9b` | 6.21:1 | the warm dot sat dE 36 from the blue/cyan either side of it and read as an orange speck |
| `bracket` | `@punctuation.bracket` | `pale_yellow_dim` `#a9a88b` | 7.40:1 | `pale_yellow` `#cfcea7` was 11.14:1, the brightest ink on screen, above body (9.39:1) |

`separator` defaults to `false` (follow `delimiter`), so every numbered build is
unchanged. Verified by sampling rendered pixels of a Go screen: all three render
at the expected values, shifted by the macOS screenshot profile by the same amount
as body text. Rejected for operators: `kanagawa` (+0.6 worst-pair, invisible, a
fourth blue), `kanagawa_saturated` (9.6 vs func), `pale_cyan` (8.9 vs members), and
every grey rung (merges operators with separators).


## 2026-11-25: full contrast audit before the config lock

Every syntax role, UI text colour, diagnostic, guide and background band was
measured on `#171716`. Two changes came out of it:

- **`@module` moved to body text** (`palette.body`, 9.39:1). It was `c.base2`
  `#ede7d4` at 14.51:1, the brightest ink on screen. Measured with the Go
  tree-sitter grammar on prometheus, caddy and etcd: 1.4-2.1% of code ink and
  6-8% of lines, 91-95% of it the package half of a qualified type
  (`*slog.Logger`). Low dose, but a cream spike in signatures; body matches how
  package names already render in calls (`config.Load` is `@variable`).
- **`IncSearch` (and `CurSearch`, which links to it)** keeps the theme's
  `#ca4c16` orange background, preferred by eye, with bold white text: 4.61:1,
  up from cream at 3.73:1. Dark text on it only reaches 3.89:1. Dark text on the
  lighter literal orange `#ed8e55` (7.35:1) was tried the same night and
  rejected on look.

Passed and left alone: all syntax roles 5.31-10.39:1 (comments 4.25:1), closest
syntax pair body/separator at dE00 10.3; LineNr 2.60:1, inlay hints 3.91:1;
indent guides 1.28/2.33:1, borders 1.42:1; body text on every selection and diff
band 4.84-9.18:1. Known and accepted: warning virtual text `#e0af68` sits dE00
5.1 from the type gold (diagnostics are toggled on manually).


## 2026-11-26: JetBrains parity, attributes, interfaces, write references

From the GoLand/WebStorm highlight gap review. Three changes, each scoped so
the numbered builds are unchanged:

- **JSX/HTML attribute names** (`@tag.attribute.{tsx,javascript,html}`) link to
  `@variable.member.key`. They were on the function blue through
  `@tag.attribute` -> `@property` -> `Identifier`, so every prop read as a call.
  A prop is a key of the props object, so it now matches `{ title: "x" }`. dE00
  22.6 from the string green of its value, 24.9 from the function blue.
- **Interfaces** get the new `interface` role (`@type.interface`), periwinkle in
  `custom-latest`. TS via vtsls `interface` tokens, Go via gopls `type` tokens
  with the `interface` modifier (gopls >= 0.17), builtins excluded. Numbers in
  `palette-reference.md`, "interface".
- **Write references** (`LspReferenceWrite`) got a warm band at the read band's
  lightness the same day, then went back to the shared read colour by
  preference after an on-screen check. Numbers in `palette-reference.md`,
  "Reference highlight".

None of these were checked on screen when written (no Neovim in the session
that made them). Check each by eye before treating it as settled.

Same day, later: **function/method declarations in bold, calls plain**
(`BOLD_FUNCTION_DECLARATIONS` in `init.lua`). Weight instead of a second blue.
The theme's `@function.call` -> `@function` link is cut so calls stay plain. No
query change, so no treesitter cost. Checked against the pinned queries: every
`@function`/`@function.method` capture is a definition.

Same day, later: **interface colour moved from `periwinkle` to `lavender`
`#c0b3f5` (trial).** A full-gamut sweep showed periwinkle only dE00 14.6 from the
function blue, its most common neighbour; lavender is 21.6 from it at the cost of
the keyword (17.3 -> 15.6). Contrast 9.40:1 (periwinkle 8.85:1). Pink/mauve
measured best and was ruled out by taste. Table in `palette-reference.md`,
"interface". Verdict pending a day or two of real Go/TSX use.

Same day, later: **Go interface declarations briefly on `periwinkle`, then back
on `lavender`** (Myo). The worry was lavender mixing with the `type`/`interface`
keywords around the name; measured at dE00 15.6, above every neighbouring pair
the palette accepts, separated mainly by lightness. One value for declaration and
use; bold declined. Numbers in `palette-reference.md`, "interface".

Same day, later: **bold function declarations dropped** (Myo: no bold for
declarations). Declarations and calls are one weight again; declarations keep
the function blue `#61afef`. Bold was tried for a few hours as the zero-cost way
to tell a declaration from a call.

**OPEN, 2026-11-26: a quieter colour for function CALLS** (declarations stay
`#61afef`). Constraint from Myo: blue hue only, no cyan-blue / violet / lavender.
Measured so far, on `#171716`, separation as Ghostty draws it (P3):

| call colour | how | WCAG / APCA | P3 C\* | vs decl | nearest | deutan worst |
| --- | --- | --- | --- | --- | --- | --- |
| `#61afef` (today) | | 7.59 / 54.7 | 44 | 0 | body 20.6 | keyword 7.5 |
| `#96aac5` | less saturated, same L\* | 7.56 / 54.3 | 18 | 12.2 | separator 12.5, body 12.7 | 9.0 |
| `#879dbb` | less saturated, darker | 6.47 / 47.3 | 20 | 12.2 | separator 12.5, interface 15.1 | 8.3 |
| `#7992b7` | darker | 5.65 / 41.8 | 24 | 13.2 | separator 14.8 | 5.0 |
| `#6e94ba` | first guess | 5.65 / 41.8 | 27 | 10.1 | separator 14.9 | 4.1 |

Ruled out: a STRONGER declaration blue with calls unchanged (blue is at its
ceiling at this lightness; best step 6.7, under the ~10 needed to see it); the
cyan-blue `#30a3bd` / `#0c9eba` (h225, best separation but off the blue hue) and
the violet-blues (crowd the keyword and the lavender interface). Leading
candidate `#96aac5`; its risk is reading as tinted body text (low chroma, the
"reads flat" failure recorded twice here).

**Trial started the same day: option 4** (Myo's pick), declarations `#5cc3fe`,
calls `#8db0e0`: both move a little instead of calls moving a lot, so calls stay
clearly blue and become MORE readable than today (APCA 57.3 vs 54.7). Full
table: `palette-reference.md`, "Declaration vs call split". Verdict: pending.

