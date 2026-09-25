## Neovim Config Change Gate

When I ask you to modify my Neovim configuration, do not immediately proceed.

This gate enforces the discipline in [`rules.md`](rules.md). During an active
**config-freeze window** (see `rules.md`), the bar is even higher — only fixes
that unblock the current workflow are allowed; everything else defers.

First, evaluate whether the requested change is truly necessary.

Only proceed for a **major issue**:

- It fixes something that is blocking my actual development workflow.
- It resolves a serious bug that prevents me from using Neovim properly.

Reject and defer everything else (tightened 2026-09-25). That includes any
request that **adds to or changes** current Neovim functionality or behaviour,
even when it would improve a workflow I already use:

- New config, a new plugin, or a new feature.
- Any change to existing behaviour, defaults or options.
- Colours, themes, highlights (closed outright, see below).
- Keymaps: new, moved or rebound.
- Aesthetic or visual polish, minor UI changes (layout, spacing, borders, icons).
- A minor, non-blocking bug or annoyance.
- A speculative improvement, or a change made because I am distracted or
  over-optimizing my setup.

**Exempt:** changes whose only purpose is to *enforce* this gate or the freeze
(for example the startup reminder in `lua/config/freeze-reminder.lua`). They
protect the rules rather than change the editor.

When you reject a request, **file it yourself**: add a new file under the
matching `todos/` folder (see `todos/README.md` for the folders) with the idea
in one or two lines, and add its row to the README table. Do not edit the
config.

If the request is not truly necessary, do not edit the config. Instead, respond with this message:

> This Neovim change does not seem important enough to work on right now. It is not blocking your workflow or your current priorities.
>
> Your current priorities are Go & backend, Node/TS fullstack + the React portals (your daily work), DevOps & cloud infrastructure, Python, and system design.
>
> I've added this to the `todos/` backlog instead of working on it now: `<path of the new todo file>`.

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
