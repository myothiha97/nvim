# Cursor Tab-level suggestions in Neovim

Added 2026-10-13. Checkpoint item (2026-12-31), not for the freeze.

## Goal

Suggestion quality and flow close to Cursor Tab: multi-line edits, next-edit
predictions that actually trigger, one key to accept and keep going.

## Start here at the checkpoint

- Research first, before building anything: what limits the current setup
  (copilot.lua ghost text + copilot-lsp NES), and which Neovim options get
  closer to Cursor Tab. Decide with the ROI test (rules.md #9).
- Ghost text in the theme's syntax colours instead of flat grey, like VS Code.
  Copilot.lua draws it with one highlight (`CopilotSuggestion`), so this needs
  either plugin support or a custom renderer. It is a highlight change, so the
  palette rules in rules.md apply at the checkpoint too.

## Syntax-coloured ghost text: how other editors do it

From memory, not checked against current docs (2026-10-13):

- **VS Code:** `editor.inlineSuggest.syntaxHighlightingEnabled`. Tokenizes the
  line as if the suggestion were accepted and paints the ghost part in the
  theme's token colours, dimmed. Off = flat `editorGhostText.foreground`.
- **Zed:** applies the predicted edit to a buffer copy, takes the tree-sitter
  highlights from it, and shows them faded.
- **WebStorm:** inline completions are still one dim colour, as far as known.

The key idea: a fragment like `", b)` cannot be highlighted alone; it must be
parsed together with the surrounding code.

## Safe design for Neovim

Drawing is easy (ghost text is an extmark, each chunk can carry its own
highlight group). Getting the colours is the work.

- **When:** parse only when a new suggestion arrives, never per keystroke or
  cursor move. Keeps it off the hot path.
- **What:** only the current line with the suggestion inserted, plus a few lines
  of context, as a string (`vim.treesitter.get_string_parser`), never the
  buffer. Expected well under 1 ms; measure it before trusting that.
- **Colours:** reuse the existing `@capture` groups (`@string`, `@function`, ...)
  so the theme supplies them and the palette is untouched.
- **Fail-safe:** wrap everything in `pcall`; any error, unknown language or
  missing parser falls back to the flat `CopilotSuggestion` grey. The worst case
  equals today.

Risks:

1. **Patches plugin internals.** copilot.lua renders the ghost text itself, so
   this wraps an internal render function, like the NES toggle patch. It can
   break silently after `:Lazy update`: re-check after each update and mark it
   `-- WARN: SILENT FAILURE`.
2. **Ghost text may look like real code.** VS Code dims it. Dimming needs a
   blended colour per group, which is colour work and waits for the palette
   checkpoint. Cheaper option: full colours plus italic only.

Before building: check whether copilot.lua (or another plugin) supports this
upstream by then. Upstream support beats a patch.

## Already rejected, do not re-propose

- **NES `<Tab>` jump/apply chaining** (claude.ai handoff, 2026-10-13). Dropped
  for low ROI: `<C-;>` already chains ghost text, and an applied NES already
  re-requests through copilot-lsp's own `TextChanged` autocmd. The only gains
  were a preview jump and skipping one `<Esc>`.
- cursortab.nvim (pre-1.0, single maintainer) and sidekick.nvim (same Copilot
  NES model, rarely triggered), per the same handoff.
