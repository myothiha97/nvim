# Neovim feature work: index

One folder per feature area. Everything is stored locally as markdown.

## Debugging (nvim-dap + dap-ui, lua/debugging/)
- Plan: [debugging/go-debugger-gui-plan.md](debugging/go-debugger-gui-plan.md)
- Review: [debugging/go-debugger-review.md](debugging/go-debugger-review.md)
- Phase 4 report (Node/Python/C#): [debugging/phase-4-report.md](debugging/phase-4-report.md)
- In repo: [lua/debugging/README.md](../../lua/debugging/README.md), [lua/debugging/MAINTENANCE.md](../../lua/debugging/MAINTENANCE.md)
- Freeze override: [todos/freeze/freeze-override-2026-11-04-debugger-gui.md](../../todos/freeze/freeze-override-2026-11-04-debugger-gui.md)

## Testing (neotest, lua/plugins/testing.lua)
- Complete guide (setup, config, adjusting it yourself, Go / Node / Python flows): [testing/neotest-guide.md](testing/neotest-guide.md)
- Beginner guide (testing basics, IDE comparison): [testing/testing-in-neovim-with-neotest.md](testing/testing-in-neovim-with-neotest.md)
- Research: [testing/jetbrains-gap-report.md](testing/jetbrains-gap-report.md)
- In repo: lua/testing/coverage.lua and lua/testing/history.lua (branch feat/test-coverage-history)
- Follow-ups: [todos/languages/neotest-review-followups.md](../../todos/languages/neotest-review-followups.md) (arrives with the test-coverage-history branch; link resolves once that is merged)

## LSP, completion and search
- Audit: [lsp-and-search/large-repo-audit.md](lsp-and-search/large-repo-audit.md)

## DB tooling (vim-dadbod, lua/plugins/database.lua)
- Research was delivered in chat; no file. Branch feat/db-tooling, PR #29.

## Editing
- Registers and macros guide: [editing/registers-and-macros-guide.md](editing/registers-and-macros-guide.md)
