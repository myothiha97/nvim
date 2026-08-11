# Syntax Palette: Follow-ups

## Status

> **Superseded for current values — see item 6 and
> `notes/syntax-palette-decisions.md`.** Everything in this Status section and in
> the sections below it describes the palette as of **2026-07-22**, before the
> 2026-08 rework moved the palette from colour-named slots to role-named ones.
> It is kept as the historical record of *why* things were tried, not as a
> statement of what is set today.
>
> **One live item: 8 (`Type` brightness).** It is the only role in the palette
> not yet optimised, it is not blocking, and it needs a real `.ts` file with a
> large `import type` block to judge. Review at the 2026-09-20 checkpoint.
>
> Closed on 2026-08-11: item 7 (symbolic logical operators off `base0`) and the
> punctuation rework (terracotta `#b55f4a` → copper `#be6421`, recorded in
> `notes/syntax-palette-decisions.md` rather than as an item here, since it was
> never filed as one). Item 6 (`@punctuation.delimiter` on the keyword colour)
> closed 2026-08-10. Item 5 closed 2026-08-09 with yellow `#aea10c`, itself
> superseded 2026-08-10 by warm violet `#a17bcc`.
>
> Both alternatives stay one command away: `:colorscheme solarized-osaka-custom-v2`
> for the warm keyword, `-custom-v3` for the softer terracotta punctuation.

**Closed 2026-07-22 as WONTFIX.** A real green/yellow collision was found,
measured, and a working fix was built and tested on real files — then reverted.
Every colour that separates cleanly looks worse than the collision does. The
palette is back to its 2026-07-21 state and that is the intended end state.

Current selections:

| role | value | L\* | chroma C\* | Lab hue |
| --- | --- | --- | --- | --- |
| yellow | `#aea10c` (`balanced`) | 65.4 | 67.4 | 97.9 |
| cyan (theme) | `#2aa298` | 60.4 | 34.6 | 186.9 |
| green | `#849900` (`solarized`) | 59.7 | 66.9 | 110.7 |
| blue | `#1d98cd` (`azure`) | 59.1 | 38.5 | 249.9 |
| red | `#b55f4a` (`terracotta`) | 50.1 | 42.9 | 40.1 |

Green and yellow measure **dE2000 9.9** apart. That is below the threshold where
small text glyphs stay distinguishable, and it is accepted knowingly. Do NOT
reopen the palette outside a scheduled config session, and do not "fix" this
without asking — it has already been fixed once and rejected.

### Benchmark against other dark themes (2026-07-22)

The palette was suspected of running bright and was measured against
`tokyonight-night` and `catppuccin-mocha`, both installed, by loading each
colorscheme and querying the same highlight groups.

| | mean accent L\* | mean perceived L\* | mean contrast | max C\* | background L\* |
| --- | --- | --- | --- | --- | --- |
| **solarized-osaka** | 59.2 | **65.6** | **6.0:1** | **67.4** | **3.9** |
| tokyonight-night | 74.3 | 78.9 | 8.5:1 | 55.0 | 10.1 |
| catppuccin-mocha | 79.0 | 83.4 | 9.5:1 | 45.7 | 12.0 |

"Perceived L\*" applies the Fairchild-Pirrotta Helmholtz-Kohlrausch correction,
which *flatters* saturated colours — and this palette still comes out the dimmest
of the three by 13-18 points.

**Conclusion: it is not too bright. If anything it runs dim.** What is unusual is
chroma — max 67.4 against 55.0 and 45.7 — on a background that is itself 6-8 L\*
points darker than theirs. High chroma against near-black is what reads as glare.

Practical consequence: when this palette feels "too bright", the fix is **chroma,
never lightness**. Lowering lightness makes an already-dim palette dimmer while
leaving the actual cause untouched.

The one genuine weak spot the benchmark surfaced is not yellow:

- `@variable.parameter` terracotta `#b55f4a` sits at **4.33:1**, just under the
  WCAG AA 4.5:1 floor for body text.
- `Comment` `#576d74` sits at 3.54:1, though dim comments are intentional.

### Terracotta is the accent-band outlier, not yellow

Sorted by perceived lightness (Helmholtz-Kohlrausch corrected):

