-- Shared snacks picker sizes, as fractions of the editor. Read when a spec file
-- loads or a picker key is pressed, never on a hot path.
return {
  -- Pickers without a preview: the picker-wide default (lua/plugins/snacks.lua)
  -- and grep, which spells out its own layout box.
  -- in future we might need to set max width and min width
  compact = { width = 0.45, height = 0.4 }, -- current live
  standard = { width = 0.6, height = 0.45 }, -- trialling at 30 Sept 2026

  -- Pickers with a preview: diagnostics (<leader>xd / <leader>xD) and the todo
  -- comment pickers (lua/plugins/todo-comments.lua).
  preview = { width = 0.85, height = 0.75 },
}
