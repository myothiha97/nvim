-- Colour selections for the solarized-osaka theme.
--
-- ============================================================================
-- WHY THIS FILE EXISTS
-- ============================================================================
--
-- The problem. Stock solarized-osaka is a good theme that does not fit how this
-- editor is used. Three concrete faults, all measured rather than felt:
--
--   1. ROLES COLLIDED WITH MEANING. `Type` was yellow500, so every `int`,
--      `string`, `float64`, `ReactNode` and `Optional` read as gold -- in Go and
--      TS that is most of a signature. `@module` and `@keyword.import` linked to
--      a saturated alarm red 31 degrees of hue from the error red, so `import`
--      and `package main` read as diagnostics.
--   2. PUNCTUATION WAS PAINTED AS LANGUAGE. `Operator` and
--      `@punctuation.delimiter` carried the keyword colour, so every `=`, `.`,
--      `,` and `;` counted as a keyword. That put an accent mark on nearly every
--      line and made the same colour feel calm in one file and loud in another --
--      measured at an 11x spread between two Lua files in the same repo.
--   3. IT RAN HOT ON A NEAR-BLACK BACKGROUND. High chroma against L* 5 is what
--      reads as glare, and stock sits ~17% higher in weighted chroma than what
--      this palette now runs.
--
-- What we were solving for, in priority order: long-session comfort first,
-- then role separation (can you tell a type from a function at a glance), then
-- staying recognisably Solarized. Not "prettier".
--
-- Where it landed, measured against upstream on real files: -17% weighted chroma
-- in TSX, -23% in Go, loudest accent down from C* 90.6 to 75.5, and four of five
-- accents still mapping to canonical Solarized hues. It is not a darker theme,
-- it is a less saturated one.
--
-- ============================================================================
-- HOW TO USE THIS FILE
-- ============================================================================
--
-- Every value ever tried is kept here by name, so changing a colour is a
-- one-word edit to the `return` block at the bottom. Keys are named for the
-- ROLE they fill, never for a theme slot -- a role can move to any hue, and
-- naming it after a colour is how `green` ended up holding a yellow.
--
-- These feed SYNTAX GROUPS ONLY. solarized-osaka/init.lua deliberately has no
-- `on_colors`, so nothing here can reach diagnostics, git signs, lualine or any
-- other UI. See the note at the top of that file before changing the approach.
--
-- THIS FILE IS A DATA TABLE, NOT A DOCUMENT. Each value carries its verdict and
-- its numbers so a candidate can be judged in place. The reasoning, the
-- measurements and every rejected experiment live in:
--
--   notes/syntax-palette-decisions.md
--
-- Read it before changing a value. Most obvious ideas have already been tried,
-- measured, and rejected for a recorded reason. Four rules in short:
--   1. Two roles must not share a hue band; splitting by lightness alone fails.
--   2. Tune hue and chroma -- lightness-only moves land under the perceptual floor.
--   3. Frequency is inversely related to brightness.
--   4. If a colour looks right in some files and wrong in others, the variable
--      is coverage, not value.
-- Measure against Ghostty's #031219, not nvim's #001419 (transparent = true).
-- Ghostty tags content display-p3, so authored numbers are NOT what the panel
-- emits -- accents arrive ~20 C* higher. Note both where it matters.

