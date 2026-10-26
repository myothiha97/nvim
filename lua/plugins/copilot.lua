local nes_debounce = 150 -- ms, read by copilot-lsp at LSP start (default 500)
local ghost_debounce = 250 -- ms, passed to suggestion.debounce below

-- Credential files Copilot never attaches to. Once loaded, Copilot can send open
-- files to GitHub as context, so a match keeps the file off the server entirely.
-- A false match only turns Copilot off in that one file. Both lists are matched
-- against the lowercased name / path in should_attach below.
local secret_names = {
  "^%.env", -- .env, .env.local, .envrc
  "%.env$", -- prod.env, docker/app.env
  "secret",
  "^%.dev%.vars$", -- Cloudflare Wrangler secrets
  "^%.pgpass$",
  "^%.vault%-token$",
  "kubeconfig",
  "%.jks$", -- Java keystores
  "%.keystore$",
  "%.ovpn$", -- VPN profiles embed keys
  "^service%-account.*%.json$", -- GCP service account keys
  "%.pem$",
  "%.key$",
  "%.p12$",
  "%.pfx$",
  "%.tfvars$",
  "%.tfstate", -- also *.tfstate.backup
  "^id_[%w_]+$", -- SSH private keys (id_rsa, id_ed25519), not id_generator.go
  "^%.npmrc$",
  "^%.pypirc$",
  "^%.netrc$",
  "^%.git%-credentials$",
  "^credentials", -- ~/.aws/credentials, credentials.json
}
local secret_dirs = { "/.ssh/", "/.kube/", "/.aws/", "/.gnupg/", "/.docker/", "/secret/", "/secrets/" }

-- Must be set before the copilot LSP initializes: copilot-lsp reads it once there.
vim.g.copilot_nes_debounce = nes_debounce

