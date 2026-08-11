; extends

; Logical operators onto the keyword colour. Full reasoning, and why the "!"
; rule is scoped rather than bare, lives in
; after/queries/typescript/highlights.scm -- keep the three ecma files in sync.
;
; Repeated here rather than inherited from typescript or ecma because of query
; precedence: an inherited file is concatenated BEFORE this language's own base
; query, while an `; extends` file named for the language being edited is
; concatenated last and therefore wins. tsx has no operator patterns of its own
; today, but this does not depend on that staying true.
[
  "&&"
  "||"
  "??"
] @keyword.operator

(unary_expression
  "!" @keyword.operator)
