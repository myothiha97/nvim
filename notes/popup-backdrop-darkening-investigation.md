# Why every popup darkens the whole editor

Investigation of the 2026-08-21 report: *"whenever any popup window appears, the
Neovim background gets completely darkened"*.

The symptom is not in the file browser and not in the colorscheme. It is a
**transparency mis-detection inside snacks.nvim, triggered by telescope**, and it
poisons the whole session.

---

## STATE — read this first (2026-08-21, ~03:00)

**Resolved.** Both fixes applied, verified in a real terminal, and **committed**
(`2099ded`). Later work moved to `trial/file-explorer-test`, where the browser is
now a snacks picker and telescope is parked; the fix below is unaffected and
stays. See the 2026-08-21 evening update at the end of this section.

| file | change |
| --- | --- |
| `lua/plugins/snacks.lua` | `backdrop = false` in `picker.layout.layout` **and** in `sources.grep.layout.layout` |
| `lua/plugins/telescope-file-browser.lua` | the custom dim **deleted**; stay-open watcher kept; `l` selects, `<C-l>` / `<C-h>` dead |
| this file | the investigation |

### Two rules for future sessions

1. **Do not add a dim/backdrop behind the file browser.** Telescope has no such
   feature, craftzdog's config (the style source) has none, and one cannot work
   with `transparent = true`: a `#000000` float has nothing to blend against, so
   it emits raw black at *every* `winblend`. Measured — blend 80 and blend 0 both
   sent `#000000` with zero default-background cells; removing the dim took
   `#000000` emissions from 268 to 0. This mistake has already been made twice.
2. **Do not re-enable snacks' picker backdrop.** Same physics: measured 371
   `#000000` cells for a picker over a plain file. With correct detection snacks
   would draw no backdrop at all for a transparent theme, so `backdrop = false` is
   not an override — it pins snacks to what it would already do if it could read
   the theme. (Originally written as "while telescope is in the config"; telescope
   has since gone and the rule still holds, see the update below.)

### Scope of the snacks fix — it is the trial's dependency, not a standalone fix

The snacks fragility was **latent** in this config until telescope arrived. Only a
float that remaps `Normal` can poison the sample, and before the trial there was
none that gets focused in normal use. Measured with the backdrop re-enabled, i.e.
the config as it stood before the fix:

| pre-trial workflow | veil | focused window's `Normal` remap |
| --- | --- | --- |
| one picker over a file | none | — |
| grep opened from inside another picker | none | — |
| picker over oil | none | — |
| picker over the snacks explorer | none | — |

`is_transparent` read `true` in all four: snacks' own input/list windows use
`NormalFloat:…`, not `Normal:…`, so snacks skipped its own backdrop correctly.
That is why the darkening only started the night telescope landed.

Consequence, as written at the time: if telescope goes, the two `backdrop = false`
lines could go with it.

### Update 2026-08-21, evening — the two lines stay

Telescope did go (`lua/plugins/telescope-file-browser.lua` is parked at
`ENABLED = false`, which leaves telescope itself uninstalled) and the browser was
rebuilt as a snacks picker in `lua/plugins/snacks-file-browser.lua`. The lines are
kept anyway, and the reasoning above is why: the *one remaining route* it called
cheap insurance is not going anywhere. The lazy.nvim UI sets
`Normal:LazyNormal` with the theme's opaque `bg_float`, ships with the config, and
is focused often enough (`:Lazy`, then any picker key inside it) to poison the
sample for the rest of the session. The new browser cannot cause the problem — a
snacks picker uses `NormalFloat:…`, which is exactly the case measured as clean
above — so this is no longer a trial dependency at all. It is a standing fix for a
latent snacks bug, and it costs nothing on a transparent theme.

### Open follow-up

Worth reporting upstream to folke/snacks.nvim: `Snacks.util.is_transparent()`
reads `Normal` in whatever window is current, so any plugin whose float remaps
`Normal` through `winhighlight` poisons the detection for the session. Nothing in
this config depends on that being fixed any more.

---

## TL;DR

