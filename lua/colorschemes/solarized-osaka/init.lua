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
      -- does not (17.7 separation against this accent's 32.9). Those were against
      -- the old cyan strings; against the green since 2026-09-24 it is 16.4.
      --
      -- PARKED (evening, 2026-09-24): the moves below live in custom-v4 and the
      -- custom-swap builds through `palette.escape`; `false` keeps the accent.
      --
      -- So it moved to the literal orange with the escapes below, by choice, the
      -- same day: TS `${}` and Python f-string `{}` were the last places yellow
      -- sat inside green (103 contacts in palette.py alone). Known cost: bash
      -- `${HOME}` reads orange `${`, yellow `HOME` (`@variable.builtin`), orange `}`.
      paint({ "@punctuation.special" }, palette.escape or palette.punctuation)

      -- `\n`, `\t`, `\"` inside a string. SAME REASONING as `${}` above: an
      -- escape is not string content, it is a switch out of it. The theme leaves
      -- it on an alarm dark red at 2.87:1, the lowest contrast in the palette, on
      -- characters that matter most in `fmt.Printf`-style code and regex.
      --
      -- On the literal orange since 2026-09-24, when strings went green: the
      -- accent yellow sat only 16.4 from the green, the orange 39.6. An escape is
      -- a literal, so no hue is added. `${}` joined it (see above). Rejected
      -- candidates: notes/string-and-member-colours.md.
      hl["@string.escape"] = { fg = palette.escape or palette.punctuation }

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
      --
      -- PARKED (evening, 2026-09-24): violet lives in custom-v4 and the
      -- custom-swap builds through `palette.import`; `false` keeps the accent.
      --
      -- `import`/`package`/`from` are keywords, so the keyword violet since
      -- 2026-09-24 (was the accent yellow, 16.4 from the green import paths under
      -- them; violet is 63.6). Dose: notes/string-and-member-colours.md.
      hl["@keyword.import"] = { fg = palette.import or palette.punctuation }

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
      -- this covers `@number` AND `@number.float`, while `Constant` keeps the
      -- theme's cyan. Before this, `@number` was
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
      -- keeps the theme's own cyan500. `@variable.member.key` links to
      -- `@variable.member` below, so keys sit with member access, not strings.
      --
      -- KNOWN COST: the accent now carries parameters, builtin constants AND
      -- every field position, making it by far the densest colour in a
      -- struct-heavy Go file (imports and escapes left it on 2026-09-24). It
      -- clears the Go literals by dE 27.7, so `Width: 3` still reads as two things.
      --
      -- Rejected on the way here, both 2026-09-08: `@variable.member` on the
      -- keyword violet for all non-Go languages (a field and a keyword read as
      -- one class), and a dedicated salmon for Go (one warm hue too many). See
      -- notes/palette-reference.md.
      -- `palette.field` lets a build hold fields on their own value (2026-09-24,
      -- all-orange builds, so `Width: 3` does not read as one orange run).
      for _, group in ipairs({ "@variable.member.go", "@variable.member.key.go", "@property.go" }) do
        hl[group] = { fg = palette.field or palette.punctuation }
      end

      -- Object-literal and type-literal KEYS, normalised. The base ecma queries
      -- file a bare key as @variable.member and a quoted key as @string, so
      -- `{ Cash: 1, 'Credit Card': 2 }` showed its two keys in two colours for
      -- no reason but the quoting. `after/queries/{typescript,tsx,javascript}`
      -- re-capture the key position as @variable.member.key; member ACCESS
      -- (`obj.attr`) keeps @variable.member and stays on the member colour.
      --
      -- Linked to @variable.member since 2026-09-24, so a key and the string
      -- value it introduces read as two things (`url: 'x'`). Until then it
      -- linked to @string, and key, member and string were all one cyan.
      --
      -- WARN: keys now FOLLOW the member colour. Giving `member` a colour of its
      -- own moves every object key with it, which is what flooded object-literal
      -- files with salmon on 2026-09-08. Re-measure dose before doing that.
      hl["@variable.member.key"] = { link = "@variable.member" }

      -- Strings, green in EVERY language since 2026-09-24 (`palette.string`).
      -- `false` keeps the theme cyan. `Character` is a bare link to `Constant` in
      -- the theme, which `paint` skips, so it is assigned directly; a rune or char
      -- literal is a string literal and moves with it.
      --
      -- A per-language version (green only where members are cyan) was tried and
      -- dropped the same day: cyan lost on legibility everywhere. Numbers:
      -- notes/string-and-member-colours.md.
      if palette.string then
        paint({ "String", "@string.documentation" }, palette.string)
        hl.Character = { fg = palette.string }
        -- WARN: SILENT FAILURE. The theme links `@markup.raw` to `String`, and
        -- markdown code blocks (`@markup.raw.block.markdown`) and :help examples
        -- fall back to it, so moving `String` repainted every doc code block in
        -- the string colour (Lua hovers: the indented blocks from Vim's docs).
        -- Code is not a string literal: pinned to the cyan it had before.
        hl["@markup.raw"] = { fg = c.cyan500 }
      end

      -- Go-only overrides (`palette.go`, a table of role -> value), so a build
      -- can give Go its own strings, parameters and escapes while every other
      -- language keeps the shared roles. `false` means none.
      local go = palette.go
      if go then
        if go.string then
          hl["@string.go"] = { fg = go.string }
          hl["@character.go"] = { fg = go.string }
        end
        if go.parameter then
          hl["@variable.parameter.go"] = { fg = go.parameter }
        end
        if go.escape then
          hl["@string.escape.go"] = { fg = go.escape }
        end
      end

      -- HCL/Terraform attribute names. The member link above is an ecma
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

      -- Selection band. Was tokyonight's `#3b4261`, an import that ended up being
      -- the LIGHTEST surface in the editor (L* 28.6, above even oil's list band)
      -- while carrying almost no hue (C* 20) -- so it identified itself by
      -- BRIGHTNESS, read as a grey-white sheet, and washed out the code under it.
      -- Measured 2026-09-23: comments sat at 2.05:1 and keywords at 2.91:1 on it,
      -- i.e. selecting a block made it harder to read exactly while you checked
      -- what you had selected.
      --
      -- The replacement sits on the theme's OWN violet (`violet900` = #24275a,
      -- hue 297, C* 35): 7 L* darker, 74% more chroma, so it identifies by HUE
      -- instead of by being the brightest thing on screen. Every role improves --
      -- body 4.62 -> 6.53:1, keyword 2.91 -> 4.11:1, comment 2.05 -> 2.89:1 -- and
      -- it pulls further from every other band (dE to CursorLine 21.8 -> 31.5, to
      -- oil's 20.2 -> 33.0, to the explorer's active file 16.8 -> 30.3).
      --
      -- TRIED TWICE AND REJECTED BOTH TIMES, same day: a brighter rung at the same
      -- hue and chroma, `#2b2d61` (violet900 lifted L* 18.2 -> 21.0, dC* 0.04, dh
      -- 0.07 deg). dE2000 between the two is only **1.95**, just over the
      -- just-noticeable difference, so it is a real but marginal change -- viewed
      -- side by side on the real panel, violet900 won.
      --
      -- The lift was for SMALL selections: a `viw` on one word is located by the
      -- band popping, not by its shape, and violet900 lifts 1.40:1 off the
      -- background where the old #3b4261 lifted 1.97:1 (a tiny mark reads
      -- LIGHTNESS first; chroma needs area to register). `#2b2d61` gets that to
      -- 1.52:1 -- and it was not worth what it cost.
      --
      -- WHAT IT COSTS, and THE CEILING if anyone reopens this: every role loses
      -- ~8% of contrast on the band, and the function blue `#359ee9` -- the
      -- dimmest thing that lands on a selection often in TS/JS -- goes 4.77 ->
      -- 4.37:1. Blue is the binding constraint and falls away fast: 4.11:1 at
      -- #303166 (L* 22.9), 3.82:1 at #35366b (L* 25.1). DO NOT GO PAST #303166.
      -- Only LIGHTNESS moves on this ladder; hue 297 and C* 35 are what keep the
      -- band theme-native.
      --
      -- And note what AA does NOT settle here: no usable band reaches 4.5:1 on the
      -- dim roles. violet900 gets 5 of 9 roles there, `#2b2d61` 4 of 9, the old
      -- #3b4261 only 2 of 9. Compare bands against each other, not the threshold.
      --
      -- `Visual` now paints visual mode only. The outline's followed row and the
      -- snacks picker rows used to inherit it; since 2026-09-23 they are pinned to
      -- `ListCursorLine` (below), so retuning this no longer repaints any panel.
      hl.Visual = { bg = c.violet900 }
      hl.VisualNOS = { bg = c.violet900 }

      -- The theme's `yellow700` gutter is a CHROMA problem, not a lightness one:
      -- it read as content competing with code. This is a low-chroma cool grey on
      -- the background's own hue. DO NOT go back toward a saturated hue: raise
      -- LIGHTNESS and keep C* < 10.
      --
      -- Raised 2026-09-23 from #2d3f43 (L* 25.3, 1.76:1), which was unreadable at
      -- a glance -- ui.lua already named it the theme's worst group. The ladder,
      -- all measured against the #001014 background:
      --
      --   #2d3f43  L* 25.3  1.76:1  the old value, too faint
      --   #33474b  L* 28.7  1.98:1  read as readable in a real pane
      --   #384e53  L* 31.6  2.20:1  the midpoint, also tried
      --   #3d555b  L* 34.5  2.44:1  SELECTED, all three rungs viewed in a real pane
      --
      -- The selected value is +9.2 L* over the old one (1.39x contrast), which is
      -- a large RELATIVE move but still an objectively dim element: 2.44:1 is far
      -- under the 4.5:1 text threshold, and the gutter remains the dimmest thing
      -- on screen by a wide margin.
      --
      -- THE STOP RULE IS THE GAP TO `comment` (#5f767d, L* 48.1), the dimmest
      -- value that carries meaning. The gutter must stay under it or the numbers
      -- start reading as content. This holds 13.6 L*, and the comment still
      -- carries 1.65x its contrast. That is the last rung with a real gap: do NOT
      -- go past it, the next step lands inside a JND-scale margin of `comment`.
      --
      -- Dose is not the risk here. The gutter is about 5.7% of visible glyphs (73
      -- of ~1290 in a 45-row viewport) and sits in its own column rather than
      -- interleaved with code, so the eye can drop it. What to watch for instead
      -- is MOTION: `relativenumber` redraws the whole column on every cursor move,
      -- so if this value ever pulls the eye it will be while navigating, not while
      -- reading. #384e53 and #33474b are the fallbacks, in that order.
      --
      -- All three carry explicit values in the theme, so all three must be set.
      -- With `number` + `relativenumber` both on, LineNrAbove/Below carry almost
      -- the whole gutter and the cursor's own row is `CursorLineNr` below.
      hl.LineNr = { fg = "#3d555b" }
      hl.LineNrAbove = { fg = "#3d555b" }
      hl.LineNrBelow = { fg = "#3d555b" }

      -- Current-line band, OFF. Turned on 2026-09-23 and turned back off the same
      -- day -- not on the numbers, which were fine, but because months of reading
      -- without a band had set the expectation and the band read as wrong. Taste,
      -- and it is the deciding vote here. The `cursorline` OPTION stays on, so
      -- these two lines are the whole switch: swap them to bring it back.
      --
      -- IF IT COMES BACK, USE `#032732`, NOT THE THEME'S DEFAULT. Upstream sets
      -- `CursorLine = { bg = c.base03 }` (#002c38, groups/editor.lua), and measured
      -- against the retuned syntax colours and the real background (#001014) that
      -- value puts the violet keyword at 4.39:1 and the operator grey at 4.51:1 --
      -- keywords fall under AA on the one line you are reading. #032732 is 2.1 L*
      -- darker, holds every accent at 4.64:1 or better, and is still a clearly
      -- visible band (1.236:1 over the background, the relationship tokyonight
      -- ships). The full ladder is in notes/palette-reference.md, "Cursor line".
      --
      -- Turning it back on also makes Trouble's preview band reappear in the code
      -- window -- expected, not a bug; see lua/config/autocmds.lua.
      -- hl.CursorLine = { bg = "#032732" }
      hl.CursorLine = { bg = "NONE" }

      -- The current-line number indicator. Change the value here.
      hl.CursorLineNr = {
        fg = palette.variants.punctuation.explored.copper,
      }
      -- Oil-only current-row band: a file list needs a row marker even though the
      -- editor's own CursorLine band is off. Oil remaps CursorLine -> OilCursorLine
      -- via winhighlight.
      hl.OilCursorLine = { bg = c.base02 }

      -- The focused row of a LIST panel -- picker, picker preview, and the outline
      -- panel, which remaps its CursorLine here (lua/plugins/trouble.lua).
      --
      -- It used to BE `Visual`: snacks links its groups to `Visual` with
      -- `default = true` (picker/core/list.lua:86 and picker/core/preview.lua:58,
      -- via util/highlight.lua `winhl`), so every one of these inherited the
      -- selection colour. That is why moving `Visual` to violet900 on 2026-09-23
      -- repainted the picker and the explorer too. `default = true` means an
      -- explicit definition here WINS and snacks will not overwrite it, so pinning
      -- the group is the whole fix -- and it keeps `Visual` meaning visual mode.
      --
      -- The value is the OLD `Visual` (tokyonight `#3b4261`), kept on purpose: in
      -- a list the band is the only marker, so here BRIGHTNESS is the right signal
      -- -- the opposite of the editor, where it cost 40% of the contrast on every
      -- syntax role. The picker PREVIEW shares it and does show code, but only one
      -- line under the band, and it wore this same value before 2026-09-23.
      --
      -- It is also what the explorer's active-file band was tuned against: that
      -- band (#003f52, L* 24.2) was set 4.4 L* BELOW this one on 2026-09-04, and
      -- pinning restores that relationship (see lua/plugins/snacks.lua).
      --
      -- Do NOT give this the teal `base02`: tried 2026-09-09, reverted 2026-09-11,
      -- because it is the same hue family as the active-file band and the focused
      -- row then reads as one thing with the open file. Violet against that teal
      -- is the separation.
      hl.ListCursorLine = { bg = "#3b4261" }
      hl.SnacksPickerListCursorLine = "ListCursorLine"
      hl.SnacksPickerPreviewCursorLine = "ListCursorLine"
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
      -- 5 L* off Comment, so there is exactly one usable value below. The
      -- border is no longer chrome (see its own note below) and the title is
      -- text, so the three values deliberately differ.
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
      -- FLOAT BORDERS, 2026-09-22, by preference. Both surfaces moved off the
      -- theme's `yellow700` (#664c00) to `c.cyan700` -- the faded end of the same
      -- cyan ramp the string green `cyan500` sits on, read by theme key rather
      -- than as a copied hex. First tried at `cyan900`, raised the same day
      -- because it was too faint. Read the live value from `FloatBorder`.
      --
      -- `FloatBorder` is the FALLBACK ring for every popup that does not define
      -- one of its own (lazy.nvim, mason, diagnostic floats, gitsigns blame,
      -- `:Lazy`), so it is painted here beside `LspDocBorder`. Before this it
      -- was the only other group carrying #664c00, which is what made hover
      -- docs and everything else share the olive ring in the first place.
      --
      -- THE PICKER SET THE DIRECTION, NOT THE FINAL VALUE. `SnacksPickerBorder`
      -- (`base02`, #063540) is what "a ring that does not shout" looks like
      -- here, so the search ran down the cyan ramp towards it. The ramp, all
      -- measured against the #001014 background:
      --
      --              L*     C*    hue     vs bg     dE00 vs picker
      --   cyan500   60.4   34.7   187    6.19:1          38.8
      --   cyan700   37.7   21.8   202    2.75:1          15.7   <- live
      --   cyan900   21.8   14.5   202    1.56:1           5.4
      --   base02    19.9   15.4   227    1.47:1           0.0   (the picker)
      --
      -- Two rungs were tried in the editor and rejected BY EYE, in this order:
      -- `cyan500` at 6.19:1 read as a drawn line competing with the text rather
      -- than as chrome, and `cyan900` -- which does match the picker's weight,
      -- dE00 5.4 -- came out too faint to find on a float that, unlike the
      -- picker, has no backdrop dim behind it. `cyan700` settled it.
      --
      -- So the ring deliberately sits ABOVE the picker now (2.75:1 vs 1.47:1).
      -- That is not drift: the picker is a full panel the eye is already aimed
      -- at, a hover popup is not.
      --
      -- STOP RULE: the ramp is exhausted in both directions. `cyan950`
      -- (1.15:1) is below the point the ring resolves at all, `cyan500` is the
      -- rejected loud end, and the yellow is not coming back. Anything further
      -- needs a NEW measured value, not another guess off this ladder.
      --
      -- NOT every border follows, on purpose: `SnacksPickerBorder` is its own
      -- definition and oil links both of its rings to that, so the picker, the
      -- oil popup and the oil startup box are untouched.
      -- `BlinkCmpDocBorder`/`BlinkCmpMenuBorder` are also self-defined.
      --
      -- Border STYLE needed no change -- `rounded` on both sides already. The
      -- snacks picker's `border = true` resolves to `rounded` because
      -- `winborder` is unset, and the hover float asks for `rounded` directly
      -- in `config/options.lua` and `plugins/lsp.lua`.
      hl.FloatBorder = { fg = c.cyan700, bg = c.bg_float }
      -- A link, so the hover ring can never drift from every other popup's.
      hl.LspDocBorder = "FloatBorder"
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
