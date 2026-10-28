; extends

; Extra aerial symbols for React and object-style code. Full reasoning and the
; silent-failure traps live in after/queries/typescript/aerial.scm; keep the
; three ecma files in sync. Classification happens in post_parse_symbol in
; lua/plugins/aerial.lua.
;
; Unlike typescript, the base javascript query only captures variables whose
; value is a function, so calls and object literals need their own pattern here.
; There is no as/satisfies in javascript: naming those nodes would break the
; whole query.

; const total = useMemo(...) / const Card = memo(...) / const [a, setA] = useState()
; const api = { get: () => {} }
(lexical_declaration
  (variable_declarator
    name: [
      (identifier)
      (array_pattern)
      (object_pattern)
    ] @name
    value: [
      (call_expression)
      (object)
    ] @var_type) @symbol
  (#set! "kind" "Variable")) @start

; useEffect(() => {}) / useDocumentTitle("x")
(expression_statement
  (call_expression
    function: (identifier) @name
    (#lua-match? @name "^use%u")) @symbol
  (#set! "kind" "Function"))

; React.useEffect(() => {})
(expression_statement
  (call_expression
    function: (member_expression
      property: (property_identifier) @name)
    (#lua-match? @name "^use%u")) @symbol
  (#set! "kind" "Function"))

; const api = { get: () => {}, post: function () {} }
(variable_declarator
  value: (object
    (pair
      key: (property_identifier) @name
      value: [
        (arrow_function)
        (function_expression)
      ]) @symbol)
  (#set! "kind" "Method"))

; service.start = () => {} / module.exports.helper = function () {}
; The base query's `X.prototype.y = function` pattern matches the same node
; first; aerial skips the second match of a node, so it is not listed twice.
(expression_statement
  (assignment_expression
    left: (member_expression) @name
    right: [
      (arrow_function)
      (function_expression)
    ]) @symbol
  (#set! "kind" "Method"))
