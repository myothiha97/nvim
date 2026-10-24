# Load Copilot only when it is first used

Status: done 2026-10-24 by freeze override, see `../freeze/freeze-override-2026-10-24-copilot-load-on-use.md`.

Since 2026-10-04 `lua/plugins/copilot.lua` loads on `BufReadPost`/`BufNewFile`, so
every nvim instance with a file open starts its own Copilot language server
(a Node process), even though Copilot is off by default. Editing is not slowed
(setup runs once per session; edits are synced in batches); the cost is RAM per
instance, multiplied across tmux sessions.

Idea: load on first use instead — the toggle (`<M-k>` insert, `<leader>ad`) and
manual `<C-j>` as lazy `keys`, no `event`. Sessions that never use Copilot then
start no server.

Check before doing it: with several tmux sessions open, Activity Monitor ->
search `copilot` -> count the processes and their memory. Only worth doing if
that number matters.

Watch out: NES-on-InsertEnter and the CursorHold trigger assume the LSP is
already running; after the change they would only work once Copilot is loaded.
