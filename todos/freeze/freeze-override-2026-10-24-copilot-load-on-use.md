# Freeze-override trace — 2026-10-24 Copilot loads on first use

Required by rule 10 in [`discipline-stop-rules.md`](../process/discipline-stop-rules.md).

**The change (one line):** `lua/plugins/copilot.lua` loads on its toggle
(`<M-k>` insert, `<leader>ad`) or manual trigger (`<C-j>` insert) instead of on
every file open, so an nvim that never uses Copilot starts no Copilot server.

**Why it did not wait:** the gate fired (optional, not blocking, RAM not yet
measured) and the idea was filed as `todos/ai/copilot-load-on-toggle.md`. It was
overridden by explicit confirmation ("fix this issue now"). Scope held to the
load trigger; no Copilot behaviour after loading changed.

**Same session, a security fix (not an override):** `should_attach` in the same
file now also keeps credential files off the Copilot server (`*.pem`, `*.key`,
`*.tfvars`, `*.tfstate`, SSH keys, `.npmrc`, `.netrc`, `credentials*`, and the
`.ssh/`, `.kube/`, `.aws/`, `.gnupg/`, `.docker/` folders). Before, only `.env*`
and `*secret*` were blocked. Treated as a fix because it is a data-leak risk.
