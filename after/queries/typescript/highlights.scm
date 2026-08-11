; extends

; Logical operators are keywords spelled as symbols. The base ecma query files
; them under @operator next to `=`, `+` and `=>`, which the theme paints neutral
; on purpose (see `hl.Operator` in lua/colorschemes/solarized-osaka.lua). This
; lifts ONLY the logical ones onto @keyword.operator, the capture that file
; already paints with the keyword colour for Python's and/or/not -- so `!x` in
; TypeScript reads the same as `not x` in Python.
;
; Compound assignment (`&&=`, `||=`, `??=`) and comparison (`===`, `!==`) are
; separate tokens in the grammar and are deliberately not listed: they are not
; logical operators, and they stay neutral with `=` and `+`.
[
  "&&"
  "||"
  "??"
] @keyword.operator

; Scoped to unary_expression on purpose. The non-null assertion `foo!.bar`
; parses as (non_null_expression "!") -- a type assertion rather than a
; negation -- so a bare "!" here would colour it too. Verified by parsing both
; forms; see notes/syntax-palette-decisions.md.
(unary_expression
  "!" @keyword.operator)
