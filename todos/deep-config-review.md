# Deep config review — PHASE 0 DONE, PHASES 1-4 DEFERRED

**Status: phase 0 done 2026-10-26, including the insert-mode measurement (baseline in `deep-config-review-baseline/`). Phases 1-4 are DEFERRED to the 2026-12-31 checkpoint (decided 2026-10-26: production work starts in November, and findings could not be fixed before then anyway). Run them with Sonnet; use Opus only to verify serious findings.**
**Plan refreshed 2026-10-24** against the live config: sizes, line ranges, phase 2
and the skip list were stale (CodeCompanion is now disabled, Copilot is live).
**Estimated: 4 sessions.** Do not try to do it in one.

This is the real review that [`config-audit-2026-09-09.md`](config-audit-2026-09-09.md)
is **not**. That one was a grep-driven pattern sweep over ~800 of 12,613 lines
(about 5%; the config is 14,821 lines across 61 files on 2026-10-24), blind to anything its patterns did not name, and it did no
correctness review at all. Read its SCOPE section first, then treat its verdict
as covering only the classes it lists.

---

## 1. Objective and non-objective

**Objective.** Read the live config end to end and find defects the pattern sweep
structurally could not: logic bugs, API misuse, dead branches, broken failure
paths, lifecycle leaks, and decisions duplicated across files that can drift apart.

**Non-objective.** This is not a redesign, not a refactor, and not a tidy-up.
Do not propose changes because something reads oddly. The config is full of
deliberate, measured decisions that look wrong without their history — several
are documented precisely because a previous session "fixed" them by mistake.

**Output is findings, not commits.** Fix nothing during the read. Fixes are a
separate, agreed pass at the end.

---

## 2. Read these before touching anything

In this order. Skipping them is how a reviewer produces confident wrong findings.

1. `CLAUDE.md` (repo root) — the entry point, the live palette table, the two
   structural traps, the file-browser history.
2. `rules.md` — discipline rules and the active config-freeze window.
3. `neovim-config-change-gate.md` — decides whether a proposed change should
   happen at all. **Apply it to every finding before writing it down.**
4. `docs/CLAUDE.md` — the canonical doc, including the Performance Rules.
5. [`../notes/silent-failure-surfaces.md`](../notes/silent-failure-surfaces.md) —
   places that accept a wrong value and do nothing. The note was written at
   fifteen; `rg "WARN: SILENT" lua/` finds 33 markers on 2026-10-24.
6. [`config-audit-2026-09-09.md`](config-audit-2026-09-09.md) — what is already
   known, so you do not re-derive it.

---

## 3. Rules of engagement

**Read whole files, in order, top to bottom.** Do not grep-and-skim. Skimming is
exactly what produced the shallow pass, and these files are dense with comments
that change the meaning of the code below them.

**A comment is a claim, not evidence.** This config's comments are unusually
detailed and mostly accurate, but several were found contradicting the code on
2026-09-09. When a comment asserts a number or a behaviour, verify it or mark the
finding as unverified.

**A clean test proves nothing unless it can detect the broken state.** Before
believing any check, run it once against a deliberately broken version. If it
cannot tell the two apart, it is worthless. This has already produced false
"working" results in this repo.

**Headless nvim never loads `config/keymaps.lua`** — it is gated on
`VeryLazy`/`UIEnter` — so keymap probes falsely report NOT MAPPED. Always run a
control before believing a negative.

**Do not review dead code line by line.** Confirm the gate still holds, then move
on. See the skip list in phase 5.

---

## 4. Phases

### Phase 0 — Baseline (30 min, do once)

Capture what "unchanged" means so any later fix can be proven safe.

- [x] Snapshot all highlight groups. The method from 2026-09-09:
      dump `nvim_get_hl` for every name in `getcompletion("", "highlight")`,
      sorted, to a file. **Filter out `lualine_[abcxyz]_<n>_*`** — those numbers
      are allocation counters that shift without any colour changing, and they
      will produce a false diff.
