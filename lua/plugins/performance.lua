return {
  { "nvim-treesitter/nvim-treesitter-context", enabled = false },

  -- noice.nvim: cmdline popup only, everything else off
  {
    "folke/noice.nvim",
    enabled = true,
    event = "VeryLazy",
    opts = {
      health = { checker = false }, -- Disable health check (causes 1.5s overhead)
      cmdline = { enabled = false }, -- if u want the nvim cmd mode chat box ui then u can enabled it from here.
      views = {
        cmdline_popup = {
          position = { row = "10%", col = "50%" },
          size = { width = 60, height = "auto" },
        },
      },
      messages = { enabled = false },
      popupmenu = { enabled = false },
      notify = { enabled = false },
      smart_move = { enabled = false },
      lsp = {
        progress = { enabled = false },
        hover = { enabled = false },
        signature = { enabled = false },
        message = { enabled = false },
        override = {
          ["vim.lsp.util.convert_input_to_markdown_lines"] = false,
          ["vim.lsp.util.stylize_markdown"] = false,
          ["cmp.entry.get_documentation"] = false,
        },
      },
      presets = {
        bottom_search = true,
        command_palette = false,
        long_message_to_split = false,
        inc_rename = false,
        lsp_doc_border = false,
      },
      routes = {},
    },
  },

  { "mfussenegger/nvim-lint", enabled = false },
  { "folke/persistence.nvim", enabled = false },
  { "nvim-mini/mini.surround", enabled = false },
  { "nvim-mini/mini.nvim", enabled = false },
  { "rafamadriz/friendly-snippets", enabled = false },

  -- mini.ai disabled: performance issues with large files.
  -- dir="/dev/null" + virtual=true prevents LazyVim from showing a warning.
  { "nvim-mini/mini.ai", enabled = false, dir = "/dev/null", virtual = true },

  -- Classic vim-surround: ys, ds, cs, s (visual — remapped from default S)
  {
    "tpope/vim-surround",
    config = function()
      vim.keymap.set("x", "s", "<Plug>VSurround", { desc = "Surround selection" })
    end,
  },

  {
    "nvim-lualine/lualine.nvim",
    init = function()
      -- LazyVim's Trouble breadcrumb is useful, but it rebuilds Trouble symbols
      -- during statusline draws and showed up as a runtime hotspot.
      vim.g.trouble_lualine = false

      vim.api.nvim_create_autocmd({ "BufModifiedSet", "BufWritePost" }, {
        callback = function()
          vim.cmd.redrawstatus()
        end,
      })
    end,
    opts = function(_, opts)
      opts.options = opts.options or {}
      opts.options.refresh = {
        statusline = 400,
        tabline = 1000,
        winbar = 1000,
        events = {
          "WinEnter",
          "BufEnter",
          "BufWritePost",
          "SessionLoadPost",
          "FileChangedShellPost",
          "VimResized",
          "Filetype",
          "ModeChanged",
        },
      }
      opts.sections = opts.sections or {}
      opts.sections.lualine_x = vim.tbl_filter(function(component)
        return not (component == "diff" or (type(component) == "table" and component[1] == "diff"))
      end, opts.sections.lualine_x or {})
      opts.sections.lualine_b = opts.sections.lualine_b or {}

      -- Solarized palette, used for the change-count badge added to lualine_c below.
      local ok_colors, sol = pcall(require, "solarized-osaka.colors")
      local palette = ok_colors and sol.setup({ transform = true }) or {}

      table.insert(opts.sections.lualine_b, {
        function()
          return "● unsaved"
        end,
        color = { fg = "#ff4444" },
        cond = function()
          return vim.bo.modified
        end,
      })

      local lualine_c = opts.sections.lualine_c or {}
      for i, component in ipairs(lualine_c) do
        if component == "diagnostics" or (type(component) == "table" and component[1] == "diagnostics") then
          table.insert(lualine_c, i + 1, {
            function()
              return "  "
            end,
            separator = "",
            padding = { left = 0, right = 0 },
          })
          break
        end
      end
      for _, component in ipairs(lualine_c) do
        if type(component) == "table" and component[1] == "filetype" then
          component.padding = { left = 0, right = 0 }
          break
        end
      end
      local filename_index
      for i = #lualine_c, 1, -1 do
        local component = lualine_c[i]
        if
          type(component) == "table"
          and component[1] ~= "filetype"
          and type(component[1]) == "function"
          and component.cond == nil
        then
          lualine_c[i] = {
            "filename",
            path = 0,
            color = { fg = "#89b4fa", gui = "bold" },
            padding = { left = 0, right = 0 },
            separator = "", -- no thin arrow between filename and the git markers
            file_status = false, -- suppress built-in [+]/[-]; we render our own green [+]
          }
          filename_index = i
          break
        end
      end

      -- Git change markers after the filename: a "[+]" dirty flag plus the hunk
      -- count. Both hidden on a clean file, green to stay clear of diagnostic red.
      -- The dirty check reads `b:gitsigns_status_dict` (zero-cost buffer var). The
      -- hunk count calls gitsigns.get_hunks() — only when the file is dirty and
      -- only on lualine's throttled 400ms refresh, so it's not a hot path.
      -- The THEME's green, not the syntax palette's. This marker means "added"
      -- and has to stay green whatever the keyword colour is doing.
      --
      -- It briefly turned yellow on 2026-08-08: the colorscheme used `on_colors`
      -- to retheme syntax, which mutates the shared ramp this line reads. That
      -- override is gone (see the note atop solarized-osaka/init.lua), so the two are
      -- decoupled at the source and this tracks the theme again.
      local green = palette.green or "#849900"
      local function git_is_dirty()
        local gs = vim.b.gitsigns_status_dict
        if not gs then
          return false
        end
        return ((gs.added or 0) + (gs.changed or 0) + (gs.removed or 0)) > 0
      end
      local function git_hunk_count()
        if not vim.b.gitsigns_status_dict then
          return 0
        end
        local hunks = require("gitsigns").get_hunks()
        return hunks and #hunks or 0
      end

      local dirty_marker = {
        function()
          return "[+]"
        end,
        cond = git_is_dirty,
        color = { fg = green, gui = "bold" },
        separator = "",
        padding = { left = 1, right = 0 },
      }
      local hunk_badge = {
        function()
          return tostring(git_hunk_count())
        end,
        cond = git_is_dirty,
        color = { fg = green, gui = "bold" },
        separator = "",
        padding = { left = 1, right = 0 },
      }
      if filename_index then
        -- Insert at the same index in reverse so final order is: filename [+] hunks
        table.insert(lualine_c, filename_index + 1, hunk_badge)
        table.insert(lualine_c, filename_index + 1, dirty_marker)
      else
        table.insert(lualine_c, dirty_marker)
        table.insert(lualine_c, hunk_badge)
      end
      opts.sections.lualine_c = lualine_c

      -- Custom percent badge styling: a Solarized Osaka accent for the text.
      -- If the colorscheme or lualine theme changes, revisit this block.
      -- Previous green fallback, if yellow reads worse:
      -- { fg = "#849900", gui = "bold" }
      --
      -- No explicit `bg` here. It used to force bg_statusline so the badge kept
      -- the statusline background while sitting inside lualine_y, whose theme
      -- background is lighter. Now that it lives in lualine_c — which already
      -- uses the statusline background — a hardcoded bg would only be a second
      -- source of truth to keep in sync, so the section colour is inherited.
      local percent_color = { fg = "#b28500", gui = "bold" }
      local ok, solarized_colors = pcall(require, "solarized-osaka.colors")
      if ok then
        local colors = solarized_colors.setup({ transform = true })
        percent_color = { fg = colors.yellow500 or colors.yellow, gui = "bold" }
      end

      opts.sections.lualine_y = {
        {
          function()
            local current = vim.fn.line(".")
            local total = vim.api.nvim_buf_line_count(0)
            return string.format("line %d/%d", current, total)
          end,
          padding = { left = 1, right = 1 },
        },
      }

      -- Scroll progress sits at the right-hand end of lualine_c, after the
      -- filename and the git markers, rather than over on the right with the
      -- line counter.
      --
      -- dirty_marker and hunk_badge both carry `cond`, so on a clean file they
      -- render nothing and the percentage lands directly beside the filename;
      -- on a dirty file it follows the git markers. Appending covers both cases
      -- without branching on git state.
      --
      -- separator = "" suppresses lualine's thin divider, matching the filename
      -- and git markers ahead of it. The left padding of 2 is the visual gap
      -- that keeps it from crowding the hunk count.
      table.insert(opts.sections.lualine_c, {
        function()
          local current = vim.fn.line(".")
          local total = vim.api.nvim_buf_line_count(0)
          local percent = total > 0 and math.floor((current / total) * 100 + 0.5) or 0
          return string.format("%d%%%%", percent)
        end,
        color = percent_color,
        separator = "",
        padding = { left = 2, right = 1 },
      })

      -- Copilot status indicator (LSP status + autocomplete toggle state)
      -- Color reflects vim.g.copilot_enabled (toggled via <leader>ad / <C-k>):
      --   enabled  -> color from LSP status (green/yellow/red)
      --   disabled -> dim gray + power-off icon
      table.insert(opts.sections.lualine_x, 1, {
        function()
          local ok, api = pcall(require, "copilot.api")
          if not ok then
            return ""
          end
          if not vim.g.copilot_enabled then
            return " Copilot"
          end
          local s = api.status.data.status
          local icons = { Normal = " ", InProgress = "󰔟", Warning = "⚠", Error = "✗" }
          return (icons[s] or "?") .. " Copilot"
        end,
        color = function()
          if not vim.g.copilot_enabled then
            return { fg = "#6c7086" }
          end
          local ok, api = pcall(require, "copilot.api")
          if not ok then
            return { fg = "#888888" }
          end
          local s = api.status.data.status
          if s == "Normal" then
            return { fg = "#6cc644" }
          elseif s == "Warning" then
            return { fg = "#f0c040" }
          elseif s == "Error" then
            return { fg = "#ff6b6b" }
          end
          return { fg = "#888888" }
        end,
        cond = function()
          return package.loaded["copilot.api"] ~= nil
        end,
      })
      return opts
    end,
  },
}