| accent | perceived L\* | contrast |
| --- | --- | --- |
| yellow | 70.8 | 7.27:1 |
| blue | 66.9 | 5.91:1 |
| green | 66.8 | 6.02:1 |
| cyan | 66.3 | 6.18:1 |
| **terracotta** | **57.3** | **4.33:1** |

Four accents cluster inside 4.5 points; yellow leads the next by only 3.9.
Terracotta trails the cluster by **9.0**. So a lingering sense that "yellow looks
bright" is mostly terracotta reading dim beside it — the sub-AA contrast above is
the same finding from a different direction.

**If the palette is ever reopened, terracotta is the lead, not yellow.** Raising
it toward the cluster would close the gap and fix the AA shortfall at once.
Untouched for now because the config is frozen and nothing is blocked.

### The 2026-07-22 green/yellow fix

**Yellow is the colour that is out of position, but green is the one that moved.**
Worth understanding before touching either again.

The selected yellow sits at Lab hue 98. Solarized's own yellow is at 84. That 14
degree drift put it 12.6 degrees from the theme's olive green (110.7), at
near-identical lightness and chroma — **dE2000 8.3**, the same colour on small
glyphs.

Yellow could not be moved back, and its chroma is not a lever:

- Hue down is the theme's stock gold (hue 84-86), rejected on sight as too
  orange. Hue up is green itself.
- Dropping yellow's chroma does nothing: even at C\* 34 the olive pair only
  reaches dE2000 12.0, because 13 degrees of hue is the entire problem. Worse,
  a lower-chroma yellow *reduces* the chroma-gap term, so green then has to sit
  at hue 136 instead of 134 to clear it.
- Lightness cannot *solve* it: at hue 98 the pair does not clear dE2000 20 until
  L\* 85, a near-fluorescent lemon.

  But it does help, and this pair is the one place lightness is worth using.
  Green and yellow share nearly the same hue (12.7 degrees apart) and nearly the
  same chroma (0.4 apart), so with both of the usual axes flat, lightness is the
  only variable left and becomes the salient difference. Moving `darker` ->
  `balanced` widened the L\* gap 2.0 -> 5.8 and was clearly perceptible, despite
  measuring only dE2000 8.6 -> 9.9. Do not generalise this to other pairs.

That left only green, and green could not move to anywhere acceptable either.

### Green is chosen on hue, not chroma

The opposite of the first read, and the thing that cost this session three
rounds. Verified against real files:

| candidate | hue | C\* | verdict |
| --- | --- | --- | --- |
| `solarized` `#859900` | 110.7 | 66.9 | **kept** — collides, but reads best |
| `grass` `#56a325` | 129.9 | 70.3 | too bright |
| `clover` `#599e49` | 136.0 | 53.8 | still too bright |
| `moss` `#629959` | 138.1 | 41.9 | closest call, still rejected on hue |

The highest-chroma option reads calmest, and dropping chroma 25 points did not
stop hue 136 reading as vivid. Below hue ~122 green reads warm and olive; above
~130 it reads kelly green. **The entire warm band is inside collision range**, so
no green is both warm and clear of yellow.

That is why this closed as WONTFIX: the fix works, it just costs the warm olive,
and the warmth is worth more in daily use than the separation is.

### A per-language split was tried and removed

Yellow density does differ sharply by language:

| language | what is yellow |
| --- | --- |
| TSX / JSX | `@tag.tsx` — every `<div>`, `<p>`, `<span>` — plus `Type` |
| Go | `Type` (`int`, `string`, `float64`) |
| Python | `Type` (`str` annotations) |
| Lua | nothing |

That suggested scoping a separate green to `tsx` / `typescript` / `javascript`
and keeping the olive elsewhere. It was implemented and then reverted: Go is not
sparse enough. Every function signature (`func sum(nums ...int) int`) puts an
olive keyword directly beside a yellow type, so the collision showed up there
too. **Do not retry the split** — the premise that only JSX is yellow-dense is
wrong.

### If this ever gets reopened

Everything tried is saved by name in the palette file, so re-testing is a
one-word edit to the `return` block. The full fix that was built and reverted:

| pair | as shipped (now) | with `moss` + `balanced` |
| --- | --- | --- |
| green / yellow | **8.3** | 21.9 |
| green / cyan | 30.6 | 18.7 |
| cyan / blue | 21.8 | 21.8 |

