# Production Stack Readiness: Gap Closure

## Status

Completed on 2026-06-20 and reconciled with the live config on 2026-08-11.
This is no longer an execution plan.

The implementation landed in:

- `b565540`: Bash formatting through shfmt.
- `a4f6c3c`: YAML, Docker, Terraform, and Helm LazyVim extras.
- `38fd53b`: documentation of the remaining real-file verification.

The detailed pre-change plan remains available in Git history. Current language
state is maintained in `todos/multi-language-support.md`.

## Current Verdict

The main stack is configured:

| Area | Current state |
|---|---|
| Node, TypeScript, React | Daily-driver ready |
| Go | Production-ready; golangci-lint is available on PATH |
| Python | LSP, format, lint, debug, test, and venv tooling configured |
| YAML | Extra installed and schema behavior verified |
| Docker | Extra and Mason tools installed; real-file attachment not verified |
| Terraform | Extra and Mason tools installed; real-file attachment not verified |
| Helm | Extra and Mason tools installed; real-chart attachment not verified |
| Bash | bashls, shellcheck, and shfmt configured |

The freeze mechanisms are active:

- `lua/config/lazy-freeze.lua` blocks accidental update, sync, and restore operations.
- `lazy-lock.json` pins plugin revisions.
- `rules.md` freezes non-essential config work until about 2026-10-20.

## Remaining Work

Only empirical checks remain from this batch:

- [x] YAML schema completion and validation.
- [ ] Dockerfile and Docker Compose LSP attachment.
- [ ] Terraform LSP attachment, hover, and completion.
- [ ] Helm LSP attachment in a real chart.

If a server does not attach, reinstall that Mason package first. Do not reopen the
daily TS/React, Go, or completion configuration unless those workflows actually fail.

## Deferred Areas

- C/C++: enable the clangd extra only for a real project.
- Rust: the Neovim extra and codelldb are ready; the system still needs `rustup`.
- Vue, Svelte, Angular, and Ruby: keep disabled until actively used.

## Performance Guard

The completed extras are filetype-lazy. They add no work while unrelated files are
open and introduce no cursor, typing, scrolling, or redraw hooks.
