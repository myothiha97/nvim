# Discipline: add stop rules to `rules.md`

**For the 2026-10-20 checkpoint session. ~10 minutes, doc-only, touches no Lua.**

Filed 2026-08-05 after a session that produced three genuinely correct findings and
then spent most of its time past the point where any further change was visible.

## The gap this closes

`rules.md` and `neovim-config-change-gate.md` are good at deciding **whether to
start**. They both fired correctly on 2026-08-05: the request was gated, deferred,
and filed to `todos/`. Neither has anything that decides **when something is
finished**, and that is where the time actually went.

The evidence from that session, since this should not be argued from memory:

- The CodeCompanion chat prose took four values in one evening: `#d4d4d4` ->
  `#b0b0b0` -> `#c4c4c4` -> `#bbbbbb`.
- The last two moves were 2.5 and 3.1 L\*, both under the ~5 L\* floor where a
  change on text glyphs becomes visible at all. Past that point the tuning was
  repetition, not information.
- What actually ended it was not willpower and not the freeze policy. It was a
  number with a floor attached: "one hex step is 0.28 L\*, about 18x below what the
  eye can resolve." That removes the question instead of asking for restraint.

## The direction/magnitude split

Worth writing into the rules as the reason, because it is the useful part:

Across that whole session the eye was **right every time on direction** (too bright,
too faded, too visible) and **never reliable on magnitude**. Every loop happened on
magnitude, never on direction.

So: trust the eye to say something is wrong. Do not trust it to say how much. Hand
magnitude to a measurement and the loop has nothing left to feed on. This is not
"care less about detail" — the detail sense found all three real problems.

## Ready to paste into `rules.md`

Add as rules 9 and 10, then link this file from the References section.

```markdown
9. **Every visual change states its stop condition as a number, before the first edit.**
   Not after it looks wrong for the third time. A stop condition is a measured
   quantity plus a floor, e.g. "target effective L\* 58 +/- 1, and note that one hex
   step is 0.28 L\*, ~18x below the ~5 L\* perceptual floor for text glyphs."

   - Trust the eye for **direction** (too bright, too dim, too visible). Do not trust
     it for **magnitude** — that is what measurement is for. Every loop in the
     2026-08-05 session was a magnitude loop; the direction calls were all correct.
   - Measure the RENDERED value, not the nominal hex. A theme colour is a ceiling the
     rasterizer rarely reaches. Method: `sips -s format bmp`, parse in plain Python
     (no PIL or ImageMagick on this machine), least-squares each pixel against the
     `background -> foreground` line to recover glyph coverage.
   - For two surfaces on screen at once, the invariant is the **gap between them**,
     never either one's absolute value.
   - When a candidate is inside its stated floor, it is DONE. Further nudging cannot
     improve it, only restart the loop.

10. **Using the change-gate override costs something.**
    The gate in `neovim-config-change-gate.md` may still be overridden, but the
    override must be **written into `todos/` first**, as one line naming the change
    and why it cannot wait for the next scheduled session. One conscious
    confirmation stays the rule; what changes is that it leaves a trace.

    Why: on 2026-08-05 the gate worked exactly as designed and was then overridden
    five times in one evening at zero cost. The gate was never the weak point. The
    free override was.
```

## Also fix while in here

- **Rule 4 is now stale.** It says "Never edit the config directly on `main`. Always
  switch to a `dev` or feature branch first." As of 2026-08-05 the workflow moved to
  working on `main` directly (`dev` was merged and fast-forwarded). Either update
  rule 4 to match, or go back to branching. Right now the rulebook contradicts the
  actual workflow, and the change gate cites `rules.md` as its source of truth.
- Add this file to the References list in `rules.md` so the reasoning stays findable
  once the rules themselves are compressed to one line each.

## Scope guard

Doc-only. Do not let this session turn into a config session. Nothing here edits
Lua, and no colour is to be reopened while doing it.
