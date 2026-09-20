# Treesitter Outline: Locals Inside Functions

> **Priority: LOW.** Nothing is blocked. The outline works for what language servers
> report. This file is only about the one thing they refuse to report: symbols declared
> *inside* a function body, in Go specifically.
>
> Raised 2026-09-20 while comparing the outline against WebStorm's Structure pane.

## Goal

Expand a Go function in the outline (`<leader>cs`) and see what it declares:

```go
func main() {
	r := gin.Default()                       // want: r
	r.GET("/ping", func(c *gin.Context) {    // want: the closure
		c.JSON(http.StatusOK, gin.H{...})
	})
	port := os.Getenv("PORT")                // want: port
	if err := r.Run(":" + port); err != nil { // want: err
		log.Fatal(err)
	}
}
```

Today that function expands to nothing.

## Why the current outline cannot do this

`lua/plugins/trouble.lua` is driven by `textDocument/documentSymbol`. The filter only
decides what to *keep*, so it can never add a symbol the server never sent.

**Measured 2026-09-20**, not assumed. A probe file containing a method with `total`,
`entry`, an `apply := func(...)` closure, a `for` loop, plus a function with `l`,
`localConst` and `localVar`, produced exactly this from gopls:

```
Struct       Ledger            detail=struct{...}
  Field      Name              detail=string
Method       (*Ledger).Post    detail=func(amount int64) error
Function     Run               detail=func()
```

Four symbols. Zero function-body locals, zero closures. gopls reports package-level
declarations and struct fields / interface methods, and stops there.

For contrast, vtsls **does** descend into bodies, which is why expanding a TypeScript
function or React component already works:

```
Variable     getUser
  Variable   svc
Function     registerRoutes
  Function   app.get('/users') callback
```

So this is a per-server limit, not a bug in the config. `zR` on a Go buffer proves it in
one keystroke.

## Rejected: go.nvim

Checked 2026-09-20 because it looked like the obvious answer. `ray-x/go.nvim` ships
`GoPkgOutline` and `GoPkgSymbols`, but both are **package-level and gopls-backed**: same
data source, same ceiling. It is a Go *workflow* plugin (tests, coverage, struct filling,
struct tags, `GoImpl`, dap glue). Worth considering on its own merits some day, in
`languages/`, not here. It does not solve this.

## Shape of the real fix

Build the outline from treesitter instead of LSP, for Go only, and merge it into the
existing panel rather than replacing it.

- trouble.nvim supports custom sources. A source returns `trouble.Item`s carrying `buf`,
  `pos`, `end_pos`, `kind` and a `symbol`-shaped table, and `item:add_child()` builds the
  nesting the fold logic already relies on.
- The query is the real work. For Go: `short_var_declaration`, `var_declaration`,
  `const_declaration`, `func_literal`, plus the existing top-level captures so the two
  halves do not fight. Naming is the hard part: `r := gin.Default()` should read as `r`,
  but the closure in `r.GET("/ping", func(...))` has no name and wants to read as its call
  site, the same problem already solved for React hooks in `js_variable_role`.
- Keep it behind the existing detail levels so level 1 stays a clean declaration list.

Rough cost: half a day, most of it in the query and in deciding what a nameless node is
called. Verify the same way this pane was verified: render it headlessly and diff the
panel text, not by eyeballing it once.

## Open question before starting

**Is this actually worth having?** GoLand's own Structure view does not list function
locals either. WebStorm shows them for JS/TS because they are top-level declarations
inside a component, which is a different case, and that case already works here.

A file where `main()` is long enough that its locals need an index is usually a file that
wants splitting, not a better outline. If the real need is *navigation* inside a long Go
function, flash.nvim and treesitter motions already cover it at lower cost.

Do not start this without answering that question first.

## Already shipped (2026-09-20, do not redo)

The following landed in `lua/plugins/trouble.lua` in the same session and are verified by
a headless render of the panel:

- Panel opens as a flat list of top-level declarations, expandable with `za` / `zR`.
  `win.wo.foldlevel` does **not** work for this; see `fold_to_declarations` for why.
- Filtering applies to the top level only, so a kept declaration keeps its whole subtree.
- vtsls placeholder callables (`<function>`, `map() callback`) dropped at levels 1 and 2.
- JS/TS arrow functions and hooks rescued from kind `Variable`; hook rows are labeled by
  the hook, `useRecurringCheckout  checkout`.
- Component detection no longer matches `SCREAMING_CASE` constants.
