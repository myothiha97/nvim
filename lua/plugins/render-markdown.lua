-- Markdown rendering for real `.md` files plus LSP hover popups and Avante windows.
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
    ft = { "markdown", "Avante" },
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
        ft = { "markdown", "Avante" },
        mode = { "n", "x" },
        desc = "Toggle Markdown render (raw/rendered)",
      },
    },
    opts = {
      file_types = { "markdown", "Avante" },
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
      },
    },
  },
}
