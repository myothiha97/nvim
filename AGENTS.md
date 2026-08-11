# Agent instructions

**Read [`CLAUDE.md`](CLAUDE.md) in this folder first. It is the canonical entry
point for every AI agent working in this repository, whatever tool you are.**

This file exists only so that agents which look for `AGENTS.md` (Codex and
others) find their way there. It is deliberately a pointer and not a copy —
two files with the same rules drift apart, and then an agent follows the stale
one.

In short, and only in short — `CLAUDE.md` is the authority:

1. Read [`rules.md`](rules.md) before touching anything. It holds the discipline
   rules and the active **config-freeze window**.
2. Apply the change-gate in
   [`neovim-config-change-gate.md`](neovim-config-change-gate.md) to **every**
   change request. The default answer to a new idea is *no*; only fixes that
   unblock real work are in scope while the freeze is on.
3. Then read `docs/` and follow it.

Two rules worth stating here because they are the easiest to violate by
accident:

- **Performance is the top priority**, above features and polish. Nothing may add
  cost to a hot path — keystrokes, cursor moves, redraws.
- **Never edit directly on `main`.** Branch, verify, then merge back.