Note that green/cyan gets *worse* under the fix. It stays usable — the two are
49 degrees apart in hue and dE2000 understates hue separation at low chroma —
but it is a second reason the trade was not clearly worth taking.

The only untried direction, if the collision ever becomes genuinely painful in
daily work: move `Type` off yellow instead of moving green. That kills the
collision at its source (a keyword only ever touches yellow via a type
annotation or a JSX tag) while leaving both green and yellow alone. Measured
worst-case separation against every Go neighbour: magenta `#cc3399` scores 24.5,
violet `#a3a9e8` scores 19.2. Cyan and blue both fail — they collide with
strings and function names respectively.

## Remaining Work

Item 8 is the only live one. Items 1 and 3 are "slightly better" changes, which
rule 1 says is never a reason on its own. Review all three at the 2026-09-20
checkpoint and most likely drop 1 and 3. Items 2, 4, 5, 6 and 7 are closed.

### 1. Neutral brackets in dense JSX

`@punctuation.bracket` currently shares terracotta with `@variable.parameter`.
JSX carries roughly 3x the punctuation density of Go, so TSX shows far more of it
than any other filetype. Pointing brackets at a neutral `c.base01` (L\* 44.8, no
hue) would calm TSX without touching Go or Python.

Only do this if dense JSX actually reads busy in daily work.

### 2. TS/JS variables are an accent, other languages are not — DONE

Closed. `solarized-osaka.lua` links `@variable.typescript` and
`@variable.javascript` back to `@variable`, so plain variables use `base0` in
every JS/TS file and match Go and Python.

Verified this is not overridden by LSP: `groups/semantic_tokens.lua` sets
`["@lsp.type.variable"] = {}` so treesitter wins.

### 3. Brighter yellow variant — DROPPED

`variants.yellow.brighter` (`#baac0d`) is still saved. It sits at hue 98 like
`darker`, so it now works fine against the retuned green. Superseded by item 2
regardless.

### 4. Base text (`Normal` fg) reads dim — CLOSED 2026-08-05, not a palette issue

**Resolved the same day it was filed. The cause is Ghostty glyph rasterization,
not `base0`. Do not change the palette for this.** The analysis below is kept
because the measuring method is reusable and because the wrong fix is tempting.

Raised while looking at a Go file: plain code text (`r := gin.Default()`, braces,
operators, identifiers) felt "a bit dark or faded" next to the accents. Two facts
surfaced right after filing: `font-thicken-strength` in `ghostty/config` had just
been lowered to 140, and the same theme looked correct in Neovide.

#### Measured, from screenshot pixels

Both clients were sampled by solving `pixel = alpha*base0 + (1-alpha)*bg` per
pixel over the code area, keeping pixels on that colour line, and taking the
distribution of `alpha` (stroke coverage).

| | Ghostty 13pt, thicken 140 | Neovide `guifont h14` |
| --- | --- | --- |
| colour sent | `#9eabac` | `#9eabac` (identical) |
| mean stroke coverage | 0.386 | 0.492 (+27%) |
| pixels at full colour | 2.0% | 4.4% |
| effective rendered text | `#3c4e51` | `#4d5e62` |
| effective L\* | 31.8 | 38.7 |

The colour is byte-identical. The whole 6.9 L\* gap is coverage. That is above the
~5 L\* perceptual floor noted below, so the complaint was real, just misattributed.

Contributing causes, both client-side:

- `font-thicken-strength = 140` (`ghostty/config:73`). Ghostty has no built-in
  text gamma boost, so this dial is the entire stroke-weight budget.
- `font-size = 13` in Ghostty vs `guifont "Maple Mono NF:h14"` in
  `lua/config/neovide.lua:5`. Neovide had silently been a point larger all along.
  14/13 is only +7.7% linear stem width against +27% measured coverage, so size is
  at most a third of it; the rest is Skia applying its own gamma/contrast
  correction to text masks, i.e. the thickening Ghostty makes you dial by hand.

#### Why the palette is the wrong lever

At 0.386 coverage the colour barely gets a vote:

| change | Ghostty effective L\* | gain |
| --- | --- | --- |
| nothing | 31.8 | baseline |
| `base0` -> `base1` `#adb7b7` | 34.0 | +2.2 |
| `base0` -> `#b0bdbe` | 34.8 | +3.0 |
| coverage 0.386 -> 0.492 | 38.7 | **+6.9** |

