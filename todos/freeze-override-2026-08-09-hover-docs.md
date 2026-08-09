# Freeze-override trace — 2026-08-09 hover-doc readability

Required by rule 10 in [`discipline-stop-rules.md`](discipline-stop-rules.md).

**The change:** two edits to LSP hover docs — dim the description prose, and put a
blank line back between the signature block and the description.

**Why it did not wait for the 2026-09-20 checkpoint:** it could have. The gate
fired, the override was explicit. Recorded as a non-essential change made by
choice, not an unblocking fix.

**Why it is still a cheap one, unlike 2026-08-08:** the magnitude was decided by
measurement before any edit, not by nudging hexes. The prose was measured at
L\* 73.7 against a signature at L\* 59.1–69.0 — brighter than the thing it
describes, an inverted hierarchy rather than a taste question. The replacement
is an existing ramp step (`c.fg`), picked because the step below it (`base00`,
4.11:1) fails WCAG AA for body text. There is no hex-by-hex loop available here:
the ramp has one usable value between "too bright" and "under AA".

**Scope limit set before starting:** two edits, no width change, no new plugin,
no new highlight group. Font size was checked first and is impossible in a
terminal (`fontsize`/`scale` are invalid `nvim_set_hl` keys; only `altfont`
exists and it selects a face, not a size), so the design space was closed before
any tuning could start.