- [x] Snapshot startup: `--startuptime`, 5 runs. Current baseline is **~50 ms**,
      slowest entry `require('config.lazy')` at 23.7 ms.
- [x] Snapshot the keymap table for `n`, `i`, `v`, `t` from a **non-headless**
      instance, or accept that keymaps.lua findings cannot be probed headlessly.
- [x] Confirm a clean boot: `XDG_STATE_HOME=/tmp/nvs XDG_CACHE_HOME=/tmp/nvc nvim --headless '+qa'`.
- [x] Added 2026-10-26: measure insert-mode cost (per-keystroke time with
      blink.cmp and Copilot loaded) in a Go, TS, Bash, Python, Rust, C/C++ and
      C# file. Phase 0 only measured normal mode, because both load on first use.
      Record per language which LSP attached: C/C++ (`clangd`) and C# have no
      extra enabled in `lazyvim.json` (deferred to 2027+), so those two measure
      blink + Copilot + treesitter without an LSP. Say so next to their numbers.
      **Done 2026-10-26**, results in `deep-config-review-baseline/insert-mode-results.txt`
      and the findings file: normal files are fast in every language.
- [x] Added 2026-10-26: run `nvim --startuptime /tmp/s.log +q` once in Ghostty
      and check `require('vim._core.defaults')`. It took 114 ms in the test
      terminal (likely a terminal query timing out there, not the config).
      **Done 2026-10-26:** 15 ms in a real tmux pane. The 114 ms was the test pty.

### Phase 1 — `lua/config/keymaps.lua`, 943 lines (1 session)

The most-touched surface in the config, and the one most likely to hold a real
defect. Known structure worth reviewing as units:

| lines | area | what to question |
| --- | --- | --- |
| 24–212 | float styling helpers (`sync_float_nontext_hl`, `hide_float_marker`, `style_doc_float`, `float_content_wraps`, `space_after_code_fences`) | width/wrap arithmetic, off-by-one on borders, behaviour on a zero-width or huge window |
| 213–370 | `hover_opts` and the `<Esc>` handler | the `vim.schedule` E565 workaround — is every mutation actually inside the schedule? |
| 371–464 | `scroll_popup_or`, `is_editor_window`, `editor_scroll_or_arrow` | which window wins when several floats are open; the documented "scrolled oil instead of the picker" class of bug |
| 465–509 | the `<Tab>` handler | four fall-through branches; confirm each is reachable and ordered correctly, and that the `1<C-i>` count prefix comment still holds |
| 510–784 | terminal toggle, git blame/show | three blocking `vim.fn.system` calls; check argument quoting and what happens on a non-git buffer or a detached HEAD |
| 785–943 | `show_unsaved_files`, `qf_add`, quickfix wiring | buffer-local map lifetime, and whether the float can leak |

Cross-check every `<leader>` binding against `docs/` and `README.md`; note any
that no longer exist or now point at a disabled plugin. **`<D-k>` was one of
these** and was only caught by accident.

### Phase 2 — Copilot, Trouble and git (1 session, ~1,530 lines)

Replaces the old phase 2. CodeCompanion is `enabled = false` since 2026-10-21 and
moved to the skip list; Copilot is live again and was only in the skip list.

**`lua/plugins/copilot.lua` (370)** — patches copilot-lsp internals, so read
`notes/copilot-nes.md` and the Copilot NES section of `CLAUDE.md` first.

- [ ] Order in `config` is load-bearing: `copilot-lsp` setup and the
      `nes.request_nes` wrap must run before `require("copilot").setup()`.
- [ ] Both internal patches (`request_nes` wrap, `_display_next_suggestion`
      render gate): confirm the wrapped names still exist at the pinned commit.
- [ ] Eight `nvim_create_autocmd` calls in `config`, most without a group:
      confirm `config` can only run once, or they stack.
- [ ] Load-on-use (2026-10-24): `<M-k>` (i), `<leader>ad`, `<C-j>` (i) as lazy
      `keys`. Runtime-tested that day; only re-check if something regressed.
