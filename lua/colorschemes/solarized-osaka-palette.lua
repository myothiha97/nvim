-- Colour selections for the solarized-osaka theme.
--
-- Every value ever tried is kept here by name, so changing a colour is a
-- one-word edit to the `return` block at the bottom. Keys are named for the
-- ROLE they fill, never for a theme slot -- a role can move to any hue, and
-- naming it after a colour is how `green` ended up holding a yellow.
--
-- These feed SYNTAX GROUPS ONLY. solarized-osaka.lua deliberately has no
-- `on_colors`, so nothing here can reach diagnostics, git signs, lualine or any
-- other UI. See the note at the top of that file before changing the approach.
--
-- Reasoning, measurements and every rejected candidate:
--   notes/syntax-palette-decisions.md
-- Read it before changing a value. Most obvious ideas have already been tried,
-- measured, and rejected for a recorded reason. Four rules in short:
--   1. Two roles must not share a hue band; splitting by lightness alone fails.
--   2. Tune hue and chroma -- lightness-only moves land under the perceptual floor.
--   3. Frequency is inversely related to brightness.
--   4. If a colour looks right in some files and wrong in others, the variable
--      is coverage, not value.
-- Measure against Ghostty's #031219, not nvim's #001419 (transparent = true).

local variants = {
  -- Keyword, Statement, @keyword, @keyword.operator, @label.
  keyword = {
    -- REJECTED 2026-08-09 after one day in the slot. It IS the calmer of the two
    -- in keyword-dense code, which is why it was picked, but two things found
    -- afterwards outweigh that:
    --
    --   1. It is display-unstable. Ghostty tags content display-p3, and between
    --      the laptop panel and an sRGB external monitor olive shifts 4.2
    --      degrees toward green while `balanced` shifts 0.5. Hue 111 sits right
    --      where the gamut difference bites. The external monitor is the main
    --      work display, so a value that changes identity between the two loses.
    --   2. It lands dE ~0.2 from the git-added green #859900, undoing the
    --      decoupling commit bdb87f0 made on purpose.
    --
    -- The density complaint that motivated it was also partly a rendering
    -- artifact: P3 tagging draws the yellow at C* 87.9, not the authored 67.4.
    olive = "#849900", -- hue 111, L* 59.6, C* 67.0, 5.92:1
    -- SELECTED. Held the slot 2026-08-08 to 2026-08-09, lost it for one day, and
    -- was restored the same day. Highest contrast of the two, hue-stable across
    -- displays, clear of the git green, and the only hue here that reads as
    -- actual yellow -- below ~L* 62 yellow turns khaki.
    --
    -- It IS the loudest colour in the palette, and that is accepted rather than
    -- solved. It is comfortable up to about 6% of glyphs (measured fine at 5.3%
    -- in real TSX) and uncomfortable past about 10%. Only Lua exceeds that, at
    -- 11.6%, and Lua is a config language here rather than a daily one. Do not
    -- try to fix the dose by moving this value -- the lever is what the colour
    -- COVERS, which is item 6 in todos/syntax-palette-followups.md.
    balanced = "#aea10c", -- hue 98, L* 65.4, C* 67.4, 7.16:1
    darker = "#a3970b", -- hue 98, L* 61.6
    brighter = "#baac0d", -- hue 98, L* 69.5
    amber = "#b59a00", -- hue 92, warmer
    citron = "#9ea100", -- hue 104, cooler
    subdued = "#aea134", -- hue 98, C* 56
    hushed = "#aea042", -- hue 98, C* 50 (C* 35 is the muddiness floor)
    gold = "#b99004", -- the theme's own yellow500; ruled out by hand
    -- Rejected 2026-08-08 alongside olive. Unlike olive these were not revisited.
    drab = "#8c9644", -- hue 111, C* 44 -- "too fade"
    verdant = "#5da100", -- hue 125, C* 75 -- "dracula green"
    -- Older greens, all rejected on looks as cool/vivid rather than warm.
    sage = "#66985e",
    moss = "#629959",
    fern = "#5d9a53",
    clover = "#599e49",
    juniper = "#569f41",
    leaf = "#4ea339",
    grass = "#56a325",
  },

  -- REJECTED WHOLESALE 2026-08-09. Nothing reads this table; it is kept so the
  -- experiment is not run a third time. Both halves were built, measured and
  -- reverted on looks: `local` (240 glyphs) through base0, bronze and warm grey,
  -- then `end`/`then`/`do` (299 glyphs) through cool grey. The mechanics all
  -- worked and the coverage numbers were real -- 8.6% of glyphs down to 6.3% --
  -- but every quiet colour read as out of place next to the accents, and the
  -- accepted outcome is to leave Lua's keywords loud. Lua is a config language
  -- here, not part of the daily JS/TS, Go, Python and Bash stack, so the density
  -- it suffers from is not worth a fourth colour.
  --
  -- Redoing it needs after/queries/lua/highlights.scm back (deleted 2026-08-09):
  -- `; extends`, then `[ "end" "then" "do" ] @keyword.structure`, because the
  -- runtime query files those tokens under the construct they close.
  --
  -- Block grammar: Lua's `end`, `then`, `do`. Not landmarks -- indentation
  -- already shows where a block closes and `if`/`for` already mark the
  -- construct -- so they are the closing brace of a language that spells its
  -- braces out. 287 of the 1125 keyword-painted glyphs in ai-prompts.lua, and
  -- `end` alone owns 52 whole lines there with nothing else on them.
  --
  -- Reached through a custom capture in after/queries/lua/highlights.scm,
  -- because the runtime query files these tokens under the capture of their
  -- opening construct and a highlight group alone would take `if` and
  -- `function` down with them.
  --
  -- `local` was the first candidate for this treatment and was REVERTED to the
  -- keyword colour on 2026-08-09 after base0, bronze and warm grey were each
  -- rejected on looks. The reason is structural, so do not retry it blind: an
  -- `end` sits alone on its line, where a quiet colour reads as chrome, while
  -- `local` sits against a variable name, where the same colour reads as dirt.
  -- `end` is also the larger share, 287 glyphs against 240.
  --
  -- The target is a GREY, and the whole difficulty is that the grey band is
  -- narrow. Comment sits at L* 44.6 and body text at L* 69.0, so the usable gap
  -- is 24 points and anything centred in it lands ~12 dE from BOTH neighbours --
  -- "distinguishable but tiring" by the rule at the bottom of this file, never
  -- unambiguous. Lightness alone cannot buy the separation, so hue does.
  --
  -- Chroma is the axis that decides grey vs colour here. At the theme's own grey
  -- level (Comment C* 9.2, base00 C* 9.3) a warm hue reads as a grey that leans
  -- warm. At double that it reads as brown, because hue 98 below L* 62 is no
  -- longer yellow at all -- see the note on `balanced` above. Same hue, two
  -- different colour categories, decided entirely by chroma.
  -- Keep these COOL. Every warm candidate tried on 2026-08-09 was rejected as
  -- "bronze", and the reason is categorical rather than a matter of degree: a
  -- warm hue dimmed far enough to recede stops being that hue and becomes
  -- brown, exactly as hue 98 becomes khaki below L* 62. Orange was measured for
  -- this slot on the same day and fails the same way -- the only oranges that
  -- clear both terracotta and the keyword by ~20 dE sit at C* 60, which is a
  -- fourth accent, and dropping them to C* 30 lands on #9c744c, a bronze.
  keyword_grammar = {
    -- SELECTED 2026-08-09. Midway between Comment and body text, on the theme's
    -- own cool grey axis: 10.7 dE from Comment so it never reads as one, 12.2
    -- from body text so it clearly recedes. Clears WCAG AA at 5.06:1.
    cool_grey = "#75878a", -- hue 215, L* 55.0, C* 7.0, 5.06:1
    -- One step down, the theme's own base00, if `end` should recede further.
    -- Sits 4.7 dE from Comment, so at this value block grammar and comments read
    -- as the same layer, and contrast drops under AA to 4.15:1.
    base00 = "#637981", -- hue 229, L* 49.4, C* 9.3, 4.15:1
    -- One step up, the theme's own fg, if it recedes too far. Only 7.8 dE from
    -- body text, so `end` starts to read as ordinary code again.
    fg = "#839395", -- hue 210, L* 59.8, C* 6.1, 5.95:1
    -- Rejected 2026-08-09 on looks, all three while this role still meant
    -- `local`. Kept because the measurements stay valid for any grammar slot.
    warm_grey = "#888474", -- hue 98, L* 55.1, C* 9.3 -- still read as bronze
    bronze = "#8b8465", -- hue 98, L* 55.0, C* 17.9 -- double chroma, a brown
    base0 = "#9eabac", -- L* 69.0, BRIGHTER than the keyword it defers to
  },

  -- Special, Debug, @punctuation.bracket, @variable.parameter,
  -- @variable.builtin, JSX tags and delimiters, @keyword.import.
  punctuation = {
    terracotta = "#b55f4a", -- SELECTED. hsl(12,42,50), L* 50.1, 4.26:1
    -- Measures better on both counts: 7.19:1 (terracotta is under the WCAG AA
    -- floor) and dE2000 21.3 from the error red against terracotta's 10.1, the
    -- tightest pair in the palette. Untried in place.
    tokyonight = "#f7768e",
    muted_contrast = "#c75b6b",
    crimson = "#bf2c47",
    magenta = "#b02669",
    vivid = "#e03857",
    bright = "#ab3a4f",
    lighter = "#b83e55",
    darker = "#993141",
    red300 = "#f6524f",
    red700 = "#b7211f",
  },

  -- Function, Identifier, @markup.link.
  func = {
    azure = "#1d98cd", -- SELECTED. hsl(198,75,46), L* 59.1, C* 38.5
    vivid = "#359ee9", -- hsl(205,80,56)
    deeper = "#2797e7", -- hsl(205,80,53)
    brighter = "#268bd2", -- the theme's own blue500
    blue300 = "#49aef5",
    balanced = "#4488ab", -- C* 27.2, reads muddy on this background
  },

  -- Type, @type.builtin, @constructor.
  --
  -- Hard to place for two reasons. TSX tags every imported PascalCase name as
  -- @type -- React components included -- so it is the densest capture there and
  -- genuinely rare in Go and Python. And the blue band is full: String/member
  -- cyan sits at hue 187 and Function at 250, leaving only the middle.
  type = {
    -- hue 220, L* 82.0, C* 43.6, 11.79:1. The only rung in the blue band that
    -- clears dE 20 against Function (20.7) -- everything at L* 74-78 scores
    -- 13-18. Rejected on sight as too bright: it buys that separation purely
    -- with lightness, and lightness is what made it glare in dense TSX.
    sky = "#0edfff",
    -- hue 225, L* 76.0, C* 34.0, 9.96:1. Tried 2026-08-09 and rejected after a
    -- pass over Go, Lua, TS and TSX. It scores well in isolation, but hue 225
    -- sits BETWEEN String (187) and Function (250), so it reads as ambiguous
    -- between the two rather than distinct from either -- its String separation
    -- falls to 18.8 where #7dcfff holds 25.5. A worst-neighbour score cannot see
    -- that; only reading real files can.
    sky_calm = "#56cae7",
    sky_soft = "#49ddff", -- hue 225, C* 39.6, vs Function 19.8
    sky_softer = "#61dbff", -- hue 230, C* 36.5, vs Function 19.0
    sky_dim = "#39cce9", -- hue 222, L* 76, C* 38 -- dE 4.6 from `sky`, borderline
    -- THE SELECTION. hue 249, L* 79.7, C* 33.5, 11.08:1. Restored 2026-08-09
    -- after three replacements were tried and rejected on real files.
    --
    -- It shares hue 249 with Function and splits on lightness alone (dE 16.2),
    -- which every replacement was chosen to fix -- and each one cost more
    -- elsewhere than it gained there. What actually carries this pair is the
    -- 20.6 L* gap, the largest of any candidate; it is also 25.5 from String,
    -- where the closest rival managed 18.8.
    tokyonight = "#7dcfff",
    -- Both rejected 2026-08-09. `vscode_entity` read "flat": de-accenting via
    -- chroma failed here exactly as it failed on the keyword ladder, so treat
    -- chroma as presence in this palette, never as the calming lever.
    -- `periwinkle` measured best of everything tried (worst 20.9, and it
    -- dissolved the Type/Function pair entirely) and still lost on looks.
    vscode_entity = "#c0caf5", -- hue 284, C* 22.9
    periwinkle = "#a7b1fe", -- hue 290, C* 42.0
    nvim_type = "#2ac3de", -- rejected: 15.2 from func, 16.4 from string
    vscode_support = "#0db9d7", -- rejected: 12.7 from func
  },

  -- Fields and properties (@variable.member, @property, and @tag.attribute by
  -- link).
  --
  -- NOTHING IN THIS TABLE IS APPLIED. The `hl["@variable.member"]` line in
  -- solarized-osaka.lua is commented out as of 2026-08-09, so member falls back
  -- to the theme's cyan500 and is an exact duplicate of String (dE2000 0.0).
  -- The values below are kept for the day this reopens; re-enabling is a
  -- one-line uncomment there.
  --
  -- Why it was turned off: rose was only ever a measurement winner, never judged
  -- on looks, and it did not hold up in HUGE files -- exactly the coverage
  -- problem rule 4 describes. Living with the String collision was preferred.
  --
  -- If it reopens, the constraints are unchanged: clear String, and stay IN the
  -- accent band (L* ~60), because these symbols appear on nearly every line and
  -- a bright value drains its neighbours. Scores below were measured against the
  -- palette of 2026-08-09, when keyword was still L* 65.4 -- it has since moved
  -- to 59.6, so re-measure anything that was close to keyword.
  member = {
    -- hue 330, L* 60.1, C* 33.6, 6.02:1, worst neighbour 21.4 -- the best score
    -- of anything measured for this slot, level with String (60.4) and Function
    -- (59.1) rather than above them. Rejected on looks 2026-08-09.
    rose = "#b67faf",
    -- hue 295, L* 62.0, C* 48.0, worst 20.9. Best option outside the rose
    -- family; tried 2026-08-09 and rejected on looks.
    iris = "#8d8de3",
    purple = "#a17bcc", -- hue 310, L* 58, worst 20.7 -- one step further round
    rose_warm = "#be7ca6", -- hue 340
    rose_cool = "#ac82b7", -- hue 320
    mauve = "#c49ac6", -- rejected: L* 68.7, above String and Function
    violet = "#9b9fec", -- rejected: L* 67.9, also above the accent band
    tokyonight = "#73daca", -- rejected: 5 degrees from String cyan, dE 15.7
    -- Non-purple families measured and rejected on collisions: green-teal hits
    -- keyword at hue 135 (20.8) and String from 150 on (15.9 falling to 10.6);
    -- tan hits punct/tag and keyword from both sides (15.5-17.9).
  },
}

-- The live selections. Changing a colour is a one-word edit here.
return {
  -- SETTLED 2026-08-09 after one day on olive. Olive shifts 4.2 degrees toward
  -- green between the laptop panel and the external monitor where yellow shifts
  -- 0.5, and it lands on the git-added green. Do not reinstate it without
  -- reading notes/syntax-palette-decisions.md.

  keyword = variants.keyword.balanced,
  -- Currently UNREAD: the whole grammar-dimming experiment was rejected on
  -- 2026-08-09 and solarized-osaka.lua paints nothing with it. Kept wired so the
  -- values stay measured if it ever reopens -- but read the variants note first,
  -- because the rejection was on looks after five colours, not on mechanics.
  keyword_grammar = variants.keyword_grammar.cool_grey,
  punctuation = variants.punctuation.terracotta,
  func = variants.func.azure,
  type = variants.type.tokyonight,
  -- Currently UNREAD: solarized-osaka.lua has the `@variable.member` override
  -- commented out, so member uses the theme's cyan500. Kept wired up so the
  -- override is a one-line uncomment if it reopens.
  member = variants.member.rose,
}
