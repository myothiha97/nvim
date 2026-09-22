-- Which highlight groups get the palette's colours, plus the UI-chrome overrides
-- that are not syntax at all. Colour VALUES live in palette.lua.
--
-- WHY EACH BLOCK BELOW EXISTS -- the measurements, the grammar traps, the
-- rejected alternatives and the "do not tune this" notes -- is in
-- notes/palette-reference.md, sections "Grammar traps" and "UI highlights".
-- Read it before changing a group list or a chrome value.
local palette = require("colorschemes.solarized-osaka.palette")

return {
  "craftzdog/solarized-osaka.nvim",
  lazy = false,
  priority = 1000,
  opts = {
    -- WARN: SILENT FAILURE. Must be an explicit `false`. The plugin defaults
    -- `transparent` to `true`, so deleting or commenting this line re-enables
    -- transparency rather than disabling it. Opaque since 2026-09-04.
    transparent = false,
    -- ONE background for the whole editor, from lua/config/ui.lua. The ONE
    -- legitimate `on_colors` -- it does not reopen the syntax-ramp ban below.
    -- All three keys, or floats and sidebars show as panels that do not match.
    --
    -- `bg_statusline` FEEDS LUALINE, NOT THE NATIVE `StatusLine`, and both are
    -- left alone so the bar keeps its base03 band (#002c38, 2.2 L* above the
    -- background). TRIED AND REVERTED 2026-09-09: flattening it needs BOTH
    -- `c.bg_statusline` here (the shipped lualine theme reads it for section `c`
    -- and all three inactive sections) AND `StatusLine`/`StatusLineNC` in
    -- `on_highlights` (groups/editor.lua hardcodes those). Reverted because the
    -- band is not new -- the 2026-09-05 winbar flattening is what made it stand
    -- out, not a regression.
    --
    -- WARN: SILENT NO-OP. `bg_popup` is deliberately NOT set and must stay unset
    -- -- it is not the key it looks like, and the completion menu depends on it
    -- staying base04. Measured.
    on_colors = function(c)
      local bg = require("config.ui").bg
      c.bg = bg
      c.bg_float = bg
      c.bg_sidebar = bg
    end,
    -- NO `on_colors` FOR SYNTAX. The theme's base ramp (green500, orange500,
    -- blue500, cyan500) is shared with the UI, so a syntax choice there silently
    -- repaints git signs, diagnostics, the dashboard and indent guides. That is
    -- how the keyword colour turned git-added markers yellow on 2026-08-08.
    on_highlights = function(hl, c)
      -- Merge `fg` so a group keeps its italic/bold/underline/background.
      --
      -- WARN: SILENT FAILURE. Values here are heterogeneous -- a highlight table
      -- OR a bare string, the theme's shorthand for a link. Merging into a
      -- string throws; a link needs no help, its target is in the same list.
      local function paint(groups, fg)
        for _, g in ipairs(groups) do
          if type(hl[g]) == "table" then
            hl[g] = vim.tbl_extend("force", hl[g], { fg = fg })
          elseif hl[g] == nil then
            hl[g] = { fg = fg }
          end
        end
      end

      -- Both roles read `false` as "follow the theme's own ramp", which is why a
      -- build must write `false` and never `nil`. See palette.lua.
      local delimiter = palette.delimiter or c.base0

      local bracket = palette.bracket or palette.punctuation

      -- Painted rather than left to the theme so a build can raise body text.
      -- `paint` merges, so `Normal` keeps its background. The other 15 groups the
      -- theme puts on base0 are chrome and stay put.
      if palette.body then
        paint({ "Normal", "NormalFloat", "@variable" }, palette.body)
      end

      -- Lift syntax comments without changing base01, which also colors UI chrome.
      if palette.comment then
        paint({ "Comment" }, palette.comment)
      end

      -- The winbar sits on the editor background, not the statusline's (the theme
      -- links WinBar -> StatusLine, bg base03, which reads as a lighter strip).
      --
      -- ONLY the winbar. The statusline KEEPS its base03 band -- see the
      -- `bg_statusline` note above for why flattening it was tried and reverted.
      hl.WinBar = { link = "Normal" }
      hl.WinBarNC = { link = "NormalNC" }

      -- `Operator` is deliberately NOT here, but `@keyword.operator` (`and`,
      -- `or`, `not`) is: those are keywords spelled as operators.
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

      paint({
        "Special",
        "Debug",
        "@variable.builtin",
        "@module.builtin",
        -- JSX tags are painted in their own block below. Same colour.
      }, palette.punctuation)

      paint({ "@punctuation.bracket" }, bracket)

      -- NOTHING IS LANGUAGE-SCOPED HERE. TS/JS/JSX/TSX held their brackets on
      -- `base0` until 2026-09-09, on the argument that a TS object literal puts
      -- key and value on the same teal so the brackets are the only marker of
      -- where it starts and ends. Dropped by request: one rung everywhere reads
      -- calmer than ecma being the exception. Put it back with
      -- `hl["@punctuation.bracket." .. lang] = { fg = c.base0 }` over
      -- `{ "tsx", "typescript", "javascript" }`.

      -- `${}` is a MODE SWITCH, not structure, so it keeps the accent -- and it
      -- has to stay readable INSIDE the string colour, which the neutral grey
      -- does not (17.7 separation against this accent's 32.9).
      paint({ "@punctuation.special" }, palette.punctuation)

      -- `\n`, `\t`, `\"` inside a string. SAME REASONING as `${}` above, and the
      -- same colour: an escape is not string content, it is a switch out of it.
      -- The theme leaves it on an alarm dark red at 2.87:1, the lowest contrast
      -- in the palette, on characters that matter most in `fmt.Printf`-style code
      -- and regex. Every readable red either collided with a warm role or stayed
      -- under 5:1; the candidate sweep is in notes/palette-reference.md.
      hl["@string.escape"] = { fg = palette.punctuation }

      paint({
        "@variable.parameter",
        "@constructor",
        "@constructor.tsx",
      }, palette.parameter)

      -- Lua captures `{` as BOTH @punctuation.bracket and @constructor, so this
      -- pin is what stops a `palette.parameter` change recolouring every Lua
      -- table brace. Language-scoped: @constructor.lua resolves first.
      paint({ "@constructor.lua" }, bracket)

      -- JSX tag NAMES. Both captures MUST carry the same value -- the grammar
      -- matches one tag with BOTH and query order picks the winner, so splitting
      -- them renders `<DragAndDrop.Droppable>` in two colours. @tag.builtin.* is
      -- listed explicitly so theme drift cannot bring that back.
      --
      -- Language-scoped, so nothing here reaches Go/Python/Lua/bash/plain TS.
      -- KNOWN COST: 30.2% of glyphs in markup-heavy TSX. That is a DOSE problem,
      -- not a colour problem -- retuning the hex cannot change coverage.
      paint({
        "@tag.tsx",
        "@tag.javascript",
        "@tag.builtin.tsx",
        "@tag.builtin.javascript",
      }, palette.punctuation)

      -- Tag wrappers (`<`, `>`, `/`) FOLLOW BODY TEXT, so dense markup gets a
      -- quieter frame. They were pinned to `c.base0` while body was base0 too;
      -- when body moved to `body.midpoint` (2026-09-09) that left the two only
      -- dE00 2.6 apart -- a pair that looks identical but is not, which is worse
      -- than either sharing or clearly differing. Tracking `palette.body` keeps
      -- the original intent and cannot drift again.
      --
      -- Keep language-scoped: ordinary comparison and division operators still
      -- follow the syntax palette.
      paint({
        "@tag.delimiter.tsx",
        "@tag.delimiter.vue",
        "@tag.delimiter.html",
        "@tag.delimiter.javascript",
      }, palette.body or c.base0)

      -- This group is `,` `;` `:` AND the `.` of every member access, so on the
      -- keyword colour it put an accent mark on nearly every line of Go and TS.
      paint({ "@punctuation.delimiter" }, delimiter)

      -- Written as tables because `paint` skips bare string links, and these two
      -- link OUTSIDE the lists above, so skipping would leave them resolving
      -- wrong: @keyword.import -> PreProc -> an alarm red that reads as a
      -- diagnostic, and @keyword.operator -> Operator, which goes neutral below.
      hl["@keyword.import"] = { fg = palette.punctuation }

      -- Decorators (Python `@dataclass`, TS/NestJS `@Injectable()`). SAME DEFECT
      -- as `@keyword.import`: `@attribute` -> PreProc -> #db302d, byte-identical
      -- to DiagnosticError, so a decorator was painted in the "error" colour.
      -- Uses `palette.punctuation` because `@attribute.builtin` already resolved
      -- there via `Special`, so both decorator kinds now match.
      hl["@attribute"] = { fg = palette.punctuation }
      hl["@keyword.operator"] = { fg = palette.keyword }

      -- Nothing paints Lua's grammar keywords, deliberately: that was tried
      -- twice in 2026-08-09 and rejected wholesale. See palette.lua.

      -- No markup/markdown groups in any of these lists, on purpose: markdown is
      -- prose and keeps the theme's own colours. Exclusion list in the doc.
      paint({
        "Function",
        "Identifier",
      }, palette.func)

      -- Builtin CALLABLES are functions, so they go on the function colour.
      -- `@function.builtin` and `@function.method.builtin` link to `Special`
      -- upstream, which this file paints with the warm accent -- so Lua's
      -- `require`/`pcall`/`tostring`, bash's `echo`, and Python's `print`/`len`
      -- rendered in the accent while every user-defined call beside them was
      -- blue. The distinction the accent was drawing (builtin vs yours) is not
      -- one worth a hue: what you read is "this is a call".
      --
      -- `@variable.builtin` (`self`, `vim`, `this`) deliberately STAYS on the
      -- accent -- those are values, not calls, and there are few of them.
      --
      -- Written as tables, not `paint`: both groups are bare string links in the
      -- theme, and `paint` skips those by design (see the helper). Going through
      -- `paint` here silently did nothing.
      hl["@function.builtin"] = { fg = palette.func }
      hl["@function.method.builtin"] = { fg = palette.func }

      -- The theme overrides `@variable.typescript`/`.javascript` yellow but has
      -- no `.tsx`/`.jsx` equivalent, so `.ts` variables were yellow while `.tsx`
      -- stayed white. Link both back to `@variable`.
      hl["@variable.typescript"] = { link = "@variable" }
      hl["@variable.javascript"] = { link = "@variable" }

      -- Symbolic operators go neutral. The theme paints Operator with the keyword
      -- colour, which is what made that colour feel brighter in some files but
      -- not others -- measured at an 11x coverage spread between two Lua files in
      -- the same repo. `=` is punctuation, not a keyword. `and`/`or`/`not` are
      -- the exception and stay on the keyword list above, which must come after
      -- this or it reaches them via @keyword.operator -> @operator -> Operator.
      hl.Operator = { fg = delimiter }

      -- Native CSS fallback: reuse syntax roles instead of Function/PreProc/Noise.
      -- Explicit links survive css.vim's later `hi def link` without buffer hooks.
      -- Function regions supply the colour of otherwise uncaptured calc operators.
      for group, target in pairs({
        cssBraces = "@punctuation.bracket",
        cssMathParens = "@punctuation.bracket",
        cssNoise = "@punctuation.delimiter",
        cssClassNameDot = "@punctuation.delimiter",
        cssAttrComma = "@punctuation.delimiter",
        cssFunctionComma = "@punctuation.delimiter",
        cssMediaComma = "@punctuation.delimiter",
        cssSelectorOp = "Operator",
        cssSelectorOp2 = "Operator",
        cssFunction = "Operator",
        cssMathGroup = "Operator",
        cssAtRule = "@keyword",
        cssAtKeyword = "@keyword",
        cssAtRuleLogical = "@keyword",
        cssPseudoClass = "@keyword",
        cssPseudoClassId = "@keyword",
        cssPagePseudo = "@keyword",
      }) do
        hl[group] = { link = target }
      end

      -- Setting the base group is the whole fix: @type, @type.builtin,
      -- @type.definition, Typedef, Structure and every @lsp.type.* link to it.
      hl.Type = { fg = palette.type }

      -- Booleans. Assigned to the BASE group because the whole chain is bare
      -- string links (`@boolean` -> `Boolean` -> `Constant`) and `paint` skips
      -- strings by design. Setting `Boolean` breaks that link, so `Constant`
      -- itself is untouched and `@boolean` follows automatically.
      hl.Boolean = { fg = palette.boolean }

      -- Numbers, on the same value as booleans and named constants -- the
      -- Tokyo Night grouping, where one colour carries every literal constant.
      -- Set on `Number` rather than `Constant`: `Float` links to `Number`, so
      -- this covers `@number` AND `@number.float`, while `Constant`, `@string`
      -- and `@character` keep the theme's cyan. Before this, `@number` was
      -- dE2000 0.0 from `@string` -- a numeric literal and a string literal
      -- were the same colour.
      hl.Number = { fg = palette.boolean }

      -- Named constants (SCREAMING_SNAKE). Were the theme's `Constant` cyan,
      -- dE2000 0.0 from both `@string` and `@number`.
      --
      -- WARN: set on the CAPTURES, not on `Constant` -- `Constant` is also
      -- `@character` and (until `Number` is set above) every numeric literal, so
      -- assigning the base group reaches further than intended.
      -- See notes/palette-reference.md, "Named constants".
      hl["@constant"] = { fg = palette.boolean }
      hl["@constant.macro"] = { fg = palette.boolean }

      -- Go struct FIELDS, every grammatical position on one value. Go names the
      -- same field in three spots and the base queries capture each differently,
      -- so `Width` was teal in `type R struct { Width float64 }`, teal again in
      -- `R{Width: 3}` and BLUE in `r.Width` -- three colours for one name.
      -- `@property` is the access one, which is why field reads looked like calls.
      --
      -- On the accent rather than a colour of its own: fields are what you
      -- actually read in Go, where the receiver is usually one letter, and the
      -- accent is the palette's loudest value.
      --
      -- GO ONLY, and language-scoped rather than painted then undone --
      -- `@variable.member.go` resolves before `@variable.member`, so no other
      -- language needs excluding. The same captures in TS/JS also cover object
      -- members, where a warm colour flooded whole files, so every other language
      -- keeps the theme's own cyan500. `@variable.member.key` links to `@string`
      -- below regardless, so keys always sit with their values.
      --
      -- KNOWN COST: the accent now carries imports, parameters, builtin
      -- constants, string escapes AND every field position, making it by far the
      -- densest colour in a struct-heavy Go file. It clears the Go literals by
      -- dE 27.7, so `Width: 3` still reads as two things.
      --
      -- Rejected on the way here, both 2026-09-08: `@variable.member` on the
      -- keyword violet for all non-Go languages (a field and a keyword read as
      -- one class), and a dedicated salmon for Go (one warm hue too many). See
      -- notes/palette-reference.md.
      for _, group in ipairs({ "@variable.member.go", "@variable.member.key.go", "@property.go" }) do
        hl[group] = { fg = palette.punctuation }
      end

      -- Object-literal and type-literal KEYS, normalised. The base ecma queries
      -- file a bare key as @variable.member and a quoted key as @string, so
      -- `{ Cash: 1, 'Credit Card': 2 }` showed its two keys in two colours for
      -- no reason but the quoting. `after/queries/{typescript,tsx,javascript}`
      -- re-capture the key position as @variable.member.key; member ACCESS
      -- (`obj.attr`) keeps @variable.member and stays on the member colour.
      --
      -- Linked to @string so keys sit with the values they introduce. The
      -- alternative is `{ link = "@variable.member" }`, which puts keys on the
      -- member colour instead and keeps key and value distinct -- one-line swap.
      -- MUST stay painted whenever `member` is. `@variable.member.key` has no
      -- colour of its own otherwise, so it FALLS BACK to `@variable.member` --
      -- which is what made a distinct member colour flood every object-literal
      -- file. The capture split in after/queries/ is necessary but not
      -- sufficient; this line is the other half.
      hl["@variable.member.key"] = { link = "@string" }

      -- HCL/Terraform attribute names. The `@string` link above is an ecma
      -- decision -- an object literal is a small part of a TS file -- but the HCL
      -- queries file EVERY `key = value` name as `@variable.member.key`, so a
      -- whole `.tf` file rendered its keys and its values in one colour
      -- (dE2000 0.0). `@property` is where YAML and TOML keys already sit, so
      -- config languages now read the same way whatever the syntax.
      for _, lang in ipairs({ "terraform", "hcl" }) do
        hl["@variable.member.key." .. lang] = { link = "@property" }
      end

      -- OPEN FOLLOW-UP, non-Go `@property`. A different group from the two above,
      -- still at the theme default where it exactly duplicates Function:
      -- struct-literal keys, object/dict keys and JSX attributes
      -- (`@tag.attribute` links to it). So a TS `mode: 'x'` renders its key in
      -- the function colour, and a YAML manifest is ~59% function-blue.
      --
      -- WARN: SILENT NO-OP if you reach for `palette.member` here -- the build
      -- leaves that `false`, so the line would set `fg = nil`. Give the role its
      -- own palette entry first. Do NOT hand it the member value even once it
      -- exists: the two land on the same line constantly and would collide.

      -- @module links to PreProc -> an alarm red 31 degrees from the error red,
      -- so imports read as diagnostics in every language except Go.
      hl["@module"] = { fg = c.base2 }

      hl.Visual = { bg = "#3b4261" }
      hl.VisualNOS = { bg = "#3b4261" }

      -- The theme's `yellow700` gutter is a CHROMA problem, not a lightness one:
      -- it read as content competing with code. #2d3f43 is a low-chroma cool grey
      -- on the background's own hue. If too dim, #33474b is the one step up --
      -- DO NOT go back toward a saturated hue, raise lightness and keep C* < 10.
      -- All three carry explicit values in the theme, so all three must be set.
      hl.LineNr = { fg = "#2d3f43" }
      hl.LineNrAbove = { fg = "#2d3f43" }
      hl.LineNrBelow = { fg = "#2d3f43" }

      -- Current-line band, OFF. Tried 2026-09-08 at `#032732` and parked, not
      -- rejected -- swap the two lines below to re-enable. The `cursorline`
      -- OPTION is already on, so this line is the whole switch. Bounds, the
      -- tested ladder, and why chroma is not an axis here:
      -- notes/palette-reference.md, "Cursor line".
      hl.CursorLine = { bg = "NONE" }
      -- hl.CursorLine = { bg = "#032732" }

      -- The current-line number indicator. Change the value here.
      hl.CursorLineNr = {
        fg = palette.variants.punctuation.explored.copper,
      }
      -- Oil-only current-row band, since CursorLine is off globally. Oil remaps
      -- CursorLine -> OilCursorLine via winhighlight.
      hl.OilCursorLine = { bg = c.base02 }

      -- `SnacksPickerListCursorLine` is deliberately NOT defined here. Leaving it
      -- alone is what restores the pre-2026-09-09 picker cursor row: snacks
      -- creates it as a `default = true` link to `Visual` (picker/core/list.lua:86
      -- via util/highlight.lua `winhl`), so the focused list row lands on
      -- `Visual` -- #3b4261, violet, hue 287 -- which is what every month up to
      -- then looked like.
      --
      -- It was pinned to base02 on 2026-09-09 to share oil's band, and reverted
      -- 2026-09-11: base02 is a dark TEAL, the same hue family as the explorer's
      -- active-file band (#003f52), so the focused row and the open file read as
      -- one thing. Violet against that teal is the separation.
      --
      -- WARN: SILENT FAILURE -- this CANNOT be scoped to the explorer alone, and
      -- both ways of trying look like they work until you look at the window:
      --   * a per-window `winhighlight` is overwritten on EVERY render.
      --     `update_cursorline` (list.lua:538) rewrites the CursorLine entry of
      --     whatever the window already has.
      --   * a window highlight namespace (`nvim_win_set_hl_ns`) is the same slot
      --     as `winhighlight`, not an addition to it. Measured on 0.12.5: with a
      --     namespace attached, the mapped target group is never consulted, and a
      --     group MISSING from the namespace renders with NO highlight rather
      --     than falling back to the global one -- so the explorer would lose its
      --     Normal, border and title colours unless the namespace redefined all
      --     of them.
      -- An explorer-only band has to be an extmark, which is how the active-file
      -- band in `lua/plugins/snacks.lua` does it.

      -- Markdown headings only. The GENERIC @markup.heading links to `Title`,
      -- which help files, pickers and `:set all` share -- so override the
      -- markdown-specific variants instead. render-markdown leaves heading fg to
      -- treesitter, so this is what paints them.
      for level = 1, 6 do
        hl["@markup.heading." .. level .. ".markdown"] = { fg = c.green, bold = true }
      end

      -- JSX/TSX <h1>-<h6> are markup ELEMENTS, not document headings, but the ecma/jsx
      -- queries capture the text inside them as @markup.heading.<level> all the same. That
      -- falls back to `Title` and paints ordinary UI copy (`<h1>Checkout</h1>`) in the same
      -- red as a picker title, while the identical text one element up is plain `Normal`.
      -- Both parsers are named because .tsx uses `tsx` and .jsx uses `javascript`.
      -- Body text is one value by design (`palette.body`, painted onto Normal and
      -- @variable above), so these read it too rather than pinning a second value.
      -- No bold either: nothing about a JSX tag name makes its text a heading.
      local jsx_heading_fg = palette.body or c.fg
      for _, lang in ipairs({ "tsx", "javascript" }) do
        for level = 1, 6 do
          hl["@markup.heading." .. level .. "." .. lang] = { fg = jsx_heading_fg }
        end
      end

      -- Markdown pipe tables, all four pieces painted in body text. A table is
      -- structure, not a heading, and it was reading in picker-title red because
      -- three separate defaults all landed on `Title`:
      --   * `RenderMarkdownTableHead` links to the GENERIC `@markup.heading`
      --     (the plugin's own default) -- the same red trap as the JSX headings
      --     above. `TableRow` already defaults to `Normal`; named here so the two
      --     halves of one frame cannot drift apart.
      --   * header CELL TEXT is captured `@markup.heading` with no level by the
      --     markdown query, so it never reaches the green `.1`-`.6` rules above.
      --     Scoped `.markdown` so help files and picker titles keep `Title`, and
      --     no level variant is shadowed.
      --   * the theme paints `@punctuation.special.markdown` red-bold; in this
      --     query that is the table pipes and `---` delimiter cells (plus a
      --     thematic break, which render-markdown draws as its own rule anyway).
      local table_fg = palette.body or c.fg
      hl.RenderMarkdownTableHead = { fg = table_fg }
      hl.RenderMarkdownTableRow = { fg = table_fg }
      hl["@markup.heading.markdown"] = { fg = table_fg }
      hl["@punctuation.special.markdown"] = { fg = table_fg }

      -- LSP doc surface (hover, signature, diagnostic floats, blink docs).
      -- Deliberately NOT applied to NormalFloat, which would repaint the snacks
      -- picker; reached only via winhighlight in config/keymaps.lua.
      -- DO NOT dim `fg` further -- the next ramp step DOWN is sub-AA and sits
      -- 5 L* off Comment, so there is exactly one usable value below. Border is
      -- chrome (2.33:1) and the title is text, so they deliberately differ.
      -- Full reasoning: notes/palette-reference.md, "LSP documentation surface".
      --
      -- RAISED 2026-09-22, from the theme's own `c.fg` (#839395) to
      -- `body.faded`. Hover prose read as faded grey against the code beside it,
      -- because `c.fg` is the theme's upstream body value while THIS config
      -- paints `Normal` from `palette.body` (#a0b6b8) -- so the doc surface had
      -- silently drifted 12.7 L* below the editor's own text.
      --
      --   #839395 -> #919e9f   +4.3 L*, 6.06:1 -> 7.01:1 (clears AAA)
      --   dE00 7.3 from editor body, so a doc still reads as secondary text
      --   worst neighbour INSIDE the popup is the inline-code blue #8ab4d8 at
      --   dE00 14.4; Comment clears at 15.5, String at 18.6, the title at 19.7
      --
      -- Not `palette.body` itself: prose matching code exactly removes the cue
      -- that the float is a different surface. Not `base0` either -- that is the
      -- file-list value, and 8.19:1 read brighter than a doc needs to be.
      hl.LspDocFloat = { fg = palette.variants.body.faded or c.fg, bg = c.bg_float }
      hl.LspDocBorder = { fg = c.yellow700, bg = c.bg_float }
      hl.LspDocTitle = { fg = palette.keyword, bg = c.bg_float, bold = true }

      -- Inline code chips in a hover doc. The theme's yellow-on-dark-green fill
      -- reads as amber boxes in a float with no other background. Same colour
      -- CodeCompanion uses, so chips match between chat and LSP doc. Scoped via
      -- winhighlight in config/keymaps.lua, because that capture is also every
      -- inline span in a real .md file.
      hl.LspDocInlineCode = { fg = "#8ab4d8", bg = "NONE" }

      -- Completion menu family: `c.bg_popup`, NOT `c.bg_float`. Since 2026-09-04
      -- `bg_float` is the shared editor background, which left the menu with no
      -- panel of its own. `bg_popup` is still base04 and is the right key -- these
      -- are popups, not floats.
      hl.BlinkCmpDoc = { fg = c.base1, bg = c.bg_popup }
      hl.BlinkCmpDocBorder = { fg = palette.type, bg = c.bg_popup }

      hl.BlinkCmpMenu = { fg = c.base1, bg = c.bg_popup }
      hl.BlinkCmpMenuBorder = { fg = c.base02, bg = c.bg_popup }
      hl.BlinkCmpMenuSelection = { fg = c.base2, bg = c.base02, bold = true }
      hl.BlinkCmpLabel = { fg = c.base1, bg = c.none }
      hl.BlinkCmpLabelMatch = { fg = c.blue300, bg = c.none }

      hl.Pmenu = { fg = c.base1, bg = c.bg_popup }
      hl.PmenuSel = { fg = c.base2, bg = c.base02, bold = true }
      hl.PmenuSbar = { bg = c.bg_highlight }
      hl.PmenuThumb = { bg = c.base01 }

      hl.DiagnosticVirtualTextError = { fg = "#ff3b30", bg = c.none }
      hl.DiagnosticVirtualTextWarn = { fg = "#e0af68", bg = c.none }
      hl.DiagnosticVirtualTextInfo = { bg = c.none }
      hl.DiagnosticVirtualTextHint = { fg = "#1abc9c", bg = c.none }

      hl.Folded = { bg = "NONE" }
      hl.UfoFoldedBg = { bg = "NONE" }

      -- grug-far match. Defaults to DiffText, a near-black green band here, so
      -- the match looks faded. Cyan deliberately, so it never reads like a vim
      -- `/` hit (Search is yellow, IncSearch muted rose-red).
      hl.GrugFarResultsMatch = { fg = c.base04, bg = c.cyan300, bold = false }

      -- grug-far summary. Defaults to Comment, too dim against the panel.
      hl.GrugFarResultsStats = { fg = c.base2 }

      -- TODO: brighten the snacks picker match highlight (currently a faded
      -- olive band). Setting `hl.SnacksPickerMatch` here does NOT take effect --
      -- something re-applies it to `DiffText` AFTER this on_highlights runs
      -- (snacks registers picker hl groups lazily on its own ColorScheme hook).
      -- Needs a late ColorScheme autocmd or the snacks plugin spec instead.
      -- Scope: snacks picker only.
    end,
  },
}
