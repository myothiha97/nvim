return {
  -- Full-fidelity, VSCode-style markdown preview in the browser (Mermaid diagrams,
  -- KaTeX math, synced scroll). Complements render-markdown.nvim: that stays the
  -- inline reader/editor; this is an on-demand "full review mode" for complex docs.
  --
  -- Perf: fully lazy. Loads only on a markdown buffer or the preview command, and
  -- the node server runs ONLY while a preview tab is open (killed on stop/close) —
  -- zero startup and zero idle cost.
  {
    "iamcco/markdown-preview.nvim",
    ft = "markdown",
    cmd = { "MarkdownPreview", "MarkdownPreviewStop", "MarkdownPreviewToggle" },
    -- Pull the prebuilt binary instead of a yarn build (no JS toolchain needed).
    -- Use install.sh with no tag so it grabs the latest release that actually ships
    -- a macOS arm64 binary; the repo's package.json version (v0.0.1) has none, which
    -- makes the default mkdp#util#install() 404 on this platform.
    build = "cd app && ./install.sh",
    keys = {
      -- Buffer-local to markdown (ft), so it never collides with the global
      -- <leader>u toggle group elsewhere.
      -- Opens the file in Obsidian, the one viewer for every markdown file
      -- (2026-10-23 freeze override, todos/freeze/). Obsidian shows the file as
      -- saved, so unsaved edits are written first. `open` runs async, so nvim
      -- never waits on it. The browser preview stays on :MarkdownPreview.
      {
        "<leader>ui",
        function()
          local file = vim.api.nvim_buf_get_name(0)
          if file == "" then
            vim.notify("Save the file first, Obsidian opens files from disk", vim.log.levels.WARN)
            return
          end
          vim.cmd("silent update")
          vim.system({ "open", "-a", "Obsidian", file }, {}, function(result)
            if result.code ~= 0 then
              vim.schedule(function()
                vim.notify("Could not open in Obsidian: " .. vim.trim(result.stderr or ""), vim.log.levels.ERROR)
              end)
            end
          end)
        end,
        ft = "markdown",
        desc = "Open in Obsidian",
      },
    },
    init = function()
      vim.g.mkdp_auto_close = 0 -- keep the tab open when switching buffers
      vim.g.mkdp_theme = "dark" -- match the dark editor (flip to "light" for prose comfort)
      -- GitHub-parity stylesheet (wider column, SF font, 1.5 line-height).
      -- NOTE: mkdp_markdown_css REPLACES the bundled sheet, so this file is a full
      -- copy of GitHub's markdown.css with 3 tweaks — edit it to adjust width/font.
      vim.g.mkdp_markdown_css = vim.fn.stdpath("config") .. "/assets/mkdp-markdown.css"
    end,
  },
}
