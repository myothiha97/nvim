# Neovim feature work: index

One folder per feature area. Reports that only exist online are linked, not copied.

## Debugging (nvim-dap + dap-ui, lua/debugging/)
- Plan: [debugging/go-debugger-gui-plan.md](debugging/go-debugger-gui-plan.md)
- Review: [Neovim Go debugger review](https://claude.ai/artifact/9rGVeguTn5vpK4FRbLfcpm)
- Phase 4 report (Node/Python/C#): [Neovim debugger: Phase 4 report](https://claude.ai/artifact/Pq72H8PMGoM99dsWDoN1kg)
- In repo: [lua/debugging/README.md](../../lua/debugging/README.md), [lua/debugging/MAINTENANCE.md](../../lua/debugging/MAINTENANCE.md)
- Freeze override: [todos/freeze/freeze-override-2026-11-04-debugger-gui.md](../../todos/freeze/freeze-override-2026-11-04-debugger-gui.md)

## Testing (neotest, lua/plugins/testing.lua)
- Complete guide (setup, config, adjusting it yourself, Go / Node / Python flows): [testing/neotest-guide.md](testing/neotest-guide.md)
- Beginner guide (testing basics, IDE comparison, practice in tmp_test.go): [testing/testing-in-neovim-with-neotest.md](testing/testing-in-neovim-with-neotest.md)
- Research: [Neovim test running: JetBrains gap report](https://claude.ai/artifact/BPr46onaoWnUAFFBbhZdzn)
- In repo: lua/testing/coverage.lua and lua/testing/history.lua (branch feat/test-coverage-history)
- Follow-ups: [todos/languages/neotest-review-followups.md](../../todos/languages/neotest-review-followups.md) (arrives with the test-coverage-history branch; link resolves once that is merged)

## LSP, completion and search
- Audit: [Neovim large-repo audit](https://claude.ai/artifact/WwLBKyMjxeEWcc7KKHtRnc)

## DB tooling (vim-dadbod, lua/plugins/database.lua)
- Research was delivered in chat; no file. Branch feat/db-tooling, PR #29.

## Editing
- Registers and macros guide: [editing/registers-and-macros-guide.md](editing/registers-and-macros-guide.md)