Thickening is ~3x more effective. A palette change also hits every client:
Neovide is already at the target, so it would overshoot there, and it would push
base text above four of the five accents, inverting the figure/ground balance the
rest of this file was tuned around.

Fix order (all in `ghostty/config`, outside the freeze):
`font-thicken-strength` 140 -> 165 first, then `font-size` 13 -> 14 if still
short. Keep avoiding `alpha-blending = linear-corrected`; it thins bright text on
dark backgrounds.

#### Reusable lesson

**Before changing a colour because it looks dim, measure rendered coverage, not
the nominal hex.** A theme value is a ceiling the rasterizer rarely reaches. If
one client looks right and another does not on the same colour, the palette is
provably innocent and the terminal is the suspect. The measuring script pattern:
convert the screenshot with `sips -s format bmp`, parse it in plain Python, and
least-squares each pixel against the `bg -> fg` line.

The candidate values and knock-on checks that were filed before this was resolved
are kept below, for the unlikely case the palette is ever reopened on purpose.

**This is a different axis from everything else in this file.** Items 1-3 and all
the Notes below are about *accent* colours, where the rule is tune hue and chroma,
never lightness. Base text is a single neutral with no neighbour to stay distinct
from, so lightness is the correct and only lever here. Do not apply the
"never lightness" note to this item.

Measured state (background is the transparent-blend base, `#001419`, L\* 5.2):

| role | value | L\* | contrast |
| --- | --- | --- | --- |
| `Normal` fg = `base0` | `#9eabac` | 69.0 | 7.97:1 |
| `base1` (theme, brighter neutral) | `#adb7b7` | 73.7 | 9.19:1 |
| `Comment` | `#576d74` | 44.6 | 3.45:1 |

So base text already passes WCAG AAA comfortably. The complaint is perceptual,
not a contrast failure. Two plausible readings, worth deciding between *before*
touching a colour:

- **Base text really is low.** At L\* 69 it sits *below* four of the five accents
  (yellow 70.8, blue 66.9, green 66.8, cyan 66.3 perceived). Ordinary code is
  therefore no brighter than the syntax highlighting around it, which inverts the
  usual figure/ground and can read as washed out.
- **It is the accents, not the base.** The 2026-07-22 benchmark found this palette
  runs high-chroma on a near-black background, and high chroma next to a neutral
  makes the neutral look duller than it measures. If so, raising base text chases
  a symptom.

Both readings turned out to be wrong: neither the base nor the accents were the
cause, the rasterizer was. Kept as a record that "which colour is at fault" was
the wrong question to start from.

Candidates if it goes ahead (nothing is overridden today — `Normal` fg comes
straight from the plugin, so this would be a **new** `on_colors` entry setting
`c.base0`, not an edit to an existing line):

| candidate | value | L\* | contrast | note |
| --- | --- | --- | --- | --- |
| theme `base1` | `#adb7b7` | 73.7 | 9.19:1 | already in the palette, +4.7 L\* |
| mid | `#b0bdbe` | 75.7 | 9.76:1 | keeps base0's hue, +6.7 L\* |
| high | `#bcc9ca` | 80.0 | 11.08:1 | +11 L\*, likely too stark on near-black |

Start with `base1` or the mid value. A move under ~5 L\* on text glyphs is below
the perceptual threshold and will return no signal, which is the same trap the
2026-07-21 session lost time to.

Knock-on checks before shipping any of these:

- `base0` is used well beyond `Normal`. Grep the plugin theme and
  `solarized-osaka.lua` for every consumer (statusline, floats, `@variable`,
  which item 2 deliberately links back to `@variable` for the JS/TS family) and
  confirm none of them get too loud.
- Raising base text widens the gap to `Comment` (3.45:1). Comments are
  intentionally dim, but check they do not start reading as disabled text.
- If base text goes up, the terracotta shortfall from the benchmark above gets
  *relatively* worse. Terracotta is already the lead candidate if the palette is
  reopened, so consider doing both in the same session or neither.

### 5. Keyword: olive vs yellow — CLOSED 2026-08-09, yellow selected

**Resolved the same day it was filed.** `variants.keyword.balanced` `#aea10c` is
the settled value. Olive is kept as a named variant but should not be reinstated
without reading the three findings below, which were not known when this item was
written.

