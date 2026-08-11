local palette = require("colorschemes.solarized-osaka-palette")

return {
  "craftzdog/solarized-osaka.nvim",
  lazy = false,
  priority = 1000,
  opts = {
    -- Terminal-transparent so Ghostty's `background` + `background-opacity`
    -- blend the wallpaper through. Set to false to force solid #001419.
    transparent = true,
    -- NO `on_colors`. Recolouring the theme's base ramp (c.green500, c.orange500,
    -- c.blue500) is the obvious way to retheme syntax and it is the wrong one:
    -- those names are shared with the UI, so a syntax choice silently repaints
    -- unrelated things. Measured consumers of each, outside syntax:
    --
    --   green500  -> GitSignsAdd, diffAdded, MiniDiffSignAdd, NeoTreeGitAdded,
    --                NvimTreeGitNew, GitGutterAdd, NeogitDiffAdd, neotest
    --   orange500 -> dashboard, snacks, indent-blankline, rainbow delimiters
    --   blue500   -> neogit, neotest, semantic_tokens, editor
    --   cyan500   -> DiagnosticHint (colors.hint is an alias of it), Question,
    --                healthSuccess, MiniStatuslineModeOther, blink/cmp, lspsaga
    --
    -- That is how the keyword colour turned git-added markers yellow on
    -- 2026-08-08. Syntax colours are therefore applied to SYNTAX GROUPS only,
    -- below, and the theme's own ramp is left intact for everything else.
    on_highlights = function(hl, c)
      -- Set `fg` while preserving whatever else a group already carries --
      -- italic on keywords, bold on markdown delimiters, underline on links, the
      -- background on markdown code. A bare table assignment drops those.
      --
      -- Values in this table are heterogeneous: a highlight table OR a bare
      -- string, which is the theme's shorthand for a link (`@keyword.return` is
      -- the string "@keyword"). Merging into a string throws, and a link needs
      -- no help -- its target is in the same list, so it follows for free.
      local function paint(groups, fg)
        for _, g in ipairs(groups) do
          if type(hl[g]) == "table" then
            hl[g] = vim.tbl_extend("force", hl[g], { fg = fg })
          elseif hl[g] == nil then
            hl[g] = { fg = fg }
          end
        end
      end

      -- Keywords. `Operator` is deliberately NOT here -- see the note further
      -- down -- but `@keyword.operator` (`and`, `or`, `not`) is, because those
      -- are keywords that happen to be spelled as operators.
      paint({
        "Statement",
        "Keyword",
        "@keyword",
        "@keyword.function",
        "@label",
        "@keyword.tsx",
        "@keyword.return.tsx",
        "@keyword.javascript",
        "@keyword.return.javascript",
      }, palette.keyword)

      -- Parameters, brackets, tags and other "structural" symbols. Feeds what
      -- the theme calls orange500.
      paint({
        "Special",
        "Debug",
        "@punctuation.bracket",
        "@punctuation.special",
        -- Lua table braces. Lua captures `{` as BOTH @punctuation.bracket and
        -- @constructor -- the same character, matched twice -- and @constructor
        -- wins only because it comes later in the highlights query. So it marks
        -- a quirk of the grammar, not a distinct construct: Go's composite
        -- literals (`Rectangle{...}`, `[]int{2,3,4}`, `map[string]int{...}`) are
        -- the same thing and are plain @punctuation.bracket, and TSX emits no
        -- @constructor at all.
        --
        -- Pointed at the type colour on 2026-08-07 so "construction reads as the
        -- type being built" -- reasoned from TSX, which turned out not to use the
        -- group. The effect was Lua-only: blue `{` `}` beside the punctuation
        -- colour on `[` `]` in the same expression, and beside azure @property on
        -- every line of a config table. Reverted 2026-08-09.
        "@constructor",
        "@constructor.tsx",
        "@variable.parameter",
        "@variable.builtin",
        "@module.builtin",
        -- JSX tag groups are painted in their own block below rather than
        -- listed here, so the reasoning stays attached to them. Same colour.
      }, palette.punctuation)

      -- JSX tags, revisited 2026-08-09. Reference measurement, taken by walking
      -- treesitter captures over two regions of the SAME production file and
      -- resolving @cap.tsx -> @cap the way the highlighter does:
      --
      --   region                       coverage   marks   run length
      --   logic-heavy (hooks, consts)     12.5%      74      2.0 ch
      --   markup-heavy (nested JSX)       34.7%      91      4.3 ch
      --
      -- Every group here is language-scoped (.tsx/.javascript/.html/.vue), so
      -- nothing in this block can reach Go, Python, Lua, bash or plain TS.
      -- Verified by measuring a 13k-glyph Lua file before and after: identical
      -- on every row including mark counts.
      --
      -- Tag NAMES stay on the punctuation colour, and both tag captures must
      -- carry the SAME value. This is the load-bearing part.
      --
      -- The tsx grammar matches one tag with BOTH @tag and @tag.builtin, and the
      -- winner is decided by query order, not by what kind of tag it is -- the
      -- same trap as Lua's `{` being both @punctuation.bracket and @constructor,
      -- documented above. Measured on real JSX: `Accordion`, `Button`, `If`,
      -- `SadFaceSVG` resolve through @tag, while `div`, `h2` AND `DragAndDrop`
      -- resolve through @tag.builtin. So splitting the two captures does NOT
      -- split "HTML element" from "React component" -- it renders
      -- `<DragAndDrop.Droppable>` as two different colours inside one name.
      --
      -- Sending @tag to the type colour was tried on 2026-08-09 and rejected:
      -- the sky value is reserved for types, and the split above made tag colour
      -- look arbitrary in exactly the files it was meant to help.
      --
      -- KNOWN COST, accepted deliberately: the punctuation colour reaches 30.2%
      -- of glyphs in markup-heavy TSX against 12.5% in logic-heavy TSX of the
      -- same file. Tags are most of that, because a tag is a WORD where a
      -- bracket is one character. This is a dose problem, not a colour problem
      -- -- retuning the hex cannot change how much of the screen it covers, so
      -- do not reach for a new value. The only lever that works is moving
      -- captures off this list, and the two candidates (@variable.parameter,
      -- @punctuation.bracket) were measured to be 88% of that colour in
      -- logic-heavy regions, so moving them would strip the files that already
      -- read well. See notes/syntax-palette-decisions.md.
      paint({
        "@tag.tsx",
        "@tag.javascript",
        -- Explicit rather than inherited: the theme already lands this on the
        -- same value, but if that ever drifts, the two captures diverge and the
        -- split-colour tag name comes back.
        "@tag.builtin.tsx",
        "@tag.builtin.javascript",
      }, palette.punctuation)

      -- The tag DELIMITERS (`<`, `>`, `/`) go neutral, for the same reason
      -- `Operator` does further down: they are punctuation carrying no meaning
      -- worth a hue, and they were 13.0% of the punctuation colour for that.
      paint({
        "@tag.delimiter.tsx",
        "@tag.delimiter.vue",
        "@tag.delimiter.html",
        "@tag.delimiter.javascript",
      }, c.base0)

      -- Generic delimiters go neutral too, 2026-08-10. This closes item 6 of
      -- todos/syntax-palette-followups.md, which had been the live one.
      --
      -- The group is `,` `;` `:` AND the `.` of every member access -- the
      -- theme's own comment on it is literally "For delimiters ie: `.`". On the
      -- keyword colour that put an accent mark on nearly every line of Go and
      -- TS, and inside every `fmt.Println`, `currentRoute.pathname` and
      -- `rolePermission.write`. They are the same case as the tag delimiters
      -- above and `Operator` below: punctuation carrying no meaning worth a hue.
      --
      -- This is a coverage change, not a colour change, so it is independent of
      -- which keyword colour is selected and stays true for the variants in
      -- lua/colorschemes/solarized-osaka-variants.lua.
      paint({ "@punctuation.delimiter" }, c.base0)

      -- Two groups `paint` deliberately cannot handle. Both are stored as bare
      -- string links whose TARGET is outside the lists above, so skipping them
      -- (correct for links like @keyword.return -> @keyword) would leave them
      -- resolving somewhere wrong. They have to be written as tables:
      --   @keyword.import   -> Include -> PreProc -> red500, a saturated alarm
      --     red 31 degrees from the error red, so `import` and Go's
      --     `package main` read as diagnostics.
      --   @keyword.operator -> @operator -> Operator, which goes neutral just
      --     below, taking `and`/`or`/`not` with it.
      hl["@keyword.import"] = { fg = palette.punctuation }
      hl["@keyword.operator"] = { fg = palette.keyword }

      -- NOTE: quieting Lua's grammar keywords was tried on 2026-08-09 and
      -- rejected wholesale -- first `local`, then `end`/`then`/`do`. Nothing is
      -- painted here now, deliberately; every Lua keyword stays on the accent.
      -- The measurements and the rejected colours are kept in the palette file
      -- so this is not re-derived. Lua is a config language here, not a daily
      -- one, and the density it suffers from does not reach the daily stack.

      -- Function names and plain identifiers.
      --
      -- No markup/markdown groups appear in any of these three lists, on
      -- purpose: markdown is prose, not a programming language, so it keeps the
      -- theme's own colours. Deliberately left out are @markup.list,
      -- @markup.link, @markup.list.checked, @punctuation.special.markdown,
      -- @markup.list.markdown, markdownLinkText, markdownHeadingDelimiter,
      -- mkdCodeStart/End and htmlH2 -- all of which the theme paints from the
      -- same ramps as code.
      paint({
        "Function",
        "Identifier",
      }, palette.func)

      -- Sync plain-variable color across the JS/TS family. The theme
      -- (solarized-osaka/groups/treesitter.lua) sets a yellow override for
      -- `@variable.typescript` / `@variable.javascript`, but has NO equivalent
      -- for `@variable.tsx` / `@variable.jsx`, so `.tsx`/`.jsx` fall back to the
      -- base `@variable` (base foreground). That made `.ts` variables yellow
      -- while `.tsx` variables stayed white. Link the ts/js variants back to
      -- `@variable` so a plain variable reads the same in every JS/TS file.
      hl["@variable.typescript"] = { link = "@variable" }
      hl["@variable.javascript"] = { link = "@variable" }

      -- Symbolic operators (`=`, `..`, `==`, `~=`, `+`) go neutral. The theme
      -- paints Operator with green500, the same colour as keywords, and that is
      -- what makes the keyword colour feel brighter in some files but not
      -- others. Measured coverage of that colour, by treesitter capture:
      --
      --   file                  real keywords   symbolic ops   total
      --   ai-prompts.lua            5.4%            2.1%        8.0%
      --   solarized-osaka.lua       0.2%            0.5%        0.7%
      --
      -- An 11x spread between two Lua files in the same repo, with the SAME
      -- colour -- so the variation is density, not the value. Symbolic
      -- operators are 26% of it in the dense file and 74% in the config-style
      -- one, because every `key = value` line in a Lua table pays for one.
      -- Dropping them to base0 cuts the dense file to 5.9% and the config file
      -- to 0.2%, i.e. it flattens the difference between files rather than
      -- dimming the colour everywhere.
      --
      -- `=` is punctuation, not a keyword, so this is also the more correct
      -- reading. `and`, `or`, `not` are the exception and stay on the keyword
      -- colour -- they are in the keyword list above, which has to come after
      -- this line would otherwise reach them via
      -- @keyword.operator -> @operator -> Operator.
      hl.Operator = { fg = c.base0 }

      -- Types. The theme sets `Type = yellow500`, which made EVERY type gold:
      -- Rectangle, Shape, float64, string, int, SlotTableProps, ReactNode,
      -- Optional, List. Setting the base group is the whole fix -- @type,
      -- @type.builtin, @type.definition, Typedef and Structure all link to it,
      -- and so does every @lsp.type.* group (inert here: lua/plugins/lsp.lua
      -- nils semanticTokensProvider on attach, so treesitter is the only
      -- painter and nothing can override this back to yellow).
      -- See `variants.type` in the palette file for the measurements.
      hl.Type = { fg = palette.type }

      -- Fields and properties: BOTH are deliberately left at the theme default
      -- as of 2026-08-09, so both are exact duplicates of another role -- not
      -- close, identical (dE2000 0.0), verified by walking treesitter captures
      -- over real Go/TSX/Python files:
      --   @variable.member (r.Width, row.count, self.width) -> cyan500 == String
      --   @property        (struct literal keys, JSX attrs)  -> blue500 == Function
      -- @tag.attribute links to @property, so JSX attributes follow Function.
      --
      -- What that costs, knowingly: a TS type literal renders `mode: 'selectable'`
      -- with the key and the string in one colour, and every Lua `key = "value"`
      -- line does the same. @property duplicating Function is the harmless half --
      -- those two rarely touch on the same line.
      --
      -- @variable.member DID carry an override (rose, see `variants.member` in the
      -- palette file) and it was removed: rose won on measurement but not on looks
      -- in large files, and the collision was preferred to a colour that had never
      -- been judged the way the other roles were. Re-enabling is the one-line
      -- uncomment below; read `variants.member` first, its scores predate the
      -- keyword move and anything close to keyword needs re-measuring.
      -- hl["@variable.member"] = { fg = palette.member }

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
      -- Chroma is more than double tokyonight's, and hue 84 sat in the same warm
      -- family as the syntax accents of the day (the keyword was yellow at hue 98
      -- when this was written; it is violet now, but punctuation is warm at hue
      -- 58, so the collision argument still holds). So the gutter read as CONTENT
      -- competing with code rather than as chrome, which is what makes
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
      -- fg paints the DESCRIPTION PROSE and essentially nothing else, which is
      -- why it is worth a value of its own. Measured 2026-08-09 by dumping the
      -- top treesitter capture of every cell in a real vtsls hover: markdown
      -- paragraph text resolves to `@spell`, and the `*@param*` tags to
      -- `@markup.italic` -- both set attributes only, no foreground -- so the
      -- prose falls through to Normal, i.e. here. Everything else in the float
      -- already carries a colour: the fenced signature gets injected
      -- typescript/go/lua captures, inline chips get LspDocInlineCode, links get
      -- @markup.link.
      --
      -- It was `base1` (#adb7b7, L* 73.7, 9.19:1) until 2026-08-09. That made
      -- the description the BRIGHTEST text in the popup -- above the signature
      -- it describes (@variable L* 69.0, @function.call L* 59.1) and above the
      -- editor's own body text (base0, L* 69.0). VSCode runs that hierarchy the
      -- other way round, and the inversion is what made hover docs read as a
      -- wall of text. `c.fg` (#839395, L* 59.8, 5.90:1) drops the prose 13.9 L*
      -- below the signature's identifiers and still clears WCAG AA for body
      -- text.
      --
      -- Do not go dimmer. The next ramp step, base00 (#637981), is 4.11:1 --
      -- under AA -- and sits only 5 L* off the comment colour. There is exactly
      -- one usable value here, so this is not a knob to tune.
      -- A thin amber frame with a readable title. The two need DIFFERENT weights
      -- and that is the whole point here:
      --   border -- chrome, so it wants to be barely there. `yellow700` sits at
      --     2.33:1 against the float, in the same register as
      --     BlinkCmpMenuBorder's base02 (1.43:1). A syntax accent was tried first
      --     at ~7:1 and read as a heavy box.
      --   title  -- actual text, so it needs contrast, which is why it follows
      --     `palette.keyword` rather than the border's amber.
      -- NOTE: when this was written the keyword was yellow, so title and border
      -- shared a hue family by design. The keyword moved to violet on 2026-08-10
      -- and the title followed it automatically, so the title is now a cool
      -- colour on a warm frame. Left alone deliberately -- it still reads fine,
      -- and the alternative is hardcoding a hex that stops tracking the palette.
      -- Deliberately not `palette.type`: the border used to follow it, so every
      -- retune of the syntax type colour silently moved this chrome with it.
      hl.LspDocFloat = { fg = c.fg, bg = c.bg_float }
      hl.LspDocBorder = { fg = c.yellow700, bg = c.bg_float }
      hl.LspDocTitle = { fg = palette.keyword, bg = c.bg_float, bold = true }

      -- Inline code spans inside a hover doc -- the `"nil"`, `"number"` chips in
      -- a Lua signature. The theme paints @markup.raw.markdown_inline as yellow
      -- on a dark-green fill (#b28500 on #2c3300), which reads as a row of amber
      -- boxes in a float that has no other background anywhere.
      --
      -- Same colour CodeCompanion uses for the same job (see its
      -- `CodeCompanionInlineCode`, lua/plugins/codecompanion.lua), so inline code
      -- reads identically whether it comes from the chat or from an LSP doc.
      -- `bg = "NONE"` matches that too: the chip becomes coloured text rather
      -- than a filled box.
      --
      -- Scoped via winhighlight in config/keymaps.lua rather than set globally,
      -- because @markup.raw.markdown_inline is also every inline span in a real
      -- .md file, and markdown deliberately keeps the theme's own colours.
      hl.LspDocInlineCode = { fg = "#8ab4d8", bg = "NONE" }

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