- [ ] `should_attach` secret filter (`secret_names` / `secret_dirs`): tested
      against 41 paths that day; only check for new credential file types.

**`lua/plugins/trouble.lua` (655)** — the outline: 3 levels, the JS/TS role
rescue, kept `useEffect` rows (see `todos/freeze/freeze-override-2026-09-23.md`
and `todos/ui/symbol-outline-split.md`). Check the
role-rescue logic on files with no symbols and on very large files.

**`lua/plugins/git.lua` (504)** — gitsigns timing and nested autocmds (see
`notes/git/git-keymaps.md`). `]]`/`[[` for hunks and Diffview
`no_merges = true` are deliberate choices, not findings.

### Phase 3 — `lua/plugins/snacks.lua` (1023) and `lua/plugins/oil.lua` (968) (1 session)

These two interact — oil is a popup, snacks pickers open over it — and the
documented bugs live in that overlap.

**snacks.lua**

- [ ] Disabled sub-modules (347–359): `scroll`, `animate`, `words`, `indent`,
      `scope`, `dim`. Confirm each is genuinely off; the comments say why each
      one is a hot-path cost.
- [ ] `picker_scroll` / `explorer_window_keys` (100+): the count handling and
      the two-window problem — keys bound on the list are unreachable from the
      input. For every key, ask which window has focus when it is pressed.
- [ ] `backdrop = false`: these **must stay**. There are three now (462, 524,
      872); confirm all are still present. This is the snacks transparency mis-detection, not a
      preference.
- [ ] `layout` blocks (~440+, ~870+): check nothing spells out a `box` in a way that drops the
      preset's overrides — a documented silent failure.

**oil.lua**

- [ ] Backdrop lifecycle (88–125): `create_backdrop`/`close_backdrop` and the
      "never stack two" guard. Trace the interrupted-close path.
- [ ] `hide_bg_search_highlights` (126) and `saved_winhl` restore — does state
      survive an abnormal close?
- [ ] Path label (409–560): `clean_path`, `path_segments`, `segments_width`,
      `fit_segments`, `set_oil_winbar`. Width arithmetic on a narrow window and
      on a very deep path.
- [ ] The `VimEnter` buffer swap for `nvim <dir>` (~855–880).
- [ ] Confirm nothing per-directory has crept into `float.win_options` — oil
      re-applies that whole table on every navigation.

### Phase 4 — Second tier and synthesis (1 session)

- [ ] `lua/config/sql-keyword-source.lua` (476) — a custom completion source, so
      it is on the completion hot path. Highest remaining perf risk.
- [ ] `lua/config/ai-prompts.lua` (447)
- [ ] `lua/plugins/lsp.lua` (318) — untouched since before the freeze and
      described as production-validated; verify that is still true.
- [ ] `lua/plugins/blink-cmp.lua`, `lua/plugins/performance.lua`
- [ ] `lua/config/mouse-hover.lua` (551) — the `on_mouse_move` handler was read
      and is sound; the other ~480 lines were not.
- [ ] `lua/config/autocmds.lua`, `options.lua`, `quickfix-*.lua`, `ui.lua`
- [ ] Not in the 2026-09-09 plan, live since: `lua/plugins/dap.lua` (303),
      `folding.lua` (292), `Grug-far.lua` (187)
- [ ] Colourscheme (`lua/colorschemes/solarized-osaka/`, ~1,680 lines):
      **breakage only**, the palette is closed until 2026-12-31. Look for nil
      palette keys, duplicate table keys and dead locals, never colour choices
- [ ] Cross-file synthesis: the same decision expressed twice and able to drift.
      Known instance to start from — the palette lives in `variants.lua` but is
      described in `CLAUDE.md`, three archive docs and `README.md`.

### Phase 5 — Skip list, confirm the gate then move on

