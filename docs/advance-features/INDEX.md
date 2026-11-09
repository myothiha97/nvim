# Neovim feature work: index

Everything produced while building Neovim features, in one place. Online docs and reports can't be moved into a folder, so they're linked here.

## Debugging (nvim-dap + dap-ui, lua/debugging/)
- Plan: [debugging/go-debugger-gui-plan.md](debugging/go-debugger-gui-plan.md)
- Review: [Neovim Go debugger review](https://claude.ai/artifact/9rGVeguTn5vpK4FRbLfcpm)
- Phase 4 report (Node/Python/C#): [Neovim debugger: Phase 4 report](https://claude.ai/artifact/Pq72H8PMGoM99dsWDoN1kg)
- In repo: lua/debugging/README.md, lua/debugging/MAINTENANCE.md

## Testing (neotest, lua/plugins/testing.lua)
- Research: [Neovim test running: JetBrains gap report](https://claude.ai/artifact/BPr46onaoWnUAFFBbhZdzn)
- Guide: [Testing in Neovim with neotest](https://claude.ai/artifact/GaDeCqZvG1bf9jS25t8kmM)
- Practice file: [testing/tmp_test.go](testing/tmp_test.go)
- In repo: lua/plugins/testing.lua; lua/testing/coverage.lua (<leader>tcf/tca in-editor coverage) and lua/testing/history.lua (<leader>th/tH test history) on branch feat/test-coverage-history
- Follow-ups and future languages (C#, Rust, C/C++): todos/languages/neotest-review-followups.md
- Scope: Go, JS/TS, Python. Bash: no test tooling planned.

## DB tooling (vim-dadbod, lua/plugins/database.lua)
- Research was delivered in chat; no file. Branch feat/db-tooling, PR #29.

## Editing
- Insert-mode navigation research: [editing/insert-mode-keymaps/](editing/insert-mode-keymaps/)
- Registers and macros guide: [editing/registers-macros/registers-and-macros-guide.md](editing/registers-macros/registers-and-macros-guide.md)

## _sync-bundles
Git bundles used to move commits to the Mac. Transport only; safe to delete once the branches are merged.
