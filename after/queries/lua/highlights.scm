; extends

; Table KEYS, normalised onto one capture -- same problem and same fix as
; after/queries/typescript/highlights.scm, which carries the full reasoning.
;
; Lua's base query files a bare key as @property and a bracketed string key as
; @string, so `{ bare = 1, ["quoted"] = 2 }` showed its two keys in two colours.
;
; `dot_index_expression` is deliberately untouched: `t.bare` is member ACCESS and
; keeps @variable.member, so it stays on the member colour.
(field
  name: (identifier) @variable.member.key)

; WARN: SILENT FAILURE (notes/silent-failure-surfaces.md, surface 19).
; `name:` is load-bearing. Without it this matched EVERY string in a field,
; values included, so `desc = "Open file"` and positional `{ "folke/x" }` were
; painted as keys. Invisible while keys linked to @string; exposed on 2026-09-24
; when keys moved to the member colour.
(field
  name: (string) @variable.member.key)