**Why yellow won**, in order of weight:

1. **Olive is unstable across the two displays actually used.** With Ghostty's
   `window-colorspace = display-p3`, olive moves 4.2° toward green between the
   MacBook XDR panel and an sRGB external monitor. Yellow moves 0.5°. This is
   what "olive looks better on the laptop than on the Samsung" was measuring.
2. **The density complaint was partly a rendering artifact.** P3 tagging emits
   every accent about 20 C\* more saturated than authored, so the yellow that
   read "loud" was being drawn at C\* 87.9, not the authored 67.4.
3. **Olive collides with the git-added green** (dE ≈ 0.2 from `#859900`), which
   `bdb87f0` had deliberately decoupled. Yellow does not.

**The dose finding that settled it.** Yellow is not too loud in general, it is
too loud past a threshold. Measured shares of glyphs painted `#aea10c`:

| language | yellow | verdict |
| --- | --- | --- |
| Go | 1.6% | comfortable |
| TSX (real work file) | 5.3% | confirmed comfortable |
| Python | 5.8% | comfortable |
| Bash | 7.8% | fine |
| TypeScript | 10.1% | between the two, closer to the bad end |
| JavaScript | 10.2% | as above |
| Lua | 11.6% | rejected |

Lua is the only language in the stack that overdoses it, and Lua is a config
language here, not part of the daily JS/TS, Go, Python and Bash work. That is the
accepted trade: Lua stays loud.

Original framing, kept because the measurements are still valid:

| | olive `#849900` | yellow `#aea10c` |
| --- | --- | --- |
| L\* | 59.6 | 65.4 |
| chroma C\* | 67.0 | 67.4 |
| Lab hue | 111.0 | 97.9 |
| contrast vs `#031219` | 5.92:1 | 7.16:1 |

The trade, stated plainly: yellow is the better colour in ordinary files and the
worse one in keyword-dense files, where it reads loud. Olive gives that up for
1.24 of contrast, both still clear of the WCAG AA 4.5 floor.

Three things to carry into the review so it is not re-derived:

- **Chroma is not the lever.** The two candidates are 0.4 C\* apart, far under
  the perceptual floor, so every bit of the difference is lightness and hue.
  Dropping chroma to calm either one has already failed twice — `drab` at C\* 44
  read "too fade", and the `subdued`/`hushed` ladder went the same way.
- **This is the documented exception to rule 2.** Lightness normally returns no
  signal here, but 5.8 L\* clears the ~5 floor, so between *these two* it is real.
- **Olive sits on the git-added green.** `#849900` is dE2000 ≈ 0.2 from
  solarized's `#859900`, which gitsigns and `diffAdded` use. Commit `bdb87f0`
  had deliberately decoupled the lualine git marker from the keyword colour;
  that separation is now gone visually. Known and accepted, not a defect.

### 6. `@punctuation.delimiter` is painted with the keyword colour — DONE 2026-08-10

**Closed.** Applied exactly as proposed below: `@punctuation.delimiter` moved out
of the keyword paint list and onto `c.base0`, beside `Operator` and the tag
delimiters, in `lua/colorschemes/solarized-osaka.lua`. Nothing else changed with
it — it is a coverage change, so it holds for every keyword colour, including
the variants in `lua/colorschemes/solarized-osaka-variants.lua`.

Landed in the same session as the keyword move to violet `#a17bcc`, but the two
are independent decisions and were measured separately.

Original filing follows, kept for the reasoning and the numbers.

---

Filed 2026-08-09, deliberately not done in that session. Reads as an
inconsistency rather than a preference, so it does not need the freeze
checkpoint, but it was left because the palette was already good enough to work
in.

`@punctuation.delimiter` sits in the keyword paint list in `solarized-osaka.lua`
while its siblings `@punctuation.bracket` and `@punctuation.special` sit in the
terracotta list. So every `,` `.` `:` `;` is painted `#aea10c`. Nothing in the
notes argues for that split, and `Operator` was moved to `base0` on 2026-08-08
with reasoning that applies word for word: "`=` is punctuation, not a keyword, so
this is also the more correct reading." Today `=` is grey and the `,` beside it
is yellow.

