# dwight.nvim-style AI workflow

Status: **open** (future enhancement, set 2026-11-22 by Myo). Research only;
nothing here is in the config. Needs dedicated time, do not start piecemeal.

## Goal

**Headline feature (Myo, 2026-11-22): inline prompts and chats both run at
the same time, async, without blocking each other, each with its own loading
indicator.** Both halves are required:

1. **Non-blocking:** start a new inline prompt or chat task while others are
   still running, in any mix (inline + inline, inline + chat, chat + chat).
   Parallel inline prompts are a must-have, not a "maybe upstream later".
2. **Own indicator:** every running inline prompt shows a spinner on its own
   lines; every running chat shows its own spinner. Today CodeCompanion shows
   one global spinner at the bottom of the editor for everything.

In practice, like dwight.nvim: fire an inline prompt at a piece of code, see a
loading indicator right on those lines, keep working, and fire more prompts at
other places (or in other chats) while the first ones are still running.

Where we stand today (from reading CodeCompanion v20.2 source, not tested):

| | own indicator | runs in parallel |
| --- | --- | --- |
| Chats | no, one global fidget spinner | **yes**: each chat opens its own ACP connection (`chat.acp_connection`), so two chats can work at once. Cost: one `claude-agent-acp` process per active chat |
| Inline prompts | no, same global spinner | **no**: one shared ACP connection, second prompt refused (see below) |

So the gap is: per-chat and per-inline indicators (both), and parallel inline
prompts.

Sources (read 2026-11-22):

- Repo: <https://github.com/otaleghani/dwight.nvim> (MIT), read at `af455f7`
  (2026-03-24). 65 commits between 2026-02-19 and 2026-03-24, then nothing for
  8 months. ~52,700 lines of Lua in 94 modules.
- Docs: <https://dwight.talesign.com/> (built from the repo's `docs/` folder).
- Reddit post (r/neovim `1rvf5e2`): **not read**, reddit.com is blocked from
  the research environment. Everything below comes from the code and docs.

## The two selling points Myo cares about

### 1. Inline loading indicator

What dwight does (`lua/dwight/ui/indicators.lua`, 96 lines):

- One namespace and one libuv timer per job. Every 120 ms it clears the
  namespace and redraws an end-of-line virtual text `⠋ #3 processing…` on the
  first and last line of the selected range.
- Optional sign column `⟳` on every line of the range
  (`indicator_style = "sign" | "virtual" | "both"`, default `both`).
- The label can change while running (`update_indicator_label`, used for
  streaming progress).

