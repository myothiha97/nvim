; extends

; Logical operators onto the keyword colour. Full reasoning lives in
; after/queries/typescript/highlights.scm -- keep the three ecma files in sync,
; and see the note there on why each language gets its own file instead of one
; shared `ecma` one.
;
; The unary_expression scoping is redundant in plain JavaScript, which has no
; non-null assertion, but it is kept identical to the TypeScript file so the
; three do not drift.
[
  "&&"
  "||"
  "??"
] @keyword.operator

(unary_expression
  "!" @keyword.operator)