1. `Snacks.util.is_transparent()` decides whether snacks draws a full-screen
   black veil behind its popups. It samples `Normal`'s background **once** and
   caches the answer for the session.
2. `nvim_get_hl(0, { name = "Normal" })` is resolved **in the context of the
   current window's `winhighlight`**. Telescope's floats set
   `winhighlight = Normal:TelescopePromptNormal`, so a read taken while a
   telescope float is focused returns `#001419` instead of `NONE`.
3. So the first snacks popup opened **from inside the file browser** makes snacks
   conclude "this colorscheme is opaque" and start drawing
   `snacks_win_backdrop`: whole editor, `bg = #000000`, `winblend = 60`.
4. With `transparent = true` there is nothing else painting the background, so
   the editor goes near-black. The veil sits at **zindex 51**, one above
   telescope's floats at **50**, so it also covers the browser itself — which is
   why the browser looked like it had vanished and "reappeared" when the picker
   closed.
5. The cached verdict is only reset by a `ColorScheme` event, so **every popup
   for the rest of the session gets the veil**, even after the browser is gone
   and even in a window that has nothing to do with telescope.

oil.nvim is immune because it is a normal window and never remaps `Normal`, so
the sample taken over oil reads `NONE` and snacks draws no veil at all.

## The browser is not the only trigger

`Normal:SomethingNormal` in `winhighlight` is a common pattern, so several UIs
can poison the sample. Measured by focusing each one and taking the same read
`is_transparent()` would take:

| UI | its `winhighlight` | `Normal.bg` read there | effect |
| --- | --- | --- | --- |
| plain file window | — | `NONE` | safe |
| telescope file browser | `Normal:TelescopePromptNormal` | `#001419` | **poisons** |
| lazy.nvim UI (`:Lazy`) | `Normal:LazyNormal` | `#001419` | **poisons** |
| snacks explorer | — | `NONE` | safe |
| snacks picker input | — | `NONE` | safe |
| oil | — | `NONE` | safe |
| trouble symbols | — | `NONE` | safe |
| mason | — | `NONE` | safe |

Two consequences worth being clear about:

- The veil shows up **with the browser closed, and in sessions where the browser
  was never opened** — `:Lazy` alone is enough. That matches the report that it
  happens when the browser is not active.
- Removing telescope would **not** fix it. `:Lazy` is unavoidable in this config,
  so the trigger cannot be designed away; only the dependence on the detection
  can.

Only snacks windows configured with a backdrop take the sample (`Snacks.win:drop`
returns early otherwise), which is why pickers, `Snacks.input` and the lazygit
terminal are the ones that matter and notifications are not.

## The measurements

All runs are `nvim` inside a real pty at 190x50 with this config, driven by
`vim.api.nvim_feedkeys`. A pty matters: headless at 80x24 picks a snacks layout
that has no backdrop, which is why this hid for so long.

### `Normal` is window-context sensitive

Browser open, read from two different windows in the same instant:

| read from | `Normal.bg` |
| --- | --- |
| the telescope float (`winhighlight = Normal:TelescopePromptNormal`) | `#001419` |
| the plain file window | `NONE` |

The float's own highlight namespace is 44 and `Normal` inside it is `NONE`, so
the value comes from `winhighlight` remapping, not from a namespace.

### Which explorer flips it

| action | `Normal.bg` |
| --- | --- |
| open telescope file browser | `NONE` → `#001419` |
| close it with `q` | back to `NONE` |
| open oil | no change |
| open snacks explorer | no change |

`#001419` is exactly this theme's `NormalFloat.bg`.

### Startup path decides the whole session

| startup | `Normal.bg` timeline | cached verdict | result |
| --- | --- | --- | --- |
| `nvim <file>` | `NONE` throughout | `is_transparent = true` | no veil, ever |
| `nvim .` (browser opens) | `NONE` at 158ms → `#001419` at 228ms | `is_transparent = false` | veil on every popup |

### The real-world sequence, reproduced exactly

| step | veil |
| --- | --- |
| 1. `<leader>e` opens the browser | none |
| 2. `<leader><leader>` **from inside the browser** | **VEIL** (z51, blend 60) |
| 3. close both, later open any picker from a plain file window | **VEIL** (sticky) |

