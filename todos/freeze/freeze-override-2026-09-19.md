# Freeze-override trace — 2026-09-19 startup explorer session

Required by rule 10 in [`discipline-stop-rules.md`](../process/discipline-stop-rules.md).

**The change (one line):** `nvim <dir>` now opens the snacks tree explorer
fullscreen with `jump = { close = true }` instead of the oil popup; it cannot
wait because it was asked for and confirmed by choice, not because anything is
broken.

**Why it did not wait for the 2026-10-20 checkpoint:** it should have. The gate
fired, the four-point answer was given — optional, not blocking, not serving the
current priorities (Go & backend, Node/TS fullstack, DevOps, Python, system
design) — and filing to `todos/ui/` was offered and declined. Overridden by
choice, at the cost this rule exists to charge.

**What actually changed:** one call inside oil's existing `VimEnter` hook in
`lua/plugins/oil.lua`. No new spec fragment, no new `init`, no new plugin. The
hook's guards (`argc() ~= 1`, the `oil://` scheme strip, the `isdirectory`
check) and the blank-buffer swap are untouched. `<leader>e`/`<leader>E` are still
oil, `<leader>r` is still the 25% sidebar, `:e <dir>` is still oil.

**Worth naming: the request started from a wrong premise, and checking cost
nothing.** The ask was "make `nvim` show the dashboard instead of oil on an empty
buffer". Bare `nvim` already showed the dashboard — probing both startup paths in
an isolated session settled it in about a minute, and the real ask turned out to
be a different one (`nvim .`). Had the first request been implemented as stated,
it would have changed working behaviour to fix nothing.

**Two traps avoided, both already documented in this repo:**

1. `snacks-file-browser.lua:850` warns that reviving that browser by flipping
   `ENABLED` re-breaks `snacks.lua`'s `init` silently. This change does not touch
   that file — the request was for the `<leader>r` tree, not the flat browser.
2. `default_file_explorer` was left alone. Setting it to `false` broke
   `:e <dir>` on 2026-08-20 and was caught only by the pre-commit perf review.

**Two upstream facts that contradicted the obvious guess**, both read from the
installed snacks source rather than assumed:

- `auto_close` does not close a picker on confirm. It only fires on `WinEnter` of
  another window (`picker/core/picker.lua:285-312`). The explorer stays open on
  file open because its source sets `jump = { close = false }`
  (`picker/config/sources.lua:64`). **Correction, same day:** shipping only
  `jump = { close = true }` was not enough. A file opened from a picker stacked
  on top is jumped by THAT picker, so the explorer never sees a confirm and kept
  floating over the buffer. `auto_close = true` is the second half, and the
  retired browser had already found and fixed exactly this on 2026-08-21 -- its
  note was read during this session and still under-weighted.
- `fullscreen` is a layout *flag*, not a preset (`snacks/layout.lua:243-248`).
  And because `snacks.lua:327-376` spells out the explorer layout box with
  `position = "left"`, a call-time table merge inherits that position and yields
  a full-height split, since `Snacks.config.merge` cannot unset with `nil`.

**Consequence:** per [`rules.md`](../../rules.md) — time spent inside a freeze
buys more freeze, not less. This session is a candidate for extending the window
at the checkpoint; that decision is left to the checkpoint.

**Still open, deliberately:**

- The retired flat browser in `lua/plugins/snacks-file-browser.lua` stays retired
  at `ENABLED = false`. This change makes its `VimEnter` hook redundant a second
  time over; if it is ever revived, the startup case is now contested and the two
  hooks must not both claim it.
- Decision 1 in `todos/ui/snacks-explorer-as-file-browser.md` ("oil keeps the
  startup case") is now reversed. That file needs an outcome line.

## Second scope change, same session

The startup screen was reshaped twice more after the first commit. Final shape:
`nvim <dir>` restores the last file edited in that directory (new
`lua/config/last-file.lua`, saved on `VimLeavePre`), and the `<leader>r` sidebar
opens only when there is nothing to restore. The fullscreen explorer and both of
its closing overrides are gone.

**This is scope creep inside a freeze, and it should be named as such.** The
original request was "show the dashboard instead of oil". The dashboard already
worked. What actually shipped is a new persistence module, a rewritten startup
path and a retuned dashboard — none of it blocking, all of it by choice, across
one evening. The gate fired once at the start and was not re-applied as the
scope grew, which is the failure mode worth carrying to the checkpoint: the
override is per-change, but the session kept spending against a single
confirmation.

Measured before keeping the persistence: `read()` 0.13 ms at startup, `save()`
4.7 ms once on exit. Neither touches an interactive path.
