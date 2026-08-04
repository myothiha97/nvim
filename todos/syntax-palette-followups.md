# Syntax Palette: Follow-ups

## Status

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

Items 1 and 3 are "slightly better" changes, which rule 1 says is never a reason
on its own. Review at the 2026-09-20 checkpoint and most likely drop them.
Items 2 and 4 are closed.

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
