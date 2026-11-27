# Format-on-save rewrites untouched lines in projects with another formatter (F25)

Found 2026-11-23 (runtime perf E2E report). `:w` on files nobody edited:

- Go: gofumpt (LazyVim go extra) removed 3 lines from gofmt-formatted `golang/tools` code.
- Python: ruff format changed 5 lines in black-formatted django.
- TS/TSX: prettierd changed nothing (excalidraw configures prettier).

In a team repo these are unrelated diff lines. Options: format only when the project
configures that formatter (conform `condition` / `require_cwd`), use `gofmt` for Go, or
`vim.g.autoformat = false` per project.
