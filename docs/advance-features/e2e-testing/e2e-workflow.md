# E2E testing workflow (Claude skill `nvim-e2e`)

Set up 2026-11-23. This is how this config's features get battle-tested without testing them
by hand: Claude runs a scripted test loop, fixes only safe bugs, flags the rest, writes a report
and opens a PR. First run: PR #88,
[report](../testing/e2e-report-2026-11-23.md).

## How to ask

The trigger is the Claude skill **`nvim-e2e`** (saved in claude.ai). One line is enough:

| You type | What gets tested |
|---|---|
| `nvim e2e` | Debugger + test runner: all three suites |
| `nvim e2e debugger` / `nvim e2e test runner` | One area |
| `nvim e2e <feature>`, e.g. `nvim e2e codecompanion` | A feature with no suite yet. Claude writes new scenarios first, then runs the loop |
| `nvim e2e debugger — only Go, no PR` | Extra instructions. They override the skill's defaults where they conflict |
| `nvim e2e — follow todos/e2e/<feature>.md` | A plan file (scenarios, acceptance criteria), committed or attached |

To test the **local, unpushed** config instead of GitHub `main`, connect `~/.config/nvim` with
"Add folder" in the Claude desktop app first. If an extra instruction keeps repeating, ask Claude
to update the skill so it becomes the default.

## What happens (the loop)

1. **Config:** clone `myothiha97/nvim` (or use the connected local folder). The run reports
   the tested commit, and all work goes on a new branch cut from `main` (rules.md #4).
2. **Environment:** a disposable Linux sandbox:
   - Neovim 0.12+ and the exact `lazy-lock.json` commits;
   - treesitter parsers at their pinned revisions;
   - Mason adapters, Go ≥ 1.25, Node + tsx, Python;
   - fixtures from `scripts/e2e/setup.sh`.
3. **Test:**
   - Real Neovim TUI in tmux, with real keystrokes and mouse clicks sent as terminal mouse
     sequences.
   - Each step is checked two ways: state over the `--listen` socket, and the screen
     (screenshots get reviewed for UI noise).
   - Every scenario runs 3×; a step that passes only sometimes counts as a finding.
4. **Negative controls:** each area is broken on purpose once to prove its checks can fail
   (docs/CLAUDE.md "a clean result is not proof").
5. **Classify each failure:**
   - **Config bug, safe to fix** (no behaviour change beyond the bug, nothing on
     keystrokes/redraws or at startup): fixed, with a regression check that fails on the old
     code.
   - **Risky, a preference, or a plugin/adapter bug:** not fixed. It is flagged with the
     cause, a suggested fix and the effort, and its check is tagged `[known Fn]`.
   - **Harness issue:** fixed in `scripts/e2e/`, then noted in the report.
6. **Loop:** fix → rerun the affected suite → finally rerun everything 3×.
7. **Performance:**
   - Changed modules must not load at startup.
   - TUI startup median, main vs branch.
   - stylua on the changed Lua files.
8. **Report:** `docs/advance-features/testing/e2e-report-<date>.md`. It covers:
   - results, bugs fixed, flagged issues, performance;
   - the JetBrains / VS Code comparison and the UI review;
   - negative controls and harness issues;
   - the **limits** (below).
9. **Ship:**
   - Commits as myothiha97, following docs/CLAUDE.md: no AI co-author lines, conventional
     prefixes.
   - Push, then a PR to `main` with manual verification steps.
   - Before/after screenshots go in the chat.
   - **You review and merge.** Nothing is merged automatically.

## Limits to keep in mind

- It runs on **Linux, not macOS + Ghostty**. Not covered:
  - Nerd Font widths;
  - Option/Meta key bindings;
  - `display-p3` colours;
  - Ghostty's own input handling.
- **The mouse is simulated** through the terminal's mouse protocol. That is close to a real
  trackpad, but momentum scrolling, double-click timing and hover timing are not identical.
- **Timing is relative.** Startup is slower in the sandbox; only before/after comparisons count.
- **No access to your AI accounts or secrets.** For AI plugins (CodeCompanion, Copilot…) the UI
  and flows are tested with fake replies; real replies need a run on the Mac with the folder
  connected.
- Each report lists exactly which features were **not** covered.

## Running the suites yourself

See [scripts/e2e/README.md](../../../scripts/e2e/README.md). In short:

```sh
scripts/e2e/setup.sh
cd scripts/e2e && python3 suite_go.py && python3 suite_node_py.py && python3 suite_test.py
```

Worth doing after `:Lazy update` or after unpinning nvim-dap / nvim-dap-ui. Checks tagged
`[known Fn]` fail on purpose until that issue is fixed.

## Adding a feature to the suites

1. Add fixture files under `scripts/e2e/fixtures/` if the feature needs a project.
2. Add `suite_<feature>.py` with `@test("<area>/<scenario>")` functions. Use `dapkit.open_nvim`,
   `n.keys(...)` for keystrokes, `n.mouse(row, col, ...)` for clicks, `n.lua(...)` to read
   state, `c.check(cond, msg, detail)` and `c.shot(label)`.
3. Run it 3× and once against a deliberately broken version before trusting it.
