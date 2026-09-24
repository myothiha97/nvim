# Personal rules for this Neovim config

> **Important reminder:** Neovim configuration can easily become a time sink.
> Every "quick tweak" can pull attention away from real work, and if it happens
> too often it reduces my productivity and hurts my professional growth.
>
> This config is only a **tool for work** — it is not the work itself.
>
> When I feel the urge to change something, the default answer is **no**:
> write the idea down, schedule it, and go back to real work.
>
> A config that starts correctly and works well is already **done enough**.

> **Accept the trade-offs (2026-09-24).** No tool is perfect, and Neovim will
> have flaws even with an extreme config. Each tool has its job:
>
> - **JetBrains:** a polished GUI and deep integrated tooling (DB, debugger,
>   large refactors). The backup for advanced work.
> - **VS Code / Cursor:** deep AI integration with little setup.
> - **Neovim:** a terminal-native, keyboard-driven workflow. Where 80 to 90% of
>   Go and Node work happens.
>
> Seeing a flaw is not a reason to act. Good enough is the goal.

This file holds the rules I actually follow. It is intentionally short so I can
read it in one pass. The detailed explanations live in the linked documents
under [References](#references).

---

## Status — config is "done enough" (set 2026-06-20)

The major build-out is **complete**. The full **fullstack + DevOps** workflow
(Go · Node/TS · React/RN/Electron · Python · DevOps) is configured and in daily
use. The config has moved from *building* to *maintenance*.

From here on:

- **Any major change must be planned with a timeline** — collected in `todos/`
  and handled in a scheduled batch session, never on impulse.
- **The config is only touched if an issue is actively blocking or degrading the
  current workflow** — a real bug or broken flow (rule #2 / the 30-minute rule).
  "Nicer", "cleaner", "more beautiful", or "slightly better" is never a reason.

### ❄️ Freeze window: 2026-06-20 → 2026-12-31 (~6 months)

The config is **frozen until 2026-12-31**. This is a *review checkpoint*, not a
hard ban: workflow-blocking fixes are still allowed throughout (rule #2), and so
is a functional tool a real Go/Node task needs, if it passes the ROI test
(rule #9). No polish or preference changes until the freeze lifts. At the checkpoint,
batch-review the ideas collected in `todos/` and decide what — if anything — is
worth doing, then set the next freeze window.

> **Extended 2026-08-11, from 2026-09-20.** Not because more time was needed, but
> because the freeze was not held. Several sessions in August spent real hours on
> the syntax palette — a preference change, exactly the category rule #1 names —
> and each one was justified at the time by the override in the change-gate. The
> gate worked as designed; the problem is that "one conscious confirmation" is
> cheap to give and the overrides stacked up.
>
> So the clock resets. **Time spent inside a freeze buys more freeze, not less.**
> If that feels backwards, that is the point: the cost of reopening the config
> should land on the decision to reopen it, or the freeze is only a suggestion.
>
> The relevant check at the next checkpoint is not "what else could be improved"
> but "how many overrides did I sign, and were they worth it".

> **Extended 2026-09-24, from 2026-10-20 to 2026-12-31.** Same reason as above.
> Three overrides landed in one week (2026-09-19, 09-23 and 09-24), and the last
> one reopened the syntax palette: strings, keys, escapes and import keywords
> were all recoloured inside the freeze. The traces are in `todos/freeze/`.

### 🎨 The palette is CLOSED until 2026-12-31 (set 2026-09-24)

The colours are **good enough and finished**. Flaws will always be visible; seeing
one is not a reason to act. The work is done with the palette as it is.

- **No colour, theme or highlight work of any kind** until the checkpoint. That
  includes "just measuring", screenshot comparisons, A/B builds, and "one quick
  check". Analysis is not a safe middle ground: it is where the hours went.
- **The change-gate override does not apply to colours.** A colour idea gets one
  line in `todos/theme/` and nothing else.
- **Only exception: something actually broken:** unreadable text, a normal
  token painted in the error colour, a regression after a plugin update. Fix
  that one thing, minimally, and stop.
- **At the checkpoint:** at most ONE session, time-boxed to 60 minutes, starting
  from `notes/string-and-member-colours.md` (the parked work is `custom-v4`).
  It ends with a decision either way, including "keep what we have".

Why: 2026-09-24 alone took most of a day (screenshots from 13:57 to 20:22) and
ended where it started, back on the morning's colours. Roughly three months had
already gone mostly into this config. Good enough is the goal, not a compromise.

> **Enforcement (AI agents / Claude Code):** apply the change-gate in
> [`neovim-config-change-gate.md`](neovim-config-change-gate.md) to **every**
> config-change request — run the ROI test (rule #9) first, and reject or defer
> anything that is not functional. Colours are closed outright (above). Default
> answer is *no*.

---

## Rules

1. **Do not change the config on impulse.**
   The default answer to any new idea is **no**. Write the idea as a new file
   under `todos/` and keep working. Never open a config or spec file "just to
   quickly check something."

   - **"It is quick" or "it is easy" is not an exception — it is the trap.**
     Small changes feel harmless *because* they are fast, and that is exactly how
     the bad habit starts. These still count as impulse changes:
     - theme or color changes
     - scroll speed changes
     - small keymap changes
     - option toggles
     - minor visual or preference tweaks

     Add them to `todos/` and handle them later in a scheduled config session.
   - This is **not** the 30-minute fix rule (rule #8). That rule is only for real
     bugs or broken workflows — never for cosmetic or preference changes.

2. **Only edit the config mid-month for critical fixes.**
   A critical fix is a real error, bug, or broken workflow that blocks actual
   work. Do not edit just because something feels nicer, annoying, cleaner, more
   beautiful, or slightly better.

3. **Every new idea needs a plan and a scheduled date.**
   Do not configure something the moment the idea appears. Collect ideas and
   handle them in batches — about once a month, or once every 3–4 months.

4. **Never edit the config directly on `main`.**
   Always switch to a `dev` or feature branch first. Merge back only after the
   change is reviewed, tested, and confirmed safe.

5. **Reserve at least 1–2 hours of focused, uninterrupted time for any change.**
   Do not make config changes in random small breaks. Every change must be
   verified to be safe, stable, complete, and not breaking other parts of the
   editor. Never leave the config in a half-finished state.

6. **Never commit partial or unfinished work.**
   Only commit changes that are complete, tested, and proven safe. A
   work-in-progress commit here can become a broken editor later.

7. **Performance is the top priority.**
   It matters more than new features, polish, or visuals. Before adding anything,
   ask: *how often does this run, and is it synchronous?* Avoid anything that
   adds cost to hot editor paths — keystrokes, cursor moves, and redraws.

8. **Use the 30-minute rule for real fixes only.**
   A real bug that can be fixed in ≤ 30 minutes, I fix myself. Anything needing
   deeper analysis or more time gets delegated — even if the visible issue looks
   small.

9. **Every change must pass an ROI test first (added 2026-09-24).**
   Only functional work qualifies: a real bug, a blocked task, or friction hit
   at least weekly in actual Go/Node work. Estimate the cost honestly (build +
   test, usually ~1 hour) and proceed only if it saves at least that much within
   about a month of normal work. UI tweaks (colours, positions, spacing,
   borders, icons, layout) fail this test by default and go to `todos/`.

   Why: nvim will never be flawless, and every tool has trade-offs (JetBrains
   for polish and deep tooling, VS Code/Cursor for AI with low setup, nvim for a
   terminal-native keyboard workflow). Chasing parity cost about three months.
   DB inspection, schema work, heavy debugging and large refactors stay in
   JetBrains on purpose.

---

## References

The detailed, reasoning-heavy versions of the rules above:

- **Change-gate (AI-facing)** — the necessity check Claude Code applies to every
  change request before touching the config.
  [`neovim-config-change-gate.md`](neovim-config-change-gate.md)
- **Config freeze policy** — default stance, allowed reasons, the batch
  schedule, the Lua-level `:Lazy` lock, and its single-session escape hatch.
  [`notes/config-freeze-policy.md`](notes/config-freeze-policy.md)
- **Safe config editing guide** — the performance-first mindset, hot-path risks,
  risky events/functions/settings, plugin-loading rules, and the pre-commit
  checklist.
  [`notes/safe-config-editing-guide.md`](notes/safe-config-editing-guide.md)
- **Maintenance and delegation** — the full 30-minute rule, and what to handle
  myself versus what to delegate.
  [`notes/config-maintenance-and-delegation.md`](notes/config-maintenance-and-delegation.md)
