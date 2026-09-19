-- ── Large file guard ──────────────────────────────────────────────────────
-- Stops treesitter highlighting for files above the threshold.
-- The parser stays alive so text objects (af/if/ac/ic etc.) still work.
-- Tune LARGE_FILE_BYTES down if you still feel lag on smaller files.
local LARGE_FILE_BYTES = 100 * 1024 -- 100 KB

vim.api.nvim_create_autocmd("BufReadPost", {
  group = vim.api.nvim_create_augroup("large_file", { clear = true }),
  callback = function(args)
    local size = vim.fn.getfsize(args.match)
    if size > LARGE_FILE_BYTES then
      pcall(vim.treesitter.stop, args.buf)
    end
  end,
})

-- ── Trouble outline: scroll the code, don't highlight it ───────────────────
-- When you move (or navigate the symbols panel), Trouble previews the symbol in
-- the code window: it scrolls there (wanted) AND paints the range with the
-- `TroublePreview` group (unwanted cue). Clearing that group removes the paint
-- while keeping the auto-scroll. Re-applied on every ColorScheme so it survives
-- theme switches; Trouble links its own groups with `default = true`, so this
-- user-set (non-default) definition always wins.
local function clear_trouble_preview_hl()
  pcall(vim.api.nvim_set_hl, 0, "TroublePreview", {})
end
vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("trouble_no_code_highlight", { clear = true }),
  callback = clear_trouble_preview_hl,
})
clear_trouble_preview_hl()

-- ── Transparent winbar gap ────────────────────────────────────────────────
-- options.lua sets `winbar = " "` for a 1-row gap at the top of each window.
-- The theme paints WinBar with its own background, which shows as a colored
-- band. Linking WinBar to Normal makes the gap match the editor exactly — so it
-- reads as empty space (transparent today, solid bg if `transparent` is off).
-- Re-applied on every ColorScheme because the theme re-sets WinBar on load,
-- which is why setting this in options.lua alone never stuck.
local function blend_winbar()
  pcall(vim.api.nvim_set_hl, 0, "WinBar", { link = "Normal" })
  pcall(vim.api.nvim_set_hl, 0, "WinBarNC", { link = "Normal" })
end
vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("transparent_winbar", { clear = true }),
  callback = blend_winbar,
})
blend_winbar()

-- ── Manual quickfix persistence ───────────────────────────────────────────
-- Persist only entries created by <leader>m. This stays off interactive hot
-- paths: one bounded read at startup and one bounded write on exit.
vim.api.nvim_create_autocmd("VimEnter", {
  group = vim.api.nvim_create_augroup("manual_quickfix_persistence", { clear = true }),
  callback = function()
    require("config.quickfix-persistence").restore()
  end,
})

vim.api.nvim_create_autocmd("VimLeavePre", {
  group = "manual_quickfix_persistence",
  callback = function()
    require("config.quickfix-persistence").save()
  end,
})

-- ── Native quickfix window delete actions ────────────────────────────────
-- Keep the stock quickfix buffer nomodifiable, but make delete-style motions
-- remove real entries from the list instead of erroring on rendered text.
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("native_quickfix_window", { clear = true }),
  pattern = "qf",
  callback = function(args)
    require("config.quickfix-window").setup_buffer(args.buf)
  end,
})

require("config.mouse-hover").setup()

-- ── Markdown: no spell check ─────────────────────────────────────────────
-- LazyVim's `wrap_spell` autocmd turns `wrap` AND `spell` on for text, plaintex,
-- typst, gitcommit and markdown. In a .md file spell squiggles every file name,
-- flag and code term (`nvim`, `tmux`, `fzf`) -- noise, not typos.
--
-- Only the markdown half of `spell` is switched back off here. LazyVim keeps
-- owning `wrap` and the other four filetypes, so any upstream change to that
-- list is still inherited. This runs last because user config loads after
-- LazyVim's defaults; an `after/ftplugin/markdown.lua` cannot do it, since
-- ftplugins are sourced BEFORE user FileType autocmds and LazyVim would just
-- switch spell straight back on (measured, not assumed).
--
-- FileType fires once per buffer, never per keystroke, and the pattern is
-- matched in C, so opening any other file costs nothing.
-- `:setlocal spell` still turns it on for a single buffer.
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("markdown_nospell", { clear = true }),
  pattern = "markdown",
  callback = function()
    vim.opt_local.spell = false
  end,
})
