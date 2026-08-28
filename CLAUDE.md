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

## File browser: snacks (trial concluded 2026-08-28, KEPT)

`<leader>e` is a **snacks** file browser, not oil and not telescope. It lives in
`lua/plugins/snacks-file-browser.lua`. Oil moved to `<leader>E` and still owns
`:e <dir>`.

The week-long trial (2026-08-21 to 2026-08-28) ended in a keep. Day-to-day use
turned up no bugs in the main flows: navigating, filtering, opening, and the CRUD
operations. That is a week of real use, not exhaustive testing, so an odd
behaviour is possible rather than impossible. Report one, do not redesign around
it. Merged to `main` on 2026-08-28; the `trial/file-explorer-test` branch is now
just history.

The telescope attempt at the same thing is **parked, not deleted**:
`lua/plugins/telescope-file-browser.lua` with `ENABLED = false`, which also keeps
telescope itself uninstalled. Do not revive it to "compare" without a reason.

Three things a new session must know before touching that file, `snacks.lua`, or
`oil.lua`:

- **Never add a dim/backdrop behind the file browser**, and **never re-enable
  snacks' picker backdrop.** With `transparent = true` a black float has nothing
  to blend against and renders as solid black at every `winblend`. Both were
  measured; both have already been tried and reverted.
- The whole-editor darkening behind popups is a **snacks transparency
  mis-detection triggered by another plugin's `winhighlight`**, not a browser bug.
  It is fixed by `backdrop = false` in two places in `snacks.lua`. Those two lines
  now **stay regardless of the trial**: telescope was one trigger and is gone, but
  the lazy.nvim UI (`Normal:LazyNormal`) is the other and ships with the config.
- **The browser is a snacks picker, so it inherits picker semantics.** Two
  behaviours had to be set explicitly rather than worked around, and both are
  documented in place: `auto_close = true` (a picker stacked on top still leaves
  it open, but opening a file closes it instead of leaving the popup floating over
  the buffer you are editing), and `<C-e>` / `<C-y>` bound to `list:scroll()` (the
  list is virtually scrolled, so the native keys have nothing to move).

Full reasoning, measurements and the rejected alternatives:
[`notes/popup-backdrop-darkening-investigation.md`](notes/popup-backdrop-darkening-investigation.md)
and [`todos/snacks-explorer-as-file-browser.md`](todos/snacks-explorer-as-file-browser.md).

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
