
# Config Refactoring

## Goal
Refactor and simplify configuration files to make them more consistent, maintainable, and easier to extend for additional languages.

## Unified Config Areas
- LSP
- Folding
- Search and replace
- Diagnostics
- Debugging
- Code analysis

## Language Priorities and Current State

| Language / area | Current state |
|---|---|
| TS/JS/React | Daily-driver ready: vtsls, prettierd, js-debug, Vitest |
| Go | Production-ready: gopls, formatters, golangci-lint, delve, neotest |
| Python | Configured: basedpyright, ruff, debugpy, neotest, venv selector; real-project verification remains |
| DevOps | YAML/Docker/Terraform/Helm extras and tools installed; Docker/Terraform/Helm attachment remains to verify |
| Bash | bashls, shellcheck, and shfmt configured |
| Rust | Extra and codelldb installed, dormant until `rustup` is installed |
| C/C++ | Deferred; clangd extra is not enabled |

## Planned Additions

### AI Action Keymaps / Commands

- [x] Generate commit prompts (`lua/config/ai-prompts.lua`).
- [x] Analyze the codebase (`lua/config/ai-prompts.lua`).
- [x] Review changes (`lua/config/ai-prompts.lua`).
- [x] Inline and agentic edits (`lua/plugins/codecompanion.lua`).

### Code Analysis Keymaps / Commands

- [x] Test and coverage panels through neotest and nvim-coverage.
- [x] Current-file symbol outline through Trouble.
- [ ] Advanced semantic inspector with categorization or usage counts. This remains
  optional and is specified under `docs/phases/phase-2/`; do not build it during the
  freeze unless it unblocks real work.

### Make the Neovim config as lean as possible

The config should stay small, predictable, and performance-safe. Every extra
Lua block, plugin override, helper function, or custom keymap increases the
maintenance cost, especially when it touches LazyVim defaults or plugin
internals. The goal is not to make the config clever; the goal is to make it
easy to understand, easy to change, and hard to accidentally slow down.

Refactoring priorities:

- Remove dead, duplicated, experimental, or rarely used config before adding
  new abstractions.
- Lean down the config to be as lean as possible so that in future if i need to add more features, we can easily extend the config without making the config very bloated
- Prefer LazyVim defaults, LazyVim extras, native Neovim options, and plugin
  `opts` over custom wrapper code.
- Keep feature ownership clear:
  - editor-wide behavior in `lua/config/`
  - plugin specs and overrides in `lua/plugins/`
  - reusable local helpers only when the same pattern is repeated enough to
    justify extraction
- Consolidate repeated patterns across LSP, formatting, diagnostics, folding,
  search/replace, and debugging, but avoid broad rewrites that make the config
  harder to trace.
- Keep runtime performance as the main constraint: no new hot-path work on
  `CursorMoved`, `TextChanged`, redraw/statusline paths, insert completion
  checks, or scroll events unless heavily justified and measured.
- Prefer small, boring modules with explicit names over "framework-style"
  abstractions. This is a personal config, not a plugin library.
- Document only the decisions that are non-obvious: performance tradeoffs,
  LazyVim overrides, plugin-internal patches, terminal/tmux keybinding
  constraints, and disabled-plugin rationale.
- Batch cleanup work during planned config sessions so refactoring does not
  become a constant distraction from actual coding work.

Concrete cleanup targets:

- Identify config blocks that are no longer used and either delete them or move
  them into a todo with rationale.
- Replace custom code with native options or LazyVim/plugin `opts` where that
  keeps the same behavior.
- Group related keymaps and commands by workflow so `keymaps.lua` is easier to
  scan.
- Wrap remaining autocmds in named augroups with `clear = true` when touching
  those files.
- Keep large-file guards, `pcall` protection, lazy-loading, and debounce/defer
  patterns consistent across modules.
- After each cleanup batch, verify startup, typing, scrolling, buffer switching,
  LSP hover/definition, completion, folds, and one real TS/React workflow.