| file | lines | gate |
| --- | --- | --- |
| `snacks-file-browser.lua` | 913 | `ENABLED = false`, and sets **no** `enabled` key — verify that is still true, it is a fragment-collision trap |
| `telescope-file-browser.lua` | 738 | `ENABLED = false` |
| `_unstable_tabline.lua` | 424 | required by nothing |
| `smooth-scroll.lua` | 105 | required by nothing |
| `*.bak` | — | not loaded |
| `avante`, `sidekick`, `spectre`, `harpoon`, `flash` | — | `enabled = false` |
| `bufferline.lua` | — | `local ENABLED = false` |
| `codecompanion.lua` | 846 | `enabled = false` since 2026-10-21 ("until next year"). `ai-prompts.lua` is NOT skipped: `keymaps.lua` still requires it |

Total skipped: roughly 3,050 lines, so the real read is about **11,750 lines**
(estimate refreshed 2026-10-24; re-count in phase 0).

---

## 5. Traps that will produce wrong findings

- **lazy.nvim fragment collisions.** Only the LAST fragment's
  `init`/`config`/`enabled` per plugin survives, ordered by module name. Grep for
  a second spec file before concluding anything about those keys. This silently
  killed `snacks.lua`'s entire `init` for weeks.
- **`enabled = false` in one fragment disables the whole plugin.** That is why
  `snacks-file-browser.lua` gates on a local flag and sets no `enabled` key. An
  `init` that merely returns early still wins the lookup — the key must be absent.
- **`transparent` must be an explicit `false`.** Commenting the line out
  re-enables transparency, which then makes the oil backdrop a solid black sheet.
- **`bg_popup` must stay unset** in `on_colors`; the completion menu depends on
  base04. `bg_statusline` is the lualine key, not the native `StatusLine` key —
  this was mis-documented until 2026-09-09.
- **A duplicate key in a Lua table is not an error.** The last one wins and the
  earlier lines become lies that a reorder would activate. Four duplicate
  `boolean` keys were found this way.
- **Unresolved picker action names get typed as keystrokes** rather than erroring,
  and an action name matching a snacks built-in replaces it everywhere.
- **`virt_lines_above` on line 1 renders nothing** while still being counted.

---

## 6. Recording findings

One line per finding, ranked by severity at the end:

```
<file>:<line> — <what is wrong> → <when it breaks, concretely> → <cheapest fix>
[verified | unverified] [change-gate: pass | fail | n/a]
```

- **Flag anything genuinely dangerous immediately** — data loss, a hang, a
  recursion — rather than saving it for the write-up.
- Mark every finding verified or unverified. Do not blur the two.
- Run the change gate before writing a finding down. A defect that the gate says
  should not be fixed is still worth recording, but say so.

Write results to `todos/deep-config-review-findings.md`, and update this file's
status line as each phase completes.

---

## 7. Carry-over

Already recorded, confirm and fold in rather than re-deriving:

- Six watch-items in [`config-audit-2026-09-09.md`](config-audit-2026-09-09.md).
- `README.md` is stale in six specific ways (four dead theme hexes, palette
  described as closed, LSP debounce `300` vs the real `200`, `<C-k>` vs `<M-k>`,
  Copilot presented as active, Copilot subscription listed as a requirement).
- The three palette archives now carry historical banners; `CLAUDE.md`'s table is
  the only reconciled snapshot.
- ~~`lua/config/neovide.lua` has an uncommitted `<D-k>` fix.~~ Committed.
- **October review (2026-10-24):** every change from 1 to 24 Oct was read.
  The visual `*`/`#`/`<M-f>` bug and both Copilot issues were fixed and
  runtime-tested (branch `fix/copilot-load-and-secrets`). Cosmetic leftovers
  (dead code, stale comments and todos, trials left live) are in
  [`process/october-cleanup.md`](process/october-cleanup.md). Do not re-derive.
- **Deliberate, not findings:** `mbake` Makefile format-on-save, Diffview
  `no_merges = true`, `]]`/`[[` hunk maps.
