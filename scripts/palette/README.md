# Palette measuring tools

Tools for judging this config's syntax colours with numbers instead of
impressions. Nothing here runs at editor startup — `scripts/` is not on
Neovim's runtimepath for anything auto-sourced, so these cost nothing.

**Read `notes/syntax-palette-decisions.md` before changing a colour.** These
tools tell you what a value *is*; that file records what was already tried and
why it lost. Most obvious ideas have been measured and rejected for a recorded
reason.

## Why these exist

Colour judgements on a near-black background fail in one specific, repeatable
way: **the eye reads chroma as brightness.** Over one session that mistake was
made three times, and each time the axis named in the complaint was not the axis
that had changed:

| the complaint | what had actually changed |
| --- | --- |
| "upstream has higher contrast" | contrast was *lower*; chroma was +19 |
| "copper is significantly brighter" | +2.9 L\*, below the perceptual floor; chroma +29.7 |
| "v6 is a bit brighter than v5" | −0.1 L\*, i.e. *darker*; chroma +5.1 |

Ladders were built on the wrong axis and thrown away. So: measure which axis the
complaint is on before building anything.

## The tools

Two files. `palette.py` is one self-contained script with subcommands —
standard library only, no cross-file imports, so there is no import path to get
wrong and nothing to install. `census.lua` is separate because it has to run
inside nvim to reach treesitter.

### `palette.py scorecard` — is the palette healthy?

```sh
python3 scripts/palette/palette.py scorecard
python3 scripts/palette/palette.py scorecard --build solarized-osaka-custom-v3
```

Pulls the colours out of a real nvim, so it scores what is actually painted.
Reports per-role lightness/chroma/contrast, every pair's separation worst-first,
the keyword/punctuation chroma pairing, what an sRGB monitor does to each value,
and distance from canonical Solarized.

Use `--build` to compare candidates without editing anything.

### `census.lua` — how much of a real file is this colour?

```sh
nvim --headless path/to/File.tsx \
  -c 'luafile scripts/palette/census.lua' -c 'qa!'
```

Resolves every non-space glyph through its winning treesitter capture and
reports area%, **marks**, and average run length per colour.

Marks matter more than area. Two colours with the same coverage read completely
differently: cyan at 44.9% and terracotta at 12.7% produced about the same number
of marks, because cyan arrives as 8-character strings and terracotta as
2.3-character fragments. *"The whole screen is X"* is a statement about mark
count, not coverage.

### `palette.py screenshot` — what did the display really emit?

```sh
python3 scripts/palette/palette.py screenshot ~/Pictures/shot.png
python3 scripts/palette/palette.py screenshot shot.png --near '#be6421'
```

The tiebreaker when a prediction and an impression disagree. Decodes real pixels
out of a screenshot, and reports the display profile it came from.

It proved the external-monitor case: `#be6421` was predicted to arrive as
`#cc5e00` with blue clipped to zero, and measured `#cb5e00` — correct to within
1/255.

### The maths

Lab/LCh, CIEDE2000, WCAG contrast, P3 emission, sRGB gamut clipping and
canonical Solarized all live in the top section of `palette.py`, documented in
place. `lch_to_hex()` is the one to reach for when walking a single axis — hold
two of the three fixed, or you will not know which one the change came from.

## Two traps that will waste your time

**`nvim -l` skips the entire config.** No lazy.nvim, no colorscheme — every
group silently reports nvim's built-in defaults, and you get a plausible-looking
scorecard that is completely wrong. Always use `-c 'lua …' -c 'qa!'`, which is
what these scripts do. If numbers ever look strange, check this first.

**Authored hexes are not what the panel shows.** Ghostty runs
`window-colorspace = display-p3`, so it tags these sRGB-authored numbers as P3
and every accent is drawn roughly 20 C\* more saturated than written. Quote the
*emitted* figure when arguing about loudness. On an sRGB external monitor the
opposite happens: out-of-gamut values get clipped, and a channel falling to `00`
is a category change (earthy red → flat orange) that a small dE badly
understates.

## How to read the numbers

**dE2000**, on small text glyphs against this background:

```
 < 10   confusable
10-20   distinguishable but tiring
 > 20   unambiguous
```

**Perceptual floors** — moves smaller than these return no signal, so a ladder
built inside them is wasted work:

```
lightness   ~5 L*
chroma      ~5 C*    (olive 67.0 and yellow 67.4 read as the same colour)
```

**Dose stop rules** currently in force:

```
keyword       re-measure past ~7% of ink
punctuation   highest-dose accent; watch it in markup-heavy TSX
```

Judge a colour on the language it hurts most, not the one it flatters. One value
measured 1.6% in Go and 11.6% in Lua.

## The limit

**None of this predicts whether something is comfortable for six hours.** Every
candidate rejected on 2026-08-11 measured well and lost on looks. Use the numbers
to *eliminate* — sub-AA contrast, a collision with the error red, a dose past the
stop rule — then judge the survivors by reading real files in the languages you
actually work in.
