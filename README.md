<div align="center">

# Full-Stack Neovim Setup

**Built on [LazyVim](https://github.com/LazyVim/LazyVim), customized for everyday coding and tuned to stay fast.**

*Reads and navigates large codebases like an IDE — and keeps every keystroke instant.*

`~40ms cold start` · `solarized-osaka` · `version-frozen`

</div>

---

## Philosophy

One rule governs everything here: **nothing expensive runs on the hot path.**
A feature earns its place only if it costs effectively `0ms` per keystroke,
cursor move, and redraw. Polish and convenience never come at the price of
snappiness.

That principle is enforced, not just intended — `:Lazy update/sync/restore` is
blocked at the Lua level, and a written editing policy keeps future changes from
quietly regressing speed.

> See [`rules.md`](rules.md) for the discipline rules,
> [`notes/config-freeze-policy.md`](notes/config-freeze-policy.md) for the freeze
> policy in full, and
> [`notes/safe-config-editing-guide.md`](notes/safe-config-editing-guide.md) for
> the performance rules every change is held to.

> **For Claude Code / AI agents:** read [`rules.md`](rules.md) **first** — before
> proposing or making any change — then the docs under `docs/` as usual. It holds
> the discipline rules and the active **config-freeze window**, which govern
> whether a change should happen at all (default answer is *no* unless it unblocks
> the current workflow).

---

## Highlights

What makes this feel less like vanilla Neovim:

| | |
|---|---|
| 🖱️ **Hover docs on mouse-over** | LSP documentation appears when the pointer rests on a symbol (Zed/WebStorm parity), behind a throttled handler that's free while you type. |
| 🤖 **AI inline + Next Edit Suggestions** | `copilot.lua` ghost text plus `copilot-lsp` NES — jump-and-apply multi-line edits with `<Tab>`, coexisting with the completion menu. |
| 💬 **CodeCompanion (inline · agentic · chat)** | `<leader>ai` rewrites the line/selection in place; `<leader>aa` opens an agentic chat that applies edits as accept/reject diffs; `<leader>af` is a plain chat. Inline runs on Copilot, chat on the `claude_code` adapter (Sonnet) — both key-free, lazy-loaded for zero startup cost. |
| 📋 **AI prompt-copy system** | `<leader>ac…` copies a context-aware prompt (commit, codebase analysis, explain, refactor, review) to the clipboard for an external CLI agent — or `<leader>aci` to pick a template / ask freeform interactively. |
| 📌 **Persistent quickfix curation** | Mark lines with `<leader>m` while reading code; the list survives restarts, scoped per project. |
| 🗂️ **Symbols outline** | `<leader>cs` opens an IDE-style structure pane that follows your cursor. |
| 🔍 **In-buffer git blame** | `<leader>gw` / `<leader>gb` show compact and full blame as floats, without leaving the file. |
| 📝 **Rendered markdown in-buffer** | `.md` files render inline (headings, code blocks, inline code) with flat no-highlight styling; `<leader>uh` flips the buffer back to raw for editing. Same renderer polishes LSP hover popups and Avante windows. |

---

## Core Stack

| Category | Plugin |
|----------|--------|
| **Completion** | blink.cmp — LSP · local snippets · path · buffer |
| **AI** | copilot.lua (inline) + copilot-lsp (NES) + CodeCompanion (inline/agentic/chat) + prompt-copy system |
| **File nav** | Snacks — picker · explorer · dashboard · terminal · oil.nvim (fullscreen) |
| **Code nav** | Trouble (symbols outline + quickfix views) · treesitter textobjects |
| **Git** | gitsigns (hunks) + diffview.nvim + custom blame floats |
| **Search** | grug-far — project/file search-replace & rename |
| **Multi-cursor** | vim-visual-multi |
| **Folding** | nvim-ufo — treesitter + indent, async |
| **Formatting** | conform.nvim — prettierd for web/JSON/Markdown, goimports/gofumpt for Go |
| **Languages** | TypeScript/React daily driver, Go + Python enabled, Rust lazy/deferred |
| **Markdown** | render-markdown.nvim — `.md` files · LSP hover popups · Avante (flat, no-highlight) |
| **UI** | lualine · noice (cmdline only) · fidget · which-key |
| **Theme** | solarized-osaka, customized — `solarized-osaka-custom-v1` (default, violet keyword) · `-custom-v2` (warm keyword) · `-original` (untouched upstream, kept to diff against) |

---

## Language Support

| Language | Status | Notes |
|----------|--------|-------|
| TypeScript / React | Daily driver | `vtsls`, package JSON auto-imports off, tsserver heap cap `4000`, semantic tokens/inlay hints off |
| Go | Enabled | `gopls`, `goimports`, `gofumpt`, `delve`; project roots guarded to `go.mod` / `go.work` |
| Python | Enabled | `basedpyright` + `ruff`, `openFilesOnly` diagnostics, safe roots for both servers, `venv-selector.nvim` lazy on Python |
| JSON | Enabled | LazyVim JSON extra + `prettierd` |
| Rust | Deferred | Lazy extra is installed but filetype-gated; no runtime cost until opening Rust/Cargo files |

Python and Go root detection intentionally avoids treating `$HOME/.git` as a
workspace. Loose files fall back to their own directory instead of making the
language server scan the whole home directory.

---

## Key Bindings

> Leader is `<Space>`. `<M-…>` keys are sent by the terminal (Ghostty) from the
> macOS Cmd/Option layer.

<details open>
<summary><b>Navigation &amp; search</b></summary>

| Key | Action |
|-----|--------|
| `<leader><leader>` | Smart finder (recent + buffers + files) |
| `<leader>ff` · `<leader>fi` | Find files — root · current dir |
| `<leader>fp` | Switch project |
| `<leader>r` | Toggle Snacks explorer |
| `<leader>e` | Oil file manager (fullscreen) |
| `<leader>sl` | Grep within current file |
| `<leader>sf` · `<leader>sF` | Search & replace — project · current file |
| `<leader>sr` · `<leader>sR` | Rename word under cursor — file · project |
| `gd` | Goto definition (skips node_modules & re-imports) |
| `gf` · `gh` | Function start · end (treesitter) |
| `[f` · `]f` | Prev · next function |
| `<M-f>` | Highlight word under cursor |

</details>

<details>
<summary><b>Code navigation — Trouble &amp; quickfix</b></summary>

| Key | Action |
|-----|--------|
| `<leader>cs` | Symbols outline (press `a` inside to include variables) |
| `<leader>cc` · `<leader>ce` | Quickfix · location list (Trouble) |
| `<leader>m` | Mark line/selection into quickfix — persists across restarts |
| `<leader>cx` | Clear quickfix list |
| `<leader>bu` | List unsaved buffers (jump / save) |
| `gi` | Line diagnostics (focusable) |
| `ge` · `gp` | Next · prev error |

</details>

> Workflow guide: [`notes/reading-codebases-with-neovim.md`](notes/reading-codebases-with-neovim.md)
> walks through navigating an unfamiliar codebase with these tools.

<details>
<summary><b>Editing</b></summary>

| Key | Action |
|-----|--------|
| `<Tab>` | Accept NES → focus float → jumplist forward |
| `<M-d>` | Add next occurrence (multi-cursor) |
| `<M-/>` | Toggle comment (line / selection) |
| `ys` · `ds` · `cs` · `s` (visual) | Surround |
| `zm` · `zn` | Toggle all folds — keep current open · fold all |
| `<leader>uh` | Toggle markdown render — raw ⇄ rendered (current buffer) |
| `zR` · `zM` · `zv` | Open all · close all · toggle function folds |
| `K` · `<M-i>` | Hover docs · signature help |

</details>

<details>
<summary><b>AI &amp; Copilot</b></summary>

| Key | Action |
|-----|--------|
| `<C-;>` | Accept suggestion + trigger next |
| `<C-l>` | Accept blink completion item |
| `<C-j>` | Trigger / cycle suggestion |
| `<C-k>` · `<leader>ad` | Toggle Copilot suggestions |
| `<M-w>` · `<M-l>` | Accept word · line |
| `<M-]>` · `<M-[>` | Cycle suggestions |
| `<leader>ab` · `<C-b>` | Toggle blink completion menu |
| `<leader>ai` | CodeCompanion — inline ask (line / selection, edits in place) |
| `<leader>aa` | CodeCompanion — agentic chat (applies edits as accept/reject diffs) |
| `<leader>af` | CodeCompanion — plain chat buffer (toggle) |
| `<leader>ae` | CodeCompanion — add line/selection content to chat |
| `<leader>ar` | CodeCompanion — reset chat approvals (undo accidental "always accept") |
| `<leader>as` · `<leader>al` | Copy file path · path:line (visual: line range) — for CLI agents |
| `<leader>acc` · `aca` · `ace` | Prompt — commit · codebase analysis · explain file |
| `<leader>acs` · `acd` (visual) | Prompt — explain symbol · explain selection |
| `<leader>acf` · `acr` | Prompt — refactor · pre-commit review |
| `<leader>aci` | Prompt — interactive picker (template or freeform + one-off instruction) |

</details>

<details>
<summary><b>Git</b></summary>

| Key | Action |
|-----|--------|
| `<leader>gd` | Toggle diff view |
| `<leader>gl` · `<leader>gL` | File history — current file · repo |
| `<leader>gf` | File history (open commit diff on enter) |
| `<leader>gw` · `<leader>gb` | Git who (compact blame) · blame line (full diff) |
| `]c` · `[c` | Next · previous hunk (gitsigns) |
| `<leader>ghs` · `<leader>ghr` | Stage · reset hunk |
| `<leader>ghS` · `<leader>ghR` | Stage · reset buffer |
| `<leader>ghu` · `<leader>ghp` | Undo stage hunk · preview hunk |
| `<leader>ghb` | Toggle inline blame |

</details>

<details>
<summary><b>General</b></summary>

| Key | Action |
|-----|--------|
| `<C-s>` | Save |
| `<C-->` | Terminal (right split) |
| `<C-d>` · `<C-u>` | Half-page scroll + recenter |
| `<C-e>` · `<C-y>` | Scroll popup, else viewport |
| `<Down>` · `<Up>` | Scroll editor viewport down · up one line |
| `<Right>` · `<Left>` | Scroll editor viewport right · left one column |
| `<leader>uH` | Toggle mouse-hover docs |
| `<leader>M` | Mason (toggle) |
| `<leader>L` · `<leader>R` | Restart Neovim · Lazy log |

</details>

---

## Performance

The whole point. What's tuned, and what's off on purpose.

**Killed on the hot path**

- `matchparen` disabled — no per-cursor-move highlight scan
- Snacks `words` · `scope` · `indent` · `scroll` · `animate` all off
- treesitter-context off; treesitter highlight stops above 100KB files
- LSP semantic tokens · `document_color` · inlay hints off; `update_in_insert = false`
- lualine throttled to 1000ms; git-diff component removed from the statusline
- LSP `debounce_text_changes = 300ms` applied globally through `vim.lsp.config("*", ...)`
- Python/Go LSP roots guard against `$HOME/.git` workspace scans
- noice restricted to the cmdline popup; python/ruby/perl/node providers disabled

**Disabled by decision** — don't re-add without a reason:
> gitsigns · bufferline · flash · harpoon · spectre · avante · sidekick ·
> nvim-lint · persistence · mini.\* · friendly-snippets

**Version freeze** — `:Lazy update/sync/restore` is blocked at the Lua level
(`lua/config/lazy-freeze.lua`). Unlock one session with `NVIM_LAZY_UNLOCK=1 nvim`.
See [`notes/config-freeze-policy.md`](notes/config-freeze-policy.md) for the
rationale, cadence, and escape hatch.

---

## Snippets

VSCode JSON format in `snippets/`, served through blink.cmp's built-in snippet
provider (not LuaSnip) — JS/TS, React, Go, and Python helpers. `package.json`
maps each file to its filetype.

Current local snippet packs:

- `snippets/js-ts/es6-javascript.json` — ES6 utilities, console helpers, functions, loops, classes
- `snippets/js-ts/typescriptreact.json` — React hooks and JSX helpers
- `snippets/go/go.json` — package/import/function/error/test/http/json helpers
- `snippets/python/python.json` — imports, functions, classes, dataclasses, TypedDict, pytest helpers

---

## Layout

```
init.lua            bootstrap
lua/config/         options · keymaps · autocmds · lazy · mouse-hover · ai-prompts
lua/plugins/        one file per plugin (disabled specs kept for reference)
lua/colorschemes/   active theme (config.lua) + reference-only alternates
snippets/           VSCode-format snippets
rules.md            the discipline rules I follow when changing the config
notes/              guides — safe-editing · freeze-policy · maintenance/delegation · reading codebases · learning · journal
todos/              backlog — one file per future config idea (not done yet)
docs/               CHANGELOG · agent instructions
```

---

## Requirements

Neovim **0.12+**, a Nerd Font, `ripgrep` & `fd` (pickers/grep), `prettierd`
(web formatting, via Mason), Go/Python tooling installed through Mason for the
enabled language extras, and a GitHub Copilot subscription for the AI features.
Tuned for the [Ghostty](https://ghostty.org) terminal on macOS; works elsewhere,
but some `<M-…>`/`<D-…>` keymaps assume Ghostty's key encoding.
