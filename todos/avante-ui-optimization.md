
# Avante: UI Optimization (Parked)

## Status

Avante has been disabled since 2026-05-26. CodeCompanion is the active AI chat and
inline-edit workflow. The existing Avante config is retained as reference code and
currently targets the Codex ACP provider, not an active Copilot/Codex switching workflow.

Do not perform UI work unless Avante is deliberately re-enabled for a real workflow.

## Remaining Work

### If Avante Is Re-enabled

- First compare it with the active CodeCompanion workflow and confirm both are needed.
- Then verify the retained provider config still matches the installed Avante version.
- Only after that, consider window layout, borders, sizing, and icons.

### Known Item

- Render-markdown still includes the `Avante` filetype, but this path is inactive while
  Avante is disabled. Re-test it only if Avante returns.

## Notes

- Active AI ownership is in `lua/plugins/codecompanion.lua`.
- Retained Avante code lives in `lua/plugins/avante.lua`.