Step 2 is the moment of poisoning: snacks calls `is_transparent()` while
building its layout, before it enters its own window, so the current window is
still the telescope prompt.

Control: with the browser never opened, a picker in the same session shows **no
veil**. So the veil is not normal behaviour for this theme — it is the bug.

### Confirming it on the real machine

In a session where the background *is* darkened behind popups:

```vim
:doautocmd ColorScheme
```

That fires snacks' own cache-reset autocmd. Then open a picker **from a normal
window** (not from the browser) and the veil should be gone until something
poisons the sample again. Cheap way to confirm this diagnosis in Ghostty rather
than in a pty.

## Why it started on 2026-08-20 night

"Everything was fine this morning until I tweaked the browser and explorer
background colours" is right about *when* and wrong about *what*. The colour work
is not implicated:

- The float background that arms the bug is the **theme's**:
  `solarized-osaka/groups/telescope.lua` sets `TelescopeNormal = { bg = c.bg_float }`,
  and `bg_float` is `base04` = `#001419` because `styles.floats` is never set.
  Telescope links `TelescopePromptNormal` → `TelescopeNormal`. True since long
  before that day.
- The only `snacks.lua` change in the trial commit (`1bbf2bd`, 23:31) was
  `replace_netrw = false`. Nothing about colours or backdrops.
- That commit introduced **telescope into this config for the first time**. Before
  it, nothing here remapped `Normal` in a float that gets focused routinely.

`:Lazy` is the only other trigger and it really does poison — verified, `:Lazy`
then `<leader><leader>` produces the veil — but it requires pressing a picker key
inside the Lazy UI, which does not happen in normal use. The browser is focused at
startup in every session and `<leader><leader>` is pressed from inside it
constantly.

So the trial did not create the defect. It made a latent defect fire on the most
common keystroke in the workflow.

### Ruled out: transparent floats

Setting `styles.floats = "transparent"` in the theme opts makes `bg_float = none`,
which removes the poison fuel entirely. Rejected: it makes every float
see-through, and the reasoning already recorded in
`lua/colorschemes/solarized-osaka/init.lua` is that float separation here comes
from the border and a brighter foreground. That trades readability everywhere for
one detection bug.

## Why every earlier theory was wrong

- **"Our browser dim stacks with snacks' dim."** Real but minor: ours is at
  zindex 40, *below* telescope's floats, so it never darkened the browser. It
  only ever dimmed the origin window. Removing it changed nothing about the
  black screen.
- **"The browser closes on `<leader><leader>`."** It does not, not since the
  `BufLeave` fix. It stays mounted the whole time; the veil simply covers it.
  Verified: `TelescopePrompt` and `TelescopeResults` are still in the window list
  while the picker is up, and a 14-second wait before pressing changed nothing.
- **"snacks skips its backdrop for transparent themes, so there is no veil."**
  True in principle, and that is exactly the code path that misfires here.

## Fix options

Nothing below is implemented. Ordered by how airtight they are.

### A. Turn off snacks' picker backdrop — one line, airtight

`backdrop` lives inside the layout table (several built-in layouts such as
`sidebar` already set it), so in `lua/plugins/snacks.lua` inside the existing
`picker = { … }` block:

```lua
layout = { layout = { backdrop = false } },
```

Verified against a deliberately poisoned session — same run, only this line
differing:

| | picker opened from the browser | any later picker |
| --- | --- | --- |
| baseline | **VEIL** | **VEIL** (sticky) |
| with the line | no veil | no veil |

In the fixed run `is_transparent()` was still wrongly `false` and it no longer
mattered. That is what makes this airtight rather than a workaround: it does not
depend on sampling order, on which window was focused, or on telescope's and
lazy's `winhighlight` ever changing.

With correct detection snacks would draw no veil for this theme anyway (see the
control run), so this only makes that the guaranteed outcome. Scope: pickers
only; `Snacks.input`, `Snacks.notifier` and lazygit floats keep their own
`backdrop` settings.

