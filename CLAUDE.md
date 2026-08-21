## Guideline

- **Before doing anything with this config, read `rules.md` at the repo root FIRST.**
  It holds the discipline rules, the active config-freeze window, and links the
  change-gate (`neovim-config-change-gate.md`) that decides whether a requested
  change should happen at all. Apply that gate to every change request.
- Then read all the infos and instructions inside `docs/` and follow them closely.
  `docs/CLAUDE.md` is the canonical one; `docs/AGENTS.md` just points at it.

> This file is the canonical entry point for **every** AI agent, not only Claude.
> `AGENTS.md` at the repo root is a pointer here so that Codex and anything else
> looking for that filename lands in the same place. Keep it a pointer — two
> copies of these rules will drift, and an agent will then follow the stale one.

## In progress: telescope file-browser trial (2026-08-21)

Uncommitted work lives on the branch **`trial/telescope-file-browser`**, being used
day-to-day before any decision. Two things a new session must know before touching
`lua/plugins/telescope-file-browser.lua` or `lua/plugins/snacks.lua`:

- **Never add a dim/backdrop behind the file browser**, and **never re-enable
  snacks' picker backdrop.** With `transparent = true` a black float has nothing
  to blend against and renders as solid black at every `winblend`. Both were
  measured; both have already been tried and reverted.
- The whole-editor darkening behind popups is a **snacks transparency
  mis-detection triggered by telescope's and lazy.nvim's `winhighlight`**, not a
  browser bug. It is fixed by `backdrop = false` in two places in `snacks.lua`.
  That fix is the **trial's dependency, not a standalone one**: measured, the
  pre-trial workflow (picker over a file, picker from a picker, picker over oil or
  the snacks explorer) never poisoned the detection, which is why this only
  started the night telescope landed. If the trial is dropped, those two lines can
  go with it.

Full reasoning, measurements and the rejected alternatives:
[`notes/popup-backdrop-darkening-investigation.md`](notes/popup-backdrop-darkening-investigation.md).

## One loose end from the freeze session (review by ~2026-10-20)

LOW priority, non-blocking. The pre-freeze build-out is committed + pushed; this is the
only thing not yet eyeballed. Do it casually next time you open one of these files — it is
NOT a reason to reopen the frozen config.

### Actually left to verify — only the NEW DevOps filetypes

- [ ] `.tf` (Terraform) — open one, `:LspInfo` shows `terraform-ls` attached, hover/complete works.
- [ ] `Dockerfile` — `:LspInfo` shows `dockerls`, hover works.
- [ ] helm chart (`templates/*.yaml` or `values.yaml`) — `helm-ls` attaches.
- [x] `.yaml` — already confirmed working.

If a server doesn't attach: `:Mason` → find it → press `i` to reinstall. It's isolated to
that filetype and can't affect anything else.

### NOT a concern (no action needed)

- **TS/JS/Python/Go LSP** (hover / go-to-def / completion): the freeze session never touched
  `lsp.lua` or `blink-cmp.lua`, so their behavior is unchanged from the already-
  production-validated state. "Only tested on a small lua/tsx file" just means *not re-tested* —
  the config they run on didn't change, so there is nothing that could have regressed.
- **TS/JS/etc. format-on-save** (prettierd): this *was* changed, but it was verified to produce
  byte-identical output for files with a project `.prettierrc` (your production repos) — confirmed
  safe, no team git-diff churn.

**Bottom line:** the only genuinely-unverified thing is whether `terraform-ls` / `dockerls` /
`helm-ls` attach on real files. High-impact areas (daily languages) are untouched or proven-safe.
