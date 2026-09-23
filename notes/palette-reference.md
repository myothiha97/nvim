# Palette reference

Compact companion to the three theme files. Holds the prose that used to live in
their comments, so the code can stay a data table.

- **Deep archive** (full arguments, session-by-session measurements, rejected
  experiments): [`syntax-palette-decisions.md`](syntax-palette-decisions.md)
- **Follow-up items and their status**: [`../todos/theme/syntax-palette-followups.md`](../todos/theme/syntax-palette-followups.md)
- **Silent-failure traps across the whole config**: [`silent-failure-surfaces.md`](silent-failure-surfaces.md)

Read this before changing a value. Most obvious ideas have already been tried,
measured, and rejected for a recorded reason.

> ## HISTORICAL AS OF 2026-09-09. Do not read values out of this file.
>
> This document describes the **salmon build**, frozen 2026-09-08 and replaced
> the next day. The freeze did not hold: punctuation moved off salmon to the
> accent yellow, boolean off amber, delimiters off the Kanagawa midpoint,
> comments off upstream, and the `member` role was switched off entirely.
>
> The **reasoning, the measurements and the rejected candidates below are still
> valid and still worth reading** — that is why this file is kept. Only the
> "which value is live" claims are dead.
>
> **For live values, read a running editor or `CLAUDE.md`'s table, never this
> file:** `:lua =vim.api.nvim_get_hl(0,{name='@boolean',link=false})`
>
> One follow-up listed here has since closed: `@number` no longer equals
> `@string`. `@property` == `Function` and the body/tag-wrapper pair at dE 5.3
> are still open.

---

## Live values as of 2026-09-08 (SUPERSEDED, see the banner above)

Measured against Nvim's opaque background. Ghostty tags content display-p3, so
authored numbers are **not** what the panel emits: accents arrive roughly 20 C\*
higher.

> **Which background is live: `#031219`.** Verified by reading `Normal`'s `bg`
> from a running instance. `lua/config/ui.lua` sets `bg =
> reference.ghostty_background` (`#031219`), even though that table is labelled
> "NOT selectable backgrounds" and `candidates.teal = "#000f13"` carries the
> `CURRENT` marker. The marker and `CLAUDE.md`'s `bg = #000f13` line are stale,
> not the code. Older contrast figures in this file were computed against
> `#031219` or `#031116`, which sit within ~1 unit of each other, so the ratios
> hold either way — but check which number a measurement used before extending
> it.

>   **This table is a hand-maintained SNAPSHOT and drifts.** `custom-latest` in
> `variants.lua` is the authority; it changed several times on 2026-09-08 alone.
> Verified against a running editor on 2026-09-08. To re-check:
> `:lua =vim.api.nvim_get_hl(0,{name='@boolean',link=false})`

