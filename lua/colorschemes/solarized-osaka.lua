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

      -- Go package names, such as `main` in `package main`.
      -- hl["@module.go"] = { fg = "#fdf6e3" }
      hl["@module.go"] = { fg = "#eee8d5" }

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
