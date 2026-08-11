# Freeze-Day Runbook: Completed

## Status

The 2026-06-20 build-out is complete. Do not execute the old installation batch
again. The config is in maintenance mode and frozen until about 2026-10-20.

Completed work:

- [x] Go tooling, including golangci-lint, delve, and neotest-golang.
- [x] YAML, Docker, Terraform, and Helm LazyVim extras.
- [x] Bash formatting through shfmt.
- [x] Plugin versions re-locked and changes committed.
- [x] YAML schema behavior verified.

Remaining first-use checks:

- [ ] Dockerfile and Docker Compose LSP attachment.
- [ ] Terraform LSP attachment, hover, and completion.
- [ ] Helm LSP attachment in a real chart.

Daily TS/React, Go, Python, completion, and formatting paths were either unchanged
by the DevOps batch or already verified. Do not retest them as a reason to reopen
the frozen config.

If one of the new DevOps servers does not attach, reinstall only that Mason package.
Do not change `lsp.lua` or `blink-cmp.lua` unless a real workflow is broken.

See `todos/production-stack-gap-closure.md` and
`todos/multi-language-support.md` for the reconciled current state.
