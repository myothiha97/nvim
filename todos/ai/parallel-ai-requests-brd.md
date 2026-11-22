# Parallel AI requests with per-job indicators: BRD

Status: **open**, requirements only (written 2026-11-22 at Myo's request).
Nothing here is built. Research and background:
[`dwight-nvim-workflow.md`](dwight-nvim-workflow.md).

## 1. Problem

Today, in CodeCompanion v20.2 on Claude Code (ACP):

- A second inline prompt (`<leader>ai`) is refused while one is running
  ("Claude Code is still working on another inline prompt"). You wait.
- All AI work shares one fidget spinner at the bottom of the editor. With two
  chats running, or a chat plus an inline edit, you can't see which one is
  working, where, or which one finished.

That turns AI into a blocking, one-thing-at-a-time tool and wastes the time
spent waiting.

## 2. Goal

**Inline prompts and chats both run at the same time, async, without blocking
each other, and every running job has its own loading indicator.**
Driven entirely by Neovim keybindings. (Myo, 2026-11-22.)

Success means: fire 3-4 AI jobs across files and chats within a minute, keep
editing, and see at a glance which are running, queued, done or failed,
with every result landing in the right place.

## 3. Users and stories

One user: Myo, Go and Node/TS backend work in large production repos, keyboard
first, Claude Code subscription (work and personal accounts).

- **S1** As Myo, I select a Go function, `<leader>ai` "add error wrapping",
  then jump to another function and `<leader>ai` "write table tests", without
  waiting for the first, then switch to another file and fire a third.
- **S2** I keep typing elsewhere in the same file while an inline job runs, and
  its result still replaces exactly the code I selected.
- **S3** I ask a long question in chat A, switch to chat B for something else,
  and see a spinner on each chat while it works.
- **S4** I see a spinner right on the lines each inline job is working on, and
  know at a glance when it's done or failed.
- **S5** I cancel one job without touching the others, or all at once.
- **S6** When I fire more jobs than allowed at once, extra ones wait in a queue
  and say "queued" instead of failing.
- **S7** When I hit the subscription limit or a job errors, that job's own
  indicator says so; the others are unaffected.

## 4. Functional requirements

### FR1 Non-blocking execution

- FR1.1 Several inline prompts run **simultaneously** (truly at the same
  time, not one after another), across **any number of files
  and buffers** (fire in file A, switch to file B and fire, and so on), and
  also in the same buffer on non-overlapping ranges. Not limited to one file.
- FR1.1c The only thing that ever makes a job wait is the concurrency cap
  (FR5, default 3, open question Q1). Below the cap, every job starts the
  moment it is fired, whatever file or buffer it is in.
- FR1.1a Each job stays tied to its own buffer: its indicator and result land
  in that buffer even when it is hidden, in another window/tab, or not focused.
  Switching buffers never cancels, moves or blocks a job.
- FR1.1b A finished job in a buffer you are not looking at waits for review
  there and tells you which file is ready (one notify line naming the file).
- FR1.2 Several chats can run at once (already true upstream, must stay true).
- FR1.3 Inline and chat jobs run at the same time in any mix.
- FR1.4 Starting a job never freezes the editor (no sync waits on the UI
  thread).
- FR1.5 A new inline job on a range that overlaps a running one is refused
  with a clear message (no silent clash).

### FR2 Per-job indicator

- FR2.1 Each inline job shows a spinner at the end of the first line of its
  range (virtual text, no gutter signs: Myo's gutter rule), with a short label
  (e.g. "#2 working", "#3 queued").
- FR2.2 The range is tracked with extmarks, so the indicator and the final
  edit follow inserts and deletes made above or inside the file while the job
  runs.
- FR2.3 If the tracked range was deleted, the result is not applied; the job
  reports it.
- FR2.4 Each running chat shows its own spinner in that chat's window
  title/winbar while a request is in flight.
- FR2.5 Indicators use theme colours at normal strength (UI colour rule).
- FR2.6 One shared timer drives all spinners; no timer runs when no job runs.
- FR2.7 The global fidget spinner is removed or kept as a summary ("3 AI jobs
  running") - decide at build time (open question Q3).

### FR3 Results

- FR3.1 Inline results keep today's review flow: diff with accept/reject
  (`ga`/`gr`), per job.
- FR3.2 Two finished jobs in one buffer can be reviewed one after another
  without one diff overwriting the other.

### FR4 Cancel

- FR4.1 Cancel the job under the cursor (inline) or the current chat's request.
- FR4.2 Cancel all running and queued jobs.
- FR4.3 Cancel stops the underlying request/process and clears its indicator.

### FR5 Concurrency cap and queue

- FR5.1 A configurable max number of running AI requests (default 3),
  counting inline and chat together.
- FR5.2 Jobs over the cap queue in order and show "queued".
- FR5.3 Queued jobs start automatically as running ones finish.

### FR6 Per-job errors

- FR6.1 Errors (network, agent crash, subscription limit) show on that job's
  indicator and in one notify line naming the job; other jobs continue.
- FR6.2 A subscription-limit error pauses the queue instead of failing every
  queued job.

### FR7 Keymaps and commands

- FR7.1 `<leader>ai` keeps working as today; it just stops blocking.
- FR7.2 New keymaps (cancel one, cancel all, list running jobs) under the
  existing `<leader>a` group, checked for clashes before choosing.

## 5. Non-functional requirements

- **NFR1 Performance (standing rule):** startup time unchanged (measure vs
  main); zero idle cost (no timers, autocmds doing work, or processes when no
  job runs); streaming CPU no worse than today per job; no UI freeze with 4
  jobs running.
- **NFR2 Safety:** keep Claude Code's permission checks. Never use
  `--dangerously-skip-permissions` or similar. Inline agents stay limited to
  the buffer copy as today.
- **NFR3 Correctness:** an edit never lands on the wrong lines; no lost or
  duplicated results.
- **NFR4 Low maintenance:** smallest change that works; prefer upstream; any
  use of CodeCompanion internals gets a WARNING comment and a re-check note
  for plugin bumps (as with the fold and auto-attach code).
- **NFR5 Resources:** each extra parallel ACP connection is one
  `claude-agent-acp` process; the cap (FR5) bounds memory.
- **NFR6 Accounts:** works with both work and personal accounts
  (`:ClaudeAccount`); jobs started before a switch finish on their account.
- **NFR7 Repo rules:** PR per phase on its own branch, `/perf-review` before
  commit, Myo as sole author/committer.

## 6. Out of scope

- Autonomous multi-step agents, worktree swarms, auto git commits (dwight's
  Auto/Swarm). Claude Code in the terminal covers that.
- Installing dwight.nvim or 99 (references only).
- Feature pragmas, `.dwight/` folders, skills marketplaces.
- Copilot / HTTP adapters for inline (not used).
- Mermaid rendering (separate todo).

## 7. Acceptance criteria

- AC1 Four inline prompts in two buffers started within 10 s all run; spinners
  show on the right lines; all four diffs can be reviewed and applied.
- AC1a Fire in file A, switch to file B and fire, switch to file C and fire:
  all three run simultaneously (all three spinners active at once, none
  queued under the default cap); A and B finish while hidden and their diffs are waiting
  when you return; nothing lands in the wrong buffer.
- AC2 Adding 20 lines above a running inline job: its spinner and its result
  move with the code.
- AC3 Two chats plus one inline job run together, each with its own spinner.
- AC4 With cap 3, a 4th job shows "queued" and starts when one finishes.
- AC5 Cancel one: only that job stops. Cancel all: everything stops, no
  leftover processes (`ps`).
- AC6 Overlapping inline range is refused with a message.
- AC7 A simulated limit error shows on its job, pauses the queue, others
  finish.
- AC8 Startup time within noise of main; no timers or extra processes when
  idle; no Claude permission flags disabled.
- AC9 Myo uses it for a week on real Go/TS work and reports no wrong-place
  edits or freezes.

## 8. Test plan

- Headless Neovim suite in the cloud with a **fake ACP agent** (scripted
  delays, errors, limit responses) to cover AC1-AC7 deterministically,
  including typing during a run and deleting a tracked range.
- One short run with the real `claude-agent-acp` (2-3 parallel prompts) to
  confirm agent behaviour with several sessions.
- Perf: startup (`--startuptime`), idle timer/process check, streaming CPU per
  job vs main.
- Myo's real-use week (AC9), with short reports.

## 9. Decision: build on CodeCompanion or write our own plugin?

**Recommendation: build on CodeCompanion.** Write our own inline plugin only
if upstream refuses the change *and* carrying the patch becomes painful.

What blocks parallel inline today (CodeCompanion v20.2, `14b4993`):
`lua/codecompanion/interactions/inline/adapters/acp.lua` (369 lines) keeps the
connection and the running prompt in module-level locals (`_connection`,
`_running`, `_connecting`). `ACP:submit` refuses when `_running` is set. Chats
don't have this limit because each chat owns its own `acp_connection`. So the
fix is contained: give each inline prompt its own connection, the way chats
already work.

| | build on CodeCompanion | own inline plugin (99-style, `claude -p` per job, keep CodeCompanion for chat) |
| --- | --- | --- |
| Indicators (phase 1) | Public events only (`InlineStarted`/`InlineFinished`, request events). No internals | Built in, our own code |
| Parallel inline | Upstream PR to make the connection per prompt. Until merged, carry it as one commit on a pinned fork (as with easy-dotnet.nvim), not by shadowing the module | Native: one process per job |
| Reused for free | Diff review (`ga`/`gr`), edits on a buffer copy, permission handling, follow-up prompts in the same session, context, account toggle, model/effort settings | Must rebuild diff review, range tracking, prompt/context building, account handling. No follow-up conversation |
| Safety | Unchanged: the agent only edits a copy of the buffer, permission checks stay | Fine only if run read-only (text answer, no tools, never `--dangerously-skip-permissions`). Both dwight and 99 get this wrong |
| Perf | One `claude-agent-acp` process per running prompt, reused for follow-ups; nothing idle | One cold `claude` CLI start per job (seconds each); nothing idle |
| Maintenance | Low if merged upstream. Fork commit needs a rebase on each bump until then | We own all of it (~1-2k lines). Two AI stacks in one config |
| Timeline | ~6-9 thread days (section 10) | ~9-13 thread days (+3-4 for diff, ranges, context, cancel) |

Why: the hard parts (safe edits, diff review, sessions, accounts) already
exist and work in CodeCompanion, and the blocker is one small, well-located
design choice that upstream has already solved for chats. A separate plugin
would mean a second AI stack to maintain forever, for a feature that is
mostly a concurrency change.

Fallback trigger: switch to our own plugin if upstream declines and the fork
commit conflicts on two plugin bumps in a row.

## 10. Phases and timeline

Estimate from [`dwight-nvim-workflow.md`](dwight-nvim-workflow.md#timeline-estimate-safe-build--thorough-testing):

| phase | scope | thread days | Myo |
| --- | --- | --- | --- |
| 1 | FR2 indicators (inline + chat) | 1-1.5 | ~30 min |
| 2 | FR1 parallel inline: upstream PR (needs Myo's OK) + same change carried on a pinned fork until merged; own plugin only per section 9 fallback trigger | 2-3 | 30-60 min |
| 3 | FR4 cancel, FR5 cap + queue, FR6 errors | 0.5-1 | ~15 min |
| 4 | Test suite + perf (section 8) | 1.5-2 | none |
| 5 | Real-use week + fixes | 0.5-1 | 1 week of use |

Total about 6-9 thread days, 1.5-2 weeks calendar, 2-3 hours of Myo's time.
One PR per phase; phase 1 is useful alone.

## 11. Risks

- CodeCompanion internals change on a plugin bump (phase 2 local route).
- ACP agent behaviour with several sessions at once is unknown until tested.
- Parallel jobs burn the 5-hour subscription window faster (shared with chat
  and terminal Claude).
- Two diffs in one buffer may conflict with CodeCompanion's diff UI.
- Parallel agents editing the same file on disk (chat tools) can clash; only
  inline is range-guarded by this design.

## 12. Open questions

- Q1 Default concurrency cap: 3? Separate caps for inline and chat?
- Q2 OK to open an issue/PR on CodeCompanion upstream (public post)?
- Q3 Keep the global fidget spinner as a summary, or remove it?
- Q4 Keymaps for cancel-one / cancel-all / list-jobs.
- Q5 Should a spinner show the agent's live output (99-style) or just a label?
