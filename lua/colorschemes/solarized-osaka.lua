local palette = require("colorschemes.solarized-osaka-palette")

return {
  "craftzdog/solarized-osaka.nvim",
  lazy = false,
  priority = 1000,
  opts = {
    -- Terminal-transparent so Ghostty's `background` + `background-opacity`
    -- blend the wallpaper through. Set to false to force solid #001419.
    transparent = true,
    on_colors = function(c)
      c.yellow = palette.yellow
      c.yellow500 = palette.yellow

      -- Currently a no-op: `palette.green` is the theme's own value. Kept as
      -- the single seam for changing green, since `lua/plugins/performance.lua`
      -- also reads `palette.green` for the lualine git marker.
      --
      -- NOTE: green and yellow measurably collide (dE2000 9.9) and that is a
      -- deliberate, informed choice — see the long comment in
      -- solarized-osaka-palette.lua before changing either.
      --
      -- Only `green`/`green500` are overridden; `green700`/`green900` remain
      -- the theme's dark background bands (mkdCode, DiffText).
      c.green = palette.green
      c.green500 = palette.green

      -- NOTE: Solarized Osaka maps syntax accents to orange/orange500; both intentionally use our selected red.
      c.orange = palette.red
      c.orange500 = palette.red

      -- blue color override
      c.blue = palette.blue
      c.blue500 = palette.blue
    end,
    on_highlights = function(hl, c)
      -- Keep module keywords consistent with the selected red accent.
      hl["@keyword.import"] = { fg = c.orange500 }

      -- Sync plain-variable color across the JS/TS family. The theme
      -- (solarized-osaka/groups/treesitter.lua) sets a yellow override for
      -- `@variable.typescript` / `@variable.javascript`, but has NO equivalent
      -- for `@variable.tsx` / `@variable.jsx`, so `.tsx`/`.jsx` fall back to the
      -- base `@variable` (base foreground). That made `.ts` variables yellow
      -- while `.tsx` variables stayed white. Link the ts/js variants back to
      -- `@variable` so a plain variable reads the same in every JS/TS file.
      hl["@variable.typescript"] = { link = "@variable" }
      hl["@variable.javascript"] = { link = "@variable" }

      -- Types. The theme sets `Type = yellow500`, which made EVERY type gold:
      -- Rectangle, Shape, float64, string, int, SlotTableProps, ReactNode,
      -- Optional, List. Setting the base group is the whole fix -- @type,
      -- @type.builtin, @type.definition, Typedef and Structure all link to it,
      -- and so does every @lsp.type.* group (inert here: lua/plugins/lsp.lua
      -- nils semanticTokensProvider on attach, so treesitter is the only
      -- painter and nothing can override this back to yellow).
      -- See `variants.type` in the palette file for the measurements.
      hl.Type = { fg = palette.type }

      -- Construction should read as the type being built, not as a parameter.
      -- Both lines are needed: the theme sets `@constructor` to orange500 (the
      -- same terracotta as @variable.parameter, @variable.builtin and brackets)
      -- and `@constructor.tsx` separately to blue500.
      hl["@constructor"] = { fg = palette.type }
      hl["@constructor.tsx"] = { fg = palette.type }

      -- Fields and properties were each an EXACT duplicate of another role
      -- (dE2000 0.0), verified by walking treesitter captures over real Go/TSX/
      -- Python files:
      --   @variable.member (r.Width, row.count, self.width) == cyan500 == String
      --   @property        (struct literal keys, JSX attrs)  == blue500 == Function
      -- One colour for both. `violet300` (#9b9fec) was tried on 2026-08-07 and
      -- rejected on looks. This is the same move that works for Type: take the
      -- LIGHTER member of a family the palette already has, and let lightness
      -- carry the separation.
      --   fields  #73daca  L* 80.8  vs  strings #29a298  L* 60.4   (20.4 apart)
      --   types   #7dcfff  L* 79.7  vs  funcs   #1d98cd  L* 59.1   (20.6 apart)
      -- So no new hue family enters the palette, and it matches both Tokyo
      -- Nights, which use this exact value for properties.
      --
      -- Known and accepted: strings and fields are now two teals, dE2000 15.7.
      -- That is the same order as the type/function pair above and separates the
      -- same way -- on lightness, not hue.
      --
      -- @tag.attribute links to @property, so JSX attributes follow.
      hl["@variable.member"] = { fg = palette.member }
      hl["@property"] = { fg = palette.member }

      -- React component names. The theme paints `@tag.tsx` / `@tag.javascript`
      -- with yellow500, so every <Form>, <Fragment>, <RecurringHeader> was gold
      -- -- the last significant yellow left in a TSX file. HTML elements are a
      -- SEPARATE capture (`@tag.builtin.tsx`, already orange500), so components
      -- now simply match them and every JSX tag reads as one thing. That is
      -- what VSCode Tokyo Night does with `entity.name.tag`, and it adds no new
      -- hue here.
      hl["@tag.tsx"] = { fg = c.orange500 }
      hl["@tag.javascript"] = { fg = c.orange500 }

      -- Module names, such as `main` in `package main` or `typing` in a Python
      -- import. The theme links `@module` -> Include -> PreProc -> red500, a
      -- saturated alarm red at 4.01:1 sitting only 31 degrees of hue from the
      -- error red, so imports read as diagnostics in every language except Go.
      -- This generalises the old Go-only override to every language and drops
      -- its magic hex. `c.base2` (#ede7d3) is not byte-identical to the #eee8d5
      -- that line hardcoded, but the two are dE2000 0.45 apart -- below the
      -- just-noticeable threshold -- so Go is unchanged in practice.
      hl["@module"] = { fg = c.base2 }

      hl.Visual = { bg = "#3b4261" }
      hl.VisualNOS = { bg = "#3b4261" }

      -- Line numbers. The theme points LineNr at `yellow700` (#664c00), a dark but
      -- SATURATED warm amber, and that is the problem rather than its lightness:
      --
      --   group              value     L*     C*    hue    dL* over bg   contrast
      --   solarized LineNr   #664c00   34.0   42.9   84    28.8          2.33:1
      --   tokyonight LineNr  #3b4261   28.6   20.1  287    18.5          1.74:1
      --
      -- Chroma is more than double tokyonight's, and hue 84 puts it in the same
      -- family as this palette's yellow syntax accent (hue 98). So the gutter reads
      -- as CONTENT competing with code rather than as chrome, which is what makes
      -- relative-jump numbers tiring to scan. It is also 10 L* further from the
      -- background than tokyonight's.
      --
      -- #2d3f43 is a low-chroma cool grey sitting on the background's own hue (bg
      -- #001419 is a cyan-ish near-black), and it reproduces tokyonight's
      -- RELATIONSHIP rather than its absolute value, which is the right invariant
      -- when the two backgrounds differ (L* 5.2 here vs 10.1 there):
      --   #2d3f43  L* 25.3  C* 7.7  dL* 20.1  contrast 1.71:1
      --   vs tokyonight's         dL* 18.5  contrast 1.74:1
      -- If this ends up too dim to read at a glance, #33474b is the one step up
      -- (dL* 23.5, 1.92:1). Do not go back toward a saturated hue to make it
      -- visible -- raise lightness, keep C* under about 10.
      --
      -- All three groups carry explicit values in the theme (not links), so all
      -- three have to be set or above/below the cursor keep the amber.
      hl.LineNr = { fg = "#2d3f43" }
      hl.LineNrAbove = { fg = "#2d3f43" }
      hl.LineNrBelow = { fg = "#2d3f43" }

      -- Re-enable with a custom color (e.g. "#073642") to restore the band.
      hl.CursorLine = { bg = "NONE" }

      -- Dedicated current-row band for Oil only (CursorLine is disabled
      -- globally above). Oil windows remap CursorLine -> OilCursorLine via
      -- winhighlight, so the band returns in Oil without touching buffers.
      hl.OilCursorLine = { bg = c.base02 }

      -- Markdown headings only. The theme links the GENERIC `@markup.heading`
      -- group to `Title` (orange500 = red-orange), and `Title` is shared by help
      -- files, pickers, `:set all` output, etc. Overriding the markdown-specific
      -- `@markup.heading.{1..6}.markdown` variants recolors `.md` titles to
      -- solarized green WITHOUT touching `Title` or any other filetype's
      -- headings. render-markdown leaves heading fg to treesitter
      -- (`foregrounds = {}` in render-markdown.lua), so this is what paints them.
      for level = 1, 6 do
        hl["@markup.heading." .. level .. ".markdown"] = { fg = c.green, bold = true }
      end

      -- LSP documentation surface (hover, signature help, diagnostic floats,
      -- mouse hover, blink's doc popup).
      --
      -- The problem: `bg_float` is `base04`, which is byte-identical to `bg`
      -- (#001419), so a float was the same colour as the editor and only
      -- differed by being opaque. It gets worse than "subtle": `transparent =
      -- true` leaves Normal bg = NONE, so the editor actually shows Ghostty's
      -- #031219 at background-opacity 0.9 blended with the wallpaper. That
      -- lands anywhere from L* 4.1 (black wallpaper) to L* 12.9 (bright one),
      -- and the float's L* 5.2 sits INSIDE that band -- so it read darker than
      -- the editor on some wallpapers and lighter on others.
      --
      -- A raised `base03` panel (L* 15.94) was tried on 2026-08-07 and rejected
      -- on looks -- it read as a lighter box pasted over the editor. Reverted to
      -- `bg_float`, so the separation now comes entirely from the border and a
      -- brighter foreground. Do not reach for a DARKER bg to compensate: bg is
      -- already L* 5.15 and the darkest usable step is -2.5 L*, below the
      -- perceptual threshold, and the editor itself drifts L* 4.1-12.9 with the
      -- wallpaper (transparent = true), so no bg value separates reliably.
      --
      -- Still deliberately NOT applied to NormalFloat: SnacksPickerBorder and
      -- SnacksPickerPreviewTitle read `c.bg_float`, and the picker body falls
      -- back to NormalFloat, so touching it would repaint the picker. These are
      -- reached only by doc floats, via winhighlight in config/keymaps.lua.
      -- fg is `base1` rather than the editor's `base0`, so doc text reads a step
      -- brighter than the code behind it.
      hl.LspDocFloat = { fg = c.base1, bg = c.bg_float }
      hl.LspDocBorder = { fg = palette.type, bg = c.bg_float }
      hl.LspDocTitle = { fg = palette.type, bg = c.bg_float, bold = true }

      -- blink.cmp's doc popup does not route through open_floating_preview, so
      -- it takes the same surface directly. The completion MENU below is left
      -- alone on purpose -- only the docs panel changes.
      hl.BlinkCmpDoc = { fg = c.base1, bg = c.bg_float }
      hl.BlinkCmpDocBorder = { fg = palette.type, bg = c.bg_float }

      hl.BlinkCmpMenu = { fg = c.base1, bg = c.bg_float }
      hl.BlinkCmpMenuBorder = { fg = c.base02, bg = c.bg_float }
      hl.BlinkCmpMenuSelection = { fg = c.base2, bg = c.base02, bold = true }
      hl.BlinkCmpLabel = { fg = c.base1, bg = c.none }
      hl.BlinkCmpLabelMatch = { fg = c.blue300, bg = c.none }

      hl.Pmenu = { fg = c.base1, bg = c.bg_float }
      hl.PmenuSel = { fg = c.base2, bg = c.base02, bold = true }
      hl.PmenuSbar = { bg = c.bg_highlight }
      hl.PmenuThumb = { bg = c.base01 }

      hl.DiagnosticVirtualTextError = { fg = "#ff3b30", bg = c.none }
      hl.DiagnosticVirtualTextWarn = { fg = "#e0af68", bg = c.none }
      hl.DiagnosticVirtualTextInfo = { bg = c.none }
      hl.DiagnosticVirtualTextHint = { fg = "#1abc9c", bg = c.none }

      hl.Folded = { bg = "NONE" }
      hl.UfoFoldedBg = { bg = "NONE" }

      -- grug-far matched-keyword highlight. Defaults to linking DiffText,
      -- which in this theme is a near-black green band (c.green900) -> the
      -- match looks faded. Override with a vivid bg + dark fg so the matched
      -- keyword stands out clearly in the results list. Cyan (not red/yellow)
      -- is deliberately chosen so it never reads like a vim `/`/`?` search hit:
      -- Search is yellow (#b28500), IncSearch is muted rose-red (#c75b6b).
      hl.GrugFarResultsMatch = { fg = c.base04, bg = c.cyan300, bold = false }

      -- grug-far results summary ("N matches in M files"). Defaults to linking
      -- Comment, which is dim/faded against the panel -> the total is hard to
      -- read. Force the theme's lightest fg so the count is legible.
      hl.GrugFarResultsStats = { fg = c.base2 }

      -- TODO: brighten the snacks picker match highlight (currently a faded
      -- olive band). Setting `hl.SnacksPickerMatch` here does NOT take effect —
      -- something re-applies it to `DiffText` AFTER this on_highlights runs
      -- (snacks registers picker hl groups lazily on its own ColorScheme hook).
      -- Needs investigating: likely set it via a late ColorScheme autocmd or in
      -- the snacks plugin spec instead of the theme. Scope: snacks picker only.
    end,
  },
}