**Proposed fix:** move `@punctuation.delimiter` out of the keyword list and set
it to `c.base0`, exactly as `Operator` already is. One line. NOT terracotta —
that is already 12.7% of TSX glyphs at 947 marks, and adding delimiters would
push it past 16% and tilt the screen red.

**Measured effect**, simulated on real files:

| | yellow area | separate yellow marks |
| --- | --- | --- |
| tsx | 5.3% → 2.7% | 546 → 128 (−77%) |
| typescript | 10.1% → 6.3% | 1222 → 351 (−71%) |
| javascript | 10.2% → 6.8% | 655 → 214 (−67%) |
| python | 5.8% → 3.1% | 434 → 112 (−74%) |
| lua | 11.6% → 8.6% | 660 → 277 (−58%) |
| go | 1.6% → 1.5% | 101 → 69 (−32%) |

It lands TypeScript and JavaScript inside the dose already confirmed comfortable
in TSX, and it removes about three quarters of the yellow *fragments* while only
removing a third to a half of the yellow *area* — because a `.` or `,` is a
single character and therefore its own isolated mark.

What each language actually captures as a delimiter, so the effect is not a
surprise: TypeScript `.` 418, `:` 357, `,` 198, `?.` 23, `|` 21, `;` 8. Python
`,` 152, `.` 107, `:` 76. Go only `.` 32, which is why Go barely moves.

Expected cosmetic trade: `values.paymentInfo` loses its lit dot, so member
boundaries are marked by the colour change alone. Same trade already accepted
for `=`.

### 7. `&&`, `||`, `!` are painted as body text — DONE 2026-08-11

**Closed the day it was filed.** Reasoning, the two grammar carve-outs and the
full dose table are in `notes/syntax-palette-decisions.md`, section "Logical
operators are keywords too".

Raised from a real TSX file where `{isChangedBg && !!description}` showed its
branch condition and its double negation in the same grey as everything around
them. Like item 6, this reads as an inconsistency rather than a preference:
`solarized-osaka.lua` puts `@keyword.operator` on the keyword colour on purpose,
so Python's `not x` and Lua's `and` are violet, while `!x` and `&&` in Go, the
JS/TS family and Bash fell through `Operator` to `base0`. The languages that lose
the accent are exactly the ones that spell the concept with symbols.

**Applied:** five new `; extends` files under `after/queries/`
(`tsx`, `typescript`, `javascript`, `go`, `bash`) re-capturing `&&`, `||`, `??`
and `!` as `@keyword.operator`. No Lua was edited and no colour was added — the
theme already paints that capture. `Operator = base0` is untouched, so `=`, `+`,
`=>`, `:=`, `===`, `!==` and `!=` stay neutral, and so do TypeScript's `foo!`
and bash's `${!ref}`, neither of which is a negation.

Reverting is `rm -r after/`, or deleting one file to drop one language.

**Measured effect** on real files, keyword-colour area and separate marks:

| file | glyphs | area | marks |
| --- | --- | --- | --- |
| `index.tsx` (the file that raised it) | 7,028 | 2.65% → 3.53% | 60 → 98 |
| gin `context.go` | 38,402 | 4.92% → 5.01% | 425 → 447 |
| rust `ci/run.sh` | 9,316 | 2.81% → 3.06% | 91 → 103 |
| rust `install-template.sh` | 21,183 | 6.22% → 6.31% | 395 → 411 |
| `free-disk-space-linux.sh` | 8,406 | 4.28% → 4.53% | 110 → 122 |

Largest move is +0.88 points against the 7% stop rule on the violet. Bash was
expected to be the risk and moved least; see the note file for why.

### 8. `Type` is the brightest thing on screen — OPEN, the only role left

**The one genuinely unoptimised colour**, filed 2026-08-11 after the punctuation
rework closed. Not blocking: it is doing its job, which was to separate types from
`Function` after every type in Go/TS/Python read as gold. That works. The cost is
brightness.

`#7dcfff` sits at **L\* 79.5**, the brightest value in the palette by 20 points,
and it is the only imported colour — dE 20.0 from Solarized's own blue, against
0.5–12.1 for every other accent.

**It is language-specific, and the numbers say why.** Measured coverage:

| file | area | marks | avg run |
| --- | --- | --- | --- |
| `recurringCheckoutService.ts` | **10.86%** | 269 | **18.3 ch** |
| `index.tsx` | 6.79% | 61 | 7.8 ch |
| `demo.go` | 4.89% | 101 | 5.2 ch |
| `test.sh` | 0% | 0 | – |

