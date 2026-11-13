-- bufferline.nvim comes from LazyVim's own spec (lazyvim/plugins/ui.lua), which
-- shows every open buffer and owns the keys: <S-h>/<S-l> cycle, <leader>bp pin,
-- <leader>bj pick, [B/]B move. This file only adds overrides on top of it.
--
-- The earlier "pinned-only favorites bar" build (custom_filter + its own config
-- function) was dropped on 2026-09-30 in favour of the stock behaviour. It is
-- in git history if it is ever wanted back. Do NOT add a `config` function here:
-- lazy.nvim keeps only the last fragment's, and it would replace LazyVim's.
--
-- ENABLED = true again since 2026-11-13, by choice, with the cost below accepted.
-- It was false from 2026-09-30: measured at ~0.12 ms per open buffer per render,
-- and the tabline re-renders about twice per typed character, so ~1.4 ms per
-- keystroke at 5 buffers and ~2.6 ms at 10. Off means Neovim's native tabline
-- (shown only with 2+ tab pages).
--
-- Flipping this is the only step. Three places follow it on their own:
-- config/keymaps.lua (<S-h>/<S-l>), the top winbar gap in config/options.lua
-- (per-window under a tab bar, global without one) and the explorer sidebar in
-- plugins/snacks.lua (drops the gap only under a tab bar). They read the flag
-- through this module's `[1].enabled`, so keep `enabled = ENABLED` on the spec.
local ENABLED = true

return {
  {
    "akinsho/bufferline.nvim",
    enabled = ENABLED,
    -- Close-to-a-side keys follow vim's h/l directions: <leader>bh closes the
    -- buffers to the left, <leader>bl the ones to the right. LazyVim puts
    -- "left" on <leader>bl and "right" on <leader>br, so both are replaced.
    keys = {
      { "<leader>br", false },

      { "<leader>bh", "<Cmd>BufferLineCloseLeft<CR>", desc = "Delete Buffers to the Left" },
      { "<leader>bl", "<Cmd>BufferLineCloseRight<CR>", desc = "Delete Buffers to the Right" },
    },
    opts = function(_, opts)
      opts.options = opts.options or {}
      -- Keep the bar visible with a single buffer too, so the current file name
      -- is always on screen.
      opts.options.always_show_bufferline = true
      -- No indicator bar: the active tab is marked by its bold name alone.
      opts.options.indicator = { style = "none" }
      -- bufferline italicises the active tab (and its diagnostics and duplicate
      -- path prefixes) by default; this preset turns all of those off at once.
      opts.options.style_preset = require("bufferline").style_preset.no_italic
      -- Full file names, like VS Code. bufferline cuts names at 18 cells by
      -- default; when the tabs no longer fit, it scrolls the bar instead.
      opts.options.truncate_names = false
      -- Transparent theme (Normal has no bg): bufferline colours the thin
      -- separators from Normal's bg, so with none they fall back to
      -- TabLineFill's fg and draw as bright bars between tabs. Spaces hide them
      -- and keep every tab's width. Read once here: transparency is a theme
      -- setup option and only changes with a restart.
      if not vim.api.nvim_get_hl(0, { name = "Normal" }).bg then
        opts.options.separator_style = { " ", " " }
      end

      -- ERRORS ONLY. The indicator drops LazyVim's warning count, and the
      -- warning/info/hint name colours are pointed back at the plain ones
      -- below: bufferline colours a tab's name by its WORST diagnostic, so a
      -- file with only warnings would otherwise still turn yellow.
      local error_icon = LazyVim.config.icons.diagnostics.Error
      opts.options.diagnostics_indicator = function(_, _, diag)
        return diag.error and error_icon .. diag.error or ""
      end

      local text = { attribute = "fg", highlight = "Normal" }
      local dim = { attribute = "fg", highlight = "Comment" }
      opts.highlights = opts.highlights or {}
      for _, level in ipairs({ "warning", "info", "hint" }) do
        for _, suffix in ipairs({ "", "_diagnostic" }) do
          opts.highlights[level .. suffix] = { fg = dim }
          opts.highlights[level .. suffix .. "_visible"] = { fg = dim }
          opts.highlights[level .. suffix .. "_selected"] = { fg = text, bold = true }
        end
      end
      -- bufferline paints errors red only on the ACTIVE tab and greys them out
      -- elsewhere, which hides the one status this bar is meant to show.
      local error_fg = { attribute = "fg", highlight = "DiagnosticError" }
      for _, suffix in ipairs({ "", "_diagnostic" }) do
        opts.highlights["error" .. suffix] = { fg = error_fg }
        opts.highlights["error" .. suffix .. "_visible"] = { fg = error_fg }
      end

      -- `style = "none"` still draws a one-cell blank in this group. A theme
      -- that defines it fg-only (solarized-osaka does) leaves that cell with no
      -- bg, so it falls through to TabLineFill and shows as a block beside the
      -- active tab. Normal's bg is what bufferline gives the selected tab, so
      -- this matches in every theme. Not gated on the theme at load time: the
      -- table is re-applied on every ColorScheme, and a gate read once at
      -- startup missed a later `:colorscheme` switch.
      --
      -- WARN: SILENT FAILURE: without `default = false` this is ignored.
      -- bufferline sets its groups with `default = themable` (true), so a group
      -- the theme already defined wins over this table.
      opts.highlights.indicator_selected = {
        default = false,
        bg = { attribute = "bg", highlight = "Normal" },
      }
    end,
  },
}
