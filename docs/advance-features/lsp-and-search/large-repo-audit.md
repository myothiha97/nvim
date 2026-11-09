# Neovim large-repo audit: LSP, completion, structure, search, file browsers

Date: 2026-11-08

## Summary

The config is already well tuned for big repos: lazy loading, no semantic tokens, open-files-only Python checking, a capped tsserver heap and size guards on folding. I found one real Go bug that gets worse the bigger the project is, one data-loss bug, and a handful of gaps where Neovim does less than GoLand or VS Code. Nothing was changed; every item below is a proposal.

| # | Priority | Area | Finding | Proposed fix (size) |
|---|---|---|---|---|
| 1 | High | Go LSP | Jumping into a dependency or the standard library (`gd` on `http.Get`, any `github.com/...` symbol) starts a **new gopls process** for that module | Reuse the running gopls for files under GOMODCACHE/GOROOT, as stock lspconfig does (~10 lines in lsp.lua) |
| 2 | High | LSP | `<leader>cL` (Restart LSP) runs `:edit!`, which **throws away unsaved changes** in the current buffer | Use Neovim 0.12's built-in `:lsp restart` (1 line) |
| 3 | Medium | Symbols | `<leader>ss` hides Go **structs**, constants and fields | Add `Struct`, `Constant`, `Field` to its filter (3 words) |
| 4 | Medium | Structure view | Aerial on Go shows only funcs, methods, structs, interfaces; misses named types (`type Status int`), const/iota enums, vars | Use the LSP backend first for Go only (1 line) |
| 5 | Medium | Go format on save | `goimports` runs as a cold process each save; in a big module graph it can hit conform's 3s timeout and save unformatted | Measure on a real repo first; if slow, let gopls organise imports |
| 6 | Medium | Inspection | No golangci-lint and no ESLint in the editor, so team lint rules only show up in CI | Optional, per project, on save only |
| 7 | Low | Go LSP | `directoryFilters = -node_modules` only skips the top level; a Go+frontend monorepo still gets `web/node_modules` scanned | Change to `-**/node_modules` (1 line) |
| 8 | Low | TS | `synchronousWatchDirectory = true` makes tsserver handle every file event immediately; a branch switch touching thousands of files means a CPU spike | Remove that one key (VS Code default) |
| 9 | Low | Search / explorer | Vendor dirs, generated code and big monorepos: no project-level exclude, and `git status` cost grows with repo size | No config change: per-repo `.ignore` file and git's fsmonitor |

Items 1 and 2 are bugs, so they pass rules.md rule 2 (blocking or degrading the workflow) during the freeze. Items 3 to 9 are improvements; you decide whether they wait for the 2026-12-31 checkpoint.

## Go (gopls)

**1. A new gopls process per dependency module (High).** Your `gopls.root_dir` in `lua/plugins/lsp.lua` roots on the nearest `go.work`/`go.mod`. That was done to keep loose `.go` files from rooting at `~/.git`, which is right. But a file inside the module cache (`~/go/pkg/mod/github.com/x/y@v1.2.3/...`) has its own `go.mod`, and so does `$GOROOT/src` (the standard library). Neovim 0.12 reuses a client only when the new root is already one of its workspace folders (`reuse_client_default` in `runtime/lua/vim/lsp.lua`), so each of those jumps starts another full gopls. Opening `$GOROOT/src` as a workspace makes gopls load the whole standard library.

- What you see: memory climbs after a few `gd` jumps into libraries; `:checkhealth vim.lsp` lists several gopls clients; workspace symbol search and references differ depending on which buffer you're in.
- Stock lspconfig avoids this: it reads `go env GOMODCACHE` and `GOROOT` once and, for files under them, returns the root of the gopls that is already running. Your override dropped that.
- Fix: keep your `$HOME` guard and add the same reuse. One async `go env` call per session, cached; nothing on a hot path.

`go.work` itself is fine. In 0.12 a flat marker list is checked in priority order, so `go.work` beats a nearer `go.mod` (`vim.fs.root` docs, `runtime/lua/vim/fs.lua`).

**5. goimports on save (Medium, measure first).** You don't override Go in conform, so LazyVim's `goimports` then `gofumpt` runs on every save. goimports is a separate process with no cache. When an import is missing, it scans the module graph, and on a big repo that can take seconds. LazyVim's format-on-save timeout is 3s; past that, the file saves unformatted. gopls already has the package index warm and already formats with gofumpt (`gofumpt = true` in the extra). VS Code Go uses gopls for both. Test: on your biggest repo, delete an import, save, and time it. If it's under 1s, leave it alone.

**7. directoryFilters (Low).** The extra sets `-node_modules`, which gopls matches only at the workspace root. `-**/node_modules` skips it at any depth.

**Build tags (gap, per project).** Files behind `//go:build integration` (or any tag) get "No packages found" and no LSP at all. GoLand prompts for this. The fix is per repo (`gopls.buildFlags = {"-tags=integration"}`), so it fits a project-local `.nvim.lua` with `exrc`. That's only worth doing if your work repos use tags.

