-- base configs
local base_width = 0.35

return {
  {
    "olimorris/codecompanion.nvim",
    enabled = true,
    -- Lazy-load only on its commands/keymaps so there is zero startup cost.
    -- The `keys` trigger loads the plugin before feeding the mapping; `cmd`
    -- covers typing `:CodeCompanion ...` directly at the cmdline.
    cmd = { "CodeCompanion", "CodeCompanionChat" },
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    ---@module 'codecompanion'
    ---@type CodeCompanion.Config
    opts = {
      -- Inline-only usage: ask the AI to write/complete/edit code in place.
      -- Reuses the GitHub Copilot OAuth token that copilot.lua already
      -- provisions, so there is no extra API key or billing.
      --
      -- MODEL: left unset = Copilot's default model. To pin one, e.g.:
      --   inline = { adapter = { name = "copilot", model = "claude-sonnet-4" } }
      -- Discover the exact model ids your Copilot sub exposes by opening a chat
      -- (<leader>aC) and pressing `ga` (Select Adapter -> Select Model).
      -- Plain chats stay tool-free (conversational). The agentic chat gets its
      -- edit tools injected per-keymap instead (see <leader>aa below), so we don't
      -- make every chat agentic globally. (Chat adapter already defaults to copilot.)
      -- ── Switching the CHAT provider: Copilot <-> Claude Code ──────────────────
      -- Both are key-free (no paid API key). Pick one on `interactions.chat.adapter`
      -- below:
      --   "copilot"      Copilot subscription. Default. Nothing to install.
      --   "claude_code"  Claude *subscription* via the ACP bridge. One-time shell
      --                  setup first:
      --                    npm install -g @agentclientprotocol/claude-agent-acp
      --                    claude setup-token
      --                    export CLAUDE_CODE_OAUTH_TOKEN="<token>"   # in ~/.zshrc
      --                  Neovim must inherit CLAUDE_CODE_OAUTH_TOKEN (restart tmux/
      --                  shell so the adapter's auth, which requires it, can see it).
      -- To switch: set `interactions.chat.adapter` below to "copilot" (string) or
      -- claude_code (string for its default model, or a table to pin one -- see the
      -- model note there). Restart Neovim after. Inline always stays on Copilot.
      --
      -- The claude_code adapter's default command is already `claude-agent-acp`
      -- (the binary the package above installs), so no command override is needed --
      -- the built-in adapter works as-is once the binary + token are in place.
      --
      -- ── Thinking / reasoning "effort" (REFERENCE) ─────────────────────────────
      -- CodeCompanion does NOT manage or auto-tune reasoning effort. It's a pass-
      -- through: it sends your prompt and renders the reply. How hard the model
      -- "thinks" is decided model-side, and you steer it -- not CodeCompanion.
      --
      --   Claude Code (claude_code, ACP):
      --     * No low/medium/high enum (unlike Codex/OpenAI `reasoning_effort`).
      --     * The Claude Code AGENT auto-decides a thinking budget from task
      --       complexity. Good default -- usually leave it alone.
      --     * Per-prompt override: include a thinking keyword in your message,
      --       escalating: `think` < `think hard` < `think harder` < `ultrathink`.
      --       The AGENT (not CodeCompanion) interprets these.
      --     * Global ceiling: `MAX_THINKING_TOKENS` env (read by the bridge + Claude
      --       Code SDK). Higher = more reasoning. Simplest is a shell export in
      --       ~/.zshrc (the spawned claude-agent-acp child inherits it):
      --         export MAX_THINKING_TOKENS=10000      # ~4000 light · 10000 heavy
      --       Or set it from this config by re-introducing an adapter extend:
      --         adapters = {
      --           acp = {
      --             claude_code = function()
      --               return require("codecompanion.adapters").extend("claude_code", {
      --                 env = { MAX_THINKING_TOKENS = "10000" },
      --               })
      --             end,
      --           },
      --         },
      --
      --   Copilot (copilot, HTTP):
      --     * No reasoning-effort knob exposed either. "Effort" is just whichever
      --       MODEL you pick (via `ga` -> Select Model, or by pinning a model in the
      --       adapter). A stronger model = more capability; there is no separate
      --       effort dial. Reasoning-capable models reason on their own.
      --
      -- TL;DR: choose effort via MODEL (both providers) + thinking KEYWORDS or
      -- MAX_THINKING_TOKENS (Claude Code only). CodeCompanion adds nothing automatic.
      adapters = {
        acp = {
          -- Optional Codex ACP adapter. Chat still defaults to Claude Code below;
          -- this only affects choosing "codex" from `ga`.
          --
          -- Use the same ChatGPT/Codex login as the Codex CLI. The adapter default is
          -- `openai-api-key`, which can hit API billing/quota even when the CLI itself
          -- works through `codex login`.
          --
          -- Pin only CodeCompanion's Codex model default. Chat and inline still use
          -- the adapters configured below.
          codex = function()
            return require("codecompanion.adapters").extend("codex", {
              -- defaults = {
              --   auth_method = "chatgpt",
              --   session_config_options = {
              --     -- model = "gpt-5.5", -- for serious coding tasks
              --     model = "gpt-5.4", -- for every day tasks and token efficiency
              --   },
              -- },
              defaults = {
                auth_method = "chatgpt",
                session_config_options = {
                  model = "gpt-5.5",
                },
              },
            })
          end,
        },
      },

      interactions = {
        -- Inline stays on Copilot (HTTP) -- ACP adapters aren't suited to inline.
        inline = {
          adapter = "copilot",
        },
        chat = {
          -- Chat provider: "copilot" (active) or "claude_code" (see notes above).
          -- String form uses the adapter's default model; the table form pins a
          -- model. Here claude_code is pinned to Sonnet (currently 4.6). Model ids
          -- the ACP bridge accepts: "default" | "sonnet" | "sonnet[1m]" (1M context)
          -- | "opus" | "haiku". (Copilot form would be { name = "copilot", model = .. }.)
          -- adapter = { name = "claude_code", model = "opus" },
          adapter = { name = "codex" },
          -- adapter = {
          -- name = "copilot", -- currently having error when open the chat panel with leader aa
          -- },
          -- Chat-buffer keymaps. By default `q` (normal) = stop request and
          -- `<C-c>` = close, which is backwards from every other panel (quickfix,
          -- help, oil) where `q` closes. So we SWAP them: `q` closes the chat,
          -- `<C-c>` stops the in-flight request. setup() deep-merges (force) over
          -- the defaults, so overriding `modes` keeps each keymap's callback,
          -- index, and description intact. Insert-mode `<C-c>` close is preserved.
          -- keymaps = {
          --   close = { modes = { n = "q", i = "<C-c>" } },
          --   stop = { modes = { n = "<C-c>" } },
          -- },
          tools = {
            -- `require_approval_before` decides whether the agent PAUSES and waits
            -- for your go-ahead BEFORE this tool runs -- the "Approval Required:
            -- Read <file>? (g1/g2/g3/g4)" prompt you see in the chat.
            --   true  = every time the agent wants to read a file it stops and
            --           asks. Safe, but noisy: it interrupts with a "Read demo.go?"
            --           step whenever it re-reads a file mid-task. (No `gv` is shown
            --           here -- a read has nothing to preview, only g1-g4.)
            --   false = the tool runs immediately, no prompt.
            -- We set it false for read_file specifically because it is READ-ONLY --
            -- it cannot change your code, so there's nothing to guard against. The
            -- edit tool (insert_edit_into_file) keeps its own separate confirmation,
            -- so your buffers are still never written without review.
            ["read_file"] = {
              opts = {
                require_approval_before = false,
              },
            },
          },
        },
      },

      display = {
        chat = {
          fold_context = true,
          window = {
            -- Keep the base config numeric. We clamp the real split width in a
            -- ChatOpened autocmd below because CodeCompanion still assumes this
            -- field is a raw number in some code paths.
            width = base_width,
            -- Window-local options, applied to the chat window ONLY
            -- (shared/ui.lua hands this table to `set_win_options(winnr, ...)`),
            -- so nothing here leaks into code buffers. Line numbers are noise in a
            -- conversation and cost columns of a narrow panel. setup() deep-merges,
            -- so the plugin's own breakindent/linebreak/wrap defaults are kept.
            opts = {
              number = false,
              relativenumber = false,
            },
          },
        },
      },

      -- Diff rendering REFERENCE (not used at runtime -- the present_diff override
      -- in config() below is what we actually use). `threshold_for_chat` is the max
      -- changed-line count that renders the diff as an inline `````diff````` preview
      -- in the chat (approval_prompt.lua gates on: changed_lines <= threshold):
      --   0    -> diff opens in the SOURCE buffer (Cursor-style inline hunks); most
      --           intrusive, mutates the buffer you may be editing.
      --   6    -> plugin default: tiny diffs preview in chat, bigger edits show
      --           nothing inline and need `cp`.
      --   1000 -> ALWAYS render the full diff inline in the chat. Non-intrusive, but
      --           a large edit becomes a huge, hard-to-scan wall of diff -- which is
      --           why we override present_diff to show a short "review with cp" line
      --           instead. To switch back to inline previews, delete that override
      --           and uncomment the block below.
      -- display = { diff = { threshold_for_chat = 1000 } },
    },
    config = function(_, opts)
      require("codecompanion").setup(opts)

      -- Ratio/max keep the clamp in the same ballpark as `display.chat.window.width`
      -- above, so it widens the panel instead of silently capping it. `max_width` is
      -- the knob that actually bites on a normal-size terminal; `min_width` only
      -- matters on narrow ones.
      local function clamp_chat_width()
        local min_width = 48
        local max_width = 110
        local target_width = math.floor(vim.o.columns * base_width)
        return math.max(min_width, math.min(max_width, target_width))
      end

      -- Chat-window-only colors.
      --
      -- Highlight groups are GLOBAL, so recoloring the theme's groups would also
      -- repaint code buffers, real .md files and LSP hover popups. To keep this to
      -- the chat we define our OWN groups and remap them per window through
      -- 'winhighlight' -- Neovim implements that option as a window-local highlight
      -- namespace, so it covers treesitter (extmark) groups too, not just UI groups.
      --
      --   CodeCompanionInlineCode  <- @markup.raw.markdown_inline, the inline `code`
      --     spans. The theme paints them gold on a dark olive block
      --     (solarized-osaka/groups/treesitter.lua: fg c.yellow500, bg c.green900),
      --     which is loud in a chat where most prose contains inline code. `bg =
      --     "NONE"` drops the block -- the color alone is enough to mark code.
      --
      --     A LIFTED, LOW-CHROMA blue, and both halves of that matter. Answers are
      --     dense with inline code (often every noun in a sentence), so a saturated
      --     accent stripes the paragraph instead of emphasising anything. Measured
      --     against the prose color, on this background:
      --       #268bd2  Solarized blue, tried first. L* 55.6, chroma 172, and only
      --                5.2:1 contrast on the bg -- the LOWEST-contrast text in the
      --                chat, i.e. simultaneously the loudest and the hardest to read.
      --       #1d98cd  `palette.blue` (variants.blue.azure), tried too. Same problem,
      --                L* 59.1, chroma 176, and it leans cyan.
      --       #8ab4d8  this. L* 71.6, so 13 apart from the prose instead of 29, with
      --                chroma cut to 78 and contrast up to 8.7:1.
      --     Keep the separation from prose in the 9-15 L* band. Do NOT "fix" a dull
      --     look by raising chroma -- chroma is what stripes the text. #9cc0dc is the
      --     calmer step if this still reads busy.
      --
      --   CodeCompanionChatText  <- Normal + NormalNC, the chat's prose. The theme's
      --     base0 grey-cyan (about #9facad) reads dull over long answers, but the
      --     brighter end glares on this near-black background. Walked down in steps,
      --     all rejected as too hot: #ffffff (Ghostty's default foreground, i.e. what
      --     the Claude Code CLI prints at), then #eaeaea (Ghostty's palette 15).
      --     #d4d4d4 was the third step and shipped until 2026-08-05. All untinted
      --     greys -- Tokyo Night's #c0caf5 was the first attempt and read FADED
      --     rather than soft, because it is tinted lavender. Stay on the neutral
      --     axis if this is revisited.
      --
      --     2026-08-05: #d4d4d4 -> #b0b0b0, and this step was measured rather than
      --     eyeballed. #d4d4d4 rendered 27.6 L* BRIGHTER than the code text beside
      --     it (effective L* 65.4 vs 37.8), which is what read as glare. The
      --     workaround first attempted was global: `font-thicken-strength` in
      --     ghostty/config lowered 255 -> 140. That did dim the chat by 10.1 L*, but
      --     it also cost 5.6 L* on all code text and every other terminal pane, to
      --     fix one panel worth ~25% of the screen. Reverted there, fixed here
      --     instead, because this group is already chat-scoped and costs nothing
      --     elsewhere.
      --
      --     Two competing criteria were used, in this order, and they disagree:
      --
      --     1. PANE GAP. The panes sit side by side, so the eye judges the chat
      --        against the code beside it, not in isolation. Absolute lightness is
      --        therefore the wrong thing to hold fixed: an intermediate #b0b0b0 was
      --        picked to reproduce the absolute effective L* 55.4 that thicken 140
      --        had produced, hit it exactly, and still read FADED, because restoring
      --        thicken to 255 had lifted code text 32.2 -> 37.8 and so squeezed the
      --        pane gap 23.2 -> 17.6. By this criterion #c4c4c4 (gap 23.2) is correct.
      --     2. LONG-SESSION READING COMFORT. The gap target above is only a snapshot
      --        of a terminal setting that was live for a few minutes, so it is a
      --        reference point, not a requirement. For hours of reading on a
      --        near-black background the dimmer of two AA-passing options is the
      --        better pick, because glare from high-luminance text on near-black is
      --        the fatigue mechanism. By this criterion #b0b0b0 wins.
      --
      --     Neither criterion won outright. #c4c4c4 (gap-correct) read BRIGHT and
      --     #b0b0b0 (comfort-correct) read FADED, so those two reactions bracket the
      --     answer and the shipped value is the midpoint: #bbbbbb, effective L* 58.5,
      --     3.1 L* above the faded end and 2.5 L* below the bright end. Both distances
      --     sit under the ~5 L* perceptual floor, which is the point: from here
      --     neither end is reachable by eye.
      --
      --     Effective (coverage-weighted) L* of each candidate, so these are what
      --     the eye actually integrates, not the nominal hex lightness. Gap is
      --     against code base text at effective L* 37.8 (thicken 255). Contrast is
      --     also on the effective value, which is the conservative reading:
      --       #d4d4d4  65.4  gap 27.7  7.07:1  first value, too hot
      --       #cccccc  63.3  gap 25.5  6.58:1
      --       #c4c4c4  61.0  gap 23.2  6.12:1  bracket TOP, read bright
      --       #bbbbbb  58.5  gap 20.7  5.62:1  CURRENT -- midpoint of the bracket
      --       #b0b0b0  55.4  gap 17.6  5.06:1  bracket BOTTOM, read faded
      --       #aaaaaa  53.7  gap 15.9  4.77:1  last value still clearing WCAG AA
      --       #a4a4a4  52.0  gap 14.2  4.49:1  FAILS AA -- hard floor, do not go here
      --
      --     STOP HERE. The whole live band is #b0b0b0..#c4c4c4, only 5.6 L* wide,
      --     and #bbbbbb sits in the middle of it. Every remaining move is under the
      --     ~5 L* perceptual floor for text glyphs, so there is nothing left that can
      --     be seen -- a 1-hex-point step is 0.28 L*, about 18x below the floor.
      --     Further nudging cannot improve this, it can only re-enter the loop that
      --     produced four values in one evening. Never go below #aaaaaa: AA fails at
      --     #a4a4a4.
      --     If the code pane's brightness ever changes (font-thicken, font-size, a
      --     new font), the gap numbers above are void and must be re-derived.
      --
      --     Do NOT reach for a terminal-wide font or gamma knob for this again. If
      --     the chat is the only thing too bright, the chat is the only thing to
      --     change. See `todos/syntax-palette-followups.md` item 4 for the same
      --     lesson from the opposite direction (text that looked too DIM was also a
      --     rasterization question, not a colour one).
      --     `bold = false` is explicit: only the COLOR changes, the weight stays
      --     regular. NormalNC maps to the same group on purpose so the chat doesn't
      --     dim while you work in the code window, and `bg = "NONE"` keeps the
      --     transparent background.
      local chat_highlights = {
        {
          name = "CodeCompanionInlineCode",
          from = { "@markup.raw.markdown_inline" },
          opts = { fg = "#8ab4d8", bg = "NONE" },
        },
        {
          name = "CodeCompanionChatText",
          from = { "Normal", "NormalNC" },
          -- opts = { fg = "#d4d4d4", bg = "NONE", bold = false },  -- until 2026-08-05, too hot
          -- opts = { fg = "#c4c4c4", bg = "NONE", bold = false },  -- bracket top, read bright
          -- opts = { fg = "#b0b0b0", bg = "NONE", bold = false },  -- bracket bottom, read faded
          opts = { fg = "#bbbbbb", bg = "NONE", bold = false },
        },
      }

      -- Built once from the table above, in order, so the value is deterministic.
      local chat_winhighlight
      do
        local parts = {}
        for _, hl in ipairs(chat_highlights) do
          for _, from in ipairs(hl.from) do
            parts[#parts + 1] = from .. ":" .. hl.name
          end
        end
        chat_winhighlight = table.concat(parts, ",")
      end

      local function define_chat_highlights()
        for _, hl in ipairs(chat_highlights) do
          vim.api.nvim_set_hl(0, hl.name, hl.opts)
        end
      end

      -- A `:colorscheme` reload clears custom groups, so re-define on ColorScheme.
      local hl_group = vim.api.nvim_create_augroup("CodeCompanionChatHighlight", { clear = true })
      define_chat_highlights()
      vim.api.nvim_create_autocmd("ColorScheme", {
        group = hl_group,
        callback = define_chat_highlights,
      })

      -- Append rather than assign: CodeCompanion appends its own WinBar entries to
      -- 'winhighlight' (utils/ui.lua set_winbar), so we must not drop what's there.
      local function apply_chat_highlights(winnr)
        local current = vim.api.nvim_get_option_value("winhighlight", { win = winnr })
        if current:find(chat_winhighlight, 1, true) then
          return
        end
        local value = current ~= "" and (current .. "," .. chat_winhighlight) or chat_winhighlight
        vim.api.nvim_set_option_value("winhighlight", value, { win = winnr })
      end

      vim.api.nvim_create_autocmd("User", {
        group = vim.api.nvim_create_augroup("CodeCompanionChatWidth", { clear = true }),
        pattern = "CodeCompanionChatOpened",
        callback = function(args)
          local bufnr = args.data and args.data.bufnr
          if type(bufnr) ~= "number" or not vim.api.nvim_buf_is_valid(bufnr) then
            return
          end

          local winnr = vim.fn.bufwinid(bufnr)
          if winnr == -1 or not vim.api.nvim_win_is_valid(winnr) then
            return
          end

          apply_chat_highlights(winnr)

          -- Width clamping only makes sense for the vertical split layout.
          local window = require("codecompanion.config").display.chat.window
          if window.layout ~= "vertical" then
            return
          end

          vim.api.nvim_win_set_width(winnr, clamp_chat_width())
        end,
      })

      -- Agentic edit confirmation: don't dump the diff into the chat. A small diff
      -- is fine but a large edit becomes an unreadable wall of diff, and we review
      -- with `cp` anyway. Replace the chat-side diff preview with a short message so
      -- it's never a blank prompt. present_diff is an exported module function whose
      -- `prompt` field is what renders above the option list; we wrap it and fall
      -- back to the original if the internal contract ever changes (update-safe).
      local ok_ap, approval = pcall(require, "codecompanion.interactions.chat.helpers.approval_prompt")
      if ok_ap and type(approval.present_diff) == "function" then
        local orig_present_diff = approval.present_diff
        approval.present_diff = function(diff_opts)
          local ok = pcall(function()
            diff_opts.approve({
              title = diff_opts.title,
              -- Short status only -- the key list ("Please select an option") is
              -- rendered right below by CodeCompanion, so don't repeat the keys here.
              prompt = "Edit complete — review the proposed diff before accepting.",
            })
          end)
          if not ok then
            return orig_present_diff(diff_opts)
          end
        end
      end

      -- Move the "Always accept" choice to the BOTTOM of the option list. The order
      -- is hardcoded in diff.lua's build_approval_choices (view -> always_accept ->
      -- accept -> reject -> cancel) and ignores the keymap `index`, so we reorder the
      -- choices on the exported request() instead -- the one place every approval
      -- prompt funnels through. Keeps the destructive option visually last to match
      -- its c4 key. pcall-guarded; on any failure the original order passes through.
      if ok_ap and type(approval.request) == "function" then
        local labels = require("codecompanion.interactions.chat.tools.labels")
        local orig_request = approval.request
        approval.request = function(chat, request_opts)
          pcall(function()
            if request_opts and type(request_opts.choices) == "table" then
              local reordered, always = {}, nil
              for _, c in ipairs(request_opts.choices) do
                -- Scope c1/c2/c3/c4 to post-edit confirmation prompts only.
                -- Do not mutate `interactions.shared.keymaps`: other
                -- CodeCompanion UI reads that table too.
                if request_opts.title and request_opts.title:match("^Proposed edits") then
                  if c.label == labels.accept then
                    c.keymap = "c1"
                  elseif c.label == labels.reject then
                    c.keymap = "c2"
                  elseif c.label == labels.cancel then
                    c.keymap = "c3"
                  elseif c.label == labels.always_accept then
                    c.keymap = "c4"
                  elseif c.label == labels.view then
                    c.keymap = "cp"
                  end
                end
                if c.label == labels.always_accept then
                  always = c
                else
                  reordered[#reordered + 1] = c
                end
              end
              if always then
                reordered[#reordered + 1] = always
                request_opts.choices = reordered
              end
            end
          end)
          return orig_request(chat, request_opts)
        end
      end

      local ok_inline, inline = pcall(require, "codecompanion.interactions.inline")
      if ok_inline and type(inline.build_diff_banner) == "function" then
        inline.build_diff_banner = function()
          return "c1 Accept | c2 Reject | c4 Always Accept"
        end
      end

      -- Same scoped mapping for post-edit diff UIs: agent preview diff popups and
      -- inline assistant confirmations. We remove only the buffer-local
      -- accept/reject/always maps in those confirmation buffers, not the shared
      -- CodeCompanion keymap table or unrelated UI maps.
      local ok_dui, diff_ui = pcall(require, "codecompanion.diff.ui")
      if ok_dui and type(diff_ui.show) == "function" then
        local orig_show = diff_ui.show
        diff_ui.show = function(diff, show_opts)
          show_opts = show_opts or {}
          local is_agent_edit = show_opts.tool_name == "insert_edit_into_file"
          local is_inline_confirmation = show_opts.keymaps
            and show_opts.keymaps.on_accept
            and show_opts.keymaps.on_reject
            and show_opts.keymaps.on_always_accept
            and not is_agent_edit
          local is_acp_confirmation = show_opts.skip_default_keymaps == true
            and show_opts.chat_bufnr
            and show_opts.keymaps
            and show_opts.keymaps.on_reject
            and type(show_opts.banner) == "string"
            and show_opts.banner:find("Accept", 1, true)
          local is_confirmation = is_agent_edit or is_inline_confirmation or is_acp_confirmation
          if is_confirmation then
            local sk = require("codecompanion.config").interactions.shared.keymaps
            if show_opts.inline then
              show_opts.banner = "c1 Accept | c2 Reject | c4 Always Accept"
            elseif is_acp_confirmation then
              show_opts.banner = string.format(
                "c4 Always Accept | c1 Accept | c2 Reject | %s/%s Next/Prev | q Close",
                sk.next_hunk.modes.n,
                sk.previous_hunk.modes.n
              )
            elseif show_opts.banner == nil then
              show_opts.banner = string.format(
                "c1 Accept | c2 Reject | c4 Always Accept | %s/%s Next/Prev hunks | q Close",
                sk.next_hunk.modes.n,
                sk.previous_hunk.modes.n
              )
            end
          end
          local ui = orig_show(diff, show_opts)
          if is_acp_confirmation and ui and ui.bufnr then
            vim.schedule(function()
              if not vim.api.nvim_buf_is_valid(ui.bufnr) then
                return
              end
              local sk = require("codecompanion.config").interactions.shared.keymaps
              local remap = {
                { from = sk.always_accept.modes.n, to = "c4" },
                { from = sk.accept_change.modes.n, to = "c1" },
                { from = sk.reject_change.modes.n, to = "c2" },
              }
              for _, m in ipairs(remap) do
                local old = vim.api.nvim_buf_call(ui.bufnr, function()
                  return vim.fn.maparg(m.from, "n", false, true)
                end)
                if old and old.buffer == 1 and old.callback then
                  vim.keymap.set("n", m.to, old.callback, {
                    buffer = ui.bufnr,
                    desc = old.desc,
                    silent = true,
                    nowait = true,
                  })
                  pcall(vim.keymap.del, "n", m.from, { buffer = ui.bufnr })
                end
              end
            end)
          elseif is_confirmation and ui and ui.bufnr then
            local km = require("codecompanion.diff.keymaps")
            local sk = require("codecompanion.config").interactions.shared.keymaps
            pcall(vim.keymap.del, "n", sk.accept_change.modes.n, { buffer = ui.bufnr })
            pcall(vim.keymap.del, "n", sk.reject_change.modes.n, { buffer = ui.bufnr })
            pcall(vim.keymap.del, "n", sk.always_accept.modes.n, { buffer = ui.bufnr })
            vim.keymap.set("n", "c1", function()
              km.accept_change.callback(ui)
            end, { buffer = ui.bufnr, desc = "Accept all changes", silent = true, nowait = true })
            vim.keymap.set("n", "c2", function()
              km.reject_change.callback(ui)
            end, { buffer = ui.bufnr, desc = "Reject all changes", silent = true, nowait = true })
            vim.keymap.set(
              "n",
              "c4",
              function()
                km.always_accept.callback(ui)
              end,
              { buffer = ui.bufnr, desc = "Always accept changes from this chat buffer", silent = true, nowait = true }
            )
          end
          return ui
        end
      end

      -- "AI is working" feedback via fidget (Cursor/VSCode-style indicator).
      -- Driven off the request lifecycle with a refcount: the inline assistant
      -- fires two requests (a hidden classification call, then generation), so
      -- we keep one handle alive while any request is in flight and close it
      -- once the count returns to zero. The deferred close bridges the brief gap
      -- between the two calls so the spinner doesn't flicker; accept/reject fires
      -- no request, so the spinner is always gone before you act on the diff.
      local group = vim.api.nvim_create_augroup("CodeCompanionFidget", { clear = true })
      local handle = nil
      local count = 0
      local track_au = nil

      local function stop_tracking()
        if track_au then
          pcall(vim.api.nvim_del_autocmd, track_au)
          track_au = nil
        end
      end

      local function open()
        if handle then
          return
        end
        local ok, progress = pcall(require, "fidget.progress")
        if not ok then
          return
        end
        handle = progress.handle.create({
          title = "CodeCompanion",
          message = "Generating…",
          lsp_client = { name = "codecompanion" },
        })
      end

      local function close()
        if handle then
          handle.message = "Done"
          handle:finish()
          handle = nil
        end
      end

      vim.api.nvim_create_autocmd("User", {
        group = group,
        pattern = "CodeCompanionRequestStarted",
        callback = function()
          count = count + 1
          open()
        end,
      })
      vim.api.nvim_create_autocmd("User", {
        group = group,
        pattern = "CodeCompanionRequestFinished",
        callback = function(args)
          -- InlineFinished is success-only. RequestFinished also covers errors
          -- and cancellation, so the cursor tracker cannot leak into the session.
          if args.data and args.data.interaction == "inline" then
            stop_tracking()
          end
          count = math.max(0, count - 1)
          if count == 0 then
            -- Defer so a follow-up request (classify -> generate) reuses the
            -- same handle instead of closing and reopening it.
            vim.defer_fn(function()
              if count == 0 then
                close()
              end
            end, 200)
          end
        end,
      })

      -- Keep the chat panel fully rendered in every mode. CodeCompanion sets the
      -- chat buffer to conceallevel=2 and lets treesitter conceal markdown symbols
      -- (backticks/emphasis), but leaves concealcursor='' -- so the cursor line and
      -- any visual selection flip to raw. Concealing in normal+visual+insert+command
      -- stops that toggling. Scoped to the chat filetype; real .md files untouched.
      vim.api.nvim_create_autocmd("FileType", {
        group = group,
        pattern = "codecompanion",
        callback = function()
          vim.opt_local.concealcursor = "nvic"
        end,
      })

      -- Inline cursor preservation. The inline assistant deliberately refocuses
      -- the edit buffer and jumps the cursor to the diff (inline/init.lua:166-175)
      -- so you can accept with c1/c2/c4 -- but if you've moved on to keep coding,
      -- that yank-back interrupts you. We track your real position ONLY while an
      -- inline op is in flight and restore it once the diff lands.
      --
      -- Timing: the CursorMoved fired by the plugin's own jump is deferred to the
      -- main loop, so at InlineFinished `user_pos` is still your pre-jump position.
      -- We read it, stop tracking (so the deferred jump can't overwrite it), then
      -- schedule the restore. The tracker autocmd exists only during generation,
      -- so there is no steady-state hot-path cost.
      local user_pos = nil

      local function record()
        user_pos = {
          win = vim.api.nvim_get_current_win(),
          cursor = vim.api.nvim_win_get_cursor(0),
          view = vim.fn.winsaveview(),
        }
      end

      vim.api.nvim_create_autocmd("User", {
        group = group,
        pattern = "CodeCompanionInlineStarted",
        callback = function()
          record()
          stop_tracking() -- clear any leaked tracker from a prior op
          track_au = vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "WinEnter" }, {
            group = group,
            callback = record,
          })
        end,
      })

      vim.api.nvim_create_autocmd("User", {
        group = group,
        pattern = "CodeCompanionInlineFinished",
        callback = function()
          local pos = user_pos
          stop_tracking()
          if not pos or not vim.api.nvim_win_is_valid(pos.win) then
            return
          end
          vim.schedule(function()
            if not vim.api.nvim_win_is_valid(pos.win) then
              return
            end
            vim.api.nvim_set_current_win(pos.win)
            local lines = vim.api.nvim_buf_line_count(vim.api.nvim_win_get_buf(pos.win))
            if pos.cursor[1] <= lines then
              pcall(vim.fn.winrestview, pos.view)
            end
          end)
        end,
      })

      -- Auto-attach the current file to a NEW chat (the file you opened from).
      -- CodeCompanion can't read a file from a pasted path -- it only sees what's
      -- attached as context -- so we format the origin buffer's CONTENTS and add
      -- it to the chat's context list (shown as a reference, like the CLAUDE.md
      -- rules). Fires only on chat creation, so toggling an existing chat won't
      -- re-add. All pcall-guarded: if a future API change breaks it, the chat
      -- still opens, just without the auto-attached file (no error spam).
      --
      -- Attaches as a BUFFER (`- <buf>Makefile</buf>`), deliberately, NOT as a file
      -- (`- <file>Makefile</file>`) like `/file` produces. Switching to a file
      -- context was tried and reverted: it needs extra code to keep the line
      -- numbers the buffer formatter gives for free, and it reads from DISK, so
      -- unsaved edits would not reach the model. The only thing it buys is that its
      -- id matches `/file`, so adding the same file that way later dedupes instead
      -- of sending the contents twice -- not worth the code.
      vim.api.nvim_create_autocmd("User", {
        group = group,
        pattern = "CodeCompanionChatCreated",
        callback = function(args)
          local bufnr = args.data and args.data.bufnr
          if not bufnr then
            return
          end
          vim.schedule(function()
            local cc = require("codecompanion")
            local chat = cc.buf_get_chat and cc.buf_get_chat(bufnr)
            if not chat or not chat.buffer_context then
              return
            end
            local origin = chat.buffer_context.bufnr
            if not origin or not vim.api.nvim_buf_is_valid(origin) then
              return
            end
            local path = vim.api.nvim_buf_get_name(origin)
            -- Only real, on-disk files -- skip [No Name], pickers, terminals, etc.
            if path == "" or vim.bo[origin].buftype ~= "" then
              return
            end
            local ok, helpers = pcall(require, "codecompanion.interactions.chat.helpers")
            if not ok then
              return
            end
            local got, content, id = pcall(helpers.format_buffer_for_llm, origin, path, {
              message = "Here is the content from a file (including line numbers)",
            })
            if not got then
              return
            end
            pcall(function()
              chat:add_context({ content = content }, "buffer", id, {
                bufnr = origin,
                path = path,
                visible = false,
              })
            end)
          end)
        end,
      })
    end,
    keys = {
      -- Normal mode: select the current line first (`V`) so the inline assistant
      -- has a selection to anchor to. Without a selection the classifier often
      -- routes the response to a chat buffer instead of editing in place; with
      -- one it reliably picks `replace`/`add`. `:` in visual mode auto-inserts
      -- the `'<,'>` range, leaving `:'<,'>CodeCompanion ` prefilled for your prompt.
      {
        "<leader>ai",
        "V:CodeCompanion ",
        mode = "n",
        desc = "CodeCompanion: Inline ask (current line)",
      },
      -- Visual mode: the existing selection is the target; `:` adds the range.
      {
        "<leader>ai",
        ":CodeCompanion ",
        mode = "x",
        desc = "CodeCompanion: Inline ask (selection)",
      },
      -- Agentic chat: opens a chat preloaded with edit tools so "fix/implement
      -- this" APPLIES to the buffer as an accept/reject diff instead of just
      -- printing a code block. `read_file` also lets it pull in other files by
      -- path. Auto-attaches the current file. No shell exec / create / delete --
      -- type `@cmd_runner` / `@create_file` in the prompt per-request if needed.
      {
        "<leader>aa",
        function()
          -- Note: CodeCompanion.chat()'s `tools` arg is NOT forwarded to the
          -- constructor, so we add the tools to the returned chat directly.
          local chat = require("codecompanion").chat()
          if chat and chat.tool_registry then
            pcall(function()
              chat.tool_registry:add("insert_edit_into_file")
            end)
            pcall(function()
              chat.tool_registry:add("read_file")
            end)
          end
        end,
        mode = "n",
        desc = "CodeCompanion: Agentic chat (applies edits)",
      },
      -- Plain chat buffer (toggle): conversational, no auto-edits -- it prints
      -- code blocks you copy/apply yourself. Auto-attaches the current file.
      -- Async: submit, switch back to your code, keep editing while it streams.
      {
        "<leader>af",
        "<cmd>CodeCompanionChat Toggle<cr>",
        mode = "n",
        desc = "CodeCompanion: Chat buffer (plain)",
      },
      -- Add the current line (normal) or selection (visual) CONTENT to the chat as
      -- context -- this sends the actual code, unlike <leader>al/<leader>as which
      -- copy a path string (for Claude Code) that CodeCompanion cannot read.
      {
        "<leader>ae",
        "<cmd>CodeCompanionChat Add<cr>",
        mode = { "n", "x" },
        desc = "CodeCompanion: Add line/selection to chat",
      },
      -- Reset the active chat's tool approvals -- undoes an accidental `c4`
      -- (Always Accept) so the diff confirmation prompt comes back. Approvals are
      -- per-chat, in-memory state; this clears them for the last chat buffer.
      {
        "<leader>ar",
        function()
          local chat = require("codecompanion").last_chat()
          if not chat then
            vim.notify("No active CodeCompanion chat", vim.log.levels.WARN, { title = "CodeCompanion" })
            return
          end
          require("codecompanion.interactions.chat.tools.approvals"):reset(chat.bufnr)
          vim.notify(
            "Chat approvals reset — confirmation re-enabled",
            vim.log.levels.INFO,
            { title = "CodeCompanion" }
          )
        end,
        mode = "n",
        desc = "CodeCompanion: Reset chat approvals (undo c4)",
      },
    },
  },
}