local variants = {
  -- Keyword, Statement, @keyword, @keyword.operator, @label.
  keyword = {
    -- SELECTED 2026-08-10, replacing yellow. This slot paints the densest
    -- capture in the daily stack, so rule 3 binds hardest here: yellow and olive
    -- both emit C* ~88 where every other accent arrives at 38-52, which made the
    -- keyword the only supersaturated colour on screen. Violet sits inside the
    -- band its neighbours occupy and 10.3 L* below body text.
    -- STOP RULE: re-measure if keyword dose passes ~7% of ink.
    -- Full reasoning: notes, "Keyword: yellow -> violet".
    warm_violet = "#a17bcc", -- L* 58.1, C* 47.7, hue 310; emits 58.6/52.3/312
    -- Measured against warm_violet 2026-08-10, not chosen. Kept so the purple
    -- band is not re-derived a second time.
    kanagawa = "#957fb8", -- best minimum separation (22.6), but flat at C* 33.5
    tokyonight = "#9d7cd8", -- more vivid and cooler; moves toward the blue family
    warm_rose = "#b67faf", -- clearest from blue, but reads rose rather than keyword
    tokyonight_magenta = "#bb9af7", -- L* 69.7, above body text -- rule 3 again
    catppuccin_mauve = "#cba6f7", -- L* 74.0, same problem, worse
    -- Held the slot for one day, 2026-08-09. Rejected on DISPLAY STABILITY, not
    -- looks: hue 111 sits where the P3/sRGB gamut difference bites, so it shifts
    -- 4.2 degrees toward green between the laptop and the external monitor where
    -- yellow shifts 0.5. Also lands dE ~0.2 from the git-added green #859900,
    -- undoing what commit bdb87f0 decoupled on purpose.
    olive = "#849900", -- hue 111, L* 59.6, C* 67.0, 5.92:1
    -- Held the slot 2026-08-08 to 2026-08-10; still reachable as
    -- `:colorscheme solarized-osaka-custom-v2`. Highest contrast of the three and
    -- the only hue here that reads as actual yellow -- below ~L* 62 it turns
    -- khaki. Lost to violet on emitted chroma (87.9), not on hue.
    -- Dose reference, still valid: comfortable to ~6% of glyphs, uncomfortable
    -- past ~10%. Only Lua exceeded that, at 11.6%.
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

  -- Lua's `end` / `then` / `do`, dimmed so block grammar reads as chrome.
  --
  -- REJECTED WHOLESALE 2026-08-09 and NOTHING READS THIS TABLE. Kept so the
  -- experiment is not run a third time. The mechanics worked and the coverage
  -- numbers were real (8.6% of glyphs down to 6.3%); every quiet colour simply
  -- read as out of place next to the accents, five in a row. Lua is a config
  -- language here, not part of the daily stack, so its density is not worth a
  -- fourth colour.
  --
  -- Two things to know before reopening it, both structural:
  --   * `end` is the right target and `local` is not -- an `end` sits alone on
  --     its line where a quiet colour reads as chrome, while `local` sits against
  --     a variable name where the same colour reads as dirt.
  --   * Keep candidates COOL. A warm hue dimmed far enough to recede stops being
  --     that hue and becomes brown; every warm candidate was rejected as bronze.
  --
  -- Redoing it needs after/queries/lua/highlights.scm back (deleted 2026-08-09):
  -- `; extends`, then `[ "end" "then" "do" ] @keyword.structure`, because the
  -- runtime query files those tokens under the construct they close.
  -- Full write-up: notes, "Grammar keywords: an experiment that failed twice".
  keyword_grammar = {
    -- Midway between Comment and body text on the theme's own cool grey axis:
    -- 10.7 dE from Comment, 12.2 from body text. Clears WCAG AA.
    cool_grey = "#75878a", -- hue 215, L* 55.0, C* 7.0, 5.06:1
    base00 = "#637981", -- one step down; 4.7 dE from Comment, sub-AA at 4.15:1
    fg = "#839395", -- one step up; only 7.8 dE from body text, reads as code
    -- Rejected 2026-08-09 on looks, all three while this role still meant `local`.
    warm_grey = "#888474", -- hue 98, C* 9.3 -- still read as bronze
    bronze = "#8b8465", -- hue 98, C* 17.9 -- double chroma, a brown
    base0 = "#9eabac", -- L* 69.0, BRIGHTER than the keyword it defers to
  },

  -- Body text: `Normal`, `NormalFloat` and `@variable`, which are the same value
  -- by design here (a plain identifier IS body text in this palette).
  --
  -- Rule 3 binds hardest on this role -- it is the most frequent colour on
  -- screen -- so it is raised only far enough to be seen, and it must stay below
  -- the Type colour `#7dcfff` (L* 79.7), which is the palette's deliberate
  -- brightest landmark.
  body = {
    base0 = "#9eabac", -- L* 69.0, 8.23:1 -- the theme's own, and the default
    base1 = "#adb7b7", -- L* 73.7 -- the theme's next rung, but only +4.6 L* and
    -- dE 3.7, i.e. at the perceptual floor: measured, and too small to see.
    brighter = "#b1bebf", -- L* 76.0, +7.0, 10.19:1, dE 5.3 -- SELECTED for
    -- the live selection. Clears the floor, still 3.7 L* under the Type colour.
    brightest = "#bcc9ca", -- L* 80.0, +11.0 -- passes the Type colour; rule 3
    base2 = "#ede7d3", -- the theme's base2: L* 91.6 and a CREAM, not a grey
  },

  -- Operators and delimiters. The grey ladder is the theme's own base ramp, so
  -- these are the theme's hexes, not new colours.
  --
  -- Why there is a choice here at all: upstream paints these olive `#849900`,
  -- and moving them to base0 put them on the SAME value as `@variable`. The
  -- value of a variable never changed, but base0 went from 32.0% to 38.1% of
  -- glyphs on lua/config/quickfix-persistence.lua and from 272 to 464 separate
  -- runs (+71%), so a name lost the coloured edge its operators used to give it.
  -- That is what reads as "variables look faded next to upstream". Rule 4: the
  -- variable is not the variable.
  delimiter = {
    base0 = "#9eabac", -- L* 69.0, 8.23:1 -- the default, identical to @variable
    base00 = "#637981", -- L* 49.4, 4.25:1 -- one rung down; dE 18.0 from base0,
    -- which is the edge that comes back, but it is SUB-AA and only dE 4.7 from
    -- Comment `#576d74`, so punctuation starts reading as commented-out. That
    -- trade was judged by eye on 2026-09-05 and lost to the maximin rung below.
    base01 = "#576d74", -- Comment itself. Listed to be explicit that it is not a
    -- candidate: punctuation would be exactly the comment colour.

    -- The theme's ramp jumps 19.6 L* from base00 to base0 with nothing between,
    -- so these are synthesised on the SAME grey axis (hue 206, C* interpolated)
    -- to land the rung the ramp does not have. They exist because base00 is
    -- sub-AA and `=` `==` `>` `<` `&&` carry logic.
    --
    -- `mid_high` IS THE MAXIMIN RUNG, and since 2026-09-06 it is the value of
    -- BOTH punctuation roles (`delimiter` and `bracket`). Punctuation has to stay
    -- clear of body text ABOVE it and Comment BELOW it, and those two pull in
    -- opposite directions, so the best value is the crossover where they balance:
    --
    --   hex       L*     AA     dE body  dE comment   worst
    --   #798c91  56.9  5.54:1     15.7       12.4      12.4   (`mid`)
    --   #7f9195  58.9  5.93:1     13.8       14.4      13.8   <- SELECTED
    --   #859699  60.9  6.33:1     12.1       16.2      12.1
    --   #8b9b9e  62.8  6.75:1     10.4       17.9      10.4   (`brightest`)
    --   #91a0a2  64.8  7.19:1      8.7       19.5       8.7
    --
    -- So "make it brighter to distinguish it better" is FALSE above this rung:
    -- past 58.9 every step buys comment separation by giving up more body
    -- separation, and the worst pair gets worse. Do not rebuild this ladder.
    --
    -- THE TWO-RUNG SPLIT WAS TRIED AND DROPPED. From 2026-09-05 to 09-06
    -- `delimiter` sat one rung above `bracket` (`brightest` over `mid_high`) on
    -- the argument that operators carry more meaning than brackets. Dropped
    -- because the gap it bought was dE 3.5, and this palette's own precedent
    -- (see `base00` above) treats dE 4.7 as the point where two colours already
    -- read as one. It was paying the delimiter's best body separation (13.8 down
    -- to 10.4) for a difference nobody can see. The two roles still exist
    -- separately so a future build can move them apart; they just hold one value.
    --
    -- COLOUR WAS TRIED HERE TOO, on 2026-09-06, and lost. Full argument in
    -- notes/syntax-palette-decisions.md, "2026-09-06: punctuation settles". The
    -- one-line version: the delimiter role is 10.5% of code ink in TS/TSX and
    -- 14.6% in Go, the highest dose of anything in this palette, and a sweep of
    -- every hue at 5-degree steps and chroma 6-45 across L* 50-68 tops out at
    -- worst-case dE 23.3 against the twelve live colours. The wheel is full.
    -- Do not reopen this without a new colour to make room with.
    mid_high = "#7f9195", -- L* 58.9, 5.93:1, worst separation 13.8 -- SELECTED
    mid = "#798c91", -- L* 56.9, 5.54:1 -- one rung down, worst 12.4
    mid_low = "#73878d", -- L* 55.0, 5.18:1 -- most body edge, closest to Comment
    -- Above the maximin, kept only so the table shows the curve turning over.
    brighter = "#859699", -- L* 60.9, worst 12.1
    brightest = "#8b9b9e", -- L* 62.8, worst 10.4 -- held `delimiter` for one day
  },

  -- Special, Debug, @punctuation.bracket, @variable.builtin, JSX tags and
  -- delimiters, @keyword.import -- and, via the `parameter` role below, also
  -- @variable.parameter and @constructor, which held this value on their own
  -- until 2026-09-05 and still default to it.
  --
  -- The densest accent in the palette: 19.1% of ink in markup-heavy TSX. Whatever
  -- sits here is the warm side of the screen on its own, because every other
  -- accent is cool (violet 310, azure 250, sky 249, cyan 187).
  --
  -- HARD CONSTRAINT: keep clear of the error red `#ff3b30` (L* 56.7, C* 88.7,
  -- hue 36, set in solarized-osaka/init.lua) so brackets never read as diagnostics.
  -- Chroma does that work, not hue -- every warm value here sits within a few
  -- degrees of hue 36, and the only one ever measured to clear dE 20 was an
  -- amber at hue 70 that failed for other reasons (`explored.balanced_amber`).
  punctuation = {
    -- SELECTED 2026-08-11, replacing terracotta. Fixes both of this role's
    -- recorded defects: contrast 4.26 -> 4.56:1, clearing the WCAG AA floor
    -- terracotta was under, and distance from the error red 13.4 -> 17.8,
    -- retiring what was the tightest pair in the palette.
    --
    -- KNOWN COST, accepted: it breaks the pairing rule below. Emits C* 75.5
    -- against the violet keyword's 52.3 -- a gap of 23.2 where terracotta held
    -- 0.4 -- so punctuation now out-saturates the keyword. IF THE SCREEN EVER
    -- READS PUNCTUATION-HEAVY, THAT GAP IS THE CAUSE; `terracotta` is one word
    -- away. Chosen over `copper_warm` on that number alone: the two are dE2000
    -- 1.3 apart, i.e. the same colour, so do not re-run that comparison.
    copper_mid = "#be6421", -- L* 52.0, C* 60.0, hue 58, 4.56:1, emits C* 75.5
    -- Held the slot until 2026-08-11 and kept as the fallback, wired as
    -- `:colorscheme solarized-osaka-custom-v3`. The only value that satisfies the
    -- pairing rule perfectly. Its two defects are why it moved: the palette's
    -- only sub-AA colour, and the tightest pair here against the error red.
    -- Display-stable where copper is not, but it fades against bright neighbours
    -- on the P3 panel, which is why copper won the single-value choice.
    terracotta = "#b55f4a", -- L* 50.1, C* 42.9, hue 40, 4.26:1, emits C* 52.0

    -- THE PAIRING RULE, found 2026-08-11. The keyword and punctuation accents
    -- want the SAME emitted chroma or one drowns the other. Exactly two balanced
    -- pairings exist: both loud (upstream olive 87.3 / orange500 90.6, gap 3.2)
    -- or both calm (violet 52.3 / terracotta 52.0, gap 0.4). It is a two-data-
    -- point rule and it cannot see temperature, which is why it was overruled
    -- here -- but check it before raising either of this pair.
    --
    -- Everything measured that day, kept as ONE group so the same three ladders
    -- are not rebuilt a fourth time. Nothing reads it. All were rejected ON LOOKS
    -- despite measuring well -- "too orange or too pink" -- so judge anything
    -- from here on looks, never on the numbers alone.
    -- Full write-up: notes, "Punctuation: terracotta -> copper".
    explored = {
      -- LIGHTNESS at hue 40, chroma held at the balance point. The measured best
      -- direction: closes the 9.1 L* gap to the accent cluster, fixes the sub-AA
      -- contrast, and is the only axis that keeps the pairing intact. Rejected
      -- because hue 40 stops being earthy and starts reading pink on the way up.
      clay = "#c16953", -- L* 54.0 (+4), 4.90:1
      coral = "#c76e58", -- L* 56.0 (+6), 5.25:1
      salmon = "#cd735d", -- L* 58.0 (+8), 5.62:1 -- lands exactly on the cluster

      -- HUE at salmon's lightness, so hue is the only variable against `salmon`.
      -- Rotating toward red is close to free: contrast stays flat and the
      -- error-red distance IMPROVES (11.8 at hue 40 -> 13.1 at hue 26), because
      -- rotating off that red's own hue 36 beats matching its lightness.
      sunset = "#cf7163", -- hue 34
      blush = "#d16f68", -- hue 30
      dusty_rose = "#d16e6c", -- hue 26
      -- Browner direction at the same three lightnesses, measured, not pursued:
      -- hue 46 gives #be6b4d / #c47052 / #ca7557.

      -- CHROMA at hue 58, the ladder that produced the selection. All share
      -- L* ~52, so saturation is the only variable. Terracotta is the C* 42.9 end
      -- of the same axis. Each rung roughly halves the pairing gap.
      copper_soft = "#ba662b", -- C* 54.8, emits 67.9, pairing gap 15.6
      copper_warm = "#c26116", -- C* 65.1, emits 83.7, gap 31.4 -- dE 1.3 from the
      -- selection, i.e. indistinguishable, and 8 points worse on the pairing
      copper = "#cb6001", -- C* 72.6, emits 97.2, gap 44.9 -- judged too bright
      -- WHY copper reads "brighter": it is only +2.9 L* over terracotta, under
      -- the perceptual floor, so the whole impression is chroma (+29.7). A "make
      -- it brighter" request on this role is almost always a chroma request --
      -- check which axis the complaint is on before building a ladder.

      -- Off-axis, both measured and rejected for reasons worth keeping.
      ember = "#c85c27", -- C* 63.1, gap 26.0 -- hue 51, the redder middle
      sienna_hot = "#d85d13", -- C* 74.7, gap 44.1
      -- Satisfied EVERY numeric constraint at once: balanced, AA-clean, and the
      -- only warm value ever measured to clear dE 20 from the error red (24.9).
      -- Lost because hue 70 is amber, and at 19.1% of TSX ink it would have put
      -- gold back on screen -- which is what moved `Type` off yellow originally.
      balanced_amber = "#a67136", -- L* 52.0, C* 43.1, hue 70, 4.56:1
      -- The real Solarized orange, for reference: copper's saturation at a redder
      -- hue, and why copper reads as "more solarized". The theme's own orange500
      -- #c94c16 is the same colour to within dE 1. Both are sub-AA.
      solarized_orange = "#cb4b16", -- L* 49.2, C* 72.5, hue 48, 4.13:1
    },

    -- Untried in place. Measures better than terracotta on both of its defects
    -- (7.19:1, and dE 21.3 from the error red), but at L* 65.5 it clears the
    -- accent cluster entirely rather than joining it.
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
  --
  -- OPEN: this is the only role not yet optimised, and the brightest value in the
  -- palette by 20 L*. See item 8 of todos/syntax-palette-followups.md -- and note
  -- that every DIMMER candidate below collides with Function, because Type and
  -- Function sit one degree apart in hue and their whole separation IS the 20.6
  -- L* gap. The blue band cannot produce a dimmer Type.
  type = {
    -- The only rung in the blue band that clears dE 20 against Function (20.7);
    -- everything at L* 74-78 scores 13-18. Rejected on sight as too bright: it
    -- buys that separation purely with lightness.
    sky = "#0edfff", -- hue 220, L* 82.0, C* 43.6, 11.79:1
    -- Tried 2026-08-09 and rejected after a pass over Go, Lua, TS and TSX. Scores
    -- well in isolation, but hue 225 sits BETWEEN String (187) and Function (250)
    -- so it reads as ambiguous between the two rather than distinct from either --
    -- its String separation falls to 18.8 where #7dcfff holds 25.5. A
    -- worst-neighbour score cannot see that; only reading real files can.
    sky_calm = "#56cae7", -- hue 225, L* 76.0, C* 34.0, 9.96:1
    sky_soft = "#49ddff", -- hue 225, C* 39.6, vs Function 19.8
    sky_softer = "#61dbff", -- hue 230, C* 36.5, vs Function 19.0
    sky_dim = "#39cce9", -- hue 222, L* 76, C* 38 -- dE 4.6 from `sky`, borderline
    -- THE SELECTION. Restored 2026-08-09 after three replacements were tried and
    -- rejected on real files. It shares hue 249 with Function and splits on
    -- lightness alone (dE 16.2) -- rule 1 broken knowingly. What carries the pair
    -- is the 20.6 L* gap, the largest of any candidate; it is also 25.5 from
    -- String where the closest rival managed 18.8.
    tokyonight = "#7dcfff", -- hue 249, L* 79.7, C* 33.5, 11.08:1
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

  -- Fields and properties (@variable.member, @property, @tag.attribute by link).
  --
  -- NOTHING IN THIS TABLE IS APPLIED. The `hl["@variable.member"]` line in
  -- solarized-osaka/init.lua is commented out as of 2026-08-09, so member falls back
  -- to the theme's cyan500 and is an exact duplicate of String (dE2000 0.0).
  -- Re-enabling is a one-line uncomment there.
  --
  -- Turned off because rose was only ever a measurement winner, never judged on
  -- looks, and it did not hold up in huge files -- rule 4 again. Living with the
  -- String collision was preferred. If it reopens: clear String, and stay IN the
  -- accent band (L* ~60), because these symbols appear on nearly every line and a
  -- bright value drains its neighbours. Scores below predate the keyword move to
  -- violet, so re-measure anything that was close to keyword.
  member = {
    -- Best score of anything measured here, level with String (60.4) and Function
    -- (59.1) rather than above them. Rejected on looks 2026-08-09.
    rose = "#b67faf", -- hue 330, L* 60.1, C* 33.6, 6.02:1, worst 21.4
    iris = "#8d8de3", -- hue 295, L* 62.0, C* 48.0, worst 20.9 -- best non-rose
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

-- THE LIVE SELECTIONS. Changing a colour is a one-word edit here; every group
-- that uses the role follows automatically. Each line names why it won in one
-- sentence -- the full argument is on the variant above it, and the measurements
-- are in notes/syntax-palette-decisions.md.
return {
  -- Every candidate above, exposed by role so the alternative colorschemes can
  -- name one without copying its hex. Read only by
  -- lua/colorschemes/solarized-osaka/variants.lua; nothing in the theme itself
  -- touches it, and it costs nothing -- the table is built either way.
  variants = variants,

  -- Violet over yellow and olive: the only one of the three that sits inside the
  -- accent band it shares the screen with, on the densest capture in the stack.
  keyword = variants.keyword.warm_violet,
  -- UNREAD. The grammar-dimming experiment was rejected 2026-08-09 and
  -- solarized-osaka/init.lua paints nothing with it. Kept wired so the values stay
  -- measured if it reopens.
  keyword_grammar = variants.keyword_grammar.cool_grey,
  -- THE 2026-09-05 SELECTION. Five roles moved together on that day, after ten
  -- builds were measured against each other; `custom-latest` is the name for it and
  -- `custom-v1` is the copper look that preceded it. The argument for each value
  -- is on `custom-latest` in variants.lua, and the measurements are in
  -- notes/syntax-palette-decisions.md, "The 2026-09-05 rebuild".
  --
  -- The shape in one sentence: FOUR LIGHTNESS STEPS, ordered by how much the
  -- thing means -- body text 76.0, names 65.5, punctuation 62.8/58.9, comments
  -- 44.6 -- with exactly one accent hue on the warm side instead of two.

  -- Yellow replaced copper here. It is the same value the keyword wore as
  -- `custom-v2`, and it wins on two things copper could not fix: copper was the
  -- palette's ONLY sub-AA colour (4.56:1 -> 7.37:1) and its tightest pair
  -- against the error red (dE 17.8 -> far). Dropping copper also removes the
  -- chroma outlier from the accent set, so emitted spread falls 31.2 -> 24.0.
  -- `variants.punctuation.copper_mid` is the one-word revert.
  punctuation = variants.keyword.subdued,
  -- Parameter names and `new X()` callees. Split off `punctuation` on 2026-09-05
  -- so a build can recolour them alone; it holds the same yellow here, because
  -- what separates a parameter from its brackets is now the BRACKET being grey,
  -- not the name being a different hue.
  --
  -- No variant table of its own: every candidate is already measured under
  -- `punctuation` or `keyword`. One constraint is specific to this role -- hue 70
  -- and below is the same colour as copper punctuation
  -- (`punctuation.explored.balanced_amber` measures dE 8.5 from it), which is why
  -- the warm band below yellow is closed to it.
  parameter = variants.keyword.subdued,
  -- Operators and delimiters (`=` `.` `,` `;` `:`, JSX `<` `>` `/`). These left
  -- the body colour on 2026-09-05: they had been painted base0 since
  -- 2026-08-08/08-10, which is the SAME value as `@variable`, so a name had no
  -- edge against the punctuation around it. That is what "variables look faded
  -- next to upstream" turned out to be -- coverage, not value.
  --
  -- `false` would mean "follow the theme's own base0"; init.lua reads it as
  -- `palette.delimiter or c.base0`, and `custom-v1` sets it back to `false`.
  --
  -- WARN: SILENT FAILURE. A build that wants the old behaviour must write
  -- `delimiter = false`, never `nil`. `nil` is not a value in a Lua table, it is
  -- the absence of the key, so `variants.load` iterates the build with `pairs`,
  -- never sees it, and the override simply does not happen -- the build renders
  -- as if that line were not there, and nothing reports it. Verified.
  --
  -- (The related leak -- a build's colour surviving into the NEXT
  -- `:colorscheme` because `pairs` skipped a nil while restoring -- is closed
  -- for this role only because the default below is a real value rather than
  -- `nil`. Keep it that way.)
  --
  -- WARN: SILENT FAILURE. This block is a Lua table literal, so writing a role
  -- key TWICE is not an error -- the last assignment simply wins and the earlier
  -- line becomes a lie that reordering would activate. It happened here on
  -- 2026-09-06 with this exact key. After editing a role, check it appears once:
  --   grep -c "^  delimiter = " lua/colorschemes/solarized-osaka/palette.lua
  --
  -- SETTLED 2026-09-06 at `mid_high`, the maximin rung, which `bracket` below
  -- also holds -- see the ladder in `variants.delimiter` for why one value beat
  -- two. Verified by measuring the rendered pixels of real Go, TSX, TS and Lua
  -- screens, not by eye: every operator glyph peaks at exactly this hex, 5.93:1,
  -- including the thinnest ones (`*` and `.` at 26 lit pixels) and the `==`/`!=`
  -- ligatures. Nothing here needs retuning.
  delimiter = variants.delimiter.mid_high,
  -- Body text, raised +7.0 L* on 2026-09-05. The theme's own next rung (base1)
  -- is only +4.6 and measured under the perceptual floor, i.e. invisible. Same
  -- `false`-not-`nil` rule as `delimiter`.
  body = variants.body.brighter,
  -- Brackets: `(` `)` `[` `]` `{` `}` and Lua's table braces. Split off
  -- `punctuation` on 2026-09-05 and sent to the GREY, not to an accent -- they
  -- are the same "punctuation carrying no meaning worth a hue" class as
  -- `Operator` and `@punctuation.delimiter` and were simply never moved with
  -- them. This is what lets a yellow name sit inside neutral punctuation.
  --
  -- The SAME value as `delimiter` since 2026-09-06. It was one rung dimmer for a
  -- day, on the argument that a bracket is the most scattered glyph on screen
  -- (1.20 chars per mark, measured) and should recede furthest. That held right
  -- up until the gap was measured at dE 3.5, below the threshold this palette
  -- already treats as invisible. The role stays separate so a build can split
  -- them again; it just is not worth a rung today.
  --
  -- WARN: SILENT FAILURE. `false`, never `nil` -- see `delimiter` above: a `nil`
  -- here is an absent key, so the override silently never happens.
  bracket = variants.delimiter.mid_high,
  func = variants.func.azure,
  -- Off the theme's yellow500, which made every type in Go/TS/Python read as
  -- gold. Known weak pair with Function -- see the note on the variant.
  type = variants.type.tokyonight,
  -- UNREAD. solarized-osaka/init.lua has the `@variable.member` override commented
  -- out, so member uses the theme's cyan500. One-line uncomment if it reopens.
  member = variants.member.rose,
}
