; extends

; Logical operators onto the keyword colour, same rule and reasoning as
; after/queries/typescript/highlights.scm.
;
; A bare "!" is safe here where it is not in TypeScript: Go has no non-null
; assertion, `!=` is a single token, and `&&=`/`||=` do not exist in the
; grammar. Matching bare anonymous nodes is also how go/highlights.scm captures
; these tokens itself.
[
  "&&"
  "||"
  "!"
] @keyword.operator
