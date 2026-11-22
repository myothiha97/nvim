-- Markdown rendering for real `.md` files, LSP hover popups, Avante windows and
-- the CodeCompanion chat (its own Copilot Chat style, see overrides.filetype).
-- Scope is controlled purely by `file_types` / `ft` below — never attaches to
-- code buffers (lua, ts, go, etc.), the blink.cmp menu, or the blink doc window.

return {
  {
    -- Ensure markdown parsers are present so render-markdown has something to walk.
    -- LazyVim merges this into the base nvim-treesitter spec.
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "markdown", "markdown_inline" } },
  },
  {
    "MeanderingProgrammer/render-markdown.nvim",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    ft = { "markdown", "Avante", "codecompanion" },
    -- Also load just BEFORE the first .md file is read, not on its FileType.
    -- WARN: SILENT FAILURE. On setup render-markdown disables the markdown
    -- query's `conceal_lines` patterns (settings.lua `patterns`), so the ```
    -- fence lines stay on screen for the code block padding and language label.
    -- Loaded on FileType, the first .md buffer's highlighter was already running
    -- and kept hiding its fence lines; only later .md buffers showed them.
    -- Same cost as before: it loads when a .md file opens either way.
    event = { "BufReadPre *.md", "BufReadPre *.markdown" },
    -- Full raw/rendered toggle for the current buffer. The `render_modes` allowlist
    -- above keeps normal/visual rendered and only insert raw — handy for reading, but
    -- it hides backtick/asterisk symbols you need for vim motions while editing. This
    -- flips the plugin OFF for the buffer so EVERY mode (normal + visual) shows raw
    -- text; press again to restore rendering. Buffer-local, so it never touches other
    -- .md buffers or the hover/Avante popups. Lazy-loaded as a keymap = zero hot-path cost.
    --
    -- WARN: SILENT FAILURE. Keep `ft` on the key. Without it lazy.nvim maps the key
    -- GLOBALLY once this plugin loads (the first markdown buffer or LSP hover
    -- popup), which replaced LazyVim's own `<leader>uh` inlay-hint toggle in
    -- every code buffer. With `ft` the map is buffer-local to these filetypes.
    keys = {
      {
        "<leader>uh",
        function()
          require("render-markdown").buf_toggle()
        end,
        ft = { "markdown", "Avante", "codecompanion" },
        mode = { "n", "x" },
        desc = "Toggle Markdown render (raw/rendered)",
      },
    },
    opts = {
      -- `codecompanion` is the chat buffer only. Its input split
      -- (`codecompanion_chat_input`) stays raw on purpose: you type there.
      file_types = { "markdown", "Avante", "codecompanion" },
      -- We don't want render-markdown providing blink.cmp/cmp sources.
      completions = { lsp = { enabled = false } },
      -- Strip ALL heading color: `backgrounds = {}` drops the full-width line
      -- block, `foregrounds = {}` drops the colored heading text/icon. Headings
      -- still get their icon glyph, just in default text color. Applies
      -- everywhere this plugin attaches (markdown files AND hover/Avante popups).
      heading = { backgrounds = {}, foregrounds = {} },
      -- Never reveal raw markdown on the cursor's line (the Obsidian-style
      -- per-line raw/rendered toggle). With this off:
      --   * Hover/Avante popups: always fully rendered; cursor position is
      --     irrelevant (read-only, no insert mode).
      --   * Real .md files: the cursor line stays RENDERED in normal mode.
      -- Editing toggles on MODE, not cursor line. `render_modes` is an allowlist
      -- of modes that stay RENDERED; the default { "n", "c", "t" } excludes both
      -- insert AND visual, so selecting text would drop to raw. We add the three
      -- visual variants ("v" charwise, "V" linewise, "\22" Ctrl-V blockwise) so
      -- visual mode keeps rendering — only insert ("i", omitted) shows raw for
      -- editing. No per-line flicker as you move.
      render_modes = { "n", "c", "t", "v", "V", "\22" },
      anti_conceal = { enabled = false },
      -- Fenced code blocks in .md files: no background, no header bar — just a
      -- plain ` js` language label above the snippet, with treesitter colors on
      -- the code. `disable_background = true` removes the code fill; the default
      -- `border = "hide"` conceals the ``` fences and surfaces the label.
      -- `language_border = ""` drops the `█` fill char that padded out the
      -- header line (highlighted via RenderMarkdownCodeBorder) — that was the
      -- teal bar stretching right of "js".
      code = { disable_background = true, language_border = "" },
      -- Conceal control, split by render-markdown state:
      --   * `rendered` = values applied while rendering is ON (normal viewing).
      --     `conceallevel = 3` fully hides backticks/emphasis markers; treesitter
      --     does the actual concealing. `concealcursor = "nvc"` (normal, visual,
      --     command) keeps the cursor's own line concealed too — only insert
      --     (omitted) reveals raw symbols for editing. No per-line flicker.
      --   * `default` = values applied while rendering is OFF, i.e. after the
      --     `<leader>uh` toggle. `conceallevel = 0` disables ALL conceal so every
      --     raw symbol (`` ` ``, `*`, `#`) shows in every mode — that's the whole
      --     point of the toggle. `concealcursor = ""` is moot at level 0 but kept
      --     consistent.
      -- Applies to markdown files and the popups.
      win_options = {
        conceallevel = { default = 0, rendered = 3 },
        concealcursor = { default = "", rendered = "nvc" },
      },
      -- Hover popups (buftype=nofile) get a tightened style: NormalFloat padding
      -- matches the float background, sign column off (signs look broken in
      -- narrow floats). render-markdown's docs explicitly recommend this block
      -- for LSP hover docs.
      overrides = {
        buftype = {
          nofile = {
            -- Render in all modes — the plugin's default mode list can skip
            -- modes that leave fences/symbols raw. `true` = always render.
            -- This is the docs-recommended setting for LSP hover docs.
            render_modes = true,
            padding = { highlight = "NormalFloat" },
            sign = { enabled = false },
            -- Strip the code-block language header (the "lua"/"typescript" chip)
            -- in hover popups. `language = false` hides the header row while
            -- keeping delimiter concealment intact. `disable_background = true`
            -- removes the RenderMarkdownCode background block behind fenced code
            -- (e.g. function signatures in LSP hover) so the popup stays flat —
            -- text/treesitter highlights remain, just no colored box.
            -- `border = "hide"` keeps popups flat: it cancels the top-level
            -- "thin" border so hover docs don't get the rule lines, just
            -- concealed fences + treesitter colors.
            code = { language = false, sign = false, disable_background = true, border = "hide" },
          },
        },
        -- Real .md files (listed buffers) get the CodeCompanion chat look (Myo,
        -- 2026-11-22: "the right side look better"). LSP hover, Avante and the
        -- chat are unlisted, so they never see this block. Snacks previews are
        -- unlisted too and keep the old look. Colours: md_doc_groups below.
        -- Two deliberate differences from the chat, because .md files are edited,
        -- not only read:
        --   * a per-level H1..H6 glyph in the sign column (the chat gives every
        --     level one colour and hides `##`, so the level is otherwise lost);
        --   * the code block language label (` ts`, ` go`) is kept.
        buflisted = {
          [true] = {
            heading = {
              position = "inline",
              icons = { "" },
              foregrounds = { "MarkdownDocHeading" },
              backgrounds = {},
              sign = true,
              signs = { "\u{F026B}", "\u{F026C}", "\u{F026D}", "\u{F026E}", "\u{F026F}", "\u{F0270}" },
            },
            code = {
              disable_background = { "diff" }, -- plugin default: diffs keep their own colours
              highlight = "MarkdownDocCode",
              highlight_border = "MarkdownDocCode",
              border = "thick",
              width = "full",
              left_pad = 2,
            },
            bullet = { icons = { "•", "◦", "▪", "▫" }, highlight = "Normal" },
            quote = { highlight = "MarkdownDocRule" },
            dash = { highlight = "MarkdownDocRule" },
          },
        },
        -- CodeCompanion chat, styled after VS Code Copilot Chat. Nothing here
        -- reaches .md files, hover or Avante: it is a filetype override.
        --
        -- WARN: SILENT FAILURE. The chat buffer is ALSO buftype=nofile, so it
        -- gets the hover block above first; render-markdown applies buftype and
        -- THEN filetype overrides (lib/config.lua, deep-extend "force"). Any key
        -- the hover block sets that this block does not re-set leaks into the
        -- chat. That is why `code` below spells out every hover key.
        --
        -- Colours live with the other chat colours in plugins/codecompanion.lua
        -- (winhighlight remaps RenderMarkdownCode/CodeInline/Bullet and the
        -- heading groups in the chat window only).
        filetype = {
          codecompanion = {
            -- Stay rendered in insert mode too, matching the chat's own
            -- concealcursor = "nvic" (plugins/codecompanion.lua); otherwise the
            -- whole reply flips to raw markdown when you press `i`.
            render_modes = true,
            win_options = { concealcursor = { rendered = "nvic" } },
            sign = { enabled = false },
            -- The hover block pads with NormalFloat; the chat pads with its own
            -- prose group (Normal is remapped in the chat window).
            padding = { highlight = "Normal" },
            -- Headings: plain semibold text, `##` hidden, no icon, no bar.
            -- `icons = { "" }` + inline position conceals the marker; with no
            -- icon render-markdown would leave the raw `##` showing.
            heading = {
              position = "inline",
              icons = { "" },
              foregrounds = { "CodeCompanionChatHeading" },
              backgrounds = {},
              sign = false,
            },
            -- Code blocks: a slightly raised panel, no language header and no
            -- border line. `thick` turns the hidden fence lines into one row of
            -- block background above and below, the padding VS Code gives.
            code = {
              language = false,
              sign = false,
              disable_background = { "diff" }, -- plugin default: diffs keep their own colours
              border = "thick",
              width = "full",
              left_pad = 2,
              -- No inline_pad: inline code has no chip (see codecompanion.lua),
              -- so padding cells would only show as stray spaces.
            },
            -- Small round bullets like Copilot Chat, instead of ● ○ ◆ ◇.
            bullet = { icons = { "•", "◦", "▪", "▫" } },
          },
        },
      },
    },
    config = function(_, opts)
      require("render-markdown").setup(opts)

      -- Colours for the .md file look (overrides.buflisted above). Same values as
      -- the CodeCompanion chat (plugins/codecompanion.lua, chat_highlights): if
      -- you retune one, retune both. Defined here, not in the theme, so they
      -- survive a colorscheme switch (re-applied on ColorScheme).
      local surface = require("config.ui").surface
      local function md_doc_groups()
        local set = vim.api.nvim_set_hl
        set(0, "MarkdownDocHeading", { fg = "#c48956", bold = true }) -- muted orange
        set(0, "MarkdownDocStrong", { fg = "#cfcea7", bold = true }) -- soft sand
        set(0, "MarkdownDocCode", { bg = surface.panel })
        set(0, "MarkdownDocRule", { fg = surface.guide_active })
      end
      md_doc_groups()
      local group = vim.api.nvim_create_augroup("MarkdownDocStyle", { clear = true })
      vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = md_doc_groups })

      -- Heading text and **bold** are painted by treesitter, not render-markdown
      -- (its `foregrounds` only colour the sign), so both are remapped per window,
      -- as the chat does. `vim.wo[win][0]` is `:setlocal`: the remap belongs to
      -- this buffer in this window, and other buffers shown in the same window
      -- later do not inherit it. Cost: one check per BufWinEnter.
      local remaps = { "@markup.strong:MarkdownDocStrong" }
      for level = 1, 6 do
        remaps[#remaps + 1] = "@markup.heading." .. level .. ".markdown:MarkdownDocHeading"
      end
      local remap = table.concat(remaps, ",")
      vim.api.nvim_create_autocmd("BufWinEnter", {
        group = group,
        callback = function(args)
          if vim.bo[args.buf].filetype ~= "markdown" or not vim.bo[args.buf].buflisted then
            return
          end
          local win = vim.api.nvim_get_current_win()
          if vim.api.nvim_win_get_buf(win) ~= args.buf then
            return
          end
          local wh = vim.wo[win][0].winhighlight
          if not wh:find(remap, 1, true) then
            vim.wo[win][0].winhighlight = (wh ~= "" and wh .. "," or "") .. remap
          end
        end,
      })
    end,
  },
}
