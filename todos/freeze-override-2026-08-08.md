# Freeze-override trace — 2026-08-08/09 syntax palette session

Required by rule 10 in [`discipline-stop-rules.md`](discipline-stop-rules.md): the
change-gate may be overridden, but the override leaves a trace.

**The change:** retuned the solarized-osaka syntax palette (keyword, types,
brackets, properties, doc-float chrome) and decoupled syntax colours from UI.

**Why it did not wait for the 2026-09-20 checkpoint:** it did not need to. The
gate fired, and the override was explicit — "for now forget about the freeze".
This is a non-essential change made by choice, not an unblocking fix.

**What it cost:** one evening, ~5 hours, well past the point where individual
colour steps stopped returning information.

**What it bought**, so the trade is on the record:

- Three real bugs found and fixed, none of them cosmetic: syntax colours were
  repainting git-added signs and the lualine marker via the shared `c.green500`
  ramp; `Keyword` was not reaching the treesitter captures that actually paint
  code; and `@constructor` was recolouring every Lua table brace as a side
  effect of a rule reasoned from TSX, which does not use that group.
- The palette file went from 73% comments to a data table, with the reasoning
  moved to `notes/syntax-palette-decisions.md`.

**Lesson for the next session, and the reason this file is worth keeping:** the
useful findings all came from *measuring coverage* — which captures a colour
actually paints, and how much of a real file it covers. The parts that burned
time were hex-by-hex tuning, where the eye was reliable on direction and useless
on magnitude, exactly as rule 9 predicts.