What we have today: one global fidget spinner ("CodeCompanion
Generating…") in the corner, driven by `CodeCompanionRequestStarted/Finished`
with a refcount (`lua/plugins/codecompanion.lua`). It says *something* is
running, not *where*.

Caveats in dwight's version:

- The range is stored as plain line numbers, not extmarks. Only dwight's own
  edits shift other jobs' ranges (`inline/jobs.lua adjust_other_jobs`). If you
  type above a running job, the spinner and the final replacement land on the
  wrong lines (`response.lua` uses `job.start_line` as stored).
- A redraw every 120 ms per running job is cheap, but it is a timer per job.
- Myo's standing rule: no gutter signs (gutter stays as it was). Only the
  end-of-line style would fit.

### 2. Many inline prompts at once

What dwight does (`inline/backends.lua`, `inline/jobs.lua`):

- Every inline job spawns its **own** `claude -p "<prompt>" --output-format
  text` process (or an HTTP call for the `api` backend). Jobs are fully
  independent, so several run at once. A second job on overlapping lines is
  refused ("This selection overlaps with a running job").
- The reply is plain text; dwight parses the code block out of it and replaces
  the range (or applies a multi-file `<changes>` XML block for `/stub`, `/code`).
- No tools, no session, no diff by default (`diff_preview = false`), `u` to undo.

What CodeCompanion v20.2 does (checked in the plugin source at our pinned
commit `14b4993`, `interactions/inline/adapters/acp.lua`):

- Inline on an ACP adapter (our `claude_code`) uses **one shared agent
  connection and one running prompt at a time**. A second inline prompt while
  one is running is refused with "Claude Code is still working on another
  inline prompt". So today we cannot run two inline prompts in parallel at all.
- In return it gets things dwight's inline path does not: the agent edits a
  copy of the buffer with real tools, a diff to accept/reject (`ga`/`gr`), and
  follow-up prompts that continue the same session.
- Not checked: whether inline on an HTTP adapter (Copilot, Anthropic API)
  allows parallel prompts. We don't use HTTP for inline anyway.

## Risks of running several tasks at once

Myo's view (2026-11-22): with Neovim keybindings this workflow would raise AI
leverage in nvim a lot. These are the costs to design around.

### Parallel edits clashing in the same buffer or file

How dwight handles it:

- **Same buffer, inline:** refuses a new job whose line range overlaps a
  running one. Non-overlapping jobs are allowed; when one finishes and changes
  the line count, later jobs' stored ranges are shifted. Gap: ranges are plain
  line numbers, so *your own* typing during a job is not tracked (results can
  land on the wrong lines). Also no check across buffers or against multi-file
  `/stub`/`/code` jobs touching a file another job is editing.
- **Agents:** `:DwightAgent` runs in the working tree with no lock, so two
  agents (or an agent plus your edits) can overwrite each other. Only Swarm
  mode isolates agents, each in its own git worktree (`max_parallel = 3`), and
  merges afterwards.

What we would need: extmark-tracked ranges (follow your edits), an overlap
check like dwight's, a diff before apply, and for parallel *chats/agents* on
the same repo either one-task-per-area discipline or worktrees.

### Claude subscription usage and rate limits

How dwight handles it:

- **No cap on parallel inline jobs.** Each one is a full `claude -p` start.
  It only prints "Job #N started (K parallel)".
- **Agents:** a rate-limit / 429 / network error is retried once by default
  (backoff 30 s, then 60 s, `max_retries`). Swarm caps agents per wave at 3.
- **Cost limits** (`cost_limits.per_session`, `per_day`, `warn_threshold`):
  dollar estimates from token pricing, checked before Auto/Swarm tasks and
  agent starts, not for inline. On a flat subscription the dollar figure is
  not what runs out; the 5-hour usage window is.

For us: inline, chat and Claude Code in the terminal all share the same
subscription window (and the work/personal account toggle splits it). Running
3-4 things at once burns it 3-4x faster. A design should have a small max
number of concurrent requests (queue the rest, show "queued" in the
indicator), and surface a limit error on the job's own indicator instead of a
global notify.

## Full feature list (from docs + code)

| area | commands | what it is |
| --- | --- | --- |
| Inline editing | `:DwightInvoke`, `:DwightMode <mode>`, `:DwightRepeat`, `:DwightMultiUndo`, `:DwightCancel` | Prompt buffer or preset mode on a selection (treesitter picks the enclosing function if none). 11 code modes (`refactor`, `fix`, `test`, `document`, `optimize`, `security`, `stub`, `code`, `lint`, `macro`, `explain`) + 4 prose modes. Prompt tokens: `@skill`, `%lib`, `$feature`, `!model`, `/mode`. Sends selection + LSP types, diagnostics, references |
| Agent mode | `:DwightAgent [--plan\|--jump]`, `:DwightAgentStatus`, `:DwightDiffReview` | One autonomous Claude Code / Codex / Gemini / OpenCode run with a live status buffer |
| Auto mode | `:DwightAuto`, pause/resume/skip/retry | Splits a task into 4-8 sub-tasks, runs each as an agent, runs tests after each, git commit per passing step |
| Swarm mode | `:DwightSwarm` | Parallel agents in separate git worktrees, DAG planner |
| Feature pragmas | `:DwightBootstrap`, `:DwightFeatures` | `// ... @feature:auth` comments group files; treesitter signatures become the agent's context |
| Skills / lessons | `:DwightSkills`, `:DwightMarketplace`, `:DwightLessons` | Markdown coding guides in `.dwight/skills/`; lessons extracted from each run and fed into later prompts |
| Git / GitHub | `:DwightCommit`, `:DwightSquash`, `:DwightPR`, `:DwightCI --fix` | AI commit messages, PRs, CI auto-fix via `gh` |
| Other | TDD, refactor, audit/heal, docs generation, digest, session replay, whiteboard, templates, multi-repo workspace, cost stats, MCP servers | 85+ commands in total, no default keymaps |

Requirements: Neovim 0.10+, plenary.nvim, nvim-treesitter, git, a CLI agent
(`claude`, `codex`, `gemini` or `opencode`). Optional API keys for the
"provider" path. Writes a `.dwight/` folder into each project.

## How it works

- **Backend** = a CLI agent spawned with `vim.uv.spawn` per job. Inline:
  `claude -p <prompt> --output-format text`. Agent/Auto/Swarm: `claude -p
  ... --output-format stream-json --dangerously-skip-permissions` (with
  `--mcp-config` when MCP servers are set).
- **Provider** = direct HTTP for single-shot calls (Anthropic, OpenAI, Gemini,
  OpenRouter, or `anthropic_max` which reuses the Claude Code OAuth token).
- `setup()` runs eagerly: loads config, provider JSON files, modes, registers
  all 85+ user commands, inits the session log, and starts MCP servers if
  configured.

## Fit with our setup (CodeCompanion v20.2 + Claude Code over ACP)

| dwight part | verdict | why |
| --- | --- | --- |
| Per-range inline indicator | **layer on** | Small and self-contained. Could be driven by CodeCompanion's `InlineStarted`/`InlineFinished` events (they carry `id` and `bufnr`). Use an extmark range so it follows edits |
| Parallel inline prompts | **required; blocked today** by CodeCompanion ACP inline | Single shared connection refuses a 2nd prompt. Routes in "Suggested plan" step 2 |
| Inline modes (`/refactor`, `/fix`, ...) | **overlap** | CodeCompanion prompt library already does preset prompts |
| Agent / Auto / Swarm | **overlap** | Claude Code itself (terminal, tmux) and the CodeCompanion agentic chat already cover this. Auto mode's test gate + git checkpoint per step is the novel part |
| Skills / lessons | **overlap** | Claude Code has `CLAUDE.md`, skills and memory natively |
| Git / GitHub / commit | **overlap / conflict** | AI commits would break the commit identity rule unless reviewed |
| Feature pragmas, `.dwight/` | **conflict** | Adds comments to every source file and a folder to every repo |
| Swarm worktrees | skip | Heavy; not a Neovim concern |

Installing dwight next to CodeCompanion would mean two AI plugins with two
inline paths, two sets of commands and two auth flows. Not recommended.

## Perf and maintenance concerns

- **Size and freshness:** 52k lines, single author, no commits since
  2026-03-24. Pinning is fine, but expect to own fixes ourselves.
- **Startup:** eager `setup()` (85+ commands, file reads). Would need
  `cmd =`/`keys =` lazy loading and a measurement before merging. Not measured.
- **Safety:** agent paths run Claude Code with
  `--dangerously-skip-permissions`. Unacceptable without a sandbox.
- **Correctness:** line-number tracking (see indicator caveats) means edits
  can land in the wrong place if you keep typing; no diff preview by default.
- **Cost:** each parallel inline job is a full `claude -p` start on the
  subscription and counts toward the 5-hour limit, same pool as chat.

## Comparison: ThePrimeagen's 99

Myo (2026-11-22): the workflow is very similar to 99. Repo:
<https://github.com/ThePrimeagen/99>, read at `c174224` (2026-06-11).

- **What it is:** a small (~10k lines incl. tests, 317 commits since
  2025-12-24) "AI + hand-coding" client. Visual-selection replace (`visual`),
  project `search` into the quickfix list, `vibe`, and a `Worker` extension.
  The README says BETA, APIs may still change, and the author now steers it
  towards `search`/`work` rather than inline replace.
- **Parallel inline requests:** yes. Each request is its own `vim.system` CLI
  process (OpenCode by default; Claude Code and cursor-agent providers). The
  agent writes its answer to a temp file, which then replaces the range.
  `stop_all_requests()` kills them all. No overlap check and no concurrency
  cap found.
- **Loading indicators:** better than dwight. The range is held by **extmarks**
  above and below the selection (`ops/marks.lua`), so it follows your edits;
  a spinner virtual line ("⠋ Implementing", 250 ms) sits on each mark and can
  show the agent's last stdout lines. If you delete the original selection,
  the result is dropped with an error instead of landing in the wrong place.
  There is also a floating status window that lists in-flight requests.
- **Maintenance:** last commit 2026-06-11 (5 months), community PRs merged
  until May. More active than dwight, still beta.
- **Safety:** the Claude Code provider runs `claude --dangerously-skip-permissions
  --print`, same problem as dwight's agents. Its temp dir must be inside the
  project (`tmp_dir = "./tmp"`).
- **Perf note:** after `setup()` the status window loop re-arms a 1 s
  `defer_fn` for the whole session, even when idle. Cheap, but not zero.

**Verdict:** 99 is the better *reference* for our goal: small, readable, and
its extmark range + per-request spinner is the right design (dwight's plain
line numbers are not). Neither should be installed as a base: both overlap
CodeCompanion, both run Claude with permissions turned off, and 99 is still
changing APIs. Copy the idea, not the plugin.

## Suggested plan (when there is time)

1. Build only the **per-range indicator** on top of CodeCompanion inline:
   on `InlineStarted` place an extmark range over the target lines with an
   end-of-line spinner (no signs), clear it on `InlineFinished`. Model it on 99's
   `ops/marks.lua` + `ops/request_status.lua` (marks above/below the range). One timer
   shared by all active jobs. Measure: startup unchanged, no redraw cost when
   idle. Keep the fidget spinner or drop it.
   For chats, the same idea per chat: a spinner in each chat's winbar/title
   while its request runs (key it on the chat's id from the request events),
   so several running chats are visible at once.
2. Make parallel inline prompts work (required). Pick the route by cost:
   a. Check upstream CodeCompanion for a per-prompt ACP connection/session
      option, and open an issue/PR if there is none (cheapest to maintain).
   b. If upstream won't do it soon, a local override that gives each inline
      prompt its own ACP connection (like chats already have). Costs one
      `claude-agent-acp` process per running prompt; mark it with a WARNING
      comment since it touches plugin internals.
   c. Fallback: a minimal `claude -p` quick-edit command like dwight's (one
      file, extmark-tracked ranges, overlap check, diff before apply).
   Whatever the route: a max-concurrency cap with a queue (see risks above).
3. Read the Reddit thread from a normal browser for any extra details.

Related: [`codecompanion-mermaid-viewer.md`](codecompanion-mermaid-viewer.md),
`lua/plugins/codecompanion.lua` (fidget spinner block).
