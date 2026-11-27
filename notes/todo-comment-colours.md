# Todo-comment tag colours

Decided 2026-11-27. The goal: no tag colour may collide with the function blue.
Code: `lua/plugins/todo-comments.lua` (`colors` table at the top).

## How to read the numbers

- **Contrast** is against `#141514`, the background measured from a full-resolution
  screenshot (`palette.py screenshot`). The theme is transparent, so this is the
  terminal's background, not a value nvim sets. On that capture royal arrived as
  `#4f80e7` (external monitor, not Display P3).
- **dE** is CIEDE2000 against every live code colour and every other tag colour.
  Below about 10 reads as "the same colour" at a glance.
- All values were measured against the LIVE groups (`nvim_get_hl` in a headless
  run), not the palette table in `CLAUDE.md`, which was stale on that day.

Live groups measured against:

| role | value |
| --- | --- |
| body / `@variable` | `#b1bebf` |
| comment | `#7d7b77` |
| function / `@property` / `Identifier` / tag attribute | `#61afef` |
| string | `#9ece6a` |
| type | `#e5c07b` |
| keyword / tag | `#a17bcc` |
| boolean / number | `#ed8e55` |
| parameter | `#e06c75` |
| member | `#77c5b9` |
| operator | `#b98f79` |

## Final groups

| tags | plugin colour name | value | verdict |
| --- | --- | --- | --- |
| `todo`, `TODO` | `hint` | royal `#5a7fe0` (`todo_tag.royal`) | CHOSEN, 4.84:1, function 15.9, keyword 17.0 |
| `NOTE`, `Note`, `note` | `note` -> `DiagnosticHint` | teal `#29a298` | kept by choice |
| `PERF`, `REFACTOR`, `TEST` | `default`, `test` | rose `#e197a3` (`member.rose_soft`) | CHOSEN, 7.98:1, parameter 11.7 |
| `WARN`, `HACK` | `warning` | amber `#b28500` | plugin default, unchanged |
| `FIX`, `ISSUE` | `error` | red `#db302d` | plugin default, unchanged |

Before: personal `todo` used `info` (`#268bd3`, dE 11.5 from the function blue,
read as a function call). `PERF`, `REFACTOR` and `TEST` used `Identifier`, which
IS the function blue.

## Every value tried

| value | contrast | nearest (dE) | verdict |
| --- | --- | --- | --- |
| sage `#8bcb8a` | 9.60:1 | string 7.9 | REJECTED: blended into JSX class names. Picked first against the stale palette table, where strings were cyan |
| royal `#5a7fe0` | 4.84:1 | function 15.9, keyword 17.0 | CHOSEN for `todo` / `TODO` |
| periwinkle `#9aa5f0` | 7.86:1 | function 14.0, keyword 15.0 | fallback, drifts toward keyword violet |
| deep `#3d7fd6` | 4.54:1 | function 15.2 | rejected, lowest contrast |
| indigo `#6c7ee8` | 5.05:1 | keyword 13.7 | rejected |
| iris `#8d8de3` | 6.15:1 | keyword 9.7 | rejected, reads as keyword |
| info `#268bd3` | 4.98:1 | function 11.5 | the old value |
| sky `#7dcfff` | 10.67:1 | function 9.0 | rejected |
| azure `#1e90ff` | 5.66:1 | function 9.5 | rejected |
| cyan `#2ac3de` | 8.68:1 | member 14.0 | not chosen, not blue enough |
| rose_soft `#e197a3` | 7.98:1 | parameter 11.7 | CHOSEN for `PERF` / `REFACTOR` / `TEST` |
| tn_magenta `#bb9af7` | 7.91:1 | keyword 10.1 | fallback for rose |

## Trap

`TODO` and `todo` cannot both be keys: highlight group names ignore case, so they
share one group. See `notes/silent-failure-surfaces.md` #21.
