; extends

; Copy of after/queries/typescript/aerial.scm (reasoning lives there). tsx has
; its own full base query instead of inheriting typescript, so this cannot
; inherit either. Keep the two files identical below this header.

; const [count, setCount] = useState(0) / const { data } = useQuery()
; The base query only captures plain identifier names.
(lexical_declaration
  (variable_declarator
    name: [
      (array_pattern)
      (object_pattern)
    ] @name
    value: (call_expression) @var_type) @symbol
  (#set! "kind" "Variable")) @start

; useEffect(() => {}) / useDocumentTitle("x"): a hook called only for its effect
; has no variable to stand for it, so the call itself is the row.
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
; Only an object assigned straight to a variable, so the callbacks in
; useQuery({ queryFn: () => {} }) and friends do not flood the list. The
; shorthand `get() {}` is already a method_definition in the base query.
(variable_declarator
  value: (object
    (pair
      key: (property_identifier) @name
      value: [
        (arrow_function)
        (function_expression)
      ]) @symbol)
  (#set! "kind" "Method"))

; const api = { ... } as const
(variable_declarator
  value: (as_expression
    (object
      (pair
        key: (property_identifier) @name
        value: [
          (arrow_function)
          (function_expression)
        ]) @symbol))
  (#set! "kind" "Method"))

; const api = { ... } satisfies Api
(variable_declarator
  value: (satisfies_expression
    (object
      (pair
        key: (property_identifier) @name
        value: [
          (arrow_function)
          (function_expression)
        ]) @symbol))
  (#set! "kind" "Method"))

; service.start = () => {} / module.exports.helper = function () {}
(expression_statement
  (assignment_expression
    left: (member_expression) @name
    right: [
      (arrow_function)
      (function_expression)
    ]) @symbol
  (#set! "kind" "Method"))
