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

; Optional marker `?` onto the delimiter grey. Reasoning lives in
; after/queries/typescript/highlights.scm; repeated here for the same
; precedence reason as the operators above.
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
