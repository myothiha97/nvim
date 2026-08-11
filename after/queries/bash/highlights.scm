; extends

; Logical operators onto the keyword colour, same rule and reasoning as
; after/queries/typescript/highlights.scm.

; `&&` and `||` are control flow in every bash context -- between commands they
; parse under (list), inside `[[ ]]` under (binary_expression) -- so a bare
; match is correct for both.
[
  "&&"
  "||"
] @keyword.operator

; "!" must NOT be matched bare here. It parses three ways and only two of them
; are negation:
;   [[ ! -f x ]] / (( ! x ))  ->  (unary_expression operator: "!")   negation
;   ! grep -q foo file        ->  (negated_command "!")              negation
;   ${!ref} / ${!arr[@]}      ->  (expansion operator: "!")          INDIRECTION
; The third is the variable-indirection sigil, not a logical operator. It is
; already captured as @punctuation.special by the base query, and leaving it
; there keeps it grouped with the rest of `${...}`. `!=` is a single token and
; is unaffected either way.
(unary_expression
  operator: "!" @keyword.operator)

(negated_command
  "!" @keyword.operator)
