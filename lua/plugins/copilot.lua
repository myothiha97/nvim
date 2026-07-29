return {
  {
    "zbirenbaum/copilot.lua",
    -- lazy.nvim uses `dependencies`, not packer's `requires`. copilot.lua's
    -- nes/api.lua delegates to require("copilot-lsp.nes"), so NES needs this
    -- plugin on the runtimepath before copilot.lua's setup runs.
    dependencies = { "copilotlsp-nvim/copilot-lsp" },
    enabled = true,
    cmd = "Copilot",
    event = { "InsertEnter" },
    opts = {
      panel = { enabled = false },
      suggestion = {
        enabled = true,
        -- Auto-suggest alongside blink.cmp. hide_during_completion = false lets
        -- copilot's ghost text render even while blink's menu is open, so both
        -- engines stay visible. Accept keys are split: <C-l> = blink menu, <C-;> = copilot ghost.
        --
        -- debounce: 300ms gives the server time to finish multi-line generations
        -- before the next keystroke cancels the in-flight request. WebStorm uses
        -- a similar window (~300-400ms). Lower if you want snappier single-token
        -- suggestions at the cost of multi-line ones.
        -- Default OFF. The real source of truth at runtime is vim.g.copilot_enabled
        -- (also false by default), synced onto each buffer via BufEnter in config().
        -- This opt is the fallback for any buffer entered before that sync runs, so
        -- it must match the default-off state too.
        auto_trigger = false,
        hide_during_completion = false,
        debounce = 300,
        keymap = { accept = false },
      },
      nes = {
        enabled = true,
        auto_trigger = false,

        -- NES persistence tuning. copilot-lsp's defaults are move_count_threshold=3
        -- and distance_threshold=40 -- aggressive enough that scrolling up to check
        -- a function signature wipes the pending edit before you can accept it.
        -- Bumping both buys time to navigate context first.

        move_count_threshold = 10,
        distance_threshold = 100,
        count_horizontal_moves = false,
        keymap = {
          accept_and_goto = "<Tab>",
          accept = false,
          dismiss = "<Esc>",
        },
      },
      filetypes = {
        ["*"] = true, -- Enable for all filetypes
      },
    },
    config = function(_, opts)
      require("copilot").setup(opts)

      -- Fidget notifications for copilot LSP connect / disconnect
      local copilot_ready_shown = false
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(args)
          if copilot_ready_shown then
            return
          end
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          if client and client.name == "copilot" then
            copilot_ready_shown = true
            vim.schedule(function()
              local ok, fidget = pcall(require, "fidget")
              if ok then
                fidget.notify(" Copilot ready", vim.log.levels.INFO, { ttl = 3 })
              end
            end)
          end
        end,
      })
      vim.api.nvim_create_autocmd("LspDetach", {
        callback = function(args)
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          if client and client.name == "copilot" then
            copilot_ready_shown = false
            local ok, fidget = pcall(require, "fidget")
            if ok then
              fidget.notify("⚠ Copilot disconnected", vim.log.levels.WARN, { ttl = 4 })
            end
          end
        end,
      })

      -- Match neocodeium's ghost text style (#808080 medium gray)
      vim.api.nvim_set_hl(0, "CopilotSuggestion", { fg = "#808080", ctermfg = 244 })
      vim.api.nvim_create_autocmd("ColorScheme", {
        callback = function()
          vim.api.nvim_set_hl(0, "CopilotSuggestion", { fg = "#808080", ctermfg = 244 })
        end,
      })

      local suggestion = require("copilot.suggestion")
      local map = vim.keymap.set

      -- Dismiss ghost text immediately when leaving insert mode
      vim.api.nvim_create_autocmd("InsertLeave", {
        callback = function()
          if suggestion.is_visible() then
            suggestion.dismiss()
          end
        end,
      })

      -- blink.cmp coexistence: copilot's built-in hide_during_completion guard
      -- relies on pumvisible() and never fires for blink's custom floating window.
      -- Setting vim.b.copilot_suggestion_hidden makes copilot's render-time guard
      -- (suggestion/init.lua:257) drop both the current ghost and any in-flight
      -- LSP response that arrives after the menu opens.
      -- vim.api.nvim_create_autocmd("User", {
      --   pattern = "BlinkCmpMenuOpen",
      --   callback = function()
      --     vim.b.copilot_suggestion_hidden = true
      --     if suggestion.is_visible() then
      --       suggestion.dismiss()
      --     end
      --   end,
      -- })
      -- vim.api.nvim_create_autocmd("User", {
      --   pattern = "BlinkCmpMenuClose",
      --   callback = function()
      --     vim.b.copilot_suggestion_hidden = false
      --   end,
      -- })

      -- <C-;>: accept current suggestion AND immediately fire a fresh request
      -- at the new cursor position. Mimics WebStorm/Zed's "chained Tab" feel
      -- where the next ghost appears right after accept without waiting for
      -- TextChangedI / debounce. We schedule the next() call so accept()'s
      -- text insertion and ctx reset complete first; otherwise next() would
      -- see the pre-accept context and cycle the old candidate list instead
      -- of fetching for the new cursor position.
      --
      -- Moved off <C-l> so blink.cmp's menu accept can take that key. <C-;> has no
      -- legacy terminal encoding -- it only arrives via the kitty keyboard protocol,
      -- which Ghostty speaks and Neovim requests, so it works here but would NOT
      -- reach a non-negotiating app like zsh.
      map("i", "<C-;>", function()
        if suggestion.is_visible() then
          suggestion.accept()
          vim.schedule(function()
            suggestion.next()
          end)
        end
      end, { desc = "Copilot: Accept + Trigger Next" })

      -- Esc: always exit insert mode; if a suggestion is visible, dismiss it first
      map("i", "<Esc>", function()
        if suggestion.is_visible() then
          suggestion.dismiss()
        end
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
      end, { desc = "Copilot: Dismiss and Exit Insert" })

      -- Manual copilot trigger: closes blink menu if open, clears the hidden
      -- guard set by BlinkCmpMenuOpen, then requests/cycles a suggestion.
      -- Press repeatedly to cycle through variants (same as <M-]>).
      map("i", "<C-j>", function()
        local ok, blink = pcall(require, "blink.cmp")
        if ok and blink.is_menu_visible and blink.is_menu_visible() then
          blink.hide()
        end
        vim.b.copilot_suggestion_hidden = false
        suggestion.next()
      end, { desc = "Copilot: Trigger / cycle suggestion" })

      -- Toggle auto-trigger only (Copilot LSP stays loaded so manual <C-j> and
      -- blink.cmp coexistence keep working). vim.g.copilot_enabled is the single
      -- source of truth: it drives the lualine indicator, the NES render gate, and
      -- (via the BufEnter sync below) the per-buffer auto-trigger decision.
      -- Default OFF: copilot loads and the LSP stays connected, but no ghost text
      -- auto-fires until you toggle it on with <leader>ad / <M-k>.
      vim.g.copilot_enabled = false

      -- copilot.lua's auto-trigger check reads vim.b.copilot_suggestion_auto_trigger
      -- and only falls back to the global opt when that buffer-local var is nil.
      -- suggestion.toggle_auto_trigger() flips that buffer-local var, so a toggle
      -- only sticks in the buffer it was pressed in -- switching to a fresh buffer
      -- (oil, a picker result, an untouched file) reverts to the opt default and
      -- silently re-enables copilot. Project the global state onto every buffer on
      -- entry so the toggle behaves globally.
      vim.api.nvim_create_autocmd({ "BufEnter", "BufNewFile" }, {
        callback = function()
          vim.b.copilot_suggestion_auto_trigger = vim.g.copilot_enabled
        end,
      })

      -- Gate NES rendering on vim.g.copilot_enabled. The TextChanged autocmd
      -- in copilot-lsp/nes/init.lua:191 captures request_nes by upvalue at
      -- LspAttach time, so we can't stop new requests post-hoc — but we can
      -- block the render. Request still flies (cheap), nothing draws.
      local nes_ui_ok, nes_ui = pcall(require, "copilot-lsp.nes.ui")
      if nes_ui_ok and not nes_ui._toggle_wrapped then
        local original_display = nes_ui._display_next_suggestion
        nes_ui._display_next_suggestion = function(bufnr, ns_id, edits)
          if not vim.g.copilot_enabled then
            return false
          end
          return original_display(bufnr, ns_id, edits)
        end
        nes_ui._toggle_wrapped = true
      end

      local function toggleCopilotSuggestions()
        -- Flip the global first, then push it to the current buffer. The BufEnter
        -- sync above carries it to every other buffer as you move between them, so
        -- the toggle is effectively global. (We set vim.b directly rather than call
        -- suggestion.toggle_auto_trigger(), which would only flip this one buffer.)
        vim.g.copilot_enabled = not vim.g.copilot_enabled
        vim.b.copilot_suggestion_auto_trigger = vim.g.copilot_enabled
        -- Belt-and-suspenders: when disabling, drop any ghost text and any
        -- pending NES that was rendered just before the toggle. The
        -- toggle/render-gate only affects *future* draws.
        if not vim.g.copilot_enabled then
          if suggestion.is_visible() then
            suggestion.dismiss()
          end
          local nes_ok, nes = pcall(require, "copilot-lsp.nes")
          if nes_ok then
            nes.clear()
          end
        elseif vim.api.nvim_get_mode().mode:find("i") then
          -- Enabling while in insert mode: fire a suggestion now instead of waiting
          -- for the next keystroke, so ghost text appears the moment you toggle on.
          vim.schedule(function()
            suggestion.next()
          end)
        end
        local status = vim.g.copilot_enabled and "Enabled" or "Disabled"
        local level = vim.g.copilot_enabled and vim.log.levels.INFO or vim.log.levels.WARN
        vim.notify("Copilot Autocomplete: " .. status, level, { title = "Copilot" })
        vim.cmd.redrawstatus()
      end

      map("n", "<leader>ad", toggleCopilotSuggestions, { desc = "Copilot: Toggle Suggestions" })
      -- Cmd+K in insert mode (Ghostty sends Cmd as <M->). Moved off <C-k> to reclaim the
      -- native insert-mode digraph entry. Neovide's Cmd mirror (<D-k>) is in config/neovide.lua.
      map("i", "<M-k>", toggleCopilotSuggestions, { desc = "Copilot: Toggle Suggestions" })

      -- Accept word / line
      map("i", "<M-w>", function()
        suggestion.accept_word()
      end, { desc = "Copilot: Accept Word" })
      map("i", "<M-l>", function()
        suggestion.accept_line()
      end, { desc = "Copilot: Accept Line" })

      -- Cycle suggestions
      map("i", "<M-]>", function()
        suggestion.next()
      end, { desc = "Copilot: Next Suggestion" })
      map("i", "<M-[>", function()
        suggestion.prev()
      end, { desc = "Copilot: Prev Suggestion" })

      -- Check / recover copilot status from normal mode
      map("n", "<leader>aS", "<cmd>Copilot status<cr>", { desc = "Copilot: Status" })
      map("n", "<leader>aR", "<cmd>Copilot restart<cr>", { desc = "Copilot: Restart" })
    end,
  },
}
