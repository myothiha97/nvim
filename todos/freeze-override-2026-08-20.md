# Freeze-override trace — 2026-08-20 telescope-file-browser session

Required by rule 10 in [`discipline-stop-rules.md`](discipline-stop-rules.md).

**The change:** `telescope-file-browser.nvim` added and made the primary file
explorer, in four parts —

1. New `lua/plugins/telescope-file-browser.lua`: telescope.nvim +
   telescope-file-browser.nvim, lazy-loaded on one key, confined to the current
   window with a backdrop, oil-mirrored navigation keys.
2. Explorer keys reshuffled: `<leader>e` telescope browser, `<leader>E` oil,
   `<leader>r` snacks. `nvim <dir>` now opens the browser fullscreen; oil keeps
   `:e <dir>` mid-session.
3. The oil miller-columns experiment parked as `_unstabled_oil.lua.bak` —
   written, working, reverted out of `oil.lua`, kept for later.
4. Lualine scroll percentage moved next to the filename.

**Why it did not wait for the 2026-10-20 checkpoint:** it should have. This is
"a new plugin installation" and "a new feature" — two of the categories the
change-gate names explicitly, not one of the allowed reasons. The gate fired,
the reject message was delivered, and it was overridden by choice.

The one honest defence is that the trigger was a real gap rather than a
preference: oil.nvim has no search, confirmed against upstream (last pushed the
same date as our pin, one docs-only commit since) and stated in its own README
FAQ. That gap is genuine. It did not have to be closed today, and the fix that
was eventually found for the original complaint — oil's `<C-p>` preview and
`<C-s>` vertical split, both already present and unused — needed no new plugin
at all.

**What it cost:** a full evening, and most of it was not the plugin. The tail
was cosmetic: popup dimensions re-tuned roughly six times, the statusline line
number moved and then reverted wholesale, and a snacks-explorer background
colour that consumed several rounds and was reverted with nothing to show. Three
separate wrong diagnoses were given for that last one before the user's own
diagnostic output settled it.

**The pattern worth naming.** Repeatedly, a headless measurement said a change
worked while the user's screen said it did not — the snacks background, the
`nowait` flag, the `on_show` hook. Each time the useful move was to have the
user run one command in their live session, and each time that was reached only
after two or three rounds of guessing. Headless verification proves the code
path, not the result. When the two disagree, ask for the session's own output
first.

**Also worth naming:** two regressions were introduced and caught only because
something forced a second look — a `doautocmd VimResized` that re-ran the whole
finder on every directory change (found because the user reported lag), and
`default_file_explorer = false` breaking `:e <dir>` (found by the pre-commit
perf review). Both were mine. The review earned its place.

**Consequence:** per the rule in [`rules.md`](../rules.md) — time spent inside a
freeze buys more freeze, not less. This session is a candidate for extending the
window again at the checkpoint; that decision is deliberately left to the
checkpoint rather than taken here.

**Still open, deliberately:**

- The trial is a trial. It has not been judged against oil or snacks in real
  work, and the whole file is designed to delete in one step (`ENABLED = false`,
  or remove the file and `:Lazy clean`).
- `DYNAMIC_SIZE = false` parks working content-aware sizing. It is off because
  resizing after mount forces file_browser to rebuild its filename column, and
  the only hook for that re-runs the finder. The code and the reasoning are kept
  in the file.
- Per-directory-change cost is ~65ms against oil's 23ms, with `git_status` off
  to get there. That is the real number to judge the trial on.
- `_unstabled_oil.lua.bak` is inert. If oil ever regains the explorer role, the
  miller-columns work is there and was verified working.
