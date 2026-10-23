# Freeze-override trace — 2026-10-23 `<leader>ui` opens Obsidian

Required by rule 10 in [`discipline-stop-rules.md`](../process/discipline-stop-rules.md).

**The change (one line):** `<leader>ui` in markdown buffers opens the file in
Obsidian instead of the browser preview (`lua/plugins/markdown-preview.lua`).
`:MarkdownPreview` stays available as a command.

**Why it did not wait:** the gate fired (optional, not blocking, a keymap change
inside the freeze) and the idea was filed as part 3 of
`todos/ui/markdown-preview-improvements.md`. It was overridden: Obsidian is now
the one app for every markdown file (macOS default, GitHub Dark snippet and
Mermaid plugin), and two viewers for the same files
was the friction. Scope held to the one key.