**staticcheck (watch item).** `staticcheck = true` from the LazyVim extra is the closest thing to GoLand inspections, so keep it. If gopls CPU is ever the bottleneck on a very large repo, this is the first setting to turn off.

## Node/TS and Python

**TypeScript (vtsls).** This holds up for monorepos. The stock root is the lockfile root, so a pnpm/yarn workspace gets one tsserver that handles every `tsconfig` in it. The heap cap is 3072 MB, the same as VS Code's default. node_modules is excluded from watching, and LazyVim's server-side fuzzy matching is on.

- **8. `synchronousWatchDirectory = true` (Low).** This tells tsserver to process directory events without batching them. On a `git checkout` touching thousands of files, that means a CPU spike and laggy completion for a few seconds. VS Code leaves it off. Fix: delete that one key.
- **`includePackageJsonAutoImports = "off"` (trade-off, keep).** It's fast, but auto-import won't suggest a dependency until some file already imports it. VS Code suggests it right away. This is a deliberate perf choice.
- **ESLint disabled (gap, see Inspection).** The comment says "TypeScript alone is sufficient for current project". On team projects, ESLint rules (hooks rules, import order, no-floating-promises) only show up in CI.

**Python (basedpyright + ruff).** These are sound. Your root_dir guards against `$HOME`, `diagnosticMode = openFilesOnly` keeps big repos cheap, and ruff covers lint.

- Trade-off to know: workspace diagnostics (`<leader>xD`) only list files you have open, unlike PyCharm's whole-project inspection.
- To check on a real project: imports resolve only when basedpyright finds the right virtualenv. If you see "Import could not be resolved" on installed packages, pick the env with `<leader>cv` (venv-selector from the LazyVim extra), or set `venvPath`/`venv` in `pyproject.toml`. I couldn't confirm basedpyright's auto-detection of `.venv` from source, so test it once.

## Completion, diagnostics, inspection

**Completion (blink.cmp) is fine for large repos.** LSP and snippets are scored at +100, the list is capped at 25, buffer words only kick in after 3 characters and stop at 10 items, and docs open only on request. blink's buffer source goes async past 20k characters and skips huge buffers, so big generated files don't stall typing. I found no change worth making here.

- One gap vs IDEs: signature help doesn't pop up automatically when you type `(` or `,`; it's manual on `<M-i>`. blink can show it on those trigger characters (`signature.enabled`), one LSP request per trigger. That's optional and changes behaviour, so it's your call.

**2. `<leader>cL` Restart LSP loses work (High).** It stops every client, including Copilot, then runs `:edit!`, which reloads the file from disk and discards unsaved edits without asking. Other buffers stay detached until you re-enter them. Neovim 0.12 ships `:lsp restart`, which restarts the clients in place and keeps the buffer.

**Diagnostics.** Errors-only virtual text, no updates in insert mode, and severity sort is a good setup at any scale.

**6. Lint rules in the editor (Medium, optional).**

- Go: gopls with staticcheck covers most of what GoLand flags. Repos with a `.golangci.yml` enforce more in CI (errcheck config, gosec, revive). nvim-lint is disabled in performance.lua. If you want it back, run it for Go on `BufWritePost` only: async, no keystroke cost, roughly 1 to 5s per package in the background.
- TS: lspconfig's eslint root requires an ESLint config file, so enabling it costs nothing in repos without one. Your `run = "onSave"` setting is already there. It also needs `eslint-lsp` removed from the Mason exclude list in formatting.lua.

**Kept on purpose, still worth knowing:** semantic tokens off (no semantic colouring of unused vars, packages vs locals) and inlay hints off. Both are deliberate perf choices, and both are why typing stays fast on big files.

## Structure view and symbol search

**4. Aerial on Go misses part of the file (Medium).** You set `backends = { "treesitter", "lsp", ... }`, so Go uses aerial's treesitter query. That query only tags Function, Method, Struct and Interface (`queries/go/aerial.scm`). Named non-struct types (`type Status int`, `type HandlerFunc func(...)`), `const ( ... iota )` enums and package vars never appear. GoLand's structure view shows all of them, and gopls's documentSymbol returns them too, with fields nested under their struct.

- Fix: per-filetype backends, `go = { "lsp", "treesitter" }`, and leave TS/JS on treesitter so your React hook/component query keeps working. Cost: aerial waits for gopls on first open (it falls back to treesitter until then) and re-asks gopls about 300 ms after edits, which is a cheap request. It only runs while the panel is open, thanks to your on-demand start/stop.
- Known limit: aerial turns itself off above 10,000 lines or 2 MB (its defaults), so huge generated files (`*.pb.go`) get no outline. I'd keep that.

**3. `<leader>ss` hides Go structs (Medium).** Your `lsp_symbols` filter replaces snacks' default list; lists aren't merged (`Snacks.config.merge` only merges dict tables). The `default` list you pass has no `Struct`, so in a Go file every `type Foo struct` is filtered out, along with constants and fields. Fix: add `"Struct"`, `"Constant"` (and `"Field"` if you want struct fields) to `default`. React note: arrow-function components (`const Foo = () =>`) come back from tsserver as Variable/Constant, so they're hidden by the same filter. Aerial's React query is the better tool there anyway.

