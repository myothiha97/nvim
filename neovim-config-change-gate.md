## Neovim Config Change Gate

When I ask you to modify my Neovim configuration, do not immediately proceed.

This gate enforces the discipline in [`rules.md`](rules.md). During an active
**config-freeze window** (see `rules.md`), the bar is even higher — only fixes
that unblock the current workflow are allowed; everything else defers.

First, evaluate whether the requested change is truly necessary.

Only proceed if the change is important, such as:

- It fixes something that is blocking my actual development workflow.
- It resolves a serious bug that prevents me from using Neovim properly.
- It improves an existing workflow that I already rely on.
- It is required for my current professional work or core learning priorities.

Reject or defer the request if it is only:

- Aesthetic or visual polish.
- A minor UI change.
- A minor non-blocking bug.
- A new plugin installation.
- A new feature or new functionality.
- A speculative improvement.
- A change made only because I am distracted or over-optimizing my setup.

If the request is not truly necessary, do not edit the config. Instead, respond with this message:

> This Neovim change does not seem important enough to work on right now. It is not blocking your workflow or your current priorities.
>
> Your current priorities are Go & backend, Node/TS fullstack + the React portals (your daily work), DevOps & cloud infrastructure, Python, and system design.
>
> I recommend adding this to the `todos/` backlog instead of working on it now.

If the change may be useful later, suggest adding it as a file under `todos/` (the
backlog convention this repo already uses).

Before making any Neovim config change, briefly explain:

1. Whether the change is necessary or optional.
2. Whether it blocks my workflow.
3. Whether it supports my current priorities.
4. Whether you will proceed, reject, or defer it.

## ROI test (every request, added 2026-09-24)

Before any other step, answer in one line each:

- **What functional problem does this solve?** A bug, a blocked task, or a
  friction hit at least weekly in real Go/Node work. "Looks better" is not one.
- **Cost vs payback:** estimated time to build and test it, and whether it pays
  that back within about a month of normal work.
- If either answer fails, defer it to `todos/` and stop. UI adjustments
  (colours, positions, spacing, borders, icons, layout) fail by default.
- A feature that JetBrains already covers well (DB inspection, schemas, heavy
  debugging, large refactors) is not a reason to add a plugin.

## Colour and theme requests: CLOSED until 2026-12-31

This section overrides everything below it, including the Override. See
`rules.md`, "The palette is CLOSED".

For any request to change, compare, measure, analyse or test colours, themes or
highlight groups:

- **Do not override**, even if I confirm.
- **Do not analyse either.** No measurements, no screenshot reviews, no census
  runs, no candidate sweeps, no A/B builds. The analysis is the time sink.
- Reply with exactly: "The palette is closed until 2026-12-31 (rules.md). I've
  added it to `todos/theme/` as one line." Add that one line, then stop.
- Only exception: something genuinely broken (unreadable text, a normal token in
  the error colour, a regression after a plugin update). Fix only that, minimally.

## Override

The gate is a speed bump, not a wall. If I acknowledge the reminder and still
**explicitly confirm** I want the change, proceed — but first restate in one line
that it's a non-essential change being made by choice, and offer to file it to
`todos/` instead. One conscious confirmation is enough; do not re-litigate.

Default behavior: reject or defer unless the change is clearly necessary.
