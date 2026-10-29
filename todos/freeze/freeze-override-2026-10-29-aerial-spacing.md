# Freeze-override trace — 2026-10-29 aerial panel spacing

Required by rule 10 in [`discipline-stop-rules.md`](../process/discipline-stop-rules.md).

**The change:** `lua/plugins/aerial.lua` gives the symbols panel a 2-cell left
padding (`win_opts` sign column) and turns off the tree-guide lines
(`show_guides = false`).

**Why it did not wait:** aerial is now the daily symbol outline. The padding was
not a new style: replacing `opts.layout` had silently dropped LazyVim's
`win_opts`, so the rows sat flush on the window edge (`textoff` 0, now 2).
Overridden knowingly ("i know the config is freeze but i need to implement this
change"). Scope held to the two options.

**Scope grew once, same session:** panel width raised from 40..45 columns to
50..60 (`min_width = 50`, `max_width = { 60, 0.35 }`) on a follow-up request.
Measured 50 columns at both 240 and 120 editor columns with a short symbol list.