**Workspace symbols (`<leader>sS`)** use LazyVim's kind filter, which includes Struct. Constants are excluded, so searching for `StatusActive` won't find it; grep will. After fix 1, workspace symbols search the whole workspace consistently.

## Search (snacks picker)

**Files and grep scale well as configured.** They use fd and ripgrep, respect `.gitignore`, skip hidden files by default, and grep is live with regex on. Nothing here does per-keystroke work in Lua beyond snacks' own matcher.

- Toggles you already have inside the picker: `<a-h>` hidden, `<a-i>` gitignored, `<a-r>` regex vs literal.
- Filtering by path or type: type ripgrep flags after `--` in the grep prompt, e.g. `HandleOrder -- -g *.go -g !*_test.go`. That covers most of GoLand's "Find in Path" scope and mask options.
- `<leader>/` (LazyVim) greps from the LSP root of the current buffer. Today, in a library file opened via `gd`, that root is the dependency module (finding 1), so the grep searches the wrong tree. Fix 1 makes it consistent.

**9. Committed vendor and generated code (Low, no config change).** Repos that commit `vendor/`, `*.pb.go`, mocks or `dist/` flood file and grep results, because those files aren't gitignored. Both fd and rg read a `.ignore` file in the repo root (same syntax as `.gitignore`, and listing `.ignore` in your global gitignore keeps it out of the team repo). Put one in each such repo instead of adding excludes to the config, and `<a-i>` still reaches them when you need to. This matches IDE "excluded folders", per project.

**Gaps vs IDEs, accepted:** no search-and-replace preview inside the picker (you have grug-far and spectre for that), and no indexed full-text search, so every grep re-reads files. ripgrep is fast enough for multi-GB repos on an SSD.

## Snacks explorer and oil.nvim

**Both are safe on big repos as configured.** Neither walks the whole tree. They read one directory at a time, when you open it.

**Snacks explorer (`<leader>r`).**

- Directories are read only when expanded, and gitignored files (node_modules, build output) stay hidden until `I`. It watches only the expanded folders plus `.git/index`.
- Git colours come from one async `git status --porcelain --ignored=matching -unormal` over the whole repo. It runs on open and whenever the git index changes, with a 15-minute cache otherwise. It never blocks the editor, but on a very large repo (100k+ files) colours can show up a second or two late. The fix is git-side, not in Neovim: `git config core.fsmonitor true` and `git config core.untrackedCache true` in that repo. That also speeds up gitsigns, lazygit and the shell prompt.
- Gap: `/` in the explorer is mapped to Vim search, but the picker list is virtually scrolled; your own comment in snacks.lua says its buffer only holds the rows on screen. So `/` can only find names that are visible right now. To locate a file in a deep tree, use `<leader>ff`; the explorer's `follow_file` (on by default) then reveals it when you open it. GoLand's type-to-search on a collapsed tree has no equivalent here.

**oil.nvim (`<leader>e`).** It reads a directory async and renders only that directory, with no git status column and no watchers, so cost doesn't grow with repo size. Thousands of entries (a `node_modules` root) render fine.

- Renaming or moving a file in oil asks LSPs to update imports (`willRenameFiles`). vtsls supports this; gopls doesn't, so in Go only the file moves. Oil waits up to 1s for the LSP by default. On a large TS project, check once that imports actually update after a rename. If not, `lsp_file_methods.timeout_ms` is the knob.
- Safety, optional: `delete_to_trash = true` would make `dd` + `:w` recoverable from the macOS Trash. Today oil deletes permanently, after its confirm prompt.

## Already solid, and how this was checked

**Already right for production scale, so leave these alone:** gopls/basedpyright/ruff root guards against `~/.git`; semantic tokens and document colour off; 200 ms didChange debounce; aerial and its breadcrumb start only on demand; ufo falls back to indent folds above 200 KB; snacks words/indent/scope off; the Trouble breadcrumb off in lualine; tsserver heap capped and node_modules unwatched; the custom `gd` that skips node_modules and import lines.

**Method.** I read your config on branch `main` from your Mac (the checkout is on `feat/test-runner`, whose diff in these files is colours only). I checked each claim against the plugin source at the exact commits in your `lazy-lock.json`: LazyVim, nvim-lspconfig, snacks.nvim, blink.cmp and aerial.nvim, plus Neovim v0.12.0's `vim.fs.root` and LSP client-reuse code.

**Not verified by running.** I couldn't run Neovim or gopls here; installing them in my sandbox was blocked. Finding 1 follows from Neovim's documented client-reuse rule plus the presence of `go.mod` in module-cache and `$GOROOT/src` directories. You can confirm it in 30 seconds: open a Go file, `gd` into `http.Get`, then `:checkhealth vim.lsp` and count the gopls clients. Before any fix ships, I'd verify headless on your machine as usual.

**Next step, your call:** approve any subset by number. Each would go on its own branch and PR, verified headless, with /perf-review run first.
