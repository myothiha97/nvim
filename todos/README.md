# Todos

Backlog and decision record. One file per idea. Nothing here is in the config
unless its own file says so.

Read [`../rules.md`](../rules.md) and
[`../neovim-config-change-gate.md`](../neovim-config-change-gate.md) before
acting on anything in this folder. During a freeze window, items here are
**collected, not executed**: they get triaged together at the checkpoint.

| folder                     | what it holds                                              |
| -------------------------- | ---------------------------------------------------------- |
| [`freeze/`](#freeze)       | the freeze-day runbook and every freeze-override trace     |
| [`process/`](#process)     | how the config is worked on, not what it contains          |
| [`theme/`](#theme)         | colours and the theme plugin                               |
| [`ui/`](#ui)               | editor surfaces: file browser, tabline, scrolling, keymaps |
| [`languages/`](#languages) | LSP, formatters, debuggers, per-language support           |
| [`ai/`](#ai)               | AI plugin configuration                                    |
| [phase 2](#phase-2)        | larger planned features, specs live in `docs/phases/`      |
| [`done/`](#done)           | shipped and verified; kept for the reasoning               |

Status column meanings:

- **open** — real remaining work, not started or partly done
- **parked** — built or investigated, deliberately inactive; do not revive
  without a reason stated in the file
- **record** — a log of a past decision, not work to do
- **done** — shipped; the file is kept for what it measured or decided

---

## freeze

| file                                                                                              | hook                                                                                                                                 | status |
| ------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ | ------ |
| [`freeze-day-runbook.md`](freeze/freeze-day-runbook.md)                                           | the 2026-06-20 build-out batch. **Do not execute again** — it is complete, config is in maintenance mode                             | done   |
| [`freeze-override-2026-08-08.md`](freeze/freeze-override-2026-08-08.md)                           | syntax palette retune, ~5 hours, well past the point of returns                                                                      | record |
| [`freeze-override-2026-08-09-hover-docs.md`](freeze/freeze-override-2026-08-09-hover-docs.md)     | hover-doc prose dimming; the cheap counterexample, magnitude decided by measurement first                                            | record |
| [`freeze-override-2026-08-09-jsx-tag-dose.md`](freeze/freeze-override-2026-08-09-jsx-tag-dose.md) | `@tag.delimiter.*` to neutral; the `@tag`/`@tag.builtin` split rejected here                                                         | record |
| [`freeze-override-2026-08-11.md`](freeze/freeze-override-2026-08-11.md)                           | the largest session inside the freeze, five parts: logical operators, copper, four named builds, `scripts/palette/`, comment cleanup | record |
| [`freeze-override-2026-08-20.md`](freeze/freeze-override-2026-08-20.md)                           | telescope-file-browser session; the reason the freeze clock was reset                                                                | record |
| [`freeze-override-2026-09-19.md`](freeze/freeze-override-2026-09-19.md)                           | startup explorer, then the oil box and dashboard; scope grew past the one gate                                                       | record |
| [`freeze-override-2026-09-23.md`](freeze/freeze-override-2026-09-23.md)                           | git hunk keys, arrow toggle, outline rows; plus the week's safety review                                                             | record |
| [`freeze-override-2026-09-24.md`](freeze/freeze-override-2026-09-24.md)                           | green strings, keys follow members; one hex and one link, scope held to the todo                                                     | record |
| [`freeze-override-2026-10-22.md`](freeze/freeze-override-2026-10-22.md)                           | inline error diagnostics; one line, scope held                                                                                       | record |
| [`freeze-override-2026-10-24-copilot-load-on-use.md`](freeze/freeze-override-2026-10-24-copilot-load-on-use.md) | Copilot loads on first use instead of every file open; load trigger only | record |
| [`freeze-override-2026-10-23-leader-ui-obsidian.md`](freeze/freeze-override-2026-10-23-leader-ui-obsidian.md) | `<leader>ui` in markdown opens Obsidian instead of the browser preview | record |
| [`freeze-override-2026-10-26-audit-fixes.md`](freeze/freeze-override-2026-10-26-audit-fixes.md) | eight small fixes from the Sept/Oct commit audit, before November production work | record |
| [`freeze-override-2026-10-29-aerial-spacing.md`](freeze/freeze-override-2026-10-29-aerial-spacing.md) | aerial panel left padding, no tree guides, wider panel; scope grew once | record |
| [`freeze-override-2026-10-29-vscode-bg.md`](freeze/freeze-override-2026-10-29-vscode-bg.md) | editor bg tried at VS Code's `#16181d`, reverted the same day; candidate parked for the checkpoint | record |
| [`freeze-override-2026-10-29-teal-ui-surfaces.md`](freeze/freeze-override-2026-10-29-teal-ui-surfaces.md) | leftover teal UI surfaces moved to neutral values derived from `ui.bg`, incl. the completion doc popup; UI only | record |
| [`freeze-override-2026-11-04-debugger-gui.md`](freeze/freeze-override-2026-11-04-debugger-gui.md) | DAP config moved to `lua/debugging/` plus debugger GUI phase 1 | record |

Rule 10 in [`process/discipline-stop-rules.md`](process/discipline-stop-rules.md)
is what requires an override to leave a trace here.

## process

| file                                                           | hook                                                                                                                                                           | status |
| -------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------ |
| [`discipline-stop-rules.md`](process/discipline-stop-rules.md) | for the checkpoint session, ~10 min, doc-only. Closes the gap where `rules.md` decides **whether to start** but nothing decides **when something is finished** | open   |
| [`config-refactoring.md`](process/config-refactoring.md)       | unify LSP, folding, search/replace, diagnostics, debugging, code analysis into consistent shapes                                                               | open   |
| [`october-cleanup.md`](process/october-cleanup.md) | dead code, stale comments/todos and live trials found in the October review; no behaviour change | open |

## theme

| file                                                                             | hook                                                                                                                                                                     | status        |
| -------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------- |
| [`syntax-palette-followups.md`](theme/syntax-palette-followups.md)               | the numbered palette items and their verdicts. Items 2, 6, 7 done; 3 dropped; 4, 5, 8 closed. Item 8 is the one `custom-latest` acts on                                  | mostly closed |
| [`solarized-osaka-upstream-update.md`](theme/solarized-osaka-upstream-update.md) | upstream advertised a large refactor ending at `0df74ef`; our lock is `f675d9a`. Deferred to the checkpoint — do not update during the freeze unless the theme is broken | open          |
| [`lazy-border-match-snacks-picker.md`](theme/lazy-border-match-snacks-picker.md) | the `:Lazy` float is the one framed panel not wearing the snacks picker ring. lazy.nvim never remaps `FloatBorder`. Link the whole group, fg alone is invisible          | open          |
| [`string-member-separation.md`](theme/string-member-separation.md)               | the LAST theme item: string/member colours: PARKED WIP in `custom-v4` + `custom-swap*`; live is back on cyan strings. Resume from the notes file                   | open          |
| [`palette-checkpoint-ideas.md`](theme/palette-checkpoint-ideas.md)             | one-line colour ideas parked while the palette is closed; review at the 2026-12-31 checkpoint                                                                   | open          |
| [`background-16181d-candidate.md`](theme/background-16181d-candidate.md)     | editor bg `#16181d` vs live `#131312`: measured, small comfort gain, no readability gain. Decide at the checkpoint                                                   | open          |
| [`comment-no-italic.md`](theme/comment-no-italic.md)                             | drop the italic on comments, keep the colour. Same as E6 option 1 in `theme-enhancements.md`                                                                     | open          |
| [`rainbow-brackets-and-operator-colours.md`](theme/rainbow-brackets-and-operator-colours.md) | rainbow bracket pairs plus a distinct operator colour. Plugin trial works in Lua/Go/Python, broken in JSX/TSX | open          |
| [`colorscheme-review-2026-10-02-and-future-enhancement.md`](theme/colorscheme-review-2026-10-02-and-future-enhancement.md) | review of the custom-latest palette with a roadmap; reference for the checkpoint | record |
| [`theme-enhancements.md`](theme/theme-enhancements.md) | proposed TSX/Go/Lua readability, font and background tweaks; not applied | open |

Live colour values and the reasoning behind them are **not** here. See
[`../notes/palette-reference.md`](../notes/palette-reference.md) (lean) and
[`../notes/syntax-palette-decisions.md`](../notes/syntax-palette-decisions.md)
(deep archive).

## ui

| file                                                                            | hook                                                                                                                                                                                                                                    | status   |
| ------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- |
| [`aerial-kind-icon-colours.md`](ui/aerial-kind-icon-colours.md) | distinct icon colour per symbol kind in `<leader>cs`, JetBrains Structure style. Shipped in PR #44 (2026-11-11): `KIND_COLORS` in `lua/plugins/aerial.lua` | done 2026-11-11 |
| [`center-after-jumps.md`](ui/center-after-jumps.md) | `zz` after `]c`/`[c` hunk jumps and `n`/`N` search, like `<C-d>`/`<C-u>`. ~15 min; hunk jumps are async, needs the callback form | open |
| [`cmdheight-zero.md`](ui/cmdheight-zero.md) | blank row above the tmux bar is `cmdheight = 1`. Tested 0: "Press ENTER" prompts with noice messages off, so the gap stays | record |
| [`keymap-native-conflicts.md`](ui/keymap-native-conflicts.md)                   | MEDIUM. High-impact conflicts resolved; remaining insert-mode cases deferred                                                                                                                                                            | open     |
| [`markdown-preview-improvements.md`](ui/markdown-preview-improvements.md) | browser choice, live updates while typing, and opening `<leader>ui` in Obsidian instead of the browser | open |
| [`material-icon-theme-parity.md`](ui/material-icon-theme-parity.md)             | the folder-name **text colour** half shipped 2026-09-22. VS Code Material icon/colour parity deferred — exact parity is impossible (VS Code ships SVGs, a terminal draws one font glyph). Also holds the cursor-row brightening finding | open     |
| [`nvim-smooth-scrolling.md`](ui/nvim-smooth-scrolling.md)                       | still short of GUI editors across mouse, trackpad and keyboard. Must not regress large files                                                                                                                                            | open     |
| [`paste-without-losing-clipboard.md`](ui/paste-without-losing-clipboard.md) | `"_dP` so pasting over a selection does not clobber the clipboard. Live as visual-mode `<leader>p` (`lua/config/keymaps.lua`) | done |
| [`indent-blankline-typing-cost.md`](ui/indent-blankline-typing-cost.md) | ibl costs 5–8 ms CPU per typed key and `<C-d>` in every language, the largest cost added since October; the accepted-cost comment only covers `j`/`k` | open |
| [`scrollview-scroll-cost.md`](ui/scrollview-scroll-cost.md) | the scrollbar costs 3–5 ms CPU per `j` in TS/TSX/Python, far above its measured 0.1–0.2 ms refresh | open |
| [`aerial-breadcrumb-over-10k-lines.md`](ui/aerial-breadcrumb-over-10k-lines.md) | aerial's `disable_max_lines = 10000` silently drops breadcrumb and outline in bigger files | open |
| [`snacks-explorer-as-file-browser.md`](ui/snacks-explorer-as-file-browser.md)   | built, kept for a week, then **REVERSED 2026-09-04** — `<leader>e` is oil.nvim again. Nothing in it was wrong, it just did not feel as smooth. `ENABLED = false`                                                                        | parked i |
| [`snacks-file-tree-icon-legibility.md`](ui/snacks-file-tree-icon-legibility.md) | built, rejected on sight, reverted the same session. Kept for the measurements. The complaint still stands: `<leader>r` icons read too small to scan                                                                                    | parked   |
| [`symbol-outline-split.md`](ui/symbol-outline-split.md) | split the Trouble outline into per-language modules. No longer needed: `<leader>cs` moved to aerial.nvim (PR #40, #44), so the Trouble outline is not the structure view any more | done (superseded) |
| [`treesitter-outline-locals.md`](ui/treesitter-outline-locals.md)               | LOW. The outline cannot show symbols inside a Go func because gopls never reports them (measured). Needs a treesitter source. Answer "is it worth it" before starting                                                                   | open     |
| [`vscode-style-scrollbar.md`](ui/vscode-style-scrollbar.md) | scrollbar in terminal Neovim with diagnostic/git/search marks, via a plugin (none built in). Adds the first `WinScrolled` handler | done 2026-11-12 (nvim-scrollview, position only) |
| [`conflict-marker-navigation.md`](ui/conflict-marker-navigation.md) | `]x` / `[x` jump between git conflict markers in any buffer; made by choice on request | done 2026-11-20 |
| [`unstable-static-tabline.md`](ui/unstable-static-tabline.md)                   | HIGH, parked 2026-07-20. `lua/config/_unstable_tabline.lua` retained but not required. Blank strip at the top, design too basic                                                                                                         | parked   |
| [`bufferline-nvim-config-for-active-buffer-tabs.md`](ui/bufferline-nvim-config-for-active-buffer-tabs.md) | IDE-style buffer tabs. Live: bufferline.nvim, always shown, no italic (`lua/plugins/bufferline.lua`) | done |
| [`tmux-nvim-pane-navigation.md`](ui/tmux-nvim-pane-navigation.md) | one grid for nvim splits and tmux panes. Live with Cmd+H/J/K/L (Ghostty `<M-h..l>`) instead of the planned `Ctrl+Space` (`lua/config/keymaps.lua`) | done |

## languages

| file                                                                                                     | hook                                                                                                                                      | status      |
| -------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- | ----------- |
| [`inline-error-diagnostics.md`](languages/inline-error-diagnostics.md)                                   | end-of-line virtual text for errors only; today the message needs `<leader>cd`                                                            | done        |
| [`lsp-popup-style-consolidation.md`](languages/lsp-popup-style-consolidation.md)                         | four entry points each carry their own `{ border, max_width, max_height }`, so a popup looks different depending on how it was opened     | open        |
| [`multi-language-support.md`](languages/multi-language-support.md)                                       | the live per-language state table (LSP / format / debug). Build-out complete; now tracks verification and deliberately deferred languages | reference   |
| [`nvim-dap-webstorm-parity-and-enhancements.md`](languages/nvim-dap-webstorm-parity-and-enhancements.md) | Go pass done 2026-08-28 (goroutines, function breakpoints, log points, hit counts). Other languages still at LazyVim defaults             | partly done |
| [`production-stack-gap-closure.md`](languages/production-stack-gap-closure.md)                           | completed 2026-06-20, reconciled 2026-08-11. No longer an execution plan                                                                  | done        |
| [`neotest-review-followups.md`](languages/neotest-review-followups.md) | Rerun Failed batching, jest `isTestFile` cache, possible neotest-vitest print (non-blocking, 2026-11-08 review). Run with Coverage done. Deferred: run profiles, benchmarks. Future: C#, Rust, C/C++ test support | open |
| [`basedpyright-standard-mode.md`](languages/basedpyright-standard-mode.md) | 2.4k strict-mode warnings make Python 3× costlier per key; `standard` mode: `j` 26.5 → 9.1 ms CPU. Behaviour change, your call | open |
| [`ts-indent-whole-file-pass.md`](languages/ts-indent-whole-file-pass.md) | `o`/`<CR>` 150–170 ms in an 11.5k-line TSX file: treesitter indent walks the whole file after every edit | open |
| [`format-on-save-foreign-style.md`](languages/format-on-save-foreign-style.md) | `:w` on an untouched file rewrites lines when the project uses gofmt/black (gofumpt/ruff here) | open |

## ai

| file                                                                  | hook                                                                                                                                         | status |
| --------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- | ------ |
| [`codecompanion-codex-acp-fix.md`](ai/codecompanion-codex-acp-fix.md) | Codex ACP adapter broken since the codex-acp 1.6.2 upgrade. Fix applied: `auth_method = "chat-gpt"` in `lua/plugins/codecompanion.lua` (model pinned to `gpt-5.5`, not the doc's `gpt-5.6-sol`/`high`) | done |
| [`cursor-tab-level-suggestions.md`](ai/cursor-tab-level-suggestions.md) | GOAL: Cursor Tab-quality suggestions in nvim. Research-first, checkpoint item. NES `<Tab>` chaining dropped 2026-10-13 (low ROI) | open   |
| [`avante-ui-optimization.md`](ai/avante-ui-optimization.md)           | Avante disabled since 2026-05-26; CodeCompanion is the active workflow. Do no UI work unless Avante is deliberately re-enabled               | parked |
| [`codecompanion-mermaid-viewer.md`](ai/codecompanion-mermaid-viewer.md) | GOAL: VS Code-quality Mermaid diagrams in CodeCompanion chat. Inline + zoom viewer shipped (#71, #73) but not readable enough; needs dedicated time | open |
| [`dwight-nvim-workflow.md`](ai/dwight-nvim-workflow.md) | GOAL: inline prompts and chats run at the same time without blocking, each with its own loading indicator (dwight.nvim-style). CodeCompanion ACP inline allows only one prompt at a time today | open |
| [`parallel-ai-requests-brd.md`](ai/parallel-ai-requests-brd.md) | BRD for the dwight-style goal: requirements, acceptance criteria, test plan, phases, open questions | open |
| [`copilot-load-on-toggle.md`](ai/copilot-load-on-toggle.md) | start Copilot on first use instead of every file open; saves one Node server per idle nvim. Done 2026-10-24 by override | done |

## phase 2

Larger planned features. The specs stay in
[`../docs/phases/phase-2/`](../docs/phases/phase-2/); these rows only make sure
the checkpoint triage sees them. Run the ROI test (rules.md #9) on each.

| file                                                                                                                  | hook                                                                                                                                                                                                                                                                     | status |
| --------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------ |
| [`features_and_changes_and_optimization.md`](../docs/phases/phase-2/features_and_changes_and_optimization.md) | three UI items. #1 statusline symbol: **done**, aerial breadcrumb in lualine, on by default (PR #66). #2 file inspector: **done** via the aerial panel, see the next row. #3 scroll info as a top-right overlay: still open, UI change, fails ROI by default | partly done |
| [`neovim-file-inspector-BRD_+_Technical_Specification.md`](../docs/phases/phase-2/neovim-file-inspector-BRD_+_Technical_Specification.md) | Semantic File Inspector, full BRD + spec. Delivered as the aerial Structure panel on `<leader>cs` (PR #40, #42, #44: tree, per-kind colours, details, Go method nesting). BRD extras not built: fuzzy search, rename and code actions from the panel | done (aerial) |

## done

| file                                                                  | hook                                                                                                 |
| --------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| [`makefile-formatter.md`](done/makefile-formatter.md)                 | conform `bake` (mbake) formats Makefiles on save; ~120 ms per save, Makefiles only                   |
| [`quickfix-list-persistence.md`](done/quickfix-list-persistence.md)   | cwd-scoped JSON, bounded restore, pcall-wrapped I/O                                                  |
| [`scroll-popup-without-focus.md`](done/scroll-popup-without-focus.md) | `<C-e>` / `<C-y>` scroll a visible doc popup without entering it; falls back to native when no popup |
