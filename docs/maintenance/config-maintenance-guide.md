# Config maintenance guide

Measured on 2026-11-10 against the live config (`main` at `6341295`, Neovim
0.12.5, 73 plugins in `lazy-lock.json`). Everything here is a proposal. Nothing
is decided until the owner accepts it.

- **Part A** is for the owner: verdict, findings, action list, trade-offs.
- **Part B** is for AI agents: rules to follow when working in this repo. Each
  section has its own status line (Proposed or Accepted).

It builds on, and does not repeat: [`rules.md`](../../rules.md), the
[change-gate](../../neovim-config-change-gate.md),
[safe editing](../../notes/safe-config-editing-guide.md),
[freeze policy](../../notes/config-freeze-policy.md),
[delegation](../../notes/config-maintenance-and-delegation.md), the
[deep review](../../todos/deep-config-review.md) and the
[October cleanup list](../../todos/process/october-cleanup.md).

---

# Part A: for the owner

## Verdict

The config is healthy at runtime (clean boot, 54 to 58 ms headless startup, no
per-keystroke handlers in normal use). The risk is not speed. The risk is that
it grows faster than anyone can review it, and that the instructions agents
read have started to drift and contradict each other.

| number                              | value                                                                                      |
| ----------------------------------- | ------------------------------------------------------------------------------------------ |
| Lua under `lua/`                    | 21,219 lines in 95 files (6,949 on 2026-07-01, 15,351 on 2026-11-01)                       |
| Growth in November alone            | +6,594 / -441 lines in 10 days (mostly `lua/debugging/` 3,026 and `lua/testing/` 2,474)    |
| Lua that never runs                 | 3,625 lines (17%): disabled specs and unrequired modules, plus 539 lines in 2 `.bak` files |
| Comment lines in live Lua           | 4,887 of 17,594 (28%)                                                                      |
| Commits since 2026-06-01            | 429 non-merge (144 feat, 107 fix, 104 docs)                                                |
| Commits per month in the freeze     | Jul 28, Aug 68, Sep 133, Oct 86, Nov 1 to 10: 51                                           |
| Freeze override records             | 17 in `todos/freeze/`                                                                      |
| Text an agent is told to read first | about 4,200 lines and 34,000 words                                                         |
| Plugins pinned                      | 2 of 73 (nvim-dap, nvim-dap-ui). Last full `:Lazy update`: 2026-08-05                      |
| Automated checks                    | none (no CI, no git hooks, no script). Stylua fails on 12 files today                      |

Top 5 proposals, highest value first:

1. **Put root `CLAUDE.md` back under git.** It is the file every agent reads
   (462 lines), it has been gitignored since 2026-10-09, so it has no backup,
   and agents working in a git worktree do not see it at all.
