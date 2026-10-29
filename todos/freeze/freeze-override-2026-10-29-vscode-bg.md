# Freeze-override trace — 2026-10-29 VS Code background

Required by rule 10 in [`discipline-stop-rules.md`](../process/discipline-stop-rules.md).

**The change:** `lua/config/ui.lua` sets `bg` to `#16181d`
(`reference.one_dark_pro_vscode.darker_custom`), the `editor.background` that
VS Code's `workbench.colorCustomizations` applies over One Dark Pro Darker.

**Why it did not wait:** it did not need to. The palette is closed and this is a
colour change. Overridden knowingly ("Change it anyway") after the closed-palette
rule was quoted. `#23272e`, the theme's own value, had been tried first the same
day and read brighter than VS Code, because VS Code overrides it. Scope held to
the one value.

**Outcome, same day: reverted.** A side-by-side trial and a measured comparison
(WCAG, APCA, CIEDE2000, glyph census over ten languages) found no readability
gain and only a small comfort gain, which needs Ghostty and the completion menu
to move with it. Live `bg` is back on `second_darkest` (`#131312`); `#16181d`
stays in `ui.lua` as a reference value. Decision deferred to the checkpoint:
[`../theme/background-16181d-candidate.md`](../theme/background-16181d-candidate.md).