| role | hex | source | note |
| --- | --- | --- | --- |
| body / `@variable` | `#b1bebf` | `body.brighter` | L\* 76.0, 10.19:1 |
| delimiter (operators, `.` `,` `;` `:`) | `#96abd3` | `delimiter.kanagawa_mid` (custom-latest) | base build uses `mid_high` `#7f9195` |
| bracket | `#96abd3` | `delimiter.kanagawa_mid` (custom-latest) | same value as delimiter again |
| HTML/JSX/TSX/Vue tag wrappers | `#9eabac` | theme `base0`, hardcoded in `init.lua` | user preference |
| function | `#359ee9` | `func.vivid` (custom-latest) | base build uses `azure` `#1d98cd` |
| type | `#2ac3de` | `type.nvim_type` (custom-latest) | base build uses `tokyonight` `#7dcfff` |
| boolean (`true`/`false`) | `#d19c59` | `boolean.amber` (custom-latest) | **added 2026-09-08**; was cyan, identical to String and `@number` |
| `@constant` + `@constant.macro` | `#d19c59` | shares the `boolean` value | **added 2026-09-08**; SCREAMING_SNAKE names were cyan, identical to String. `@constant.macro` was `#db302d`, the error red |
| `@number` | `#29a298` | theme `Constant` | **unstyled** — still identical to String. `Number` links to `Constant`, so `hl.Number = { fg = palette.boolean }` moves it to the constant colour (what Tokyo Night does) |
| punctuation / parameter / member | `#cd735d` | `punctuation.explored.salmon` (custom-latest) | base default is `keyword.subdued` `#aea134`; salmon taken up 2026-09-08 |
| keyword | `#a17bcc` | `keyword.warm_violet` | base value; a copper keyword was tried on 2026-09-08 and reverted — see [the copper keyword](#the-copper-keyword-2026-09-08) |
| comment | `#576d74` | theme default (upstream) | `comment.subtle` `#637981` exists but its line is commented out in `custom-latest` |
| `@variable.member` | `#cd735d` | shares salmon with punctuation above | **paint line re-enabled 2026-09-08** — it was a silent no-op before |
| `@property` (object/dict keys, JSX attrs) | `#359ee9` | theme default | **unstyled** — exactly duplicates Function; see [member](#member) |
| keyword_grammar | *unread* | nothing paints it | experiment rejected twice |

**Palette status: closed, ~90% done.** Final call 2026-09-08. The last 10%,
deliberately left open and only worth reopening if it bothers you in daily use:

- a red (or other hue) that can replace the subdued yellow
- object member colours
- object/dict key and value colours
- boolean colours

### The copper keyword (2026-09-08)

`keyword` was moved from violet to `punctuation.explored.copper_soft` `#ba662b`
and **reverted the same day**, so violet is live again. Kept because the numbers
are the argument for not retrying it casually: it put **two** dense roles on the
warm side. Measured against the live background `#031219`:

| role | hex | L\* | C\* | hue | contrast |
| --- | --- | --- | --- | --- | --- |
| keyword (new) | `#ba662b` | 52.0 | 54.8 | 58 | 4.55:1 |
| keyword (violet, base build) | `#a17bcc` | 58.1 | 47.8 | 310 | 5.63:1 |
| punctuation | `#aea134` | 65.5 | 56.3 | 98 | 7.20:1 |
| error red | `#ff3b30` | 56.7 | 88.7 | 36 | 5.36:1 |

What the numbers say, for and against:

- **It satisfies the pairing rule well.** Keyword C\* 54.8 against punctuation
  56.3 is a gap of 1.5 — the closest balanced pairing this palette has had
  (violet/terracotta was 0.4, violet/copper_mid was 23.2). Both calm, neither
  drowns the other.
- **The error-red constraint holds**, at dE76 43.0. Note the metric: the recorded
  17.8 figure for `copper_mid` is dE2000, which is not comparable — dE76 numbers
  run larger. Do not read 43.0 as "2.4x better than copper_mid".
- **It is now the palette's dimmest accent, at 4.55:1** — 0.05 over the WCAG AA
  floor, where violet had 5.63:1. Nothing is sub-AA, but there is no headroom.
- **Two dense warm roles 40° apart.** Keyword is the densest capture in the daily
  stack and punctuation the densest accent, and they are now dE76 40.7 apart
  where violet/yellow was 100.3, i.e. 2.5x closer. What separates them is
  lightness (13.5 L\*), which is rule 1 broken knowingly — the same trade the
  Type/Function pair makes. The thing to watch is whether keywords and brackets
  blur together in dense TSX; that is a dose question, so judge it on real files.

### The punctuation verdict (2026-09-08)

Terracotta red and subdued yellow stayed close. Analysis scored yellow better and
it still reads best in daily use, so **yellow stays even though it goes against
personal colour preference**, and no red variant has beaten it. The `punctuation`
and `parameter` lines are therefore left commented out in `custom-latest`, which
falls through to the base palette's `keyword.subdued`.

Candidates kept commented in place as one-line toggles, in the order they were
tried: `punctuation.terracotta`, `punctuation.explored.copper`,
`punctuation.explored.clay`. `explored.salmon` was tried live on 2026-09-08 and
reverted the same session.

---

## Why the theme is overridden at all

Stock solarized-osaka had three measured faults:

1. **Roles collided with meaning.** `Type` was yellow500, so every `int`,
   `string`, `float64`, `ReactNode`, `Optional` read as gold, which in Go and TS
   is most of a signature. `@module` and `@keyword.import` linked to a saturated
   alarm red 31° of hue from the error red, so `import` and `package main` read
   as diagnostics.
2. **Punctuation was painted as language.** `Operator` and
   `@punctuation.delimiter` carried the keyword colour, so every `=`, `.`, `,`,
   `;` counted as a keyword. Measured at an 11× coverage spread between two Lua
   files in the same repo.
3. **It ran hot on a near-black background.** High chroma against L\* 5 is what
   reads as glare; stock sits ~17% higher in weighted chroma.

Priority order when solving it: long-session comfort, then role separation, then
staying recognisably Solarized. Not "prettier".

Where it landed against upstream on real files: −17% weighted chroma in TSX,
−23% in Go, loudest accent down from C\* 90.6 to 75.5, four of five accents still
on canonical Solarized hues. Less saturated, not darker.

## One accent hue on the warm side

The palette's shape is **four lightness steps ordered by how much the thing
means** — body 76.0, names 65.5, punctuation 62.8/58.9, comments 44.6 — with
**exactly one accent hue on the warm side instead of two**.

That last clause is the one that gets broken, and 2026-09-08 confirmed it
empirically. Yellow punctuation beside a salmon `member` was rejected on sight.
The census shows the reason is **not dose** — total warm ink was identical either
way, to two decimal places:

| file | three warm hues | total | two warm hues | total |
| --- | --- | --- | --- | --- |
| `api.ts` | salmon 15.40 + yellow 11.98 + amber 4.48 | **31.86%** | salmon 27.38 + amber 4.48 | **31.86%** |
| `demo.go` | 6.66 + 3.49 + 2.84 | **12.99%** | 9.50 + 3.49 | **12.99%** |
| `Panel.tsx` | 12.11 + 3.50 + 2.24 | **17.85%** | 15.62 + 2.24 | **17.86%** |

So no amount of retuning a hex fixes it: splitting one warm field into two
similar-dose warm hues 58° apart is what reads as busy. Keep the warm side to one
dominant hue plus at most one **low-dose** accent — which is what `boolean` is,
at 0.65–4.48%.

**Corollary.** `punctuation` and `member` are separate roles, so splitting member
off the string cyan does *not* require moving punctuation. Moving it anyway is
still correct: unifying the two keeps the warm side to one hue and leaves room
for the boolean. Tightest warm pair is 20.0 unified, against 16.1 when
punctuation and member hold different hues and the boolean has to squeeze between
them.

## Four rules that keep being relearned

1. Two roles must not share a hue band; splitting by lightness alone fails.
2. Tune hue and chroma. Lightness-only moves land under the perceptual floor.
3. Frequency is inversely related to brightness.
4. If a colour looks right in some files and wrong in others, the variable is
   **coverage**, not value.

Corollaries used throughout: dE ~4.7 is where two colours already read as one,
and "make it brighter" is almost always a chroma request, not a lightness one.

---

## keyword

`Keyword`, `Statement`, `@keyword`, `@keyword.function`, `@label`, plus the
`.tsx`/`.javascript` scoped variants. `@keyword.operator` (`and`, `or`, `not`) is
written explicitly in `init.lua` because it is stored as a bare string link whose
target goes neutral.

Densest capture in the daily stack, so rule 3 binds hardest here.
**Stop rule: re-measure if keyword dose passes ~7% of ink.**

| value | hex | numbers | verdict |
| --- | --- | --- | --- |
| `warm_violet` | `#a17bcc` | L\* 58.1, C\* 47.7, h310; emits 58.6/52.3/312 | **SELECTED 2026-08-10.** Sits inside the band its neighbours occupy, 10.3 L\* below body text |
| `kanagawa` | `#957fb8` | C\* 33.5 | best minimum separation (22.6) but flat |
| `tokyonight` | `#9d7cd8` | — | more vivid and cooler, drifts to the blue family |
| `warm_rose` | `#b67faf` | — | clearest from blue, but reads rose not keyword |
| `tokyonight_magenta` | `#bb9af7` | L\* 69.7 | above body text, rule 3 |
| `catppuccin_mauve` | `#cba6f7` | L\* 74.0 | same problem, worse |
| `olive` | `#849900` | h111, L\* 59.6, C\* 67.0, 5.92:1 | held the slot 2026-08-09 only. Rejected on **display stability**: shifts 4.2° toward green between laptop and external monitor (yellow shifts 0.5), and lands dE ~0.2 from git-added green `#859900`, undoing what commit `bdb87f0` decoupled |
| `balanced` | `#aea10c` | h98, L\* 65.4, C\* 67.4, 7.16:1 | held 2026-08-08→08-10, still reachable as `custom-v2`. Highest contrast, the only hue here that reads as actual yellow (below ~L\* 62 it turns khaki). Lost to violet on emitted chroma (87.9), not hue. Dose reference still valid: comfortable to ~6% of glyphs, uncomfortable past ~10%; only Lua exceeded, at 11.6% |
| `darker` | `#a3970b` | h98, L\* 61.6 | ladder rung |
| `brighter` | `#baac0d` | h98, L\* 69.5 | ladder rung |
| `amber` | `#b59a00` | h92 | warmer |
| `citron` | `#9ea100` | h104 | cooler |
| `subdued` | `#aea134` | h98, C\* 56 | **live value of `punctuation` + `parameter`** |
| `hushed` | `#aea042` | h98, C\* 50 | C\* 35 is the muddiness floor |
| `gold` | `#b99004` | — | the theme's own yellow500, ruled out by hand |
| `drab` | `#8c9644` | h111, C\* 44 | rejected 2026-08-08, "too fade" |
| `verdant` | `#5da100` | h125, C\* 75 | rejected, "dracula green" |
| `sage` `moss` `fern` `clover` `juniper` `leaf` `grass` | `#66985e` `#629959` `#5d9a53` `#599e49` `#569f41` `#4ea339` `#56a325` | — | older greens, all rejected as cool/vivid rather than warm |

## keyword_grammar

Lua's `end` / `then` / `do`, dimmed so block grammar reads as chrome.

**Rejected wholesale 2026-08-09, and nothing reads the table.** The mechanics
worked and the coverage numbers were real (8.6% of glyphs down to 6.3%); every
quiet colour simply read as out of place next to the accents, five in a row. Lua
is a config language here, not part of the daily stack, so its density is not
worth a fourth colour.

Two structural things to know before reopening:

- `end` is the right target and `local` is not. An `end` sits alone on its line
  where a quiet colour reads as chrome; a `local` sits against a variable name
  where the same colour reads as dirt.
- Keep candidates **cool**. A warm hue dimmed far enough to recede stops being
  that hue and becomes brown; every warm candidate was rejected as bronze.

Redoing it needs `after/queries/lua/highlights.scm` back (deleted 2026-08-09):
`; extends`, then `[ "end" "then" "do" ] @keyword.structure`, because the runtime
query files those tokens under the construct they close.

| value | hex | numbers | verdict |
| --- | --- | --- | --- |
| `cool_grey` | `#75878a` | h215, L\* 55.0, C\* 7.0, 5.06:1 | the wired default. 10.7 dE from Comment, 12.2 from body |
| `base00` | `#637981` | 4.15:1 | one step down, 4.7 dE from Comment, sub-AA |
| `fg` | `#839395` | — | one step up, only 7.8 dE from body text |
| `warm_grey` | `#888474` | h98, C\* 9.3 | rejected, still read as bronze |
| `bronze` | `#8b8465` | h98, C\* 17.9 | rejected, a brown |
| `base0` | `#9eabac` | L\* 69.0 | brighter than the keyword it defers to |

## comment

| value | hex | numbers | verdict |
| --- | --- | --- | --- |
| `subtle` | `#637981` | L\* 49.4, 4.15:1 | small approved lift, previously `#576d74` at 3.48:1. Live in `custom-latest`; reference builds keep upstream |

## body

`Normal`, `NormalFloat` and `@variable`, one value by design: a plain identifier
**is** body text in this palette. Rule 3 binds hardest here since it is the most
frequent colour on screen, so it is raised only far enough to be seen.

| value | hex | numbers | verdict |
| --- | --- | --- | --- |
| `base0` | `#9eabac` | L\* 69.0, 8.23:1 | the theme's own, and the pre-2026-09-05 default |
| `base1` | `#adb7b7` | L\* 73.7, +4.6, dE 3.7 | the theme's next rung, at the perceptual floor: measured, too small to see |
| `brighter` | `#b1bebf` | L\* 76.0, +7.0, 10.19:1, dE 5.3 | **SELECTED.** Clears the floor, still 3.7 L\* under the base Type |
| `brightest` | `#bcc9ca` | L\* 80.0, +11.0 | passes the Type colour, rule 3. Reviewed 2026-09-07: not needed |
| `base2` | `#ede7d3` | L\* 91.6 | the theme's base2, and a cream rather than a grey |

## delimiter

Operators and delimiters (`=` `.` `,` `;` `:`, and via `init.lua` the JSX
wrappers, which are separately pinned to `base0`).

Why there is a choice at all: upstream paints these olive `#849900`. Moving them
to `base0` put them on the **same value as `@variable`**. The value of a variable
never changed, but `base0` went from 32.0% to 38.1% of glyphs on
`lua/config/quickfix-persistence.lua` and from 272 to 464 separate runs (+71%),
so a name lost the coloured edge its operators used to give it. That is what
"variables look faded next to upstream" was. Rule 4: the variable is not the
variable.

| value | hex | numbers | verdict |
| --- | --- | --- | --- |
| `kanagawa_mid` | `#96abd3` | L\* 69.7, C\* 22.7, 8.21:1 | **LIVE in custom-latest.** LCh midpoint between `kanagawa` and `kanagawa_saturated`, trialled 2026-09-07 |
| `kanagawa_green` | `#8db488` | L\* 69.5, C\* 28.4, h140, 8.16:1 | rejected, user preferred returning to blue |
| `kanagawa_saturated` | `#90abdd` | L\* 69.7, C\* 28.4, 8.20:1 | user liked it; kept as the stronger end of the comparison |
| `pale_yellow` | `#cfcea7` | L\* 81.9, C\* 20.5, 11.81:1 | warmer comparison, user preferred Kanagawa's tone |
| `pale_cyan` | `#9cc8ca` | L\* 77.7, C\* 15.1, 10.44:1 | closer to variables and cyan Type than Kanagawa |
| `kanagawa` | `#9cabca` | L\* 69.8, C\* 17.6, 8.23:1 | user likes this tone; the reference for the trials |
| `warm_taupe` | `#b98f79` | L\* 62.8, C\* 21.9, 6.58:1 | rejected: separates from variables but looks muddy |
| `base0` | `#9eabac` | L\* 69.0, 8.23:1 | identical to `@variable`, the problem described above |
| `base00` | `#637981` | L\* 49.4, 4.25:1 | dE 18.0 from base0 (the edge comes back) but **sub-AA** and only dE 4.7 from Comment, so punctuation starts reading as commented-out. Judged by eye 2026-09-05, lost to the maximin rung |
| `base01` | `#576d74` | — | Comment itself. Listed to be explicit it is not a candidate |
| `mid_high` | `#7f9195` | L\* 58.9, 5.93:1, worst sep 13.8 | **the maximin rung, and the BASE-build value of both punctuation roles** |
| `mid` | `#798c91` | L\* 56.9, 5.54:1, worst 12.4 | one rung down |
| `mid_low` | `#73878d` | L\* 55.0, 5.18:1 | most body edge, closest to Comment |
| `brighter` | `#859699` | L\* 60.9, worst 12.1 | above the maximin, kept to show the curve turn over |
| `brightest` | `#8b9b9e` | L\* 62.8, worst 10.4 | held `delimiter` for one day |

### The maximin ladder, and why not to rebuild it

The theme's ramp jumps 19.6 L\* from `base00` to `base0` with nothing between, so
`mid*` are synthesised on the same grey axis (hue 206, C\* interpolated).
Punctuation has to stay clear of body text **above** it and Comment **below** it,
and those pull in opposite directions, so the best value is the crossover:

| hex | L\* | AA | dE body | dE comment | worst |
| --- | --- | --- | --- | --- | --- |
| `#798c91` | 56.9 | 5.54:1 | 15.7 | 12.4 | 12.4 (`mid`) |
| `#7f9195` | 58.9 | 5.93:1 | 13.8 | 14.4 | **13.8 ← selected** |
| `#859699` | 60.9 | 6.33:1 | 12.1 | 16.2 | 12.1 |
| `#8b9b9e` | 62.8 | 6.75:1 | 10.4 | 17.9 | 10.4 (`brightest`) |
| `#91a0a2` | 64.8 | 7.19:1 | 8.7 | 19.5 | 8.7 |

So "make it brighter to distinguish it better" is **false** above this rung: past
58.9 every step buys comment separation by giving up more body separation, and
the worst pair gets worse.

**The two-rung split was tried and dropped.** 2026-09-05 to 09-06 `delimiter` sat
one rung above `bracket` (`brightest` over `mid_high`), on the argument that
operators carry more meaning than brackets. Dropped because the gap it bought was
dE 3.5, and this palette's own precedent treats dE 4.7 as the point where two
colours read as one. It paid the delimiter's best body separation (13.8 → 10.4)
for a difference nobody can see. The roles still exist separately so a future
build can move them apart; `custom-latest` currently holds one value for both.

**Colour was tried here too, 2026-09-06, and lost.** The delimiter role is 10.5%
of code ink in TS/TSX and 14.6% in Go, the highest dose in the palette. A sweep of
every hue at 5° steps, chroma 6–45, across L\* 50–68, tops out at worst-case
dE 23.3 against the twelve live colours. The wheel is full. Do not reopen without
a new colour to make room with. Full argument:
[`syntax-palette-decisions.md`](syntax-palette-decisions.md), "2026-09-06:
punctuation settles".

`mid_high` was also verified by measuring rendered pixels of real Go, TSX, TS and
Lua screens rather than by eye: every operator glyph peaks at exactly that hex,
including the thinnest ones (`*` and `.` at 26 lit pixels) and the `==`/`!=`
ligatures.

## punctuation

`Special`, `Debug`, `@variable.builtin`, `@module.builtin`, `@punctuation.special`
(`${}`), `@keyword.import`, JSX tag names, and via the `parameter` role also
`@variable.parameter` and `@constructor`.

The densest accent in the palette: 19.1% of ink in markup-heavy TSX. Whatever sits
here is the warm side of the screen on its own, because every other accent is cool
(violet 310, azure 250, sky 249, cyan 187).

**Hard constraint:** keep clear of the error red `#ff3b30` (L\* 56.7, C\* 88.7,
h36, set in `init.lua`) so brackets never read as diagnostics. Chroma does that
work, not hue: every warm value here sits within a few degrees of h36, and the
only one measured to clear dE 20 was an amber at h70 that failed for other
reasons.

**Live value is `keyword.subdued` `#aea134`, not anything in this table.** Yellow
replaced copper on 2026-09-05 and the choice was reaffirmed 2026-09-08. It wins on
two things copper could not fix: copper was the palette's only sub-AA colour
(4.56 → 7.37:1) and its tightest pair against the error red (dE 17.8 → far).
Dropping copper also removes the chroma outlier from the accent set, so emitted
spread falls 31.2 → 24.0. AI analysis scored yellow better and it still reads best
in daily use, so it stays even though it goes against personal colour preference.
`punctuation.copper_mid` is the one-word revert.

| value | hex | numbers | verdict |
| --- | --- | --- | --- |
| `copper_mid` | `#be6421` | L\* 52.0, C\* 60.0, h58, 4.56:1, emits C\* 75.5 | selected 2026-08-11, replaced 2026-09-05. Fixed terracotta's two defects: 4.26 → 4.56:1, and error-red distance 13.4 → 17.8. **Known cost:** emits C\* 75.5 against violet's 52.3, a gap of 23.2 where terracotta held 0.4, so punctuation out-saturates the keyword. If the screen ever reads punctuation-heavy, that gap is the cause |
| `terracotta` | `#b55f4a` | L\* 50.1, C\* 42.9, h40, 4.26:1, emits C\* 52.0 | held until 2026-08-11, wired as `custom-v3`. The only value satisfying the pairing rule perfectly. Two defects: the palette's only sub-AA colour, and the tightest pair against the error red. Display-stable where copper is not, but fades against bright neighbours on P3 |

### The pairing rule (found 2026-08-11)

The keyword and punctuation accents want the **same emitted chroma** or one drowns
the other. Exactly two balanced pairings exist: both loud (upstream olive 87.3 /
orange500 90.6, gap 3.2) or both calm (violet 52.3 / terracotta 52.0, gap 0.4). It
is a two-data-point rule and it cannot see temperature, which is why it was
overruled for copper. Check it before raising either of this pair.

### `punctuation.explored`

Everything measured on 2026-08-11, kept as one group so the same three ladders are
not rebuilt a fourth time. **Nothing reads it.** All were rejected on **looks**
despite measuring well ("too orange or too pink"), so judge anything from here on
looks, never on the numbers alone.

Lightness ladder at h40, chroma held at the balance point. The measured best
direction: closes the 9.1 L\* gap to the accent cluster, fixes the sub-AA
contrast, and is the only axis that keeps the pairing intact. Rejected because
h40 stops being earthy and starts reading pink on the way up.

| value | hex | numbers |
| --- | --- | --- |
| `clay` | `#c16953` | L\* 54.0 (+4), 4.90:1 |
| `coral` | `#c76e58` | L\* 56.0 (+6), 5.25:1 |
| `salmon` | `#cd735d` | L\* 58.0 (+8), 5.62:1, lands exactly on the cluster |

Hue ladder at salmon's lightness, so hue is the only variable. Rotating toward red
is close to free: contrast stays flat and the error-red distance **improves**
(11.8 at h40 → 13.1 at h26), because rotating off that red's own h36 beats
matching its lightness. The browner direction at the same three lightnesses was
measured and not pursued: h46 gives `#be6b4d` / `#c47052` / `#ca7557`.

| value | hex | hue |
| --- | --- | --- |
| `sunset` | `#cf7163` | 34 |
| `blush` | `#d16f68` | 30 |
| `dusty_rose` | `#d16e6c` | 26 |

Chroma ladder at h58, the one that produced the 2026-08-11 selection. All share
L\* ~52, so saturation is the only variable; `terracotta` is the C\* 42.9 end of
the same axis. Each rung roughly halves the pairing gap.

| value | hex | numbers |
| --- | --- | --- |
| `copper_soft` | `#ba662b` | C\* 54.8, emits 67.9, pairing gap 15.6 |
| `copper_warm` | `#c26116` | C\* 65.1, emits 83.7, gap 31.4. dE 1.3 from `copper_mid`, i.e. the same colour, and 8 points worse on pairing, so do not re-run that comparison |
| `copper` | `#cb6001` | C\* 72.6, emits 97.2, gap 44.9. Judged too bright. **Live value of `CursorLineNr`** |

Why `copper` reads "brighter": it is only +2.9 L\* over terracotta, under the
perceptual floor, so the whole impression is chroma (+29.7). A "make it brighter"
request on this role is almost always a chroma request. Check which axis the
complaint is on before building a ladder.

Off-axis, measured and rejected for reasons worth keeping:

| value | hex | numbers | verdict |
| --- | --- | --- | --- |
| `ember` | `#c85c27` | C\* 63.1, gap 26.0, h51 | the redder middle |
| `sienna_hot` | `#d85d13` | C\* 74.7, gap 44.1 | — |
| `balanced_amber` | `#a67136` | L\* 52.0, C\* 43.1, h70, 4.56:1 | satisfied **every** numeric constraint at once: balanced, AA-clean, and the only warm value ever measured to clear dE 20 from the error red (24.9). Lost because h70 is amber, and at 19.1% of TSX ink it would have put gold back on screen, which is what moved `Type` off yellow originally |
| `solarized_orange` | `#cb4b16` | L\* 49.2, C\* 72.5, h48, 4.13:1 | the real Solarized orange, for reference: copper's saturation at a redder hue, and why copper reads as "more solarized". The theme's own orange500 `#c94c16` is the same colour to within dE 1. Both sub-AA |

Untried in place. `tokyonight` measures better than terracotta on both defects
(7.19:1, dE 21.3 from the error red) but at L\* 65.5 it clears the accent cluster
entirely rather than joining it.

`#f7768e` (`tokyonight`), `#c75b6b` (`muted_contrast`), `#bf2c47` (`crimson`),
`#b02669` (`magenta`), `#e03857` (`vivid`), `#ab3a4f` (`bright`), `#b83e55`
(`lighter`), `#993141` (`darker`), `#f6524f` (`red300`), `#b7211f` (`red700`).

## parameter

Parameter names and `new X()` callees. Split off `punctuation` on 2026-09-05 so a
build can recolour them alone; it holds the same yellow, because what separates a
parameter from its brackets is now the **bracket being grey**, not the name being
a different hue.

No variant table of its own: every candidate is already measured under
`punctuation` or `keyword`. One constraint is specific to this role: hue 70 and
below is the same colour as copper punctuation (`balanced_amber` measures dE 8.5
from it), which is why the warm band below yellow is closed to it.

**`parameter` must be named alongside `punctuation` in any build.** It defaults to
the punctuation **value**, not the punctuation **role**, so a build that moves
`punctuation` alone silently leaves parameters behind, and nothing errors.

## func

`Function`, `Identifier`, `@markup.link`.

| value | hex | numbers | verdict |
| --- | --- | --- | --- |
| `azure` | `#1d98cd` | hsl(198,75,46), L\* 59.1, C\* 38.5 | the base-build selection |
| `vivid` | `#359ee9` | hsl(205,80,56) | **LIVE in custom-latest**, retained on review 2026-09-07 |
| `deeper` | `#2797e7` | hsl(205,80,53) | — |
| `brighter` | `#268bd2` | — | the theme's own blue500 |
| `blue300` | `#49aef5` | — | — |
| `balanced` | `#4488ab` | C\* 27.2 | reads muddy on this background |

## type

`Type`, `@type.builtin`, `@constructor`. Setting the base `Type` group is the
whole fix: `@type`, `@type.builtin`, `@type.definition`, `Typedef` and `Structure`
all link to it, and so does every `@lsp.type.*` group (inert here, since
`lua/plugins/lsp.lua` nils `semanticTokensProvider` on attach, so treesitter is
the only painter).

Hard to place for two reasons. TSX tags every imported PascalCase name as `@type`,
React components included, so it is the densest capture there and genuinely rare
in Go and Python. And the blue band is full: String/member cyan sits at h187 and
Function at h250, leaving only the middle.

**Closed 2026-09-07.** The base build keeps the historical bright selection;
`custom-latest` uses `nvim_type` after dense JS/TS objects exposed the final
practical issue. See item 8 of `../todos/theme/syntax-palette-followups.md`.

| value | hex | numbers | verdict |
| --- | --- | --- | --- |
| `sky` | `#0edfff` | h220, L\* 82.0, C\* 43.6, 11.79:1 | the only rung in the blue band clearing dE 20 against Function (20.7); everything at L\* 74–78 scores 13–18. Rejected on sight as too bright: it buys that separation purely with lightness |
| `sky_calm` | `#56cae7` | h225, L\* 76.0, C\* 34.0, 9.96:1 | tried 2026-08-09, rejected after a pass over Go/Lua/TS/TSX. Scores well in isolation, but h225 sits **between** String (187) and Function (250), so it reads as ambiguous rather than distinct: String separation falls to 18.8 where `#7dcfff` holds 25.5. A worst-neighbour score cannot see that, only reading real files can |
| `sky_soft` | `#49ddff` | h225, C\* 39.6, vs Function 19.8 | — |
| `sky_softer` | `#61dbff` | h230, C\* 36.5, vs Function 19.0 | — |
| `sky_dim` | `#39cce9` | h222, L\* 76, C\* 38 | dE 4.6 from `sky`, borderline |
| `tokyonight` | `#7dcfff` | h249, L\* 79.7, C\* 33.5, 11.08:1 | **the base selection.** Restored 2026-08-09 after three replacements were tried and rejected on real files. Shares h249 with Function and splits on lightness alone (dE 16.2), rule 1 broken knowingly. What carries the pair is the 20.6 L\* gap, the largest of any candidate; it is also 25.5 from String where the closest rival managed 18.8 |
| `vscode_entity` | `#c0caf5` | h284, C\* 22.9 | rejected 2026-08-09, read "flat". De-accenting via chroma failed here exactly as on the keyword ladder: treat chroma as presence in this palette, never as the calming lever |
| `periwinkle` | `#a7b1fe` | h290, C\* 42.0 | measured best of everything tried (worst 20.9, and it dissolved the Type/Function pair entirely) and still lost on looks |
| `nvim_type` | `#2ac3de` | 15.2 from func, 16.4 from string | **LIVE in custom-latest** |
| `vscode_support` | `#0db9d7` | 12.7 from func | rejected |

## boolean

`true` / `false`, painted through `Boolean` in `init.lua`.

**Added 2026-09-08.** Before that the whole chain `@boolean` -> `Boolean` ->
`Constant` resolved to the theme's cyan `#29a298`, byte-identical to `@string`
**and** `@number` — a boolean was indistinguishable from a string.

Modelled on Tokyo Night's `orange` `#ff9e64` (the value the VSCode
`enkia.tokyo-night` theme also uses for booleans) by reproducing its
**relationship**, not its hex — the same invariant used for `LineNr`:

| | bg L\* | body L\* | orange L\* | orange vs body |
| --- | --- | --- | --- | --- |
| Tokyo Night (night) | 10.1 | 81.9 | 74.0 | **−7.9** |
| ours | 4.7 | 76.0 | 68.0 | **−8.0** |

So the equivalent on our brighter body text is L\* 68, not 74. Copying `#ff9e64`
verbatim would sit only 2.1 L\* under body and read hotter than TN intends,
because our background is 5.4 L\* darker (9.35:1 here vs 8.40:1 on TN's own bg).

| value | hex | numbers | verdict |
| --- | --- | --- | --- |
| `tokyonight_dim` | `#ed8e55` | L\* 68.0, C\* 54.8, h55.5, 7.79:1 | tried first; **blurred into salmon** (dE 20.2, 16° hue) and was replaced |
| `tokyonight` | `#ff9e64` | L\* 74.0, C\* 54.6, h55.6, 9.35:1 | TN exactly as shipped; only −2.1 L\* under body here |
| `amber` | `#d19c59` | L\* 68.1, C\* 44.1, h73.8, 7.80:1 | **SELECTED 2026-09-08.** dE 27.4 / 34° from salmon, still reads warm |
| `gold` | `#b5a73b` | L\* 67.9, C\* 55.9, h97.9, 7.75:1 | dE 50.3 / 58° — max clarity, but yellow not orange |

**Why this hue is available at all: dose.** The amber band was closed to
`punctuation` because that role is ~19% of TSX ink and would have put gold back
on screen. Booleans are a fraction of a percent, so rule 3 permits a bright,
saturated mark where a dense role could not have one.

**The one thing to watch.** With `keyword` on copper (hue 58) this lands 2° away
in hue, separated by lightness alone at dE 16.2 — rule 1 broken knowingly. That
pairing is not currently live: on the base violet keyword the two are dE 82 apart
with a 105° hue gap, no warm conflict at all. If copper is ever reinstated for
`keyword`, switch this role to `amber` at the same time.

`@number` was deliberately left alone — `Constant` keeps the theme's cyan, so
numbers are still identical to String. Give it its own role if that matters.

## member

Fields and properties (`@variable.member`, `@property`, `@tag.attribute` by
link).

**Reopened and APPLIED 2026-09-08.** `custom-latest` sets `member`, and
`init.lua` paints `@variable.member` again, so a value set there now takes effect.
Candidates are still being compared, so no single value is recorded as settled
here — read `custom-latest` in `variants.lua` for what is live right now.

From 2026-08-09 until then the paint line was commented out, which made this role
a **silent no-op**: setting `member` in a build changed nothing, because nothing
read `palette.member`. If a `member` change ever appears to do nothing again,
check that line in `init.lua` first.

It had been turned off because rose was only ever a measurement winner, never
judged on looks, and it did not hold up in huge files (rule 4). Living with the
String collision was preferred at the time.

`@property` is a **different group** and is still on the theme default, where it
exactly duplicates Function `#359ee9`. It covers struct-literal keys, object/dict
keys and JSX attributes (`@tag.attribute` links to it), so a TS `mode: 'x'` still
renders its key in the function colour. It needs a role of its own before being
recoloured, not `palette.member` — the two land on the same line constantly and
would collide. A commented `hl["@property"]` line sits next to the member one.

Guidance if retuning: clear String, and stay **in** the accent band (L\* ~60),
because these symbols appear on nearly every line and a bright value drains its
neighbours. Scores below predate the keyword move to violet, so
re-measure anything that was close to keyword.

| value | hex | numbers | verdict |
| --- | --- | --- | --- |
| `rose` | `#b67faf` | h330, L\* 60.1, C\* 33.6, 6.02:1, worst 21.4 | best score measured here, level with String (60.4) and Function (59.1) rather than above them. Rejected on looks 2026-08-09 |
| `iris` | `#8d8de3` | h295, L\* 62.0, C\* 48.0, worst 20.9 | best non-rose |
| `purple` | `#a17bcc` | h310, L\* 58, worst 20.7 | one step further round |
| `rose_warm` | `#be7ca6` | h340 | — |
| `rose_cool` | `#ac82b7` | h320 | — |
| `mauve` | `#c49ac6` | L\* 68.7 | rejected, above String and Function |
| `violet` | `#9b9fec` | L\* 67.9 | rejected, above the accent band |
| `tokyonight` | `#73daca` | dE 15.7 | rejected, 5° from String cyan |

Non-purple families measured and rejected on collisions: green-teal hits keyword
at h135 (20.8) and String from h150 on (15.9 falling to 10.6); tan hits
punct/tag and keyword from both sides (15.5–17.9).

---

## Coverage and dose findings

These are the measurements that keep getting re-derived. All are **coverage**
problems, and rule 4 applies: retuning a hex cannot change how much of the screen
a colour covers.

### Symbolic operators are not keywords (2026-08-08)

The theme paints `Operator` with green500, the same colour as keywords, which is
what makes the keyword colour feel brighter in some files but not others:

| file | real keywords | symbolic ops | total |
| --- | --- | --- | --- |
| `ai-prompts.lua` | 5.4% | 2.1% | 8.0% |
| `solarized-osaka/init.lua` | 0.2% | 0.5% | 0.7% |

An 11× spread between two Lua files in the same repo with the **same** colour, so
the variation is density, not value. Symbolic operators are 26% of it in the
dense file and 74% in the config-style one, because every `key = value` line in a
Lua table pays for one. Dropping them to neutral cuts the dense file to 5.9% and
the config file to 0.2%: it flattens the difference **between** files rather than
dimming the colour everywhere. `=` is punctuation, not a keyword, so this is also
the more correct reading. `and`, `or`, `not` are the exception and stay on the
keyword colour.

### JSX tags (2026-08-09)

Reference measurement, taken by walking treesitter captures over two regions of
the **same** production file and resolving `@cap.tsx` → `@cap` the way the
highlighter does:

| region | coverage | marks | run length |
| --- | --- | --- | --- |
| logic-heavy (hooks, consts) | 12.5% | 74 | 2.0 ch |
| markup-heavy (nested JSX) | 34.7% | 91 | 4.3 ch |

**Known cost, accepted deliberately:** the punctuation colour reaches 30.2% of
glyphs in markup-heavy TSX against 12.5% in logic-heavy TSX of the same file.
Tags are most of that, because a tag is a **word** where a bracket is one
character. This is a dose problem, not a colour problem. The only lever that works
is moving captures off the list, and the two candidates
(`@variable.parameter`, `@punctuation.bracket`) were measured to be 88% of that
colour in logic-heavy regions, so moving them would strip the files that already
read well.

### `${}` is a mode switch, not a bracket

Deliberately **not** grouped with brackets even though it is brace-shaped: it
marks where a string stops being text and becomes an expression, so it carries
meaning and the "punctuation carrying no meaning worth a hue" rule does not apply.

It also has to survive being read **inside** the string colour, which is the
measurement that settled it. Separation from `@string` cyan `#29a298`: copper
46.9, the accent yellow 32.9, the neutral grey only 17.7. It was grouped with the
brackets in the first cut of the 2026-09-05 rebuild and moved out because the
marker was disappearing into the string.

Language-free in practice: Go and Lua emit **zero** of this capture, and it is
0.16% of TSX / 0.24% of TS.

---

## Grammar traps in `init.lua`

Cases where one character or name matches two captures and query order decides
the winner. Each of these is a per-language pin, not a preference.

- **Lua `{` is both `@punctuation.bracket` and `@constructor`.** The same
  character, matched twice, so Lua's `@constructor` is a grammar quirk rather
  than a construct (Go's composite literals are plain `@punctuation.bracket`).
  Without the `@constructor.lua` pin, a build that moves `palette.parameter`
  recolours every `{` `}` in every Lua file. Pointing `@constructor` at the
  **type** colour was tried 2026-08-07, reasoned from TSX, which turned out not
  to use the group. The effect was Lua-only: blue `{` `}` beside copper `[` `]`
  in the same expression. Reverted 2026-08-09.
- **A TSX tag matches both `@tag` and `@tag.builtin`, and query order decides.**
  Measured on real JSX: `Accordion`, `Button`, `If`, `SadFaceSVG` resolve through
  `@tag`, while `div`, `h2` **and** `DragAndDrop` resolve through
  `@tag.builtin`. So splitting the two captures does **not** split "HTML element"
  from "React component": it renders `<DragAndDrop.Droppable>` as two colours
  inside one name. Both captures must therefore carry the same value, and
  `@tag.builtin.*` is listed explicitly rather than inherited so a drift in the
  theme cannot bring the split-colour tag name back. Sending `@tag` to the type
  colour was tried 2026-08-09 and rejected.
- **`@variable.typescript` / `@variable.javascript` have no `.tsx` / `.jsx`
  equivalent** in the theme, so `.tsx`/`.jsx` fell back to base `@variable` while
  `.ts` variables were yellow. Both are linked back to `@variable`.
- **`@keyword.import` and `@keyword.operator` cannot go through `paint`.** Both
  are stored as bare string links whose target is outside the painted lists, so
  skipping them (correct for links like `@keyword.return` → `@keyword`) would
  leave them resolving somewhere wrong. `@keyword.import` → `Include` → `PreProc`
  → red500, a saturated alarm red 31° from the error red, so `import` and Go's
  `package main` read as diagnostics. `@keyword.operator` → `@operator` →
  `Operator`, which goes neutral, taking `and`/`or`/`not` with it.
- **`@module`** links to `Include` → `PreProc` → red500 at 4.01:1, same
  diagnostics problem in every language except Go. Painted `c.base2` (`#ede7d3`),
  which is not byte-identical to the `#eee8d5` the old Go-only override
  hardcoded, but dE2000 0.45 apart (below just-noticeable), so Go is unchanged in
  practice.
- **`@attribute` fell through to the error red** (fixed 2026-09-08). Decorators
  -- Python's `@dataclass`, and the TS/NestJS/Angular `@Injectable()` family --
  link `@attribute` -> `PreProc` -> `#db302d`, which is byte-identical to
  `DiagnosticError`, `DiagnosticSignError`, `DiagnosticFloatingError`, the error
  undercurl and `ErrorMsg`. So a decorator was painted in the exact colour that
  means "error": measured at 8.9% of a decorated Python class and 12.4% of a
  NestJS-style controller. Now pointed at `palette.punctuation`, because
  `@attribute.builtin` (`@property`, `@staticmethod`) already resolved there via
  `Special` -- before the fix, a builtin and a user-defined decorator on adjacent
  lines rendered in two different colours, one of them the error red. Same defect
  and same fix shape as `@keyword.import` and `@module` above.
- **`@constant.macro` had the identical problem**, via `Define` -> `PreProc`.
  Fixed alongside the named-constant change and pointed at `palette.boolean`.
- **Object keys were two colours depending on quoting** (fixed 2026-09-08). The
  base ecma queries file a BARE key as `@variable.member` and a QUOTED key as
  `@string`, so `{ Cash: 1, 'Credit Card': 2 }` rendered its two keys in salmon
  and cyan for no reason but the quotes. The same split exists in Lua
  (`@property` vs `@string`) and Terraform (`@variable.member` vs `@string`);
  YAML is the only language that was already consistent.

  It **cannot** be fixed with a highlight override, because the grammar gives an
  object key and a member *access* the same capture name. So
  `after/queries/{typescript,tsx,javascript,lua,terraform}/highlights.scm`
  re-capture the key position as `@variable.member.key`, which `init.lua` links
  to `@string`. Member access (`obj.attr`, `var.environment`,
  `aws_s3_bucket.artifacts.arn`, `t.field`) keeps `@variable.member` and stays on
  the member colour — verified per language.

  Two mechanics worth remembering: a capture on a **wrapper** node does not
  override a deeper one (Terraform's `object_elem key:` had to be captured at the
  `identifier` / `string_lit` leaf), and an **unknown node name makes the whole
  query file error out**, not just that pattern — which is why the javascript
  file has no `property_signature` rule (TypeScript-only node).

  Keys are linked to `@string` so a key sits with the value it introduces; the
  one-line alternative is `{ link = "@variable.member" }`, which puts keys on the
  member colour and keeps key and value distinct.

  Python and Go were left alone deliberately: there the quoted form is a genuine
  string literal used as a key (`d = {'a': 1}`, `map[string]int{"a": 1}`) rather
  than a quoted identifier, so it is a different case.
- **Markdown is prose, not a programming language**, so it keeps the theme's own
  colours. Deliberately left out of every painted list: `@markup.list`,
  `@markup.link`, `@markup.list.checked`, `@punctuation.special.markdown`,
  `@markup.list.markdown`, `markdownLinkText`, `markdownHeadingDelimiter`,
  `mkdCodeStart`/`End`, `htmlH2`. Headings are the one exception, below.
- **Native CSS keeps its grammar limitations.** Function names and their outer
  parentheses share one group; Dockerfile JSON-form command arrays still fall
  back to body text. Neither calls for retuning the core palette, and no parser
  or runtime hooks were added. Explicit links survive `css.vim`'s later
  `hi def link` without buffer hooks; `cssFunction`/`cssMathGroup` supply the
  colour of otherwise-uncaptured calc operators while their nested numbers,
  strings and function names keep their own groups.

---

## UI highlights set in `init.lua`

### Background: one value, one legitimate `on_colors`

The theme is **opaque** since 2026-09-04, background from `lua/config/ui.lua`.
`on_colors` is banned for the syntax ramp but correct for the background: the ban
is about names shared with the UI (`green500`, `orange500`, `blue500`,
`cyan500`), where a syntax choice silently repaints git signs and diagnostics.
Repainting the UI is the entire point of the background assignment, so the
propagation that makes the ramp dangerous is what makes this correct.

Measured non-syntax consumers of the ramp, which is how the keyword colour turned
git-added markers yellow on 2026-08-08:

| name | reaches |
| --- | --- |
| `green500` | GitSignsAdd, diffAdded, MiniDiffSignAdd, NeoTreeGitAdded, NvimTreeGitNew, GitGutterAdd, NeogitDiffAdd, neotest |
| `orange500` | dashboard, snacks, indent-blankline, rainbow delimiters |
| `blue500` | neogit, neotest, semantic_tokens, editor |
| `cyan500` | DiagnosticHint (`colors.hint` is an alias), Question, healthSuccess, MiniStatuslineModeOther, blink/cmp, lspsaga |

Why all of `bg`, `bg_float`, `bg_sidebar` and not just `bg`: the theme spreads
four other backgrounds around it and each shows up as a panel that does not match
the editor. `bg_float` reaches `NormalFloat`, `FloatBorder`, `FloatTitle`, i.e.
the oil browser, snacks pickers and explorer sidebar, blink-cmp's docs window and
the lazy.nvim UI. `bg_sidebar` reaches `NormalSB`, the `sidebars` filetypes
(`qf`, `help`).

`on_colors` runs **last** in the theme's colour setup
(`solarized-osaka/colors.lua` calls it after every derived value), so these
assignments are not overwritten and nothing needs recomputing. Lualine is
unaffected: it carries its own theme rather than reading `StatusLine`.

### WinBar

The theme links `WinBar` → `StatusLine`, whose background is `base03` (`#002c38`),
so it reads as a lighter strip against `Normal`. It is a real visible row in two
places: the global 1-row winbar from `options.lua`, and the padding row under
oil's path label. Linking to `Normal`/`NormalNC` makes the row take whatever
background the window already has, which is the point of a blank winbar. The
statusline itself is untouched.

### LineNr

The theme points `LineNr` at `yellow700` (`#664c00`), a dark but **saturated**
warm amber. Chroma is the problem, not lightness:

| group | value | L\* | C\* | hue | dL\* over bg | contrast |
| --- | --- | --- | --- | --- | --- | --- |
| solarized `LineNr` | `#664c00` | 34.0 | 42.9 | 84 | 28.8 | 2.33:1 |
| tokyonight `LineNr` | `#3b4261` | 28.6 | 20.1 | 287 | 18.5 | 1.74:1 |

Chroma is more than double tokyonight's, and h84 sat in the same warm family as
the syntax accents (the keyword was yellow at h98 when this was written; it is
violet now, but punctuation is warm, so the collision argument still holds). The
gutter read as **content competing with code** rather than as chrome, which is
what makes relative-jump numbers tiring to scan.

`#2d3f43` is a low-chroma cool grey on the background's own hue, and it reproduces
tokyonight's **relationship** rather than its absolute value, which is the right
invariant when the two backgrounds differ (L\* 5.2 here vs 10.1 there):
L\* 25.3, C\* 7.7, dL\* 20.1, 1.71:1 against tokyonight's dL\* 18.5, 1.74:1.

If it is ever too dim, `#33474b` is the one step up (dL\* 23.5, 1.92:1). **Do not
go back toward a saturated hue to make it visible**: raise lightness, keep C\*
under about 10. All three groups (`LineNr`, `LineNrAbove`, `LineNrBelow`) carry
explicit values in the theme rather than links, so all three have to be set.

### LSP documentation surface

Hover, signature help, diagnostic floats, mouse hover, blink's doc popup.

The original problem: `bg_float` was `base04`, byte-identical to `bg`, so a float
was the same colour as the editor and only differed by being opaque. Under the old
`transparent = true` it was worse: `Normal` bg was `NONE`, so the editor showed
Ghostty's `#031219` blended with the wallpaper, landing anywhere from L\* 4.1 to
L\* 12.9, with the float's L\* 5.2 sitting **inside** that band.

A raised `base03` panel (L\* 15.94) was tried 2026-08-07 and rejected on looks: it
read as a lighter box pasted over the editor. Separation now comes entirely from
the border and a brighter foreground. **Do not reach for a darker bg to
compensate**: bg is already L\* 5.15 and the darkest usable step is −2.5 L\*,
below the perceptual threshold.

Deliberately **not** applied to `NormalFloat`: `SnacksPickerBorder` and
`SnacksPickerPreviewTitle` read `c.bg_float` and the picker body falls back to
`NormalFloat`, so touching it repaints the picker. These groups are reached only
by doc floats, via `winhighlight` in `config/keymaps.lua`.

`LspDocFloat`'s `fg` paints the **description prose** and essentially nothing
else, which is why it is worth a value of its own. Measured 2026-08-09 by dumping
the top treesitter capture of every cell in a real vtsls hover: markdown paragraph
text resolves to `@spell` and `*@param*` tags to `@markup.italic`, both
attribute-only, so the prose falls through to `Normal`. Everything else already
carries a colour: the fenced signature gets injected captures, inline chips get
`LspDocInlineCode`, links get `@markup.link`.

It was `base1` (`#adb7b7`, L\* 73.7, 9.19:1) until 2026-08-09, which made the
description the **brightest** text in the popup, above the signature it describes
(`@variable` L\* 69.0, `@function.call` L\* 59.1) and above the editor's own body
text. VSCode runs that hierarchy the other way round, and the inversion is what
made hover docs read as a wall of text. `c.fg` (`#839395`, L\* 59.8, 5.90:1) drops
the prose 13.9 L\* below the signature's identifiers and still clears AA.

**RAISED 2026-09-22 to `body.faded` (`#919e9f`, L\* 64.1, 7.01:1).** `c.fg` is the
theme's UPSTREAM body value, and this config repaints `Normal` from `palette.body`
(`#a0b6b8`), so the doc surface had silently drifted 12.7 L\* below the editor's
own text. Two measurements decided it:

- `c.fg` sat **dE00 1.3** from the operator grey `#7f9195`, which appears in the
  same popup (2.1% of the ink, inside the fenced signature). That is below the
  just-noticeable threshold: prose and operators were not similar, they were the
  same colour. `faded` clears it at 5.0.
- Separation from `Comment` went 11.6 -> 15.5, out of the band where prose starts
  reading as a comment.

Scored against a measured glyph census of a live vtsls/lua_ls hover (1015 inked
glyphs inside the float, prose 71.0%, inline code 12.7%, String 5.4%), weighting
each neighbour by its dose:

| prose | contrast | worst neighbour | composite |
| --- | --- | --- | --- |
| `#839395` (was) | 6.06:1 | Operator, dE00 1.3 | 49.9 |
| `#919e9f` (now) | 7.01:1 | Operator, dE00 5.0 | 74.9 |
| `#93a3a6` | 7.41:1 | `@variable`, dE00 5.7 | 78.3 |
| `#9eabac` base0 | 8.19:1 | `@variable`, dE00 4.1 | 70.5 |

Composite is contrast scored against AAA 7:1 plus worst-neighbour dE00 scored
against 10, 50/50 — a ranking aid, not a standard. Note `base0` scores WORSE
despite the best contrast, because it closes on `@variable` in the code block:
**more contrast is not automatically more readable on this surface.** `#93a3a6`
is the best of the four and holds the old chroma rather than trading it for
lightness; it was left on the table because `faded` already existed as a rung.

**Do not go dimmer.** The next ramp step, `base00` (`#637981`), is 4.11:1 (under
AA) and sits only 5 L\* off the comment colour. There is exactly one usable value
below, so dimming is not a knob to tune.

Border and title need **different weights**, which is the whole point:

- **border** is chrome, so it wants to be barely there. `yellow700` sits at
  2.33:1 against the float, in the same register as `BlinkCmpMenuBorder`'s
  `base02` (1.43:1). A syntax accent was tried first at ~7:1 and read as a heavy
  box. Deliberately not `palette.type`: the border used to follow it, so every
  retune of the syntax type colour silently moved this chrome with it.
- **title** is actual text, so it needs contrast, which is why it follows
  `palette.keyword` rather than the border's amber. When written, the keyword was
  yellow so title and border shared a hue family; the keyword moved to violet on
  2026-08-10 and the title followed automatically. Left alone deliberately: it
  still reads fine, and the alternative is hardcoding a hex that stops tracking
  the palette.

`LspDocInlineCode` (`#8ab4d8`, `bg = NONE`) is the inline code spans inside a
hover doc, the `"nil"` / `"number"` chips in a Lua signature. The theme paints
`@markup.raw.markdown_inline` yellow on a dark-green fill (`#b28500` on
`#2c3300`), a row of amber boxes in a float that has no other background. This is
the same colour CodeCompanion uses for the same job
(`CodeCompanionInlineCode`), so inline code reads identically whether it comes
from the chat or an LSP doc; `bg = NONE` matches that too, making the chip
coloured text rather than a filled box. Scoped via `winhighlight` in
`config/keymaps.lua` rather than globally, because that capture is also every
inline span in a real `.md` file, and markdown keeps the theme's colours.

### Completion menu

Uses `c.bg_popup`, **not** `c.bg_float`, for the whole family (`Pmenu`,
`BlinkCmpMenu`, `BlinkCmpDoc` and their borders). Both were `base04` until
2026-09-04, when `on_colors` repointed `bg_float` at the shared editor background,
silently dragging the completion menu with it and leaving it with no panel of its
own: measured, the menu interior and the code beside it were both `#031216`, so
only the selected-row band separated them. `bg_popup` is still `base04`
(`#001419`), exactly the darker background these had before, and it is the
semantically right key. These are popups, not floats.

### Markdown headings

The theme links the **generic** `@markup.heading` to `Title` (orange500), and
`Title` is shared by help files, pickers and `:set all` output. Overriding the
markdown-specific `@markup.heading.{1..6}.markdown` recolours `.md` titles
without touching `Title` or any other filetype. render-markdown leaves heading fg
to treesitter (`foregrounds = {}`), so this is what paints them.

### Cursor line

**LIVE at `#032732` since 2026-09-23.** It was tried on 2026-09-08, judged "not
bad", parked at `bg = NONE`, and turned back on. The `cursorline` **option** is
always on, so the highlight is the whole switch.

`OilCursorLine` (`#063540`) and the outline panel's `CursorLine → Visual` remap
stay: a LIST wants a heavier row marker than a text buffer, where the band has to
sit under code without dimming it.

**The theme's own default is NOT used, and that is the finding.** Upstream ships
`CursorLine = { bg = c.base03 }` = `#002c38`. Re-measured 2026-09-23 against the
**retuned** palette and the real background `#001014` (the table below was taken
on the dead salmon build, against a different bg), it is one rung too light:

| band | L\* | dL\* over bg | band/bg | worst accent | verdict |
| --- | --- | --- | --- | --- | --- |
| `#032732` | 13.8 | +10.0 | 1.236:1 | violet `#a17bcc` 4.64:1 | **live**, AA-safe |
| `#002839` | 14.5 | +10.7 | 1.257:1 | violet 4.57:1 | last AA-safe rung |
| `#002c38` | 15.9 | +12.1 | 1.307:1 | violet 4.39:1 | theme default — **sub-AA** |
| `#063540` | 19.9 | +16.1 | 1.467:1 | violet 3.91:1 | oil's list band |

At the theme default the violet keyword lands at 4.39:1 and the operator grey at
4.51:1 — keywords fall under AA on the one line you are reading. The worst accent
is now the **violet keyword**, not salmon: salmon is gone from the build.
Comments unavoidably dip (4.03:1 → 3.26:1); every cursorline does that.

Synthesised on the background's own hue rather than taken from the theme's ramp,
and bounded from both sides:

- **Floor** — it has to be seen. dL\* +9.11 over `bg`, band/bg ratio 1.213:1,
  which reproduces tokyonight's own cursorline relationship (+9.2 dL\*, 1.27:1).
  Same "match the relationship, not the hex" invariant as `LineNr`.
- **Ceiling** — it must not push text under AA on the cursor row. The dimmest
  accents bind: at this value salmon is 4.63:1 and violet 4.66:1.

**The table below is the ORIGINAL 2026-09-08 measurement**, kept for the method,
not for its numbers: it was taken on the salmon build against the older
background, so its ratios are ~0.01–0.02 off the live ones above. Where the two
disagree, the table above wins.

| band | L\* | band/bg | worst accent | note |
| --- | --- | --- | --- | --- |
| `#032732` | 13.8 | 1.213:1 | 4.63:1 | the parked value, AA-safe |
| `#002839` | 14.5 | 1.234:1 | 4.55:1 | last AA-safe rung |
| `#002c38` | 15.9 | 1.283:1 | 4.38:1 | theme `base03` — **sub-AA** |
| `#063540` | 19.9 | 1.441:1 | 3.90:1 | oil's popup band |

"worst accent" is salmon; violet tracks it within 0.03. Comments unavoidably dip
(3.48:1 → 2.87:1) — every cursorline does that.

**More chroma is not an option here.** sRGB's gamut narrows to a point at black,
so at this lightness C\* is already at the ceiling on this hue: every attempt to
raise it clipped and came back as extra *lightness*. Same geometry as the hard
floor documented in `lua/config/ui.lua`. Lightness is the only axis.

### Named constants

`@constant` (SCREAMING_SNAKE names like `EMPTY_GUID`) shared the theme's
`Constant` cyan with `@string` **and** `@number` — all three dE2000 0.0, so an
imported constant was the same colour as a string literal. Pointed at the
`boolean` value on 2026-09-08: a named constant and a boolean are the same class
of thing, and Tokyo Night groups them together.

Set on the **captures**, not on the `Constant` base group, and the difference is
load-bearing: **`Number` links to `Constant`**, so assigning the base group would
silently recolour every numeric literal. That may be wanted — Tokyo Night does
exactly that, and it would close the `@number` == `@string` duplicate — but it is
a separate decision. The one-liner is `hl.Number = { fg = palette.boolean }`.

Measured cost of taking it: amber goes from 8.3% → 21.7% of a numeric TS file and
2.7% → 16.2% of a Helm values file, with avg run dropping to 2.7–3.4 (fragmented).
Amber was chosen bright *because* it was rare, so that is the trade. A quieter
relative such as `#c2a079` (same hue, C\* 26, dE 7.0 from amber) would carry the
dose better if numbers ever do move.

`@constant.macro` is included because it is a constant and because its default was
a defect: it linked to `Define` → `#db302d`, byte-identical to `DiagnosticError`.

`@constant.builtin` is deliberately **not** included — it carries `nil`, `None`,
`null`, `undefined` and follows `Special` (the punctuation accent) on purpose.

### grug-far

- `GrugFarResultsMatch` defaults to linking `DiffText`, which in this theme is a
  near-black green band (`green900`), so the match looks faded. Overridden with a
  vivid bg and dark fg. Cyan deliberately, so it never reads like a vim `/`
  search hit: `Search` is yellow (`#b28500`), `IncSearch` is muted rose-red
  (`#c75b6b`).
- `GrugFarResultsStats` ("N matches in M files") defaults to linking `Comment`,
  which is dim against the panel, so the total is hard to read. Forced to the
  theme's lightest fg.

### Open item: snacks picker match

Setting `hl.SnacksPickerMatch` in `on_highlights` does **not** take effect:
something re-applies it to `DiffText` after `on_highlights` runs (snacks
registers picker hl groups lazily on its own `ColorScheme` hook). Needs setting
via a late `ColorScheme` autocmd or in the snacks plugin spec instead. Scope:
snacks picker only.

---

## Builds (`variants.lua`)

| build | what it is |
| --- | --- |
| `solarized-osaka-custom-latest` | the selection we run, **default** |
| `solarized-osaka-custom-v1` | the copper build `custom-latest` replaced (2026-08-11 → 09-05) |
| `solarized-osaka-custom-v2` | `custom-v1` on the warm keyword (yellow) |
| `solarized-osaka-custom-v3` | `custom-v1` on the softer terracotta punctuation |
| `solarized-osaka-original` | upstream craftzdog, nothing of ours applied |

**`custom-latest` is a moving name and the numbered ones are not.** It always
means "whatever we run today", so `config.lua` never has to be repointed and
muscle memory never goes stale. The numbered builds are frozen snapshots of what
it used to be, newest first.

**When `custom-latest` is superseded:** give its current values the next number
(e.g. `custom-v4`) with the reasoning that justified them, **then** move the new
values into the palette. Never edit a numbered build. The whole value of one is
that it still renders what it rendered on the day it was named.

The point of `original` is a reference build to diff against, and it is a precise
thing: the **only** deviation this config makes from upstream is `on_highlights`.
`transparent = true` is not ours, it is the plugin's own default. So `original` is
exactly "the same theme with our `on_highlights` switched off", and any difference
between it and `custom-latest` is one we introduced. It is deliberately not a full
`config.setup({})`, which would also throw away anything the plugin spec sets for
non-syntax reasons, making a visible difference ambiguous between ours and a
side effect of the reset.

Costs nothing at startup: nothing in `variants.lua` is read until `:colorscheme`
names a build, because the only entry points are the one-line files in `colors/`.

### How a build works

Two kinds of override, applied the same way: swap, rebuild, swap back.

- **`palette`** swaps a role value in `palette.lua`. `on_highlights` is a closure
  that reads the palette when it **runs**, and `require` hands every caller the
  same cached table, so a build does not re-paint a list of highlight groups.
  Every group using the role follows automatically, including ones added later,
  so there is no group list to drift out of sync with the theme.
- **`config`** swaps an entry in the plugin's own resolved options. Only
  `original` uses it, to disable `on_highlights`. `options` is **reassigned**
  rather than mutated because the plugin's own `extend()` reassigns it too, and
  every consumer reads it through `require("solarized-osaka.config").options` at
  call time.

Restoring afterwards is load-bearing in both cases: the tables are shared, so
leaving one mutated would make a later `:colorscheme solarized-osaka` silently
keep this build's colours.

### Adding a build

1. Add an entry to `builds`. Any role in the palette works, not just `keyword`,
   and a build may change several at once.
2. Create `colors/solarized-osaka-<name>.lua` containing one line:
   `require("colorschemes.solarized-osaka.variants").load("<name>")`

Builds are for values worth **living with**, not for comparing candidates. A
candidate belongs in the palette's variant tables with its numbers; it only earns
a build once you would actually switch to it. The 2026-09-05 rebuild broke that
rule on purpose (ten builds existed at once so they could be compared in real
files) and then collapsed back to the winner. Do that again the same way: many
builds while deciding, none afterwards.

### `vim.g.colors_name` stays `"solarized-osaka"`

Deliberate. Do not "fix" it to the build name.

It is not a label, it is the key plugins look themselves up by. lualine resolves
`lualine/themes/<colors_name>` and the theme ships exactly one, so naming this
`solarized-osaka-custom-v1` orphans that lookup and lualine silently falls back to
its auto theme: a visibly duller statusline, with no error. Anything else keyed
the same way breaks the same way.

So build names are **entry points, not identities**: they are what you type, not
what the editor calls itself afterwards. A build only ever changes syntax colour,
so it **is** solarized-osaka as far as the rest of the editor is concerned.
Verified by diffing all 629 highlight groups across `custom-v1` and `custom-v2`:
only the keyword groups differ.

The trade is that `:colorscheme` reports the base name, and a plugin that reloads
via `:colorscheme <g:colors_name>` drops back to `custom-v1`. That is the safe
direction to fail, and the reason bare `solarized-osaka` must keep meaning
`custom-v1` rather than being repointed at `original`.

---

## Silent-failure traps in these files

Also listed in [`silent-failure-surfaces.md`](silent-failure-surfaces.md), and
marked in code with `-- WARN: SILENT FAILURE`.

- **`transparent` must be an explicit `false`.** The plugin defaults it to
  `true`, so deleting or commenting the line re-enables transparency rather than
  disabling it.
- **`bg_popup` in `on_colors` is a no-op.** The theme writes `Pmenu` from
  `c.base02` directly, so overriding `bg_popup` there changes nothing. It is
  deliberately not set, and must stay that way, because the completion-menu family
  in `on_highlights` is pointed at it precisely so the menu keeps a darker panel.
- **`bg_statusline` in `on_colors` is a no-op.** It looks like the key for the
  statusline and winbar and is not: the theme writes `StatusLine = { bg =
  c.base03 }` directly and links `WinBar` to it, so overriding it changes nothing
  visible. Measured: `WinBar` stayed `#002c38`.
- **A build role must be `false`, never `nil`.** `nil` is not a value in a Lua
  table, it is the absence of the key, so `variants.load` iterates with `pairs`,
  never sees it, and the override silently does not happen. The build renders as
  if the line were not there. Applies to `delimiter`, `body`, `bracket`. Verified.
  (The related leak, a build's colour surviving into the next `:colorscheme`
  because `pairs` skipped a nil while restoring, is closed for these roles only
  because their defaults are real values rather than `nil`. Keep it that way.)
- **A duplicate role key in the palette's `return` block is not an error.** The
  last assignment wins and the earlier line becomes a lie that reordering would
  activate. It happened on 2026-09-06 with `delimiter`. After editing a role,
  check it appears once:
  `grep -c "^  delimiter = " lua/colorschemes/solarized-osaka/palette.lua`
- **`paint` values are heterogeneous.** A group may hold a highlight table **or**
  a bare string, which is the theme's shorthand for a link (`@keyword.return` is
  the string `"@keyword"`). Merging into a string throws, and a link needs no
  help since its target is in the same list. `paint` also merges `fg` rather than
  assigning a bare table, to preserve italic on keywords, bold on markdown
  delimiters, underline on links, and the background on markdown code.
