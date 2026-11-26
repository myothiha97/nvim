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

; Object-literal and type-literal KEYS, normalised onto one capture.
;
; The base ecma queries file a BARE key as @variable.member and a QUOTED key as
; @string, so `{ Cash: 1, 'Credit Card': 2 }` rendered its two keys in two
; different colours for no reason but the quoting. Both are keys.
;
; This deliberately does NOT touch @variable.member itself: member ACCESS
; (`obj.attr.deep`) and class fields keep that capture and stay on the member
; colour. Only the key position is re-captured, which is why it needs a query
; rather than a highlight override -- the base grammar gives both the same name.
;
; Keep the three ecma files in sync (typescript / tsx / javascript); see the note
; above on why each language needs its own copy rather than inheriting.
(pair
  key: (property_identifier) @variable.member.key)

(pair
  key: (string) @variable.member.key)

(shorthand_property_identifier) @variable.member.key

(property_signature
  name: (property_identifier) @variable.member.key)

(property_signature
  name: (string) @variable.member.key)

; PascalCase IS NOT A TYPE. The ecma queries capture every capitalised bare
; identifier as @type (`#lua-match? "^[A-Z]"`), so an imported component and a
; plain reference to one rendered in the type colour: `import { ReportMenuCard }`
; and `export default ReportMenu` both read as types when neither is one.
;
; Only the two bare-identifier positions are re-captured. Real types are
; (type_identifier) nodes, not (identifier), so `type CardProps` and `: Plan`
; keep the type colour untouched. JSX usage keeps @tag, and `const Foo = () =>`
; is already caught as @function by the base queries.
;
; Keep the three ecma files in sync (typescript / tsx / javascript); see the note
; at the top of this file on why each language needs its own copy.
(import_specifier
  name: (identifier) @variable)

(export_statement
  value: (identifier) @variable)

; `import type { Plan }` really is a type import, so put it back. Later patterns
; win, which is why this follows the rule above rather than trying to exclude it.
; TypeScript only: the javascript grammar has no `import type`, and naming the
; anonymous "type" token there is a query parse error, not a no-op.
(import_statement
  "type"
  (import_clause
    (named_imports
      (import_specifier
        name: (identifier) @type))))

; The optional marker `?` in `name?: T`, `(v?: T)` and `[T?]` reads as one `?:`
; delimiter with its colon. The base typescript query files it under
; @punctuation.special, which the theme paints in the escape yellow meant for
; template `${}`, so it stood out as a lone yellow mark. Moved onto the colon's
; @punctuation.delimiter. The definite-assignment `!` stays where it is.
(property_signature
  "?" @punctuation.delimiter)

(optional_parameter
  "?" @punctuation.delimiter)

(method_signature
  "?" @punctuation.delimiter)

(abstract_method_signature
  "?" @punctuation.delimiter)

(method_definition
  "?" @punctuation.delimiter)

(public_field_definition
  "?" @punctuation.delimiter)

(optional_type
  "?" @punctuation.delimiter)
