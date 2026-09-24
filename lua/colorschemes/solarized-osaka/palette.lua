-- Colour VALUES for the solarized-osaka theme. Keys name the ROLE, never a hue.
-- Changing a colour is a one-word edit to the `return` block at the bottom.
--
-- Feeds SYNTAX GROUPS ONLY. `on_colors` in init.lua owns the UI background.
--
-- EVERY value's measurements, verdict and rejection reason live in
-- notes/palette-reference.md -- one table per role, anchored by role name.
-- READ IT BEFORE CHANGING A VALUE. Most obvious ideas are already rejected there
-- with numbers, including four rules that keep being relearned.
--
-- WHAT IS ACTUALLY ON SCREEN IS NOT DECIDED HERE. The `return` block at the
-- bottom sets the BASE defaults, and `custom-latest` in variants.lua overrides
-- any of them -- so that build is the authority, and comments in this file
-- describe candidates and base defaults, never "what I am looking at". A note
-- here claiming otherwise has probably gone stale; read variants.lua, or dump
-- the truth from a running editor:
--   :lua =vim.api.nvim_get_hl(0,{name='@boolean',link=false})

local variants = {
  -- Keyword, Statement, @keyword, @keyword.operator, @label.
  -- Densest capture in the daily stack. STOP RULE: re-measure past ~7% of ink.
  keyword = {
    warm_violet = "#a17bcc", -- SELECTED for `keyword` itself
    kanagawa = "#957fb8",
    tokyonight = "#9d7cd8",
    warm_rose = "#b67faf",
    tokyonight_magenta = "#bb9af7",
    catppuccin_mauve = "#cba6f7",
    olive = "#849900",
    balanced = "#aea10c", -- custom-v2
    darker = "#a3970b",
    -- The yellows below are candidates for `punctuation` + `parameter`, which
    -- read from this table; they are not keyword candidates.
    brighter = "#baac0d", -- L*69.5 C*70.8 h97.9 8.14:1 | SELECTED for punctuation + parameter
    -- L*74.0 C*76.0 h97.9 9.39:1 | TRIED AND REJECTED 2026-09-08. `brighter` is
    -- already at the sRGB chroma ceiling for its lightness and hue, so "more
    -- saturated at the same brightness" does not exist -- yellow only gets vivid
    -- by getting lighter, and the 4.5 L* it costs puts this level with body text
    -- on the palette's highest-dose role after body itself. Every separation gain
    -- was at or below the JND. If the yellow reads dull the lever is DOSE, not
    -- lightness. Full measurements in notes/palette-reference.md, "keyword".
    vivid = "#c7b903",
    amber = "#b59a00",
    citron = "#9ea100",
    subdued = "#aea134", -- the yellow; base default for punctuation + parameter
    hushed = "#aea042",
    gold = "#b99004",
    drab = "#8c9644",
    verdant = "#5da100",
    sage = "#66985e",
    moss = "#629959",
    fern = "#5d9a53",
    clover = "#599e49",
    juniper = "#569f41",
    leaf = "#4ea339",
    grass = "#56a325",
  },

  -- Lua's `end` / `then` / `do`. REJECTED WHOLESALE 2026-08-09 and NOTHING READS
  -- THIS TABLE. Reopening needs after/queries/lua/highlights.scm back; read the
  -- doc first, the experiment already failed twice.
  keyword_grammar = {
    cool_grey = "#75878a", -- the wired default
    base00 = "#637981",
    fg = "#839395",
    warm_grey = "#888474",
    bronze = "#8b8465",
    base0 = "#9eabac",
  },

  -- Comments. LADDER, brightest first, all on upstream's hue and chroma
  -- (h~226 C*9.2) so only lightness moves. dE against the live value in
  -- brackets; the JND is ~2.3, so anything under that is not a visible change.
  --
  -- AA (4.5:1) IS ONLY CLEARED BY `readable`. Every dimmer stop is below it,
  -- which is what this config ran for months on upstream anyway, so dropping
  -- back is a comfort call, not a defect.
  --
  -- The FLOOR is not contrast, it is `delimiter.mid_high` #7f9195 at L*58.9:
  -- going dimmer moves AWAY from it, so the "two low-chroma greys blur" risk
  -- only exists above `readable`. L*54 (#6e858c, 4.89:1) is the brightest safe
  -- value while punctuation stays chromatic.
  comment = {
    readable = "#698087", -- L*52.1  4.56:1  (dE 0.0)   the only AA stop
    dim = "#647b82", -- L*50.0  4.25:1  (dE 2.0)   below JND, do not bother
    subtle = "#637981", -- L*49.4  4.15:1  (dE 2.8)   one stop down, not enough
    dimmer = "#5f767d", -- L*48.0  3.96:1  (dE 4.0)   SELECTED 2026-09-09
    dimmest = "#5a7178", -- L*46.0  3.68:1  (dE 5.9)   one short of upstream
    -- Upstream #576d74 (L*44.6, 3.48:1, dE 7.4) is reached with `comment = false`,
    -- not a key here: `false` means "leave the theme's own ramp alone".
  },

  -- Body text: `Normal`, `NormalFloat`, `@variable`, one value by design.
  body = {
    -- ONE RUNG BELOW base0, and the only rung here that is NOT a body-text
    -- candidate. L* 64.0 C* 4.8 h 205.7 -- base0's own axis, 5 L* down. Both
    -- axes move, because a lightness-only step on a near-grey is at the JND and
    -- returns no signal (see the rejected chroma rungs below).
    --
    -- LIVE, as `LspDocFloat` in init.lua: the LSP doc surface (hover, signature,
    -- diagnostic floats, blink docs). It RAISED that surface, which had drifted
    -- to the theme's upstream `c.fg` (#839395, 6.06:1) while the editor moved up
    -- to `tinted`. Prose there now clears AAA and still reads as secondary text.
    --
    --   7.01:1 vs #001014     above AAA
    --   dE00 7.3 vs `tinted`  the editor body value: a clear step
    --   dE00 3.9 vs `base0`   the file-list value
    --   dE00 14.4 vs #8ab4d8  inline code, the worst neighbour in a doc float
    --
    -- ALSO TRIED, and reverted the same day: file/folder names in the snacks
    -- explorer and oil. It read as too faded for a name you scan; those lists
    -- run `base0` below. The gap that constrains a file list is dE00 14.2 to
    -- `NonText` #637981, which dims HIDDEN entries in the same list -- floor
    -- about #8c9899 (dE00 12.6), below which hidden files stop looking hidden.
    faded = "#919e9f",
    base0 = "#9eabac", -- the theme's own; also the pre-2026-09-05 @variable value
    -- SELECTED 2026-09-09, replaced by `tinted` on 2026-09-21 (variants.lua).
    -- LCh midpoint of base0 and brighter, same axis as both
    -- (C*4.8 h206). Picked on measurement, not just as a compromise: base0's
    -- nearest neighbour is the delimiter grey at dE00 8.7, which is INSIDE the
    -- <10 band where two values read as one colour on small glyphs. This clears
    -- it at 11.2 and costs nothing elsewhere (worst palette pair stays delimiter
    -- vs comment, 10.7). CVD-safe by construction: a near-grey has no hue to
    -- lose, so deutan/protan separation equals normal vision.
    midpoint = "#a7b4b5", -- L*72.4 C*4.8  8.91:1 vs #031219  nearest 11.2
    -- Chroma-lifted rungs, tried 2026-09-09 because a lightness-only step of
    -- 3.4 L* on a near-grey is at the JND and returned no signal. REJECTED: at
    -- C*8 the value reads as bright as `brighter`, because chroma on the
    -- highest-dose role in the file lifts the whole page, not one mark.
    tinted_high_chroma = "#96b8bb", -- L*72.5 C*12.0  the far end before body reads teal
    tinted = "#a0b6b8", -- L*72.5 C*8.0   8.94:1  first read as too close to brighter; LIVE body since 2026-09-21
    base1 = "#adb7b7", -- L*73.7  9.27:1  off-axis: loses a chroma stop, C*3.7 h199
    brighter = "#b1bebf", -- L*76.0  9.95:1  ran until 2026-09-09, read as too bright
    brightest = "#bcc9ca",
    base2 = "#ede7d3",
  },

  -- Operators and delimiters. `mid_high` IS THE MAXIMIN RUNG: past it, every step
  -- buys comment separation by giving up more body separation, so "make it
  -- brighter to distinguish it better" is FALSE above it. The `mid*` rungs are
  -- synthesised on the theme's grey axis. Ladder + rejected colour sweep in the
  -- doc; do not rebuild it.
  delimiter = {
    kanagawa_mid = "#96abd3", -- LCh midpoint of the two Kanagawa blues below
    kanagawa_green = "#8db488",
    kanagawa_saturated = "#90abdd",
    pale_yellow = "#cfcea7",
    pale_cyan = "#9cc8ca",
    kanagawa = "#9cabca",
    warm_taupe = "#b98f79",
    base0 = "#9eabac", -- identical to @variable
    base00 = "#637981", -- sub-AA
    base01 = "#576d74", -- Comment itself. NOT a candidate.
    mid_high = "#7f9195", -- MAXIMIN rung; base default for delimiter + bracket
    mid = "#798c91",
    mid_low = "#73878d",
    brighter = "#859699",
    brightest = "#8b9b9e",
  },

  -- Special, Debug, @punctuation.bracket, @variable.builtin, JSX tags,
  -- @keyword.import, and via `parameter` also @variable.parameter/@constructor.
  --
  -- Densest accent in the palette (19.1% of ink in markup-heavy TSX) and the warm
  -- side of the screen on its own.
  --
  -- HARD CONSTRAINT: stay clear of the error red #ff3b30 (set in init.lua) so
  -- brackets never read as diagnostics. Chroma does that work, not hue.
  --
  -- NOTE: the base default for this role is `keyword.subdued`, not anything in
  -- this table. Builds override it freely -- check variants.lua for what is live.
  punctuation = {
    copper_mid = "#be6421", -- ran 2026-08-11 to 09-05
    terracotta = "#b55f4a", -- custom-v3

    -- Every ladder measured 2026-08-11, kept as ONE group so they are not
    -- rebuilt a fourth time. NOTHING READS THIS. All rejected ON LOOKS despite
    -- measuring well, so judge anything from here on looks, never the numbers.
    explored = {
      clay = "#c16953",
      coral = "#c76e58",
      salmon = "#cd735d", -- taken up 2026-09-08 for punctuation/parameter/member
      sunset = "#cf7163",
      blush = "#d16f68",
      dusty_rose = "#d16e6c",
      copper_soft = "#ba662b",
      copper_warm = "#c26116",
      copper = "#cb6001", -- LIVE on CursorLineNr
      ember = "#c85c27",
      sienna_hot = "#d85d13",
      balanced_amber = "#a67136",
      solarized_orange = "#cb4b16",
    },

    -- Untried in place.
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
    azure = "#1d98cd", -- base build
    vivid = "#359ee9", -- LIVE in custom-latest
    deeper = "#2797e7",
    brighter = "#268bd2",
    blue300 = "#49aef5",
    balanced = "#4488ab",
  },

  -- Type, @type.builtin, @constructor. CLOSED 2026-09-07.
  -- The blue band is FULL: String cyan sits at h187 and Function at h250.
  type = {
    sky = "#0edfff",
    sky_calm = "#56cae7",
    sky_soft = "#49ddff",
    sky_softer = "#61dbff",
    sky_dim = "#39cce9",
    tokyonight = "#7dcfff", -- base build
    vscode_entity = "#c0caf5",
    periwinkle = "#a7b1fe",
    nvim_type = "#2ac3de", -- LIVE in custom-latest
    vscode_support = "#0db9d7",
  },

  -- Booleans and `@constant`, painted via `Boolean` / `@constant` in init.lua.
  -- Modelled on Tokyo Night's orange by reproducing its RELATIONSHIP (7.9 L*
  -- below body text), not its hex, so every value here sits at L* 68.
  --
  -- What picks the value is separation from the DENSE warm role, and TN's own
  -- hue loses there -- see notes/palette-reference.md, "boolean".
  boolean = {
    -- Added 2026-09-08 when punctuation moved to the BRIGHTER yellow #baac0d
    -- (h98): amber sits only 24 degrees off it at dE 17.2, so it stopped
    -- reading as a separate colour. These clear it by rotating toward orange,
    -- which the warm side has room for now that it carries only the yellow.
    --
    -- This role is DENSE here -- number + boolean + constant is ~19% of a
    -- numeric TS file -- so chroma stays at 40, not 60.
    orange_mid = "#c48956", -- L*62 C*40 h65 6.39:1 | SELECTED: maximin, vs yellow 23.1, vs error red 22.5
    orange_bright = "#e39a71", -- L*70 C*40 h55 8.26:1 | better vs yellow (27.7) but 20.5 from the error red
    -- L*70.0 C*32.2 h55.6 8.30:1 | Tokyo Night's hue at our lightness, muted:
    -- 20% less chroma than `orange_bright` on the same rung, so the ladder does
    -- not move. Best CVD of the realistic candidates (12.3 deutan / 15.2 protan
    -- against orange_bright's 9.9 / 13.3), because dropping chroma pulls it off
    -- the axis both deficiencies compress. THE SAFER SWAP if the live value ever
    -- reads too hot or too close for colour-blind use. C*28 is one step too far:
    -- the nearest neighbour becomes body text and it starts reading beige.
    tokyonight_muted = "#da9e7c",
    orange_vivid = "#ed9747", -- L*70 C*60 h65 8.26:1 | best vs yellow (23.8) but C*60 is loud at this dose
    rose = "#f28f9a", -- L*70 C*40 h15 8.30:1 | furthest from yellow (47.1), reads pink
    amber = "#d19c59", -- L*68.1 C*44.1 h73.8 7.80:1 | ran until 2026-09-08. Only
    -- dE 17.2 from the brighter yellow across a 24 degree hue gap, which is not
    -- enough separation for this palette: re-tried the same day and REJECTED ON
    -- SIGHT both times, because it mixes with the yellow.
    gold = "#b5a73b", -- L*67.9 C*55.9 h97.9 7.75:1 | dE 50.3 / 58deg -- MAX clarity, but yellow not orange
    -- L*68.0 C*54.8 h55.5 7.79:1 | SELECTED 2026-09-08, by eye. TN's hue at our
    -- lightness, dE 29.5 from the accent yellow, the widest of any candidate. It
    -- blurred into the salmon member colour when that role existed; the salmon is
    -- gone, so the objection is too. Carries C*54.8 against the C*40 this role's
    -- dose note asks for, and 5.4 deutan is its weak axis -- both accepted
    -- knowingly, with `tokyonight_muted` as the swap.
    tokyonight_dim = "#ed8e55",
    tokyonight = "#ff9e64", -- L*74.0 C*54.6 h55.6 9.35:1 | TN as shipped; dE 23.7 / 16deg, same hue problem and -2.1 L* vs body
  },

  -- Strings (`String`, `@string.documentation`, `Character`), every language.
  -- Added 2026-09-24 so strings stop sharing the theme cyan with object keys and
  -- member access, which stay on that cyan. The layout is TokyoDark Islands'
  -- (green strings, teal members); our cyan sits dE 9.3 from its member teal.
  --
  -- Swept over the whole gamut on our background. Stop rule: dE >= 15 from the
  -- member cyan, >= 10 from every other role, not above body lightness.
  --
  -- Its own exact `#9ece6a` does NOT transfer: L*77.6 is above body text, and
  -- Ghostty's P3 lifts it to C*65. Match what WebStorm SHOWS, not its hex.
  --
  -- Why not a darker/calmer green: measured 2026-09-24 on real screens, the
  -- green is 9.7% of the coloured ink in a TSX file but 49.1% in Go, where it
  -- becomes the page's main colour. At C*44 it was the least colourful accent
  -- (the others average C*54 there), so Go read dull while TSX read fine.
  string = {
    -- L*71.8 C*47.4 h125.0 8.93:1 | Ghostty draws it at L*71.4 C*55.3 h126.8:
    -- WebStorm's `#9ece6a` hue and chroma, 6 L* darker so it stays under body.
    -- vs member cyan 25.2, worst neighbour 16.4 vs the accent yellow (`\n`
    -- escapes sit inside strings). SELECTED 2026-09-24.
    --
    -- THE CEILING: anything brighter crosses body lightness or rotates into the
    -- kelly greens (h > 130) already rejected. Do not look for a next step up.
    -- Tailwind-heavy TSX gets louder with it; if that bites, scope `tokyodark`
    -- to tsx/typescript rather than dimming this for every language.
    vivid = "#96bc67",
    -- L*66.1 C*38.0 h124.2 7.47:1 | Ghostty C*44.0 h126.0. Ran a few hours on
    -- 2026-09-24: good in TSX, dull in Go (see above). dE 5.5 below `vivid`.
    tokyodark = "#8eaa67",
    -- L*64.0 C*33.1 h123.6 6.97:1 | the calmer finalist, worst 17.5. Only dE 2.6
    -- from `tokyodark`, below what can be seen: do not compare the two.
    soft = "#8ca369",
  },

  -- Member fields (`@variable.member`). NOT APPLIED as of 2026-09-08: the build
  -- leaves `member = false` and init.lua paints Go fields from `punctuation`
  -- instead, so nothing reads these values. They are kept as the candidate set
  -- for giving fields a colour of their own again. `@property` (object/dict keys,
  -- JSX attrs) is a separate group, still on the theme default where it
  -- duplicates Function.
  --
  -- These scores predate the keyword move to violet, so re-measure anything
  -- close to keyword. Stay IN the accent band (L* ~60): these symbols appear on
  -- nearly every line, and a bright value drains its neighbours.
  member = {
    -- Swept 2026-09-08 against the palette as it stands now (yellow punctuation,
    -- orange literals, cyan strings+keys). The historical candidates below all
    -- score 10-16 against it; these two were found by sweeping the gaps.
    --
    -- Colouring this role is only SAFE because after/queries/ split object keys
    -- onto @variable.member.key -- before that, a distinct member colour flooded
    -- every object-literal file, since bare keys shared this capture.
    -- The green window is squeezed between the git-add sign colour (h111) and
    -- the string cyan (h187), so h134-150 is all there is. It measures a little
    -- worse than the pink below, but better than pairs this palette already
    -- lives with (type vs string cyan is dE 16.4), and pink was not wanted.
    --
    -- WARN: this DEPENDS on string staying cyan, and it no longer does:
    -- custom-latest has strings on the green `string.tokyodark` (h124) since
    -- 2026-09-24, and object keys now follow this role. Re-measure all of these
    -- against that green before using any of them.
    sage = "#8bcb8a", -- L*76 C*42 h142 9.97:1 | SELECTED: worst 20.6 vs the git-add green
    sage_dim = "#88be87", -- L*72 C*36 h142 8.84:1 | dimmer, worst 19.0 vs string cyan
    rose_soft = "#e197a3", -- L*70 C*30 h10 8.29:1 | best measured (23.5) but pink, not wanted
    rose = "#b67faf", -- base-build default
    iris = "#8d8de3",
    purple = "#a17bcc",
    rose_warm = "#be7ca6",
    rose_cool = "#ac82b7",
    mauve = "#c49ac6",
    violet = "#9b9fec",
    tokyonight = "#73daca",
    -- The theme's own cyan500: what `@variable.member` and object keys show in
    -- every non-Go language. Named here so a build can put Go fields on it
    -- (`field` role, custom-swap-3). Keep equal to the theme's cyan500.
    theme_cyan = "#29a298",
  },
}

-- THE BASE SELECTIONS. `custom-latest` in variants.lua overrides several of
-- these; every other build starts from the values below.
--
-- THE SHAPE: four lightness steps ordered by how much the thing means -- body
-- 76.0, names 65.5, punctuation 62.8/58.9, comments 44.6 -- with EXACTLY ONE
-- ACCENT HUE ON THE WARM SIDE instead of two.
--
-- That last clause is the one people break. Re-confirmed 2026-09-08: yellow
-- punctuation beside a salmon `member` was rejected on sight, and total warm ink
-- was IDENTICAL either way -- so it is not a dose problem and no hex retune
-- fixes it. Keep the warm side to one dominant hue plus at most one LOW-DOSE
-- accent. Measurements: notes/palette-reference.md, "One accent hue".
--
-- WARN: SILENT FAILURE. Three traps here, all verified:
--   1. A build role must be `false`, NEVER `nil` -- `nil` is an absent key, so
--      `variants.load`'s `pairs` never sees it and the override does not happen.
--   2. A duplicate role key is not an error; the last assignment wins silently.
--      After editing a role: grep -c "^  delimiter = " <this file>
--   3. `false` on `comment` is meaningful -- it keeps upstream comments in
--      reference builds and prevents override leakage.
return {
  -- Exposed by role so builds can name a value without copying a hex. Read only
  -- by variants.lua; costs nothing, the table is built either way.
  variants = variants,

  keyword = variants.keyword.warm_violet,
  -- UNREAD: the grammar-dimming experiment was rejected and init.lua paints
  -- nothing with it. Kept wired so the values stay measured.
  keyword_grammar = variants.keyword_grammar.cool_grey,
  -- Yellow replaced copper 2026-09-05, reaffirmed 2026-09-08.
  punctuation = variants.keyword.subdued,
  -- Parameter names and `new X()` callees. Holds the same yellow: what separates
  -- a parameter from its brackets is the BRACKET being neutral, not the hue.
  parameter = variants.keyword.subdued,
  -- `false` here would mean "follow the theme's own base0" -- init.lua reads
  -- `palette.delimiter or c.base0`.
  delimiter = variants.delimiter.mid_high,
  body = variants.body.brighter,
  comment = false,
  -- Brackets are the same "punctuation carrying no meaning worth a hue" class as
  -- `Operator`, which is what lets a yellow name sit inside neutral punctuation.
  -- Separate from `delimiter` so a build can split the two; custom-latest does.
  bracket = variants.delimiter.mid_high,
  func = variants.func.azure,
  type = variants.type.tokyonight,
  -- Booleans. Painted by `hl.Boolean` in init.lua, which `@boolean` links to.
  boolean = variants.boolean.amber,
  -- `false` keeps the theme's own cyan500, so the numbered builds are unchanged.
  string = false,
  -- Escapes and interpolation (`@string.escape`, `@punctuation.special`).
  -- `false` follows `punctuation`, the behaviour before 2026-09-24; custom-v4
  -- and the custom-swap builds pin the orange.
  escape = false,
  -- `@keyword.import`. `false` follows `punctuation`, the behaviour before
  -- 2026-09-24; custom-v4 and the custom-swap builds pin the keyword violet.
  import = false,
  -- Go struct fields (`@variable.member.go`, `@property.go`, keys). `false`
  -- follows `punctuation`; a build pins it to keep fields apart from literals.
  field = false,
  -- Go-only role overrides, `{ string = , parameter = , escape = }`. `false`
  -- means Go uses the shared roles like every other language.
  go = false,
  -- UNREAD: see `member` above.
  -- member = false,
}