return {
  {
    "zbirenbaum/copilot.lua",
    -- lazy.nvim uses `dependencies`, not packer's `requires`. copilot.lua's
    -- nes/api.lua delegates to require("copilot-lsp.nes"), so NES needs this
    -- plugin on the runtimepath before copilot.lua's setup runs.
    dependencies = { "copilotlsp-nvim/copilot-lsp" },
    enabled = true,
    cmd = "Copilot",
    -- Loaded on first use, not on file open (2026-10-24, see
    -- todos/freeze/freeze-override-2026-10-24-copilot-load-on-use.md). Copilot is
    -- off by default and every loaded nvim starts its own Copilot server, so an
    -- nvim that never uses it should start none. These keys (and :Copilot) load it;
    -- lazy.nvim then replays the key, so the first press also toggles / triggers.
    -- Insert <M-k> (Cmd+K) is claimed here for one more reason: LazyVim skips any
    -- key a plugin claims, so its insert <A-k> "move line up" never replaces it.
    keys = {
      { "<M-k>", mode = "i", desc = "Copilot: Toggle Suggestions" },
      { "<leader>ad", desc = "Copilot: Toggle Suggestions" },
      { "<C-j>", mode = "i", desc = "Copilot: Trigger / cycle suggestion" },
    },
    opts = {
      panel = { enabled = false },
      suggestion = {
        enabled = true,
        -- Auto-suggest alongside blink.cmp. hide_during_completion = false lets
        -- copilot's ghost text render even while blink's menu is open, so both
        -- engines stay visible. Accept keys are split: <C-l> = blink menu, <C-;> = copilot ghost.
        --
        -- Default OFF. The real source of truth at runtime is vim.g.copilot_enabled
        -- (also false by default), synced onto each buffer via BufEnter in config().
        -- This opt is the fallback for any buffer entered before that sync runs, so
        -- it must match the default-off state too.
        auto_trigger = false,
        hide_during_completion = false,
        -- Delay before a ghost-text request starts. Higher means fewer requests,
        -- not more time for the server to finish a multi-line completion.
        debounce = ghost_debounce,
        keymap = { accept = false },
      },
      -- copilot.lua reads only enabled + keymap here; unknown keys are silently
      -- ignored. NES tuning lives in copilot-lsp (see config() below).
      nes = {
        enabled = true,
        keymap = {
          accept_and_goto = "<Tab>",
          accept = false,
          dismiss = "<Esc>",
        },
      },
      filetypes = {
        ["*"] = true, -- Enable for all filetypes
        text = false, -- Disable for text files
      },
      -- Replaces copilot.lua's default, so its buflisted/buftype check is kept.
      -- Then keeps credential files (secret_names / secret_dirs above) away from
      -- the server. Runs once per buffer attach, never per keystroke.
      should_attach = function(buf, bufname)
        if not vim.bo[buf].buflisted or vim.bo[buf].buftype ~= "" then
          return false
        end
        local path = bufname:lower()
        local name = vim.fs.basename(path)
        for _, pattern in ipairs(secret_names) do
          if name:match(pattern) then
            return false
          end
        end
        for _, dir in ipairs(secret_dirs) do
          if path:find(dir, 1, true) then
            return false
          end
        end
        return true
      end,
    },
    config = function(_, opts)
      -- 1. NES persistence tuning. Must run BEFORE anything requires
      --    copilot-lsp.nes: nes/ui.lua captures the config table at load time and
      --    setup() replaces that table, so a later call is silently ignored.
      --    Defaults (3 moves / 40 lines) wipe a pending edit as soon as you scroll
      --    up to check a signature; these give room to navigate first.
      require("copilot-lsp").setup({
        nes = {
          move_count_threshold = 10,
          distance_threshold = 100,
          count_horizontal_moves = false,
          -- Defaults, spelled out to avoid the missing-fields diagnostic
          clear_on_large_distance = true,
          reset_on_approaching = true,
        },
      })

      -- 2. Gate ALL NES requests on the toggle. Must wrap before copilot starts:
      --    copilot-lsp captures request_nes when the LSP initializes.
      local nes = require("copilot-lsp.nes")
      local original_request = nes.request_nes
      nes.request_nes = function(...)
        if not vim.g.copilot_enabled then
          return
        end
        return original_request(...)
      end

      -- 3. Start copilot (loads the NES modules and the LSP client).
      require("copilot").setup(opts)

      -- Request NES without typing: on entering insert mode, and when the cursor
      -- rests in normal mode. copilot-lsp itself only requests on TextChanged(I).
      local function request_nes_now(args)
        if not vim.g.copilot_enabled or vim.b.nes_state then
          return -- toggle off, or a suggestion is already showing
        end
        -- A macro replay enters insert mode once per iteration, so `100@a` would
        -- fire ~100 requests at once and burn the quota.
        if vim.fn.reg_executing() ~= "" then
          return
        end
        -- CursorHold re-arms after ANY key, including the <Esc> that dismissed
        -- the NES, so without this check the same edit comes back ~updatetime
        -- later. Only re-request once the text or the cursor line has changed.
        local key
        if args.event == "CursorHold" then
          key = vim.b.changedtick .. ":" .. vim.fn.line(".")
          if vim.b.copilot_nes_last == key then
            return
          end
        end
        -- request_nes returns quietly (no error) when the buffer is not attached
        -- yet, which happens just after Copilot loads. Send only to a client
        -- attached to this buffer, so the spot is marked only once the request
        -- really went out and an early attempt is retried.
        local client = vim.lsp.get_clients({ name = "copilot", bufnr = 0 })[1]
        if not client then
          return
        end
        local ok = pcall(nes.request_nes, client)
        if ok and key then
          vim.b.copilot_nes_last = key
        end
      end

      vim.api.nvim_create_autocmd({ "InsertEnter", "CursorHold" }, {
        group = vim.api.nvim_create_augroup("CopilotNesTriggers", { clear = true }),
        callback = request_nes_now,
      })

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

      -- No insert-mode <Esc> map on purpose: native <Esc> fires InsertLeave, and
      -- the autocmd above dismisses the ghost text there. A map that re-feeds
      -- <Esc> via feedkeys appends it AFTER pending typeahead, so a macro like
      -- `ihello<Esc>oworld<Esc>` replays as "hellooworld".

      -- Manual copilot trigger: closes blink menu if open, clears the
      -- copilot_suggestion_hidden guard (set by the BlinkCmpMenuOpen autocmd when
      -- that is enabled above), then requests/cycles a suggestion.
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
      -- source of truth: it drives the lualine indicator, the NES request and
      -- render gates, and (via the BufEnter sync below) the per-buffer
      -- auto-trigger decision.
      -- Default OFF. Copilot loads on its first toggle (<leader>ad / <M-k>), <C-j>
      -- or :Copilot; from then on the LSP stays connected and the toggle only
      -- decides whether ghost text auto-fires.
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

      -- Gate NES rendering on vim.g.copilot_enabled. Requests are already gated
      -- by the request_nes wrap above; this is a safety net that hides responses
      -- arriving just after toggle-off.
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
        -- When disabling, drop any ghost text and any NES rendered just before
        -- the toggle; the gates only affect *future* requests and draws.
        -- dismiss() runs even with nothing visible: it also cancels the debounce
        -- timer and any in-flight request and resets the request context.
        -- Otherwise a leftover context keeps copilot.lua re-requesting on every
        -- CursorMovedI until InsertLeave.
        if not vim.g.copilot_enabled then
          suggestion.dismiss()
          -- nes.clear() only clears the current buffer; an NES left in another
          -- split would still apply on <Tab> there.
          for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            if vim.api.nvim_buf_is_loaded(buf) and vim.b[buf].nes_state then
              vim.api.nvim_buf_call(buf, nes.clear)
            end
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
