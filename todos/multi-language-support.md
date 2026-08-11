# Multi-Language Support

## Status

Reconciled with the live config on 2026-08-11. The language build-out is complete.
This file now tracks verification and intentionally deferred languages, not missing
configuration that has already been installed.

## Current State

| Language / area | LSP | Format / lint | Debug / test | Status |
|---|---|---|---|---|
| JS/TS/React | vtsls | prettierd; TypeScript diagnostics | js-debug; neotest-vitest | Daily-driver ready |
| Go | gopls | gofumpt, goimports, golangci-lint | delve; neotest-golang | Production-ready and debug-verified |
| Python | basedpyright | ruff | debugpy; neotest-python | Configured; real-project verification remains |
| Bash | bashls | shfmt; shellcheck | Not needed | Ready |
| Lua | lua_ls | stylua available through Mason | Not needed | Ready |
| JSON | jsonls | prettierd | Not needed | Ready |
| YAML | yamlls + SchemaStore | prettierd | Not needed | Verified |
| Docker | dockerls + compose LSP | hadolint | Not needed | Installed; real-file verification remains |
| Terraform | terraform-ls | terraform tooling | Not needed | Installed; real-file verification remains |
| Helm | helm-ls | Helm tooling | Not needed | Installed; real-chart verification remains |
| Rust | rustaceanvim | rustfmt through toolchain | codelldb; rustaceanvim neotest | Config ready; dormant until `rustup` exists |
| C/C++ | Not enabled | Not configured | codelldb is installed | Deferred until a real task exists |

The enabled LazyVim extras are recorded in `lazyvim.json`. Installed adapters and
test integrations are pinned in `lazy-lock.json`.

## Remaining Verification

These checks need real project files. They do not justify new config by themselves.

- [ ] Dockerfile: confirm `dockerls` attaches and hover works.
- [ ] Docker Compose: confirm compose completion and diagnostics.
- [ ] Terraform: confirm `terraform-ls` attaches, hover and completion work.
- [ ] Helm chart: confirm `helm-ls` attaches to chart templates or values files.
- [ ] Python project: confirm `:VenvSelect`, ruff format-on-save, debugpy, and
  neotest-python with the project virtual environment.
- [ ] JS/TS debugging: confirm the required Node or browser launch configuration in a
  real project when that workflow is needed.

YAML schema completion has already been verified. Go debugging has already been
verified with breakpoints, stepping, locals, and call stacks.

## Deferred Work

- Rust needs the system toolchain: install `rustup`, then verify hover, formatting,
  tests, and codelldb. No Neovim config change is currently required.
- C/C++ needs the LazyVim clangd extra only when a real project appears.
- Vue, Svelte, Angular, Ruby, and other unused stacks stay disabled until needed.

## Performance and Scope Rules

- Keep language support filetype-lazy through LazyVim extras.
- Do not enable unused languages speculatively.
- Preserve the `$HOME/.git` root guards for Go and Python.
- Smoke-test TS/React after any extra that modifies vtsls integration.
- No new cursor-move, text-change, scroll, or redraw-path work.