2. **Fix the instruction conflicts and shrink root `CLAUDE.md` to an index.**
   Seven conflicts are listed in [A.5](#a5-conflicts-between-instruction-files).
   About 240 of its 462 lines (file browser, dashboard, a stale review
   pointer) are dated history that belongs in `notes/`.
3. **Add one check script with three checks, each already control-tested
   here** (boot with `VeryLazy`, fragment scan, plugin-internals probe). It
   replaces "trust the agent's report" with output you can read in 10 seconds.
4. **Delete dead code**: 1,068 lines that nothing loads (2 `.bak` files,
   `_unstable_tabline.lua`, `smooth-scroll.lua`), and decide at the checkpoint
   on the 3,096 lines of disabled specs.
5. **One list of patched plugin internals, and one planned update per
   checkpoint.** Plugin commits are 2 to 11 months old; each month of waiting
   makes the eventual update bigger and riskier.

## A.1 Where the size and change actually are

Large and often changed (commits touching the file since 2026-06-01):

| file                                       | lines | commits | note                                            |
| ------------------------------------------ | ----: | ------: | ----------------------------------------------- |
| `lua/plugins/snacks.lua`                   | 1,037 |      48 | largest, most changed, 8 `WARN: SILENT` markers |
| `lua/config/keymaps.lua`                   | 1,013 |      45 | also overrides a Neovim core function (A.3)     |
| `lua/plugins/oil.lua`                      |   972 |      27 | 5 `WARN: SILENT` markers                        |
| `lua/colorschemes/solarized-osaka/*`       | 1,729 |     109 | counted as size only                            |
| `lua/plugins/testing.lua` + `lua/testing/` | 2,876 |     19+ | new in November                                 |
| `lua/debugging/`                           | 3,026 |     new | has its own README and MAINTENANCE file         |

Custom logic, not plugin options, is most of the code: 16 of the 21 live
files in `lua/plugins/` contain 5 or more `function` keywords (6,116 lines),
only 5 are near-pure option tables (252 lines). This is a rough count, not a
review.

Hot-path handlers in live code: `CursorHold` in `options.lua` and
`copilot.lua`, one buffer-local `CursorMoved` in `git.lua`. `cursortab.lua`
adds global `CursorMoved`/`TextChanged` handlers only after `<leader>an`, and
they stay until restart (its own header says so).

## A.2 Dead and disabled code

| kind | files | lines |
| --- | --- | ---: |
| `local ENABLED = false` | `snacks-file-browser`, `telescope-file-browser`, `bufferline` | 1,738 |
| `enabled = false` | `codecompanion`, `avante`, `harpoon`, `sidekick`, `indent-blank-line`, `rainbow-delimiters`, `spectre` | 1,358 |
| required by nothing | `config/_unstable_tabline.lua`, `config/smooth-scroll.lua` | 529 |
| `.bak` (not Lua-loaded) | `_unstabled_oil.lua.bak`, `lua-line.lua.bak` | 539 |

[`docs/CLAUDE.md`](../CLAUDE.md) says disabled specs are kept on purpose as a
record. That has a cost: they show up in every grep, every review plan has to
carry a skip list for them, and `snacks-file-browser.lua` is the file that
caused the fragment collision that broke snacks for weeks. Git history already
keeps the record. Proposal in the action list, item 6.

## A.3 Coupling to plugin internals

These break silently or loudly on `:Lazy update`. The `lua/debugging/` and
`lua/testing/` ones already have a good table with check and rollback per row:
[`lua/debugging/README.md`, "Upstream internals"](../../lua/debugging/README.md)
(13 rows). The rest are not listed in one place:

| file                           | internal used                                                             | listed today in                                                                    |
| ------------------------------ | ------------------------------------------------------------------------- | ---------------------------------------------------------------------------------- |
| `plugins/copilot.lua:134,325`  | wraps `copilot-lsp.nes.request_nes` and `nes.ui._display_next_suggestion` | [`notes/copilot-nes.md`](../../notes/copilot-nes.md), "After every `:Lazy update`" |
| `config/keymaps.lua:147`       | replaces Neovim's `vim.lsp.util.open_floating_preview`                    | nowhere (Neovim upgrade risk)                                                      |
| `config/lazy-freeze.lua`       | patches `lazy.manage.update/sync/restore` inside `pcall`                  | nowhere. If lazy renames them, the freeze lock fails open with no message          |
| `plugins/todo-comments.lua:74` | `todo-comments.highlight.match/is_comment`                                | code comment only                                                                  |
| `plugins/snacks.lua:15`        | `snacks.picker.util.history` and its `kv.data`, `idx`, `cursor` fields    | nowhere                                                                            |
| `testing/history.lua:275`      | `snacks.picker.preview`                                                   | nowhere                                                                            |
| `plugins/trouble.lua:332`      | `trouble.view.get`                                                        | nowhere                                                                            |
| `plugins/aerial.lua:130,184`   | `aerial.data`, `aerial.backends`                                          | nowhere                                                                            |
| `plugins/git.lua:455`          | `diffview.lib.get_current_view`                                           | nowhere                                                                            |

I probed all of these names headless on the current lock: all present. A
control row with a fake name reported MISSING, so the probe can see a break.
It checks names only, not behaviour.

## A.4 Documentation load and drift

What an agent is told to read before it can work (root `CLAUDE.md`
"Guideline"):

| file | lines | words | why it is read |
| --- | ---: | ---: | --- |
| root `CLAUDE.md` | 462 | 4,336 | loaded into every session |
| `rules.md` + gate | 274 | 2,187 | "read FIRST" |
| all of `docs/` | 3,492 | 27,794 | "read all ... and follow them closely" |

Roughly 45,000 tokens before the first useful step (inferred at about 1.3
tokens per word). The biggest single doc is a 1,193-line spec for a feature
that is not built (`docs/phases/phase-2/`).

Root `CLAUDE.md` by section: file browser 171 lines, palette 108, dashboard 40,
deep-review pointer 29, loose end 28, Copilot 27, two traps 25, silent failures
20. The two-traps and silent-failure sections are the parts an agent most
needs; the file-browser and dashboard sections are mostly dated history.

Drift found:

- Root `CLAUDE.md` and `docs/CLAUDE.md` say "twenty" silent-failure places.
  The code has 34 `WARN: SILENT FAILURE` markers in 14 files; the note has 20
  entries.
- `README.md` still presents CodeCompanion (disabled 2026-10-21), plus the six
  stale items already listed in `todos/deep-config-review.md`.
- [`docs/advance-features/INDEX.md`](../advance-features/INDEX.md) says the
  testing code is on a branch "until merged". It is on `main`.
- [`todos/README.md`](../../todos/README.md) misses 10 files, including 3
  freeze overrides (10-23, 10-26, 11-04). 4 finished items sit outside
  `todos/done/`.
- 23 files hard-code the freeze end `2026-12-31`. The owner moved the freeze
  end to 2027-01-17 on 2026-11-08, so all 23 are already stale.

## A.5 Conflicts between instruction files

Listed, not resolved. Each one needs an owner decision.

1. `docs/CLAUDE.md` says run `:Lazy sync` after editing specs.
   [`lazy-freeze.lua`](../../lua/config/lazy-freeze.lua) blocks it unless
   `NVIM_LAZY_UNLOCK=1`, and `rules.md` freezes updates.
2. Root `CLAUDE.md` says read all of `docs/` "and follow them closely". That
   includes the phase-2 feature spec, which the gate would reject.
3. Root `CLAUDE.md` says "NEXT SESSION STARTS HERE: begin at phase 0" of the
   deep review. The review file says phase 0 is done and phases 1 to 4 are
   deferred to the checkpoint.
4. Root `CLAUDE.md` says one `init`/`config`/`opts` function per plugin.
   [`notes/silent-failure-surfaces.md`](../../notes/silent-failure-surfaces.md)
   #8 says `init`/`config`/`enabled`. lazy.nvim's source chains `opts`
   functions (`lua/lazy/core/plugin.lua`, `_values`), and the live config
   already has two lualine `opts` functions (`aerial.lua`, `performance.lua`).
5. Root `CLAUDE.md` and `docs/CLAUDE.md` both call themselves the canonical
   entry point for agents.
6. [`todos/README.md`](../../todos/README.md) says "Rule 10" requires an
   override trace. `rules.md` has no rule 10, and the gate says "one conscious
   confirmation is enough". The draft in
   [`discipline-stop-rules.md`](../../todos/process/discipline-stop-rules.md)
   would add rules 9 and 10, but rule 9 (ROI test) already exists.
7. `docs/CLAUDE.md` says read `notes/syntax-palette-decisions.md` before a
   colour change; root `CLAUDE.md` calls that note historical. (Pointer
   conflict only; the topic stays closed.)

## A.6 Safety net: what exists, and what I tested

Every check below was run on a copy of the config (`XDG_CONFIG_HOME` pointing
at a copy, state and cache redirected), once clean and once deliberately
broken.

| check | exists? | broken case | result |
| --- | --- | --- | --- |
| headless boot (`docs/CLAUDE.md` command) | documented | syntax error in `plugins/git.lua` | caught in output, **exit code 0** |
| same | | `error()` at end of `keymaps.lua` | **not caught** (keymaps load on `VeryLazy`) |
| boot that also fires `User VeryLazy` | no | same `keymaps.lua` error | caught. Clean run prints `E716 ... "Skip Region"` (vim-visual-multi), so compare to a baseline, not to empty |
| fragment scan (user specs setting `init`/`config`/`enabled` for one plugin in 2+ files) | no | extra file with `snacks.nvim` `init` | caught. Boot tests did not see it. Live config: 0 collisions |
| internals probe (names in A.3 exist) | no | fake module row | reported MISSING. All real rows present |
| LuaLS `--check` (Mason, 3.19.2) | no | none needed | 2,066 warnings, 2,019 of them the `vim`/`Snacks` globals. It found the known duplicate `member` key (`variants.lua:158,161`), the silent-failure class #15 |
| `stylua --check` | documented | n/a | 0.12 s, fails on 12 files today, so useless until one format pass |

Two cautions learned while testing. Loading `easy-dotnet` in a probe ran
`dotnet tool install -g EasyDotnet` on its own (it failed, nothing changed).
LuaLS fails on any path that contains `-config`, so run it from a plain path.

## A.7 Updates

- Plugins: locked by `lazy-freeze.lua` and `lazy-lock.json`. Only nvim-dap and
  nvim-dap-ui are pinned. Rollback with `:Lazy restore` also needs the unlock.
- The plugin folder `~/.local/share/nvim/lazy` is shared by every checkout, so
  a git worktree does not isolate an update. A separate data dir (for example
  `NVIM_APPNAME`) would, at the cost of a full download. Not tried.
- Neovim: brew-pinned at 0.12.5. Known risks: the `open_floating_preview`
  override, `:restart` session restore (see
  [`lua/debugging/MAINTENANCE.md`](../../lua/debugging/MAINTENANCE.md) section
  6 for the debugger smoke test).

## A.8 Repo hygiene

- Uncommitted edits on `main` right now (`variants.lua`, `snacks.lua`), against
  rule 4.
- Branches: 22 local, 19 merged. `dev` has 0 unique non-merge commits.
  `feat/db-tooling` was merged on GitHub as PR #29 today, but local `main` is
  not pulled yet. `feat/test-coverage-history` has 1 unmerged docs commit
  (1,455 lines). Two stale worktrees from dotfiles sessions are `prunable`.
  One open PR: #40 (aerial tree guides).
- Tracked strays: 2 `.bak` files, `intellij-lazyvim-keymap.xml` and
  `.ideavimrc` (unchanged since January), an HTML colour-notes file in
  `todos/theme/`, 5.8 MB of reference images in `todos/`.
- Untracked strays: `nvim.log`, `.nvimlog` (ignored, harmless).

## A.9 Action list

Freeze column: **ok** = doc or safety work, fits the planned stability and
refactor work. **checkpoint** = wait for the batch session. Effort is my
estimate.

| # | action | effort | benefit | risk | freeze | optional |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | Track root `CLAUDE.md` in git again, or merge its durable parts into `docs/CLAUDE.md` | 10 min | backup; worktree agents see it | it is public in the repo | ok | no |
| 2 | Add the pointer line to this guide (exact text below) | 2 min | agents find Part B | none | ok | no |
| 3 | Resolve conflicts 1 to 6 in A.5 with one line each | 30 min | agents stop getting opposite orders | low | ok | no |
| 4 | Shrink root `CLAUDE.md`: keep pointers, traps, status; move file-browser and dashboard history to `notes/`; drop the stale "NEXT SESSION" and "loose end" sections | 1 to 2 h | about half the per-session cost | a trap moves one click away; keep all traps in root | ok | no |
| 5 | Delete the 1,068 dead lines (2 `.bak`, `_unstable_tabline.lua`, `smooth-scroll.lua`) and update the two parked todos that point at them | 15 min | less noise for every grep and review | very low, nothing requires them (checked) | ok | no |
| 6 | Decide on the 3,096 lines of disabled specs: tag the commit (`archive/...`), then delete, or keep | 30 min | review plans need no skip list | reviving one costs a `git show` instead of a flag | checkpoint | yes |
| 7 | Add `scripts/check.sh`: boot with `VeryLazy` against a saved baseline, fragment scan, internals probe | 1 to 2 h | a 10-second answer to "did it break" | false alarms until the baseline is set | ok | no |
| 8 | One internals list: add the 9 rows of A.3 to a single table (the debugging README table, or a new note) | 30 min | the update checklist becomes complete | none | ok | no |
| 9 | One planned `:Lazy update` per checkpoint, with Part B section B.6 as the checklist | 2 h | smaller jumps, fewer surprises | breakage in that session; rollback is the lockfile | checkpoint | no |
| 10 | Hygiene: commit or drop the 2 edits on `main`, pull `main`, decide `dev` and `feat/test-coverage-history`, `git worktree prune`, delete the 2 local log files | 15 min | clean state before the refreeze | branch deletes only on your word | ok | no |
| 11 | `todos/`: add the 10 missing README rows, move the 4 finished files to `done/` | 20 min | the backlog shows the truth | none | ok | yes |
| 12 | Freeze date in one place: `rules.md` plus `FREEZE_END` in [`freeze-reminder.lua`](../../lua/config/freeze-reminder.lua); other files say "next checkpoint" | 20 min | refreezes stop creating 23 stale lines | none | ok | yes |
| 13 | Format the 12 files with stylua on their own branch, so `stylua --check` becomes usable | 10 min | a real format check | whitespace-only diff to review | ok | yes |
| 14 | Add a `.luarc.json` declaring `vim`, `Snacks`, `LazyVim` so LuaLS output is about 47 real warnings | 15 min | catches duplicate keys and typos | some noise remains | ok | yes |
| 15 | Two next-edit systems are live (Copilot NES and cursortab). Pick one | decision | one less internals surface | losing the other's strengths | checkpoint | yes |
| 16 | **Do nothing** about splitting `snacks.lua`, `keymaps.lua`, `oil.lua` now | 0 | no new review load in the freeze | files stay big | n/a | n/a |

Item 16 on purpose: no bug forces the split, the deep review phases 1 and 3
read exactly these files, and a split done before that review only moves the
unknown defects. Revisit after phase 3.

Proposed pointer line for item 2, under "Guideline" in root `CLAUDE.md`
(`docs/CLAUDE.md` forbids edits unless you ask, so root is the cheaper home):

```markdown
- Maintenance rules for agents (structure, docs, checks, plugin updates): `docs/maintenance/config-maintenance-guide.md`, Part B. Follow only the sections marked Accepted.
```

## A.10 Maintenance rhythm (proposed)

- **Per change:** branch, checks from B.5, one todo or findings line updated.
  Nothing else.
- **Per month (15 min, freeze or not):** skim `todos/README.md`, `git status`,
  `git branch --no-merged main`. No config edits.
- **Per checkpoint (end of January 2027):** one plugin update (B.6), deep
  review phases in order, decide item 6 and item 15, prune docs, set the next
  freeze date in `rules.md` and `freeze-reminder.lua`.

## A.11 Trade-offs and what I could not verify

- Token numbers are estimates from word counts.
- The "custom logic" share is a keyword count, not a reading of the code.
- Startup was measured headless from a copy, so 54 to 58 ms is not directly
  comparable to the 47 to 49 ms baseline from 2026-10-26.
- The fragment scan reads only top-level specs in `lua/plugins/`, not nested
  `dependencies` and not LazyVim's own fragments.
- The internals probe checks that names exist, not that they behave the same.
- I did not read the large files end to end. Correctness is the deep review's
  job.
- I did not see PR #29's content locally (not fetched).
- The separate-data-dir update rehearsal (A.7) is an idea, not tested.
- Deleting disabled specs makes the record harder to revive. Shrinking root
  `CLAUDE.md` makes some history one click further away. Both are
  deliberate trade-offs for lower review cost.
- The fix-to-feat ratio (107 to 144) suggests most features need follow-up
  fixes. That reading is inferred, not measured per feature.

---

# Part B: rules for AI agents

**Status: PROPOSED.** A section is binding only when its status line says
**Accepted**. Until then, treat it as advice and follow `rules.md`, the
change-gate, root `CLAUDE.md` and `docs/CLAUDE.md` first. If a rule here seems
to conflict with one of those, those win, and you report the conflict.

These rules add to the existing ones. They do not restate them. Where a rule
already exists, the section links it.

## B.1 Before you start

Status: Proposed

- Follow the read order in root `CLAUDE.md`, then
  [`rules.md`](../../rules.md) and the
  [change-gate](../../neovim-config-change-gate.md). Reason: they decide
  whether to act at all.
- If you work in a git worktree, root `CLAUDE.md` is not there (it is
  gitignored). Read it from the main checkout, `~/.config/nvim/CLAUDE.md`.
  Reason: it holds the traps. Unclear case: ask the owner where it is.
- If two instruction files disagree (see A.5), stop, name both lines, and ask.
  Do not pick a side. Reason: the owner decides, and a silent choice hides the
  conflict.

## B.2 Scope of a change

Status: Proposed

- Do not refactor, rename, move or reformat code unless a bug or a requested
  change opens that file, and then only the part it touches. Reason: every
  extra line is review time for the owner.
- Every structural change is a proposal: splitting a file, creating a package,
  deleting a file, adding a doc file. Write it as a proposal; do it only after
  the owner says yes. Unclear case: treat it as structural.
- Do not edit disabled specs (`ENABLED = false`, `enabled = false`,
  `_unstable*`, `.bak`). Do not delete them unasked;
  [`docs/CLAUDE.md`](../CLAUDE.md) keeps them on purpose. Reason: dead code
  should cost zero attention.
- Keep one concern per branch and per commit. Branch rules:
  [`rules.md`](../../rules.md) rule 4.

## B.3 Structure

Status: Proposed

- Propose a split when a file has more than about 600 lines of live code
  **and** holds a second, separable concern. Do not split it yourself. Reason:
  size alone is not a defect; mixed concerns are.
- Propose a package (like `lua/debugging/`) when one feature needs 3 or more
  helper modules. A package needs a README with an "Upstream internals" table
  (check and rollback per row) and a single line that turns the whole package
  off, like `{ import = "debugging.plugins" }`. Reason: that is what makes
  `lua/debugging/` cheap to maintain.
- A new experiment that the owner rejects: ask whether to delete it (reason in
  a todo, plus the commit hash) or to gate it. Do not add a new gated file on
  your own.

## B.4 Plugin specs and plugin internals

Status: Proposed

- Before you add or change `init`, `config` or `enabled` for a plugin, run
  `rg -l '"<owner>/<plugin>"' lua/` and check every hit. If another file sets
  the same key, stop and report. Reason: only the last fragment wins
  ([silent failure #8](../../notes/silent-failure-surfaces.md)).
- An `opts` function must change the `opts` it receives and return it. Never
  return a new table. Reason: lazy.nvim chains `opts` functions, and a new
  table drops what earlier fragments set.
- Use a plugin's public API. If you must use an internal (a submodule not in
  its docs, a `_name` field, wrapping or replacing a module function,
  `package.loaded[...] =`), then: wrap it in `pcall`, notify clearly on
  failure, and add a row to the internals table
  ([`lua/debugging/README.md`](../../lua/debugging/README.md), or the central
  list if action 8 is accepted). Reason: these are what break on update.
- When you find a new place that accepts a wrong value and does nothing, mark
  it `-- WARN: SILENT FAILURE` and add it to
  [`notes/silent-failure-surfaces.md`](../../notes/silent-failure-surfaces.md).
- Hot-path and loading rules:
  [`notes/safe-config-editing-guide.md`](../../notes/safe-config-editing-guide.md).

## B.5 Checks before you report "done"

Status: Proposed

1. Boot headless (command in [`docs/CLAUDE.md`](../CLAUDE.md)) and **read the
   output**. Reason: the exit code is 0 even when a spec fails to load
   (measured).
2. If you touched `keymaps.lua`, `options.lua`, `autocmds.lua` or anything
   loaded on `VeryLazy`, boot again and fire the event:
   `nvim --headless -c 'lua vim.api.nvim_exec_autocmds("User",{pattern="VeryLazy"})' -c 'qa!'`.
   Reason: plain headless never loads `keymaps.lua`.
3. Compare messages with the same command run on `main`, not with an empty
   result. Reason: a clean `main` already prints one E716 from
   vim-visual-multi.
4. If you touched `init`, `config` or `enabled`, run the fragment check from
   B.4.
5. A check counts only if it also fails on a deliberately broken version. Do
   that control in a copy (`XDG_CONFIG_HOME` pointing at a copy) or a
   worktree. Never break the live config, and never use `git stash` for it.
   Reason: several checks in this repo passed on broken code
   ([`docs/CLAUDE.md`](../CLAUDE.md), "Testing").
6. In the report, list what you ran, the control result, and what you could
   not check (UI, real-terminal keymaps, timing).

Commit-time review: see "Committing" in [`docs/CLAUDE.md`](../CLAUDE.md).

## B.6 After a plugin or Neovim update

Status: Proposed

Only in a planned session with the unlock
([`notes/config-freeze-policy.md`](../../notes/config-freeze-policy.md)).
Then, in this order:

1. B.5 checks 1 to 3.
2. Probe every internal in A.3 and in the debugging README table: does the
   name still exist? Do not load `easy-dotnet` in a probe (it installs a global
   dotnet tool by itself).
3. [`notes/copilot-nes.md`](../../notes/copilot-nes.md), "After every
   `:Lazy update`".
4. [`lua/debugging/README.md`](../../lua/debugging/README.md), "Upstream
   internals": run each row's check for the plugins that moved.
5. Start a new plain `nvim` and run `:Lazy update`. It must show the "frozen"
   warning. Reason: `lazy-freeze.lua` fails open if lazy renames its functions.
6. Neovim upgrade only: hover (`K`) on a symbol, because `keymaps.lua`
   replaces `open_floating_preview`; then
   [`MAINTENANCE.md`](../../lua/debugging/MAINTENANCE.md) section 6.
7. Something broke: `:Lazy restore` (needs the unlock) from the committed
   `lazy-lock.json`, report, stop. Do not patch around it in the same session.

## B.7 Where new information goes

Status: Proposed

| what | where |
| --- | --- |
| a defect found during review | [`todos/deep-config-review-findings.md`](../../todos/deep-config-review-findings.md), in its format |
| an idea or deferred request | a new file in `todos/<area>/` plus a row in [`todos/README.md`](../../todos/README.md) (the gate already says so) |
| why a decision was made, measurements | `notes/` |
| how a feature works for the user | the package README or `docs/` |
| a trap in code | a `WARN: SILENT FAILURE` comment plus the silent-failure note |

- Add to root `CLAUDE.md` only: pointers, traps that break silently across
  files, and the current status a new session needs. Never add dated
  narratives, measurement logs, "tried and dropped" stories, colour values or
  task lists. Reason: it is paid for in every session.
- Do not write the freeze end date into new files. Write "the next checkpoint
  (see `rules.md`)". Reason: 23 files went stale this way.
- Prefer a command over a count that drifts: write
  `rg -c "WARN: SILENT" lua` rather than "twenty places".
- When a todo is finished, update its row in `todos/README.md` and propose the
  move to `todos/done/`.
- Do not edit `docs/CLAUDE.md` unless the owner asks (it says so itself).

## B.8 Reporting to the owner

Status: Proposed

- Start with the decisions you need, one line each: the question, your
  recommendation, the cost of each option. Reason: decisions and review are
  the bottleneck, not writing Lua.
- Mark each claim **verified** (with the command) or **inferred**.
- State the size of the diff. If one change needs more than about 200 lines of
  Lua, say why and offer a smaller version first.
- If you have several proposals, group them and rank them. Do not start the
  next one before the owner answers.