**Applied 2026-08-21** inside the existing `picker.layout.layout` table in
`lua/plugins/snacks.lua`, next to `width`/`height`.

Two traps found while applying it:

- `picker = { … }` already had a `layout` key near the end of the table. A second
  `layout` key earlier in the same Lua constructor is **silently dropped** — the
  option looked applied, `stylua` and `loadfile` were happy, and
  `Snacks.config.picker.layout` still showed no `backdrop`. It has to go inside
  the existing table.
- A **per-source** layout *replaces* the global one instead of merging, because
  `Snacks.picker.config.layout` skips preset resolution once
  `layout.layout[1]` exists (a positional box entry). So `sources.grep`, which
  defines its own box, keeps the veil until the same line is added there.

So the line is written **twice**: once in the picker-wide `layout.layout`, and
once inside `sources.grep`'s own box layout. Any future source that spells out
its own `box` needs it too.

Swept every picker keymap in a deliberately poisoned session (`is_transparent`
still `false`, so the detection is as broken as ever and no longer matters):
smart, buffers, files, recent, grep, grep-word, keymaps, help and explorer are
all clean. `<leader>ss`, `<leader>xd`, `<leader>xD` and `<leader>gl` open no
window in that buffer — they notify "cannot proceed" instead (no LSP client, no
diagnostics, no git log), so there is nothing to veil.

### B. Pre-warm the cache while a normal window is focused

Sample once early, before any telescope float can be current:

```lua
pcall(function() require("snacks").util.is_transparent() end)
```

Measured working: pre-warming in the `nvim .` path gave `is_transparent = true`
and the picker over the startup browser had no veil. But it is order-dependent —
a later `ColorScheme` (theme switch) clears the cache, and the next sample could
again land while the browser is focused. Works, less airtight than A.

### C. Report it upstream to folke/snacks.nvim

`is_transparent()` reads `Normal` in whatever window happens to be current. Any
plugin whose float remaps `Normal` through `winhighlight` — telescope does, and
nui-based UIs can — poisons the detection for the rest of the session. A robust
read would evaluate `Normal` outside the current window's `winhighlight`, and
the cache would ideally not be a one-shot. Worth filing regardless of what we do
locally, since it affects every transparent-theme user of both plugins.

### D. Stop using telescope — does **not** fix this

Listed only to rule it out. `:Lazy` remaps `Normal` the same way, so the veil
would still happen in a telescope-free config. The browser is a trigger, not the
defect, and it is not the only trigger.

Separately, and unrelated to the veil: keeping the browser alive under another
picker needs two hacks that oil gets for free by being a buffer. That is a fair
point to weigh when judging the trial on its merits — but it is not this bug.

## State of the working tree when this was written

`lua/plugins/telescope-file-browser.lua` is modified and **uncommitted**. Those
changes are unrelated to the root cause above and stand on their own:

- `<leader><leader>` (and any other picker) no longer kills both the browser and
  the picker. Telescope's self-destruct `BufLeave` is cleared and a single
  `WinEnter` watcher decides teardown: focus on the prompt or a foreign float
  means stay, a real window means close. The decision is confirmed one tick
  later so a transient focus flicker cannot tear it down, and the watcher deletes
  itself with the picker.
- The dim was removed, then put back on request, now following focus instead of
  the picker's lifetime: dropped while a foreign float is in front, restored when
  the browser has focus again.
- Normal-mode `l` selects (enter directory / open file); `<C-l>` and `<C-h>` are
  both dead; `h`, `-` go to the parent.

## Reproducing any of this

The probes live in the session scratchpad, not in the repo:

- `run.py <seconds> <nvim args…>` — pty runner at 190x50, hard-kills on deadline.
- `trap2.lua` / `trap3.lua` / `trap4.lua` — poll `Normal.bg`, compare per-window
  reads, log `ColorScheme` events.
- `exp3.lua` — the three-step real-world reproduction.
- `fbdiag.lua` — 40-second recorder meant for a live Ghostty session; logs to
  `~/fbdiag.log`. Never run, the pty repro made it unnecessary.
