return {
  {
    "kevinhwang91/nvim-ufo",
    dependencies = { "kevinhwang91/promise-async" },
    event = "BufReadPost",
    enabled = true,
    -- init = function()
    --   -- Disable fold highlight - run after colorscheme loads
    --   vim.api.nvim_create_autocmd("ColorScheme", {
    --     callback = function()
    --       vim.api.nvim_set_hl(0, "Folded", { bg = "NONE" })
    --       vim.api.nvim_set_hl(0, "UfoFoldedBg", { bg = "NONE" })
    --       vim.api.nvim_set_hl(0, "UfoFoldCount", { fg = "#c9ba9b", italic = true })
    --     end,
    --   })
    --   vim.api.nvim_set_hl(0, "Folded", { bg = "NONE" })
    --   vim.api.nvim_set_hl(0, "UfoFoldedBg", { bg = "NONE" })
    --   vim.api.nvim_set_hl(0, "UfoFoldCount", { fg = "#c9ba9b", italic = true })
    -- end,
    -- Note: Folded/UfoFoldedBg highlights are cleared in themes.lua on_highlights
    keys = {
      {
        "zR",
        function()
          require("ufo").openAllFolds()
        end,
        desc = "Open all folds",
      },
      {
        "zM",
        function()
          require("ufo").closeAllFolds()
        end,
        desc = "Close all folds",
      },
      {
        "zk",
        function()
          require("ufo").peekFoldedLinesUnderCursor()
        end,
        desc = "Peek fold",
      },
      {
        "zv",
        function()
          local bufnr = vim.api.nvim_get_current_buf()
          local lang_queries = {
            typescript = "[(function_declaration) (function_expression) (arrow_function) (method_definition)] @func",
            tsx = "[(function_declaration) (function_expression) (arrow_function) (method_definition)] @func",
            javascript = "[(function_declaration) (function_expression) (arrow_function) (method_definition)] @func",
            jsx = "[(function_declaration) (function_expression) (arrow_function) (method_definition)] @func",
            lua = "[(function_declaration) (local_function)] @func",
            python = "(function_definition) @func",
            go = "[(function_declaration) (method_declaration)] @func",
            rust = "(function_item) @func",
          }

          local func_lines = {}
          local ok_p, parser = pcall(vim.treesitter.get_parser, bufnr)
          if ok_p and parser then
            local lang = parser:lang()
            local query_str = lang_queries[lang]
            if query_str then
              local ok_q, query = pcall(vim.treesitter.query.parse, lang, query_str)
              if ok_q and query then
                local tree = parser:parse()[1]
                if tree then
                  local root = tree:root()
                  for _, node in query:iter_captures(root, bufnr, 0, -1) do
                    local lnum = node:start() + 1
                    if vim.fn.foldlevel(lnum) > 0 then
                      table.insert(func_lines, lnum)
                    end
                  end
                end
              end
            end
          end

          -- Fallback: top-level folds when treesitter has no query for this language
          if #func_lines == 0 then
            local line_count = vim.api.nvim_buf_line_count(bufnr)
            for lnum = 1, line_count do
              if vim.fn.foldlevel(lnum) > 0 and (lnum == 1 or vim.fn.foldlevel(lnum - 1) == 0) then
                table.insert(func_lines, lnum)
              end
            end
          end

          if #func_lines == 0 then
            return
          end

          local any_open = false
          for _, lnum in ipairs(func_lines) do
            if vim.fn.foldclosed(lnum) == -1 then
              any_open = true
              break
            end
          end

          local saved_cursor = vim.api.nvim_win_get_cursor(0)
          for _, lnum in ipairs(func_lines) do
            if vim.fn.foldlevel(lnum) > 0 then
              vim.api.nvim_win_set_cursor(0, { lnum, 0 })
              if any_open then
                if vim.fn.foldclosed(lnum) == -1 then
                  pcall(vim.cmd, "normal! zc")
                end
              else
                if vim.fn.foldclosed(lnum) ~= -1 then
                  pcall(vim.cmd, "normal! zo")
                end
              end
            end
          end
          vim.api.nvim_win_set_cursor(0, saved_cursor)
        end,
        desc = "Toggle all function folds",
      },
    },
    init = function()
      -- bufnr → true once imports have been auto-folded for this buffer lifetime.
      -- Reset on BufDelete/BufWipeout so a re-opened file gets a fresh fold.
      local folded = {}

      local function get_first_import_line(bufnr)
        local ok_parser, parser = pcall(vim.treesitter.get_parser, bufnr)
        if not ok_parser or not parser then
          return nil
        end
        local tree = parser:parse()[1]
        if not tree then
          return nil
        end
        local lang = parser:lang()
        local ok_q, query = pcall(vim.treesitter.query.parse, lang, [[ (import_statement) @import ]])
        if not ok_q or not query then
          return nil
        end
        for _, node in query:iter_captures(tree:root(), bufnr, 0, -1) do
          return node:start() + 1 -- first import, 1-indexed
        end
        return nil
      end

      local function try_fold(bufnr, line, retries)
        if retries <= 0 or not vim.api.nvim_buf_is_valid(bufnr) then
          return
        end

        -- foldlevel == 0 means UFO hasn't computed this fold yet; retry
        if vim.fn.foldlevel(line) == 0 then
          vim.defer_fn(function()
            try_fold(bufnr, line, retries - 1)
          end, 150)
          return
        end

        -- Only act when this buffer is visible in the current window
        local win = vim.api.nvim_get_current_win()
        if vim.api.nvim_win_get_buf(win) ~= bufnr then
          return
        end

        if vim.fn.foldclosed(line) == -1 then
          local saved = vim.api.nvim_win_get_cursor(win)
          vim.api.nvim_win_set_cursor(win, { line, 0 })
          pcall(vim.cmd, "normal! zc")
          vim.api.nvim_win_set_cursor(win, saved)
        end

        folded[bufnr] = true
      end

      -- BufReadPost fires on first open AND after :bdelete/:bwipeout + reopen.
      -- It does NOT fire when switching between already-open buffers (snacks/harpoon/marks),
      -- so we never re-fold a buffer the user is actively working in.
      vim.api.nvim_create_autocmd("BufReadPost", {
        pattern = { "*.ts", "*.tsx", "*.js", "*.jsx" },
        callback = function(args)
          local bufnr = args.buf
          folded[bufnr] = nil -- fresh read = treat as new

          local ok_stat, stat = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(bufnr))
          if ok_stat and stat and stat.size > 102400 then
            return
          end

          vim.defer_fn(function()
            if folded[bufnr] or not vim.api.nvim_buf_is_valid(bufnr) then
              return
            end
            local line = get_first_import_line(bufnr)
            if line then
              try_fold(bufnr, line, 5)
            end
          end, 200)
        end,
      })

      -- Clean up tracking when buffer is removed so its number can be reused safely
      vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
        callback = function(args)
          folded[args.buf] = nil
        end,
      })
    end,
    opts = {
      provider_selector = function(bufnr, filetype, buftype)
        if buftype ~= "" then
          return { "indent" }
        end

        local treesitter_folds = {
          javascript = true,
          javascriptreact = true,
          typescript = true,
          typescriptreact = true,
          tsx = true,
          jsx = true,
          lua = true,
          go = true,
          python = true,
          rust = true,
        }

        if treesitter_folds[filetype] then
          local ok, stat = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(bufnr))
          if ok and stat and stat.size > 200 * 1024 then
            return { "indent" }
          end

          return { "treesitter", "indent" }
        end

        return { "indent" }
      end,
      -- use fold_virt_text_handler to customize the virtual text displayed for folded lines
      -- fold_virt_text_handler = function(virtText, lnum, endLnum, width, truncate)
      --   local newVirtText = {}
      --   local suffix = ("  %d lines "):format(endLnum - lnum) -- display number of lines in fold
      --   local sufWidth = vim.fn.strdisplaywidth(suffix)
      --   local targetWidth = width - sufWidth
      --   local curWidth = 0
      --   for _, chunk in ipairs(virtText) do
      --     local chunkText = chunk[1]
      --     local chunkWidth = vim.fn.strdisplaywidth(chunkText)
      --     if targetWidth > curWidth + chunkWidth then
      --       table.insert(newVirtText, chunk)
      --     else
      --       chunkText = truncate(chunkText, targetWidth - curWidth)
      --       local hlGroup = chunk[2]
      --       table.insert(newVirtText, { chunkText, hlGroup })
      --       break
      --     end
      --     curWidth = curWidth + chunkWidth
      --   end
      --   table.insert(newVirtText, { suffix, "UfoFoldCount" })
      --   return newVirtText
      -- end,
      open_fold_hl_timeout = 0,
    },
  },

  {
    "luukvbaal/statuscol.nvim",
    enabled = false,
    event = "BufReadPost",
    init = function()
      -- Toggle fold column with <leader>uo
      vim.keymap.set("n", "<leader>uo", function()
        if vim.o.foldcolumn == "0" then
          vim.o.foldcolumn = "1"
        else
          vim.o.foldcolumn = "0"
        end
      end, { desc = "Toggle fold column" })
    end,
    opts = function()
      local builtin = require("statuscol.builtin")
      return {
        relculright = true,
        segments = {
          { text = { "%s" }, click = "v:lua.ScSa" },
          { text = { builtin.lnumfunc }, click = "v:lua.ScLa" },
          { text = { " ", builtin.foldfunc, " " }, click = "v:lua.ScFa" },
        },
      }
    end,
  },
}
