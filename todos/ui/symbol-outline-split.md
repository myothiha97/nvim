# Split the symbol outline into per-language modules

Status: **open** (LOW). Added 2026-09-23.

## Why

`lua/plugins/trouble.lua` is ~500 lines, and most of it is the outline
(`symbols` mode): level filter, folding, formatters and JS/TS role detection
all in one spec file. Future Go, Python or Rust rules would pile into the same
file.

Today only JS/TS needs language rules: vtsls reports arrow functions, hooks,
components and `type` aliases as `Variable`, and effects as
`useEffect() callback`. gopls and basedpyright already report callables as
`Function`/`Method`, so they need nothing yet.

## When

At the **first real need** for a second language's rules, or at the
2026-12-31 checkpoint (moved from 2026-10-20). Not before: on its own it is a move with no behaviour
change.

## Layout

```
lua/config/symbol-outline/
  init.lua    -- levels, filter core, folding, formatters (shared)
  js.lua      -- current JS/TS role detection, hooks, effect callbacks
  go.lua      -- only when Go needs rules
  python.lua  -- only when needed
lua/plugins/trouble.lua  -- spec only: requires config.symbol-outline
```

Each language module exposes the same small interface, for example:

- `keep(item, ctx)`: extra top-level keep rule (return nil to defer to the core)
- `kind(item)`: the kind to render the icon as
- `label(item)`: the row label

The core picks the module by filetype, so adding a language means one new file
and no core edits.

## Traps to keep

- Keep the filetype and line caches in the core, shared by every module (the
  filetype lookup was 92% of the formatter cost before it was cached).
- `trouble.lua` must stay the ONLY spec fragment defining `opts` for
  `folke/trouble.nvim` (lazy.nvim keeps the last fragment's value).
- Verify on a real `.tsx` file after the move: effect rows, hook labels,
  arrow-function icons, `a` level cycling, fold-to-declarations.
