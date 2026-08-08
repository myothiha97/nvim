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
    -- SELECTED 2026-08-09, but NOT settled -- the olive/yellow call is an open
    -- todo (todos/syntax-palette-followups.md). Rejected on 2026-08-08 as
    -- "gold/yellowish", then reinstated for the opposite reason: it is the
    -- calmer of the two in KEYWORD-DENSE code. The yellow is fine in ordinary
    -- files and only reads loud where keywords cluster, which is rule 3
    -- (frequency vs brightness) and rule 4 (coverage is the variable) applied
    -- to the keyword role itself.
    --
    -- The two differ on lightness, not saturation: chroma is 67.0 vs 67.4,
    -- which is far under the perceptual floor, so "less intense" here means
    -- L* 59.6 against 65.4. Do not try to calm either one by dropping chroma --
    -- `drab` and the subdued/hushed ladder below are that experiment failing.
    olive = "#849900", -- hue 111, L* 59.6, C* 67.0, 5.92:1
    -- Runner-up, and the selection from 2026-08-08 to 2026-08-09. Higher
    -- contrast (clears WCAG AA with more room), and it is the only hue that
    -- reads as actual yellow -- below ~L* 62 yellow turns khaki.
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
  -- Provisional, 2026-08-09. `balanced` (yellow) is the runner-up and the two
  -- are still an open call -- see todos/syntax-palette-followups.md. Not a bug,
  -- do not "fix" it back.
  keyword = variants.keyword.olive,
  punctuation = variants.punctuation.terracotta,
  func = variants.func.azure,
  type = variants.type.tokyonight,
  -- Currently UNREAD: solarized-osaka.lua has the `@variable.member` override
  -- commented out, so member uses the theme's cyan500. Kept wired up so the
  -- override is a one-line uncomment if it reopens.
  member = variants.member.rose,
}
