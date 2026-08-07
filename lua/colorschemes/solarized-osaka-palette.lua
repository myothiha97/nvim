-- Previously tested colors are kept as named choices for quick switching.
local variants = {
  yellow = {
    -- Lab L* 61.6, C* 64.2, hue 98.0. The 2026-07-21 selection.
    darker = "#a3970b",
    -- Lab L* 65.4, C* 67.4, hue 97.9. THE SELECTION — the exact midpoint of
    -- `darker` and `brighter`, and the best-contrasted accent in the palette
    -- at 7.27:1.
    --
    -- It was suspected of being too bright and benchmarked against
    -- tokyonight-night and catppuccin-mocha on 2026-07-22. It is not. Measured
    -- perceived lightness (L* with the Fairchild-Pirrotta Helmholtz-Kohlrausch
    -- correction, which flatters saturated colours):
    --
    --   this yellow        L* 65.4  C* 67.4  looks 70.8
    --   tokyonight yellow  L* 74.5  C* 44.0  looks 77.3
    --   catppuccin yellow  L* 90.6  C* 27.9  looks 91.2
    --
    -- It is the dimmest of the three by a wide margin. What is unusual is
    -- chroma, not brightness: 67.4 against their 44.0 and 27.9. On this
    -- near-black background that saturation reads as glare. Do not "fix" it by
    -- lowering lightness — that only makes an already-dim palette dimmer.
    balanced = "#aea10c",
    -- `balanced` with chroma pulled to 56.3, holding its lightness and hue, so
    -- contrast is unchanged (7.13:1). Tried on 2026-07-22 and judged not
    -- meaningfully different from `balanced` in practice — an 11-point chroma
    -- drop is only dE2000 2.9, because the metric divides chroma differences by
    -- (1 + 0.045*C), a divisor near 4 up here. If a calmer yellow is ever
    -- wanted, this is the correct axis but it needs a bigger step than this.
    subdued = "#aea134",
    -- Same again at C* 50.0 — the size of step that would actually register.
    -- Do not go far below: the muddiness floor is about C* 35 against the
    -- hsl(192,100%,5%) background.
    hushed = "#aea042",
    -- Lab L* 69.5, C* 70.8, hue 97.9. Same again, further. REJECTED, too hot.
    brighter = "#baac0d",
    -- Lab L* 61.9, C* 65.9, hue 86. REJECTED: this is essentially the gold the
    -- theme ships (hue 84), which reads too orange. Kept only to document that
    -- the collision must not be solved by moving yellow back toward gold.
    gold = "#b99004",
  },
  -- KNOWN AND ACCEPTED: the selected green (`solarized`) and yellow
  -- (`balanced`) collide. They sit 12.7 degrees apart in hue at near-identical
  -- chroma — dE2000 9.9, which is the same colour on small glyphs. It shows
  -- wherever a keyword touches a type: every Go and Python function signature,
  -- and every JSX tag.
  --
  -- This was measured, every alternative below was tried on real files, and the
  -- olive was kept anyway on 2026-07-22 because nothing that separates cleanly
  -- looks as good. That is a deliberate trade, not an oversight. Do not "fix"
  -- it by swapping in one of the greens below without asking first.
  --
  -- Why nothing here works: green reads on HUE, not chroma. Below ~122 it reads
  -- warm olive, above ~130 it reads vivid kelly green, and dropping chroma does
  -- not undo that — `clover` at C* 53.8 still read too bright while `solarized`
  -- at C* 66.9 reads calm. Every green that clears yellow sits above 130, so
  -- "warm and separated" does not exist. Yellow cannot move either: hue down is
  -- the theme's stock gold (too orange), hue up is green, and at hue 98 the
  -- pair does not clear dE2000 20 until L* 85, a near-fluorescent lemon.
  green = {
    -- The theme default, and the selection. Warm, and the calmest-reading of
    -- every option here despite the highest chroma. Collides with yellow,
    -- knowingly.
    --
    -- This is `#849900`, not Solarized's published `#859900`: the theme builds
    -- its palette through `hsl(68, 100, 30)`, which rounds one step lower in
    -- red. Matching the theme exactly keeps this override a true no-op, so
    -- nothing shifts by selecting it.
    solarized = "#849900",
    -- All of the below clear yellow (dE2000 ~20-22) and were all rejected on
    -- looks: at hue 130+ they read cool and vivid rather than warm. Ordered
    -- calmest to strongest by chroma; all are one-word swaps.
    sage = "#66985e", -- C* 38.2, matches blue
    moss = "#629959", -- C* 41.9, matches terracotta — the closest call
    fern = "#5d9a53", -- C* 46.3
    clover = "#599e49", -- C* 53.8
    juniper = "#569f41", -- C* 58.2
    leaf = "#4ea339", -- C* 64.9
    grass = "#56a325", -- C* 70.3 — the first attempt
  },
  red = {
    vivid = "#e03857",
    bright = "#ab3a4f",
    lighter = "#b83e55",
    bright_red = "#b83549",
    lower_contrast = "#ad4454",
    muted_contrast = "#c75b6b",
    darker = "#993141",
    magenta = "#b02669",
    crimson = "#bf2c47",
    red300 = "#F6524F",
    red700 = "#B7211F",
    -- hsl(12, 42, 50). Less saturated than both stock orange (#c94c16) and
    -- muted_contrast, with hue pulled back out of the pink range.
    terracotta = "#b55f4a",
  },
  -- Type colour. Moved off the theme's `Type = yellow500` on 2026-08-07 because
  -- every type in Go/TS/Python read as gold. This ALSO resolves the green/yellow
  -- collision documented above at its source: a keyword only ever touched yellow
  -- through a type annotation or a JSX tag, so with types on cyan the pair stops
  -- meeting in real code. That is the "only untried direction" named in
  -- todos/syntax-palette-followups.md.
  --
  -- All four were measured against the live palette on the real background
  -- (Ghostty #031219 at opacity 0.9, NOT nvim's #001419 -- `transparent = true`
  -- leaves Normal bg = NONE, so the terminal's colour is what shows).
  type = {
    -- THE SELECTION. L* 79.7, C* 33.5, hue 249, contrast 11.08:1.
    -- Worst neighbour is Function/@property #1d98cd at dE2000 16.2, but the two
    -- sit 20.6 L* apart on the SAME hue (249 vs 250). That is the axis that
    -- carries when hue and chroma are flat -- the same lesson the green/yellow
    -- note above records. Chroma 33.5 lands between string-cyan (34.7) and
    -- function-blue (38.5), so it adds no glare to an already high-chroma palette.
    --
    -- NOTE: this is NOT the type colour in either Tokyo Night. It is `Keyword` in
    -- tokyonight.nvim and `variable.other.property` in the VSCode theme. Their
    -- real type colours are saved below and both measure TIGHTER here, because
    -- this background is darker and cyan-tinted rather than navy.
    tokyonight = "#7dcfff",
    -- tokyonight.nvim's actual `Type` (its blue1). Rejected: 15.2 from function,
    -- 16.4 from string -- tighter than the selection on both counts.
    nvim_type = "#2ac3de",
    -- VSCode Tokyo Night's `support.type` / `support.class` (builtin types).
    -- Rejected: 11.9 from #7dcfff and 15.8 from string cyan.
    vscode_support_type = "#0db9d7",
    -- VSCode Tokyo Night's `entity.name.type` -- there, user-defined types are
    -- just plain foreground. Cleanest against everything (worst 18.9), but reads
    -- as a neutral rather than an accent. The fallback if the selection's
    -- same-hue split from function blue turns out not to read.
    vscode_entity_type = "#c0caf5",
  },
  blue = {
    blue300 = "#49aef5",
    balanced = "#4488ab",
    brighter = "#268bd2",
    -- hsl(205, 80, 56). Saturated like blue300, but held level with
    -- green/cyan/yellow in perceived lightness so blue stays in the accent band.
    vivid = "#359ee9",
    -- hsl(205, 80, 53). Same hue and saturation as vivid, three points darker so
    -- blue sits level with cyan/green instead of leading the accent band.
    deeper = "#2797e7",
    -- hsl(198, 75, 46). Leans toward cyan and drops chroma about a fifth versus
    -- deeper, staying clearly blue and level with green in the accent band.
    azure = "#1d98cd",
  },
}

-- Change only these selections to try another saved color.
return {
  yellow = variants.yellow.gold,
  green = variants.green.solarized,
  red = variants.red.terracotta,
  blue = variants.blue.azure,
  type = variants.type.tokyonight,
}

-- Theme-native red alternative kept from earlier testing:
-- c.red = c.red300
-- c.red500 = c.red300
