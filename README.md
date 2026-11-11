<div align="center">

# Full-Stack Neovim Setup

**Built on [LazyVim](https://github.com/LazyVim/LazyVim), customized for everyday coding and tuned to stay fast.**

_Reads, tests and debugs large codebases like an IDE, and keeps every keystroke instant._

`~50ms cold start` · `solarized-osaka` · `version-frozen`

</div>

---

## Philosophy

One rule governs everything here: **nothing expensive runs on the hot path.**
A feature earns its place only if it costs effectively `0ms` per keystroke,
cursor move, and redraw. Heavy tools (debugger, test runner, database UI, AI
next-edit) load only when you first use them.

The principle is enforced, not just intended: `:Lazy update/sync/restore` is
blocked at the Lua level, and a written editing policy keeps future changes from
quietly regressing speed.

> See [`rules.md`](rules.md) for the discipline rules,
> [`notes/config-freeze-policy.md`](notes/config-freeze-policy.md) for the freeze
> policy in full, and
> [`notes/safe-config-editing-guide.md`](notes/safe-config-editing-guide.md) for
> the performance rules every change is held to.

> **For Claude Code / AI agents:** read [`rules.md`](rules.md) **first**, before
> proposing or making any change, then the docs under `docs/` as usual. It holds
> the discipline rules and the **config-freeze window**, which decide whether a
> change should happen at all. **The freeze is suspended since 2026-11-11** (see
> the note in `rules.md`); the performance rules still apply.

---

## Highlights

What makes this feel less like vanilla Neovim:

|                                         |                                                                                                                                                                                                                                                             |
| --------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 🐞 **Mouse-driven debugger**            | A GoLand-style DAP GUI for Go, Node/JS/TS, Python and C#: a control bar, Variables and Call Stack panels, right-click debug menu, click the gutter to set breakpoints, hover a name to see its value. Breakpoints (with conditions and log points) persist per project. |
| 🧪 **Test runner + coverage**           | neotest for Go, Vitest/Jest, pytest and .NET: inline ✓/✗, a JetBrains-style Test Results panel, rerun failed, test history across sessions, jump test ⇄ implementation, and gutter coverage from your runner's report.                                       |
| 🗄️ **Database UI**                      | vim-dadbod UI on `<leader>D` with SQL completion in SQL buffers only. Nothing loads until you open it.                                                                                                                                                      |
| 🤖 **AI next edits**                    | `copilot.lua` ghost text plus `copilot-lsp` NES (`<Tab>` jumps and applies multi-line edits), and **cursortab** Cursor-Tab-style next edits on hosted Mercury or local Zeta-2.1. Both are off until you toggle them, and load only on first use.            |
| 📋 **AI prompt-copy system**            | `<leader>ac…` copies a context-aware prompt (commit, codebase analysis, explain, refactor, review) to the clipboard for an external CLI agent, or `<leader>aci` to pick a template or ask freeform.                                                          |
| 🗂️ **Symbols outline**                  | `<leader>cs` opens an **aerial** structure pane with JetBrains-style kind icons and colours, dimmed signatures, and React-aware rows in JSX/TSX (components, `useState [a, setA]`, `useEffect`). Aerial runs only while the pane is open.                 |
| 🖱️ **Hover docs on mouse-over**         | LSP documentation appears when the pointer rests on a symbol, behind a throttled handler that is free while you type. While the debugger is stopped, hover shows values instead.                                                                           |
| 📌 **Persistent quickfix curation**     | Mark lines with `<leader>m` while reading code; the list survives restarts, scoped per project.                                                                                                                                                              |
| 📂 **Edit-the-filesystem file browser** | `<leader>e` opens **oil.nvim** as a centred popup with the path in its border. Rename, create and delete by editing the buffer and `:w`. Oil owns netrw, so `:e <dir>` lands in the same place.                                                             |
| 🚀 **Startup screen**                   | Bare `nvim` shows the dashboard (a plain greeting plus the current folder). `nvim <dir>` opens oil in the same box and position as `<leader>e`.                                                                                                             |
| 🔍 **Git without leaving the file**     | `gn` / `gN` jump between changed files, `ghs` / `ghr` / `ghp` stage, reset and preview hunks, and `<leader>gw` / `<leader>gb` show compact and full blame as floats.                                                                                       |
| 📝 **Rendered markdown in-buffer**      | `.md` files render inline with flat styling; `<leader>uh` flips back to raw, `<leader>ui` opens the file in Obsidian. The same renderer polishes LSP hover popups.                                                                                         |

---

## Core Stack

| Category         | Plugin                                                                                                                                             |
| ---------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Completion**   | blink.cmp: LSP · local snippets · path · buffer (+ dadbod in SQL, adapter completion in the debug REPL)                                            |
| **AI**           | copilot.lua + copilot-lsp (NES) · cursortab.nvim (Mercury / Zeta-2.1) · prompt-copy system. CodeCompanion is installed but disabled until 2027.   |
| **Debugging**    | nvim-dap + nvim-dap-ui with a custom GUI in `lua/debugging/` · Delve · js-debug · debugpy · easy-dotnet (native arm64 netcoredbg)                   |
| **Testing**      | neotest (golang · vitest · jest · python · easy-dotnet) + custom panel, history and marks in `lua/testing/` · nvim-coverage                         |
| **Database**     | vim-dadbod · vim-dadbod-ui · vim-dadbod-completion                                                                                                 |
| **File nav**     | oil.nvim (`<leader>e`, owns netrw) · Snacks: picker · explorer (`<leader>r` sidebar) · dashboard · terminal                                         |
| **Code nav**     | aerial (symbols outline) · Snacks LSP symbol picker · Trouble (quickfix views) · treesitter textobjects                                            |
| **Git**          | gitsigns (hunks) + diffview.nvim + custom blame floats                                                                                             |
| **Search**       | grug-far: project/file search-replace and rename                                                                                                   |
| **Multi-cursor** | vim-visual-multi                                                                                                                                   |
| **Folding**      | nvim-ufo: treesitter + indent, async                                                                                                               |
| **Formatting**   | conform.nvim: prettierd for web/JSON/Markdown, goimports/gofumpt for Go, shfmt for shell, mbake for Makefiles                                      |
| **Markdown**     | render-markdown.nvim (`.md` files and LSP hovers) · Obsidian on `<leader>ui` · markdown-preview.nvim (`:MarkdownPreview`)                          |
| **UI**           | lualine · noice (cmdline only) · fidget · which-key                                                                                                |
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
- LSP semantic tokens · `document_color` · inlay hints off; `update_in_insert = false`;
  inline virtual text for errors only
- lualine statusline throttled to 400ms (tabline/winbar 1000ms); git-diff component removed
- LSP `debounce_text_changes = 200ms` applied globally through `vim.lsp.config("*", ...)`
- Python/Go LSP roots guard against `$HOME/.git` workspace scans
- noice restricted to the cmdline popup; python/ruby/perl/node providers disabled
- aerial runs only while its pane (or the opt-in breadcrumb) is visible
- Copilot, cursortab, neotest, nvim-dap, dadbod and easy-dotnet load on first use
  (key, command or filetype), so a session that never touches them pays nothing

**Disabled by decision** (do not re-add without a reason):

> bufferline · flash · harpoon · spectre · avante · sidekick · codecompanion ·
> telescope · treesitter-context · nvim-lint · persistence · mini.\* · friendly-snippets

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
docs/               agent instructions (docs/CLAUDE.md is canonical) · advance-features guides (debugging, testing, ...)
```

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
