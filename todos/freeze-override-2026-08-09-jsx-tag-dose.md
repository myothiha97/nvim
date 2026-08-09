# Freeze-override trace — 2026-08-09 JSX tag dose

Required by rule 10 in [`discipline-stop-rules.md`](discipline-stop-rules.md).

**The change, as shipped:** `@tag.delimiter.*` (`<`, `>`, `/`) → neutral. Tag
NAMES stay terracotta, with `@tag.builtin.*` now painted explicitly so both tag
captures always carry the same value.

**What was tried and reverted inside the same session:** sending `@tag` to the
type/sky colour. It measured well (34.7% → 17.5%) and was rejected on two
grounds, one of them a real defect:

- The sky value is reserved for types. Owner's call, stated directly.
- The `@tag` / `@tag.builtin` split does **not** separate HTML elements from
  React components, which was the premise the split was justified with. The tsx
  grammar matches one tag with both captures and query order picks the winner,
  so `<DragAndDrop.Droppable>` rendered as terracotta + grey + sky inside a
  single name. Same class of bug as Lua's `{` being both `@punctuation.bracket`
  and `@constructor`, already documented in the theme file. Finding kept in the
  code comment so it is not rediscovered.

**Why it did not wait for the 2026-09-20 checkpoint:** it could have. Gate
fired, override was explicit. Non-essential change made by choice.

**Why it did not turn into a tuning loop, unlike 2026-08-05:** the magnitude was
a measurement, not a judgement. Punctuation-colour coverage was 34.7% in
markup-heavy TSX against 12.5% in logic-heavy TSX **of the same file** — for
scale, the Lua yellow rejected the same day was 11.6%. The stop rule ("≤ 20%,
then stop") was written before the first edit and the type-colour version hit
17.5% exactly as predicted.

**The stop rule then lost to a preference, which is the right outcome and worth
recording as such.** Shipped state is 30.2%, above the target, because the owner
chose terracotta tags after seeing both. The number was not the decision; it was
what made the trade legible. What the session bought at 30.2% is the delimiter
fix and the unified tag colour, not a dose cut.

**Open, deliberately not acted on:** markup-heavy TSX still sits at 30.2%
against 12.5% for logic-heavy. If that becomes annoying, the ONLY levers that
work are moving whole captures off the colour, and both remaining candidates
(`@variable.parameter`, `@punctuation.bracket`) are 88% of the terracotta in
logic-heavy regions — so taking them would strip the files that already read
well. There is no third option that does not involve a hue the owner has
excluded.

**The rule that made it cheap, worth reusing:** no hex was touched, and none
should be. The terracotta value was already proven acceptable at 12.5% — the
variable was how much of the screen it covered, not what colour it was. Framing
it as a dose problem meant there was nothing continuous to nudge, only a
discrete "which captures belong on this colour" decision.

**Verified, not assumed:** Lua measured byte-identical before and after (every
row, including mark counts), because every group moved is language-scoped to
tsx/javascript/html/vue. Logic-heavy TSX also unchanged at 12.5%.
