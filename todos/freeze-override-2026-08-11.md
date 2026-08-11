# Freeze-override trace — 2026-08-11 syntax palette session

Required by rule 10 in [`discipline-stop-rules.md`](discipline-stop-rules.md).

**The change:** the largest single session inside this freeze, in five parts —

1. Logical operators (`&&`, `||`, `??`, `!`) moved onto the keyword colour in
   TS/TSX/JS, Go and Bash, via five new `after/queries/` files.
2. The punctuation role moved from terracotta `#b55f4a` to copper `#be6421`.
3. The theme split into four named builds (`-original`, `-custom-v1/v2/v3`) so
   what we run is no longer mistaken for stock.
4. `scripts/palette/` added — measuring tools so future colour questions are
   answered with numbers instead of another session of nudging hexes.
5. Comment cleanup across the theme files, plus a root `AGENTS.md`.

**Why it did not wait for the 2026-10-20 checkpoint:** mostly it should have.
Being honest about each part:

- **Part 1 defends itself.** It was an inconsistency, not a preference: the
  config already painted `and`/`or`/`not` as keywords in Python and Lua while
  `&&`/`!` fell through to body text in Go and TS. Same shape as the
  `@punctuation.delimiter` fix closed on 2026-08-10.
- **Part 2 is a preference change**, exactly the category rule #1 names. It did
  fix two recorded defects (the palette's only sub-AA colour, and its tightest
  pair against the error red), but those had been known and accepted for weeks
  and were not blocking anything. It ran for hours across three separate colour
  ladders, two of which were built on the wrong axis and thrown away.
- **Parts 3–5 are cheap and durable**, and would not have happened without 2.

**What it cost:** most of a day. The measurable outcome is a palette −17% in
weighted chroma against upstream and two defects retired. The unmeasurable one
is the day.

**The pattern worth naming.** Three times in that session a complaint about
"brightness" turned out to be about chroma, and each time a ladder was built on
the named axis before being discarded. That is now recorded in
`notes/syntax-palette-decisions.md` and in `scripts/palette/README.md`, and it is
the main reason the session produced tools rather than only a colour.

**Consequence:** the freeze was extended from 2026-09-20 to 2026-10-20 on the
same day. See the note under the freeze window in [`rules.md`](../rules.md) —
time spent inside a freeze buys more freeze, not less.

**Still open, deliberately:** item 8 in
[`syntax-palette-followups.md`](syntax-palette-followups.md) — `Type` is the one
role not optimised. It was left alone on purpose rather than extending the
session further, and the trap that makes it hard is written down so the next
attempt does not re-derive it.