TS is the bad case because an `import type { ... }` block is 18-character runs of
the brightest colour, line after line. Go gets 5-character runs of `int`,
`string`, `error` — the "rare landmark" the value was justified as. Same colour,
different dose, exactly rule 4.

**Do not try to fix this by dimming it inside the blue band.** Every saved
candidate was re-scored against the current palette on 2026-08-11 (the previous
scores predate both the violet keyword and the copper punctuation, and rejections
are only valid against the palette that existed when they were made):

| candidate | L\* | vs Function |
| --- | --- | --- |
| `sky_calm` `#56cae7` | 75.7 | 16.0 |
| `sky_dim` `#39cce9` | 75.6 | 16.7 |
| `periwinkle` `#a7b1fe` | 74.3 | 21.9, but worst neighbour 17.3 |
| `nvim_type` `#2ac3de` | 72.3 | 15.2 |
| `vscode_support` `#0db9d7` | 68.8 | 12.7 |
| `sky` `#0edfff` | **81.3** | 20.7 — the only one that clears, and it is *brighter* |

Every dimmer option collides with `Function`. That is arithmetic, not bad luck:
`Type` and `Function` sit at hue 249 and 250, one degree apart, so their entire
separation **is** the 20.6 L\* gap. Lowering Type's lightness necessarily
collapses the pair. The blue band cannot produce a dimmer Type.

**The three real directions, all unexplored:**

1. **Move `Type` out of the blue band.** The 2026-07-22 note measured magenta
   `#cc3399` at 24.5 and violet `#a3a9e8` at 19.2 for this — but that was scored
   against a yellow keyword, and violet is now the keyword, so magenta is the
   surviving lead and needs re-scoring against violet at hue 310.
2. **Move `Function` instead**, freeing room below for a dimmer Type. Never
   tried. The existing note only records that Function cannot be *brightened*
   without collapsing the pair; going the other way was not tested.
3. **Reduce the dose rather than the value.** No mechanism known — `@type` cannot
   be scoped to "not inside an import block" by highlight group, and an
   `after/queries` split would need a capture the grammar does not provide.

Review at the 2026-09-20 checkpoint. Judge on a real `.ts` file with a large
`import type` block, not on Go.

## Notes

- Tune on **hue and chroma, never lightness**. Lightness-only changes on text
  glyphs land below the perceptual threshold and return no signal. The 2026-07-21
  session lost most of its time to this: 8 of 11 saved red variants sat within
  2.4 degrees of the same hue and all felt identical.
- Background is `hsl(192, 100%, 5%)`. Keep accent hues clear of it, and if one
  must sit close, keep chroma above ~35 or it reads muddy. This is why `balanced`
  (`#4488ab`, C\* 27.2) failed.
- Error red is `#ff3b30` (Lab hue 3 degrees). Keep the punctuation red clear of it
  so brackets never read as diagnostics.
- Every tested colour is kept as a named variant in the palette file, so any swap
  is a one-word edit to the `return` block at the bottom.
- **Check every new accent against the whole palette with dE2000, not by eye.**
  Rough reading for small text glyphs: under 10 is confusable, 10-20 is
  distinguishable but tiring, over 20 is unambiguous. Judging one colour in
  isolation is what let yellow drift into green on 2026-07-21 — it looked fine
  alone and only failed next to keywords in real TSX.
- **Judge green on hue, not chroma.** The 2026-07-22 session wasted three rounds
  assuming "too bright" meant chroma. It did not: `solarized` at C\* 66.9 reads
  calm and `clover` at C\* 53.8 reads bright, because the difference is hue 111
  vs 136. Chroma only decides flat vs alive *within* a hue.
- **Check a candidate in every language before shipping it.** The binding
  neighbour changes: TSX is yellow-dense (`@tag.tsx`), Go and Python are
  cyan-dense (strings) with almost no yellow, Lua has neither. A green that
  passes in one can fail in another, and testing only TSX is what produced two
  rejected greens in a row.
- **Scoping to a language family is legitimate here.** The theme already defines
  `@keyword.tsx` / `@keyword.javascript` separately, so a per-family override
  follows its grain rather than fighting it. Prefer it over degrading a colour
  in four languages to fix one.
