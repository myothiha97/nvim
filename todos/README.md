# Todos

Backlog and decision record. One file per idea. Nothing here is in the config
unless its own file says so.

Read [`../rules.md`](../rules.md) and
[`../neovim-config-change-gate.md`](../neovim-config-change-gate.md) before
acting on anything in this folder. During a freeze window, items here are
**collected, not executed**: they get triaged together at the checkpoint.

| folder | what it holds |
| --- | --- |
| [`freeze/`](#freeze) | the freeze-day runbook and every freeze-override trace |
| [`process/`](#process) | how the config is worked on, not what it contains |
| [`theme/`](#theme) | colours and the theme plugin |
| [`ui/`](#ui) | editor surfaces: file browser, tabline, scrolling, keymaps |
| [`languages/`](#languages) | LSP, formatters, debuggers, per-language support |
| [`ai/`](#ai) | AI plugin configuration |
| [`done/`](#done) | shipped and verified; kept for the reasoning |

Status column meanings:

- **open** — real remaining work, not started or partly done
- **parked** — built or investigated, deliberately inactive; do not revive
  without a reason stated in the file
- **record** — a log of a past decision, not work to do
- **done** — shipped; the file is kept for what it measured or decided

---

## freeze

| file | hook | status |
| --- | --- | --- |
| [`freeze-day-runbook.md`](freeze/freeze-day-runbook.md) | the 2026-06-20 build-out batch. **Do not execute again** — it is complete, config is in maintenance mode | done |
| [`freeze-override-2026-08-08.md`](freeze/freeze-override-2026-08-08.md) | syntax palette retune, ~5 hours, well past the point of returns | record |
| [`freeze-override-2026-08-09-hover-docs.md`](freeze/freeze-override-2026-08-09-hover-docs.md) | hover-doc prose dimming; the cheap counterexample, magnitude decided by measurement first | record |
| [`freeze-override-2026-08-09-jsx-tag-dose.md`](freeze/freeze-override-2026-08-09-jsx-tag-dose.md) | `@tag.delimiter.*` to neutral; the `@tag`/`@tag.builtin` split rejected here | record |
| [`freeze-override-2026-08-11.md`](freeze/freeze-override-2026-08-11.md) | the largest session inside the freeze, five parts: logical operators, copper, four named builds, `scripts/palette/`, comment cleanup | record |
| [`freeze-override-2026-08-20.md`](freeze/freeze-override-2026-08-20.md) | telescope-file-browser session; the reason the freeze clock was reset | record |

Rule 10 in [`process/discipline-stop-rules.md`](process/discipline-stop-rules.md)
is what requires an override to leave a trace here.

## process

| file | hook | status |
| --- | --- | --- |
| [`discipline-stop-rules.md`](process/discipline-stop-rules.md) | for the checkpoint session, ~10 min, doc-only. Closes the gap where `rules.md` decides **whether to start** but nothing decides **when something is finished** | open |
| [`config-refactoring.md`](process/config-refactoring.md) | unify LSP, folding, search/replace, diagnostics, debugging, code analysis into consistent shapes | open |

## theme

| file | hook | status |
| --- | --- | --- |
| [`syntax-palette-followups.md`](theme/syntax-palette-followups.md) | the numbered palette items and their verdicts. Items 2, 6, 7 done; 3 dropped; 4, 5, 8 closed. Item 8 is the one `custom-latest` acts on | mostly closed |
| [`solarized-osaka-upstream-update.md`](theme/solarized-osaka-upstream-update.md) | upstream advertised a large refactor ending at `0df74ef`; our lock is `f675d9a`. Deferred to the checkpoint — do not update during the freeze unless the theme is broken | open |
| [`lazy-border-match-snacks-picker.md`](theme/lazy-border-match-snacks-picker.md) | the `:Lazy` float is the one framed panel not wearing the snacks picker ring. lazy.nvim never remaps `FloatBorder`. Link the whole group, fg alone is invisible | open |

Live colour values and the reasoning behind them are **not** here. See
[`../notes/palette-reference.md`](../notes/palette-reference.md) (lean) and
[`../notes/syntax-palette-decisions.md`](../notes/syntax-palette-decisions.md)
(deep archive).

## ui

| file | hook | status |
| --- | --- | --- |
| [`keymap-native-conflicts.md`](ui/keymap-native-conflicts.md) | MEDIUM. High-impact conflicts resolved; remaining insert-mode cases deferred | open |
| [`nvim-smooth-scrolling.md`](ui/nvim-smooth-scrolling.md) | still short of GUI editors across mouse, trackpad and keyboard. Must not regress large files | open |
| [`paste-without-losing-clipboard.md`](ui/paste-without-losing-clipboard.md) | `"_dP` so pasting over a selection does not clobber the clipboard. Smallest item here | open |
| [`snacks-explorer-as-file-browser.md`](ui/snacks-explorer-as-file-browser.md) | built, kept for a week, then **REVERSED 2026-09-04** — `<leader>e` is oil.nvim again. Nothing in it was wrong, it just did not feel as smooth. `ENABLED = false` | parked |
| [`snacks-file-tree-icon-legibility.md`](ui/snacks-file-tree-icon-legibility.md) | built, rejected on sight, reverted the same session. Kept for the measurements. The complaint still stands: `<leader>r` icons read too small to scan | parked |
| [`unstable-static-tabline.md`](ui/unstable-static-tabline.md) | HIGH, parked 2026-07-20. `lua/config/_unstable_tabline.lua` retained but not required. Blank strip at the top, design too basic | parked |

## languages

| file | hook | status |
| --- | --- | --- |
| [`lsp-popup-style-consolidation.md`](languages/lsp-popup-style-consolidation.md) | four entry points each carry their own `{ border, max_width, max_height }`, so a popup looks different depending on how it was opened | open |
| [`multi-language-support.md`](languages/multi-language-support.md) | the live per-language state table (LSP / format / debug). Build-out complete; now tracks verification and deliberately deferred languages | reference |
| [`nvim-dap-webstorm-parity-and-enhancements.md`](languages/nvim-dap-webstorm-parity-and-enhancements.md) | Go pass done 2026-08-28 (goroutines, function breakpoints, log points, hit counts). Other languages still at LazyVim defaults | partly done |
| [`production-stack-gap-closure.md`](languages/production-stack-gap-closure.md) | completed 2026-06-20, reconciled 2026-08-11. No longer an execution plan | done |

## ai

| file | hook | status |
| --- | --- | --- |
| [`codecompanion-codex-acp-fix.md`](ai/codecompanion-codex-acp-fix.md) | Codex ACP adapter broken since the codex-acp 1.6.2 upgrade. Root cause known, values measured, the edit is ~4 lines. Nothing here is a guess | open |
| [`avante-ui-optimization.md`](ai/avante-ui-optimization.md) | Avante disabled since 2026-05-26; CodeCompanion is the active workflow. Do no UI work unless Avante is deliberately re-enabled | parked |

## done

| file | hook |
| --- | --- |
| [`quickfix-list-persistence.md`](done/quickfix-list-persistence.md) | cwd-scoped JSON, bounded restore, pcall-wrapped I/O |
| [`scroll-popup-without-focus.md`](done/scroll-popup-without-focus.md) | `<C-e>` / `<C-y>` scroll a visible doc popup without entering it; falls back to native when no popup |
