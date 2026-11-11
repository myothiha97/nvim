# Config Freeze Policy — Detailed

> **⏸ SUSPENDED 2026-11-11 (Myo).** The freeze, the palette closure and the
> freeze-override traces (rule 10) are off while the open issues and IDE-parity
> features are worked through. Changes still follow the performance and safety
> rules. Myo will set a new freeze window when that work is done; until then,
> treat this policy as history, not as active rules.

The full version of the freeze rule summarized in [`../rules.md`](../rules.md).
Core setup is stable and already has every feature and plugin needed for a
standard IDE. From this point the config is **frozen by default** — changes are
the exception, not the routine.

> Established 2026-05-24. The freeze is the single most important discipline in
> this repo: nvim tinkering is a known time sink, and an unfrozen config quietly
> eats the hours owed to professional work.

---

## The default stance

Don't touch the config. Even when I read about an "amazing" plugin, a cleaner
pattern, or a tempting refactor — the answer is **no**. Capture it and move on:

- New feature ideas / "would be nice" items → a new file under `todos/`, one
  task per file. (The old single `todo.md` list is retired.)
- Do **not** open a plugin spec file "just to take a quick look." That is
  exactly how the time sink starts — one look becomes an afternoon.

## The only allowed reason to edit mid-month

A must-fix that is **critical to current work**: an actual error, bug, or broken
workflow that is blocking or actively impacting real work. Nothing else
qualifies. "This could be nicer," "this is annoying," "this would be cleaner" do
not justify a mid-month edit — they wait for the batch.

## Cadence — batch the rest

All "would be nice" configuration, optimization, and customization happens in a
single focused batch session:

- Roughly **once a month**, possibly every **3–4 months**.
- Everything accumulated in `todos/` gets triaged and done together, then the
  config goes back to frozen.

Batching keeps context-switching cost low and prevents a steady drip of small
edits from becoming a constant background distraction.

## How the freeze is enforced (not just willpower)

The freeze is enforced at the Lua level, not left to discipline alone:

- `:Lazy update` / `:Lazy sync` / `:Lazy restore` are **blocked**. See
  [`lua/config/lazy-freeze.lua`](../lua/config/lazy-freeze.lua).
- Plugins are therefore version-pinned and stable between batches — which is
  also what makes the config's internal monkey-patching safe to rely on.

### Escape hatch for the monthly batch

When it *is* batch time and I genuinely need to update plugins:

```
NVIM_LAZY_UNLOCK=1 nvim
```

then `:Lazy sync`. This unlocks for that **single session only** — the next
plain `nvim` is locked again. No permanent unlock, by design.

## Why this exists

nvim config tinkering is a known, recurring time sink and a distraction from the
actual coding work. The freeze converts "I'll just tweak one thing" from a
reflex into a deliberate, scheduled decision — so config time never bleeds into
time owed to the professional job.
