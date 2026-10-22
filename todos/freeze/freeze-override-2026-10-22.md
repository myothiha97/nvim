# Freeze-override trace — 2026-10-22 inline error diagnostics

Required by rule 10 in [`discipline-stop-rules.md`](../process/discipline-stop-rules.md).

**The change (one line):** `virtual_text = { severity = ERROR }` in
`lua/plugins/lsp.lua`, so error messages show at end of line. Warnings and hints
are unchanged (sign + underline).

**Why it did not wait:** the gate fired (optional, not blocking), filing was done
(`todos/languages/inline-error-diagnostics.md`), and it was overridden: "if the
change dont take time then proceed". Scope held to the one line.
