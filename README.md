<div align="center">

# Neovim PDE

**A personal development environment, written in Lua on top of [LazyVim](https://github.com/LazyVim/LazyVim).**

_Debugger, test runner, database client, structure view and AI next edits in one terminal editor.
Built to do the job of a full GUI IDE on large production codebases, and still start in ~50 ms._

`~50ms cold start` · `Go · TypeScript/Node · Python · C#` · `Neovim 0.12+` · `pinned plugins`

</div>

---

## Why a PDE, not a dotfile

This started as a LazyVim config. It has grown into roughly 22,000 lines of Lua
under `lua/`, including a ~3,000-line debugger GUI and ~2,500 lines of test
tooling, plus written rules, maintenance guides and design notes for every
non-obvious decision. LazyVim is the base layer and plugin manager; the IDE
layer on top is built here.

The target is IDE parity for professional work: the full
**edit → navigate → test → debug → inspect** loop that popular GUI IDEs
give you, without leaving the terminal and without giving up Neovim's
speed. Go comes first, TypeScript/Node second; Python and C# are supported.

### Why not just use an IDE?

Because the IDE features are added without giving up what makes Neovim worth
using: **it is still keyboard-driven at its core.** Every feature here (stepping
through a debugger, rerunning failed tests, browsing test history, opening the
structure view, querying a database, accepting an AI edit) has a key, and is
operated with the same modal editing, motions, text objects, registers and
macros as the code itself. Your hands never have to leave the keyboard.

Mouse support exists (clicking the gutter, right-click menus, double-click to
expand panels), but it is an optional layer on top, never the only way in.

What that buys over a GUI IDE:

- **One editing model everywhere.** Panels, pickers and file trees are buffers,
  so the motions you use for code also work in the debugger, test results and
  file browser. No Vim-emulation plugin with gaps.
- **Speed.** ~50 ms to start, and nothing heavy runs until you use it.
- **Full ownership.** Every behaviour is Lua in this repo: readable, changeable,
  and documented where it is non-obvious, instead of a settings screen.
- **The terminal stays home.** It runs alongside tmux, shells and CLI agents,
  locally or over SSH.

---

## What's inside

### 🐞 Debugger: `lua/debugging/`

One debugging workflow for **Go** (Delve), **Node/JS/TS** (js-debug),
**Python** (debugpy) and **C#** (easy-dotnet, native arm64 netcoredbg), on
nvim-dap + nvim-dap-ui with a custom GUI:

- VS Code-style control bar: Continue/Pause · Step Over · Step Into · Step Out ·
  Restart · Stop, then Run Again with the exit code once the program ends.
- A stable layout: the console tray opens on start, Variables and Call Stack
  (goroutines) open on the first stop, and nothing moves after that.
- Click the gutter to toggle a breakpoint. Conditions, hit counts, log points
  and function breakpoints persist per project.
- Right-click menu chosen by state, value-on-hover while stopped, copy value,
  and adapter-driven completion in the debug REPL.
- Launch helpers: npm scripts and attach to `9229` (Node), `python -m` and
  Django `runserver` (Python), `launchSettings.json` profiles (.NET), and
  Debug Test from the test runner.

Reference: [`lua/debugging/README.md`](lua/debugging/README.md) ·
upkeep: [`lua/debugging/MAINTENANCE.md`](lua/debugging/MAINTENANCE.md)

### 🧪 Test runner and coverage: `lua/testing/`

neotest for **Go**, **Vitest**, **Jest**, **pytest** and **.NET**, extended with:

- Pass/fail marks at the end of the test line (no gutter signs).
- A JetBrains-style **Test Results panel**: newest run on top, failures with
  their got/want output, per-test durations, mouse support.
- Rerun failed, **test history** across sessions per project, and jump
  test ⇄ implementation.
- **Coverage** in the gutter, read from your runner's own report.
- **Project test settings**: env from `.env.test` / `.envrc`, the Jest/Vitest
  command from `package.json`, and `go test` flags from a Makefile, Taskfile or
  justfile, so tests run with the project's own setup.

Guide: [`docs/advance-features/testing/neotest-guide.md`](docs/advance-features/testing/neotest-guide.md)

### 🧠 Code intelligence

- LSP per language (see [Language Support](#language-support)), tuned for big
  repos: dependency files join the running gopls, `$HOME/.git` is never taken as
  a workspace root, edits are debounced at 200 ms, and tsserver's heap is capped.
- **blink.cmp** completion: LSP, local snippets, path and buffer, plus dadbod in
  SQL buffers and adapter completion in the debug REPL.
- Docs on mouse hover, inlay hints trimmed to parameter names, error-only inline
  diagnostics, and `<leader>cL` to restart LSP without losing unsaved edits.
- Format on save through **conform.nvim** (prettierd, goimports/gofumpt, shfmt).

### 🧭 Navigation, structure and search

- **Structure view** (`<leader>cs`): an aerial pane with JetBrains-style kind
  icons and colours, Go methods nested under their types, and React-aware rows
  in JSX/TSX. It runs only while the pane is open.
- **Snacks picker**: smart finder, files, grep and LSP symbols. **Snacks
  explorer** as a tree sidebar, and **oil.nvim** to rename, create and delete
  files by editing a buffer.
- **grug-far** for project search-and-replace, **Trouble** for quickfix views,
  quickfix marks that survive restarts, and treesitter textobjects.

### 🗄️ Database

vim-dadbod UI on `<leader>D`, with SQL completion in SQL buffers only. Nothing
loads until you open it.

### 🤖 AI in the editor

- **copilot.lua** ghost text and **copilot-lsp** next edit suggestions
  (`<Tab>` jumps to and applies multi-line edits).
- **cursortab**: Cursor-Tab-style next edits on hosted Mercury or a local
  Zeta-2.1 model.
- A **prompt-copy system** (`<leader>ac…`) that copies context-aware prompts
  (commit, codebase analysis, explain, refactor, review) for an external CLI agent.

All AI features are off until toggled and load on first use.

### 🔀 Git and editing

- gitsigns hunks, diffview and compact or full blame floats, plus `gn` / `gN`
  to jump between changed files.
- Markdown rendered in the buffer, async folding (nvim-ufo), multi-cursor,
  surround, and VSCode-format snippets.

---

## Engineering principles

One rule governs everything here: **nothing expensive runs on the hot path.**
A feature earns its place only if it costs effectively `0ms` per keystroke,
cursor move and redraw. The debugger, test runner, database UI and AI tools
load only when first used, so a session that never touches them pays nothing.

The rules are enforced, not just intended: plugin versions are pinned and
`:Lazy update/sync/restore` is blocked at the Lua level, every change is
reviewed for performance before it is committed, and known caveats are marked
in code comments where they live.

> See [`rules.md`](rules.md) for the discipline rules,
> [`notes/safe-config-editing-guide.md`](notes/safe-config-editing-guide.md) for
> the performance rules every change is held to, and
> [`docs/maintenance/config-maintenance-guide.md`](docs/maintenance/config-maintenance-guide.md)
> for keeping the whole thing healthy.

> **For Claude Code / AI agents:** read [`rules.md`](rules.md) **first**, before
> proposing or making any change, then [`docs/CLAUDE.md`](docs/CLAUDE.md). The
> config freeze is suspended while IDE-parity work continues (see the note in
> `rules.md`); the performance rules still apply.

---

## Under the hood

| Category         | Plugin                                                                                                                                             |
| ---------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Completion**   | blink.cmp: LSP · local snippets · path · buffer (+ dadbod in SQL, adapter completion in the debug REPL)                                            |
| **AI**           | copilot.lua + copilot-lsp (NES) · cursortab.nvim (Mercury / Zeta-2.1) · prompt-copy system. CodeCompanion is installed but disabled.              |
| **Debugging**    | nvim-dap + nvim-dap-ui with a custom GUI in `lua/debugging/` · Delve · js-debug · debugpy · easy-dotnet (native arm64 netcoredbg)                   |
| **Testing**      | neotest (golang · vitest · jest · python · easy-dotnet) + custom panel, history and marks in `lua/testing/` · nvim-coverage                         |
| **Database**     | vim-dadbod · vim-dadbod-ui · vim-dadbod-completion                                                                                                 |
| **File nav**     | oil.nvim (`<leader>e`, owns netrw) · Snacks: picker · explorer (`<leader>r` sidebar) · dashboard · terminal                                         |
| **Code nav**     | aerial (structure view) · Snacks LSP symbol picker · Trouble (quickfix views) · treesitter textobjects                                             |
| **Git**          | gitsigns (hunks) + diffview.nvim + custom blame floats                                                                                             |
| **Search**       | grug-far: project/file search-replace and rename                                                                                                   |
| **Multi-cursor** | vim-visual-multi                                                                                                                                   |
| **Folding**      | nvim-ufo: treesitter + indent, async                                                                                                               |
| **Formatting**   | conform.nvim: prettierd for web/JSON/Markdown, goimports/gofumpt for Go, shfmt for shell, mbake for Makefiles                                      |
| **Markdown**     | render-markdown.nvim (`.md` files and LSP hovers) · Obsidian on `<leader>ui` · markdown-preview.nvim (`:MarkdownPreview`)                          |
| **UI**           | lualine · bufferline · noice (cmdline only) · fidget · which-key                                                                                   |
| **Theme**        | solarized-osaka, customized. `solarized-osaka-custom-latest` is the live build; see [Theme](#theme).                                              |

---

## Language Support

| Language           | Status       | Notes                                                                                                                       |
| ------------------ | ------------ | --------------------------------------------------------------------------------------------------------------------------- |
| TypeScript / React | Daily driver | `vtsls`, package JSON auto-imports off, tsserver heap cap `3072`; js-debug; Vitest and Jest tests                           |
| Go                 | Daily driver | `gopls`, `goimports`, `gofumpt`; Delve; neotest-golang; roots guarded to `go.mod` / `go.work`              |
| Python             | Enabled      | `basedpyright` + `ruff`, `openFilesOnly` diagnostics; debugpy; pytest; `venv-selector.nvim` lazy on Python                  |
| C# / .NET          | Enabled      | easy-dotnet.nvim: Roslyn LSP, build-then-debug with launch profiles, xUnit / NUnit / MSTest. Loads only in .NET buffers     |
| SQL                | Enabled      | dadbod completion in SQL buffers only                                                                                       |
| JSON               | Enabled      | LazyVim JSON extra + `prettierd`                                                                                            |
| YAML               | Enabled      | `yamlls`                                                                                                                    |
| Docker             | Enabled      | `dockerls`: `Dockerfile` / compose                                                                                          |
| Terraform          | Enabled      | `terraform-ls`                                                                                                              |
| Helm               | Enabled      | `helm-ls`: chart templates and `values.yaml`                                                                                |
| Shell              | Enabled      | `shfmt` formatting                                                                                                          |
| Rust               | Deferred     | Lazy extra is installed but filetype-gated; no runtime cost until opening Rust/Cargo files                                  |

Python and Go root detection intentionally avoids treating `$HOME/.git` as a
workspace. Loose files fall back to their own directory instead of making the
language server scan the whole home directory. Go stdlib and module-cache files
join the running gopls instead of starting a new one.

---

## Key Bindings

> Leader is `<Space>`. `<M-…>` keys are sent by the terminal (Ghostty) from the
> macOS Cmd/Option layer.

<details open>
<summary><b>Navigation &amp; search</b></summary>

| Key                         | Action                                                                    |
| --------------------------- | ------------------------------------------------------------------------- |
| `<leader><leader>`          | Smart finder (recent + buffers + files)                                   |
| `<leader>ff` · `<leader>fi` | Find files: root · current dir                                            |
| `<leader>fp`                | Switch project                                                            |
| `<leader>r`                 | Toggle Snacks explorer (tree sidebar)                                     |
| `<leader>e`                 | Oil file manager (centred popup; edit the buffer to rename/create/delete) |
| `<leader>E`                 | Same as `<leader>e`, kept for muscle memory                               |
| `<leader>sl`                | Grep within current file                                                  |
| `<leader>sf` · `<leader>sF` | Search & replace: project · current file                                  |
| `<leader>sr` · `<leader>sR` | Rename word under cursor: file · project                                  |
| `gd`                        | Goto definition (skips node_modules & re-imports)                         |
| `[f` · `]f`                 | Prev · next function                                                      |
| `<M-f>`                     | Highlight word under cursor                                               |

</details>

<details>
<summary><b>Code navigation: aerial, Trouble &amp; quickfix</b></summary>

| Key                         | Action                                                       |
| --------------------------- | ------------------------------------------------------------ |
| `<leader>cs`                | Symbols outline (aerial), opens collapsed                    |
| `l` · `s` (in the outline)  | Expand a row or jump to it · scroll the code to the symbol   |
| `<leader>ss`                | LSP symbol picker                                            |
| `<leader>uB`                | Toggle the aerial breadcrumb in the statusline (off)         |
| `<leader>cc` · `<leader>ce` | Quickfix · location list (Trouble)                           |
| `<leader>m`                 | Mark line/selection into quickfix (persists across restarts) |
| `<leader>cx`                | Clear quickfix list                                          |
| `<leader>bu`                | List unsaved buffers (jump / save)                           |
| `<leader>cd`                | Line diagnostics (focusable)                                 |
| `<leader>cL`                | Restart the buffer's LSP servers, keeps unsaved edits        |

</details>

> Workflow guide: [`notes/reading-codebases-with-neovim.md`](notes/reading-codebases-with-neovim.md)
> walks through navigating an unfamiliar codebase with these tools.

<details>
<summary><b>Editing</b></summary>

| Key                         | Action                                                      |
| --------------------------- | ----------------------------------------------------------- |
| `<Tab>`                     | Accept next edit → focus float → jumplist forward           |
| `<M-d>`                     | Add next occurrence (multi-cursor)                          |
| `<M-/>`                     | Toggle comment (line / selection)                           |
| `ys` · `ds` · `cs` · `s` (visual) | Surround                                              |
| `zm` · `zn`                 | Toggle all folds: keep current open · fold all              |
| `zR` · `zM` · `zv`          | Open all · close all · toggle function folds                |
| `<leader>uh` · `<leader>ui` | Markdown: raw ⇄ rendered · open in Obsidian                 |
| `<leader>uh`                | Inlay hints on / off (in any non-markdown buffer)           |
| `K` · `<M-i>`               | Hover docs · signature help                                 |

</details>

<details>
<summary><b>Testing &amp; coverage</b></summary>

| Key                           | Action                                                      |
| ----------------------------- | ----------------------------------------------------------- |
| `<leader>tr` · `<leader>tt`   | Run nearest test · run file                                 |
| `<leader>tT` · `<leader>tF`   | Run all · rerun failed                                      |
| `<leader>td`                  | Debug nearest test                                          |
| `<leader>ts` · `<leader>tO`   | Summary tree · Test Results panel                           |
| `<leader>to`                  | Show output                                                 |
| `<leader>tD`                  | Discover all project tests                                  |
| `<leader>th` · `<leader>tH`   | Test history: all runs · test at cursor                     |
| `<leader>tX`                  | Clear this project's test history                           |
| `<leader>tx`                  | Toggle test UI (marks and panels)                           |
| `<leader>tj`                  | Jump test ⇄ implementation                                  |
| `<leader>tcf` · `<leader>tca` | Coverage: run file · run all                                |
| `<leader>tcc` · `<leader>tcx` | Coverage: load and show report · clear                      |
| Right-click (test file)       | Run Test · Debug Test · Run File Tests · Show Test Output   |

</details>

<details>
<summary><b>Debugging</b></summary>

| Key                                       | Action                                                        |
| ----------------------------------------- | ------------------------------------------------------------- |
| `<leader>dc`                              | Start / continue                                              |
| `<leader>db` · click the gutter           | Toggle breakpoint (saved per project)                         |
| `<leader>dN` · `<leader>dH` · `<leader>dL` | Breakpoint condition · hit count · log point                 |
| `<leader>dd` · `<leader>dD`               | Disable this breakpoint · mute all                            |
| `<leader>dm` · `<leader>dM`               | Breakpoint list: file · project                               |
| `<leader>dB` · `<leader>dX`               | Clear breakpoints: file · project                             |
| `<leader>do` · `<leader>dO` · `<leader>dI` | Step over · step out · smart step into                       |
| `<leader>dC`                              | Run to cursor                                                 |
| `<leader>dR` · `<leader>dt` · `<leader>dl` | Restart · terminate · run last                               |
| `<leader>de`                              | Evaluate name or selection                                    |
| `<leader>du`                              | Toggle debug panels                                           |
| `<leader>dv` · `dG` · `dW` · `dp`         | Focus Variables · Call Stack · Watches · Breakpoints          |
| Right-click                               | Debug menu for the clicked line                               |

Full reference: [`lua/debugging/README.md`](lua/debugging/README.md).

</details>

<details>
<summary><b>AI &amp; Copilot</b></summary>

| Key                            | Action                                                                   |
| ------------------------------ | ------------------------------------------------------------------------ |
| `<M-k>` · `<leader>ad`         | Toggle Copilot suggestions                                               |
| `<C-j>`                        | Trigger / cycle suggestion                                               |
| `<C-;>`                        | Accept suggestion + trigger next                                         |
| `<M-w>` · `<M-l>`              | Accept word · line                                                       |
| `<M-]>` · `<M-[>`              | Cycle suggestions                                                        |
| `<leader>aS` · `<leader>aR`    | Copilot status · restart                                                 |
| `<leader>an`                   | cursortab next-edit on/off (`<Tab>` accepts / jumps)                     |
| `<leader>aN`                   | cursortab provider: Mercury (hosted) ⇄ Zeta-2.1 (local llama-server)     |
| `<C-l>`                        | Accept blink completion item                                             |
| `<leader>ab` · `<C-b>`         | Toggle blink completion menu                                             |
| `<leader>as` · `<leader>al`    | Copy file path · path:line (visual: line range) for CLI agents           |
| `<leader>acc` · `aca` · `ace`  | Prompt: commit · codebase analysis · explain file                        |
| `<leader>acs` · `acd` (visual) | Prompt: explain symbol · explain selection                               |
| `<leader>acf` · `acr`          | Prompt: refactor · pre-commit review                                     |
| `<leader>aci`                  | Prompt: interactive picker (template or freeform + one-off instruction)  |

</details>

<details>
<summary><b>Git</b></summary>

| Key                           | Action                                           |
| ----------------------------- | ------------------------------------------------ |
| `gn` · `gN`                   | Next · previous changed file                     |
| `]c` · `[c`                   | Next · previous hunk                             |
| `ghs` · `ghr`                 | Stage · reset hunk (visual: selected lines)      |
| `ghp`                         | Preview hunk                                     |
| `<leader>ghS` · `<leader>ghR` | Stage · reset buffer                             |
| `<leader>ghu`                 | Undo stage hunk                                  |
| `<leader>ghb`                 | Toggle inline blame                              |
| `<leader>gd`                  | Toggle diff view                                 |
| `<leader>gl` · `<leader>gL`   | File history: current file · repo                |
| `<leader>gf`                  | File history (open commit diff on enter)         |
| `<leader>gw` · `<leader>gb`   | Git who (compact blame) · blame line (full diff) |

</details>

<details>
<summary><b>General</b></summary>

| Key                       | Action                                                          |
| ------------------------- | --------------------------------------------------------------- |
| `<C-s>`                   | Save                                                            |
| `<C-->`                   | Terminal (bottom split)                                         |
| `<C-d>` · `<C-u>`         | Half-page scroll + recenter                                     |
| `<C-e>` · `<C-y>`         | Scroll popup / picker list, else viewport                       |
| `<Up>` · `<Down>`         | Scroll editor viewport down · up one line (off by default)      |
| `<Right>` · `<Left>`      | Scroll editor viewport right · left one column (off by default) |
| `<leader>uv`              | Toggle arrow-key scrolling                                      |
| `<leader>uH`              | Toggle mouse-hover docs                                         |
| `<leader>uj` · `<leader>uk` | Inspect position · inspect treesitter tree                    |
| `<leader>D`               | Database UI (toggle)                                            |
| `<leader>M`               | Mason (toggle)                                                  |
| `<leader>L` · `<leader>R` | Restart Neovim · Lazy log                                       |

</details>

---

## Performance

The whole point. What is tuned, and what is off on purpose.

**Killed on the hot path**

- `matchparen` disabled: no per-cursor-move highlight scan
- Snacks `words` · `scope` · `indent` · `scroll` · `animate` all off
- treesitter-context off; treesitter highlight stops above 100KB files
- LSP semantic tokens · `document_color` off; inlay hints on, trimmed to parameter names
  (`<leader>uh` toggles); `update_in_insert = false`;
  inline virtual text for errors only
- lualine statusline throttled to 400ms (tabline/winbar 1000ms); git-diff component removed
- LSP `debounce_text_changes = 200ms` applied globally through `vim.lsp.config("*", ...)`
- Python/Go LSP roots guard against `$HOME/.git` workspace scans
- noice restricted to the cmdline popup; python/ruby/perl/node providers disabled
- aerial runs only while its pane (or the opt-in breadcrumb) is visible
- Copilot, cursortab, neotest, nvim-dap, dadbod and easy-dotnet load on first use
  (key, command or filetype), so a session that never touches them pays nothing

**Disabled by decision** (do not re-add without a reason):

> flash · harpoon · spectre · avante · sidekick · codecompanion ·
> telescope · treesitter-context · nvim-lint · persistence · mini.\* · friendly-snippets

**Accepted on purpose**: bufferline is on by choice, at a measured ~1.4 ms per
keystroke with 5 buffers open. Its `ENABLED` flag in `lua/plugins/bufferline.lua`
is the only switch.

**Version freeze**: `:Lazy update/sync/restore` is blocked at the Lua level
(`lua/config/lazy-freeze.lua`). Unlock one session with `NVIM_LAZY_UNLOCK=1 nvim`.
See [`notes/config-freeze-policy.md`](notes/config-freeze-policy.md) for the
rationale, cadence, and escape hatch.

---

## Theme

`solarized-osaka`, opaque, with one file of highlight overrides on top. Upstream
is one command away (`:colorscheme solarized-osaka-original`), so the difference
this repo makes is always precise.

`custom-latest` in `lua/colorschemes/solarized-osaka/variants.lua` is the only
authority for what runs. The numbered builds (`-custom-v1` to `-custom-v4`) are
frozen snapshots kept to compare against. This README deliberately lists no hex
values, because they drift. Read a live value from a running editor:

```vim
:lua =vim.api.nvim_get_hl(0, { name = "@boolean", link = false })
```

The background lives in `lua/config/ui.lua`, together with every value that was
tried and why it was rejected. `on_colors` reads it and assigns the float,
sidebar and popup backgrounds from it, so every panel matches the editor.

Design history and measurements: [`notes/palette-reference.md`](notes/palette-reference.md),
[`notes/syntax-palette-decisions.md`](notes/syntax-palette-decisions.md) and
[`notes/string-and-member-colours.md`](notes/string-and-member-colours.md).
They describe earlier builds; their reasoning still holds, their hex values may not.

---

## Snippets

VSCode JSON format in `snippets/`, served through blink.cmp's built-in snippet
provider (not LuaSnip). `package.json` maps each file to its filetype.

- `snippets/js-ts/es6-javascript.json`: ES6 utilities, console helpers, functions, loops, classes
- `snippets/js-ts/typescriptreact.json`: React hooks and JSX helpers
- `snippets/go/go.json`: package/import/function/error/test/http/json helpers
- `snippets/python/python.json`: imports, functions, classes, dataclasses, TypedDict, pytest helpers

---

## Layout

```
init.lua            bootstrap
lua/config/         options · keymaps · autocmds · lazy · lazy-freeze · mouse-hover · ai-prompts · quickfix persistence
lua/plugins/        one file per plugin (disabled specs kept for reference)
lua/debugging/      debugger GUI: panels, control bar, menu, breakpoints, per-language files (see its README)
lua/testing/        test panel, history, marks, coverage, test ⇄ implementation jump
lua/colorschemes/   active theme (palette.lua = roles, init.lua = groups, variants.lua = builds)
colors/             one line each: the `:colorscheme` entry points for the builds
after/queries/      treesitter query extensions
scripts/palette/    measuring tools for the syntax colours (see its README)
snippets/           VSCode-format snippets
rules.md            the discipline rules I follow when changing the config
notes/              guides: safe-editing · freeze policy · maintenance · reading codebases · silent failures · palette
todos/              backlog, grouped by subject (see todos/README.md)
docs/               agent instructions (docs/CLAUDE.md is canonical) · advance-features guides · maintenance guide
```

---

## Documentation

The config documents itself as it grows:

- [`docs/advance-features/INDEX.md`](docs/advance-features/INDEX.md): guides and design reports per feature area (debugging, testing, LSP and search, editing)
- [`docs/maintenance/config-maintenance-guide.md`](docs/maintenance/config-maintenance-guide.md): how the config is kept healthy over time
- [`lua/debugging/README.md`](lua/debugging/README.md) and [`MAINTENANCE.md`](lua/debugging/MAINTENANCE.md): the debugger, file by file, and how to fix it after an update
- [`notes/`](notes/): workflow guides (reading codebases, safe editing, silent failures) and theme history
- [`todos/`](todos/README.md): the backlog, grouped by subject

---

## Requirements

Neovim **0.12+**, a Nerd Font, `ripgrep` and `fd` (pickers/grep), `prettierd`
(web formatting, via Mason), and Go/Python tooling installed through Mason for
the enabled language extras. Optional, only for the features that use them:

- **Copilot:** a GitHub Copilot subscription. Suggestions stay off until toggled.
- **cursortab:** `$MERCURY_AI_TOKEN` for Mercury, or a local `llama-server` running Zeta-2.1.
- **C# / .NET:** the .NET SDK. easy-dotnet installs its own server on first use.
- **Markdown:** Obsidian for `<leader>ui`.

Tuned for the [Ghostty](https://ghostty.org) terminal on macOS; works elsewhere,
but some `<M-…>`/`<D-…>` keymaps assume Ghostty's key encoding.
