-- WARN: SILENT FAILURE — grug-far's VISUAL p/P corrupt the header, and they do
-- it quietly: the text is written into a LATER input and the one you were
-- editing is emptied. Reproduced on `nvim --clean` with nothing but grug-far
-- 1.6.76 and `setup({})`, so this is the plugin, not this config. From
-- search = "previousKeyword", filesFilter = "*.{ts,tsx}":
--
--   V   p  ->  search = ""  filesFilter = "businessName\n*.{ts,tsx}"
--   viw p  ->  search = ""  filesFilter = "previousKeyworbusinessName*.{ts,tsx}"
--
-- Why: an input is a run of buffer lines fenced by LEFT-GRAVITY extmarks
-- (grug-far/render/input.lua). `inputs.pasteBelow` appends a scratch line with
-- `fillInput` and only THEN re-feeds `p`, so the edit lands while the selection
-- is still live and the two drift apart. Normal-mode p/P are fine (measured)
-- and stay with grug-far; only the visual maps are taken back.
--
-- Plain vim is then correct for every charwise selection (measured). V is the
-- one case it still gets wrong: a linewise paste DELETES the input's line,
-- collapsing two fences onto one row, and the pasted text is lost. So a
-- single-line V is rewritten to its charwise equivalent, which replaces the
-- text without ever removing the line. Multi-line V keeps vim's own behaviour.
-- The map covers the whole grug-far buffer, results rows included: a single-line
-- V p on a result row is rewritten the same way, which keeps the row and its
-- extmark intact.
local function reclaim_visual_paste(buf)
  for _, key in ipairs({ "p", "P" }) do
    vim.keymap.set("x", key, function()
      -- The count and register typed before `p` are still pending when an expr
      -- mapping returns, so return the bare key. Prefixing them again applied
      -- the count twice (`viw2"rp` pasted 4 times, `viw3p` 99 times).
      if vim.fn.mode() ~= "V" or vim.fn.line("v") ~= vim.fn.line(".") then
        return key
      end
      -- Clear the line's TEXT with "_D and type the register's in, so the line
      -- itself is never removed and no fence can move. Three traps, all
      -- measured, all of which put the text in the wrong input:
      --   * any linewise paste deletes the line;
      --   * `v$` / `0v` look like "select this line" and are not — both take
      --     the line break with them, so the paste joins the next line. That
      --     also makes a selection unusable on an EMPTY input line;
      --   * pasting a LINEWISE register over a charwise selection still splits
      --     the line in three, so the text is inserted with its trailing
      --     newline cut rather than pasted.
      -- "_D keeps the cleared text out of the registers. <C-r><C-o> inserts the
      -- text literally: plain <C-r> inserts it as if typed, so 'expandtab' turned
      -- a yanked tab-indented line into spaces that no longer match the code.
      return ('<Esc>0"_Di<C-r><C-o>=trim(getreg(\'%s\'), "\\n", 2)<CR><Esc>'):format(vim.v.register)
    end, {
      buffer = buf,
      expr = true,
      replace_keycodes = true,
      nowait = true,
      desc = "Paste over the selection (in place)",
    })
  end
end

local searchAndReplaceInProject = function()
  local grug = require("grug-far")
  local ext = vim.bo.buftype == "" and vim.fn.expand("%:e")
  local ext_groups = {
    ts = "*.{ts,tsx}",
    tsx = "*.{ts,tsx}",
    js = "*.{js,jsx}",
    jsx = "*.{js,jsx}",
  }
  local filter = ext_groups[ext] or ((ext and ext ~= "") and ("*." .. ext) or nil)
  grug.open({
    prefills = {
      filesFilter = filter,
      flags = "--ignore-case --sort=path --hidden --no-ignore --glob !node_modules/ --glob !.git/ --glob !build/",
    },
  })
end

return {
  {
    "MagicDuck/grug-far.nvim",
    opts = {
      headerMaxWidth = 80,
    },
    -- WARN: SILENT FAILURE — this is the ONLY `config` for grug-far. lazy.nvim
    -- keeps just the last fragment's config, so a second grug-far spec file
    -- defining one would drop this without a word.
    config = function(_, opts)
      require("grug-far").setup(opts)
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "grug-far",
        callback = function(args)
          vim.schedule(function()
            if vim.api.nvim_buf_is_valid(args.buf) then
              reclaim_visual_paste(args.buf)
            end
          end)
        end,
      })
    end,
    keys = {
      {
        "<leader>sf",
        searchAndReplaceInProject,
        -- function()
        --   local grug = require("grug-far")
        --   local ext = vim.bo.buftype == "" and vim.fn.expand("%:e")
        --   local ext_groups = {
        --     ts = "*.{ts,tsx}",
        --     tsx = "*.{ts,tsx}",
        --     js = "*.{js,jsx}",
        --     jsx = "*.{js,jsx}",
        --   }
        --   local filter = ext_groups[ext] or ((ext and ext ~= "") and ("*." .. ext) or nil)
        --   grug.open({
        --     prefills = {
        --       filesFilter = filter,
        --       flags = "--ignore-case --sort=path --hidden --no-ignore --glob !node_modules/ --glob !.git/ --glob !build/",
        --     },
        --   })
        -- end
        mode = { "n", "x" },
        desc = "Search and Replace in Project (Grug-far)",
      },
      {
        "<leader>sF",
        function()
          local grug = require("grug-far")
          local path = vim.fn.expand("%:p")
          if path == "" then
            return
          end
          grug.open({
            prefills = {
              filesFilter = vim.fn.expand("%:t"),
              paths = vim.fn.expand("%:h"),
              flags = "--ignore-case --sort=path",
            },
          })
        end,
        mode = { "n", "x" },
        desc = "Search and Replace in Current File (Grug-far)",
      },
      {
        "<leader>sR",
        function()
          local grug = require("grug-far")
          local word = vim.fn.expand("<cword>")
          local ext = vim.bo.buftype == "" and vim.fn.expand("%:e")
          local ext_groups = {
            ts = "*.{ts,tsx}",
            tsx = "*.{ts,tsx}",
            js = "*.{js,jsx}",
            jsx = "*.{js,jsx}",
          }
          local filter = ext_groups[ext] or ((ext and ext ~= "") and ("*." .. ext) or nil)
          grug.open({
            prefills = {
              search = word,
              filesFilter = filter,
              flags = "--sort=path --hidden --no-ignore --glob !node_modules/ --glob !.git/ --glob !build/",
            },
          })
        end,
        mode = { "n" },
        desc = "Rename Word Under Cursor in Project (Grug-far)",
      },
      {
        "<leader>sr",
        function()
          local grug = require("grug-far")
          local word = vim.fn.expand("<cword>")
          local path = vim.fn.expand("%:p")
          if path == "" then
            return
          end
          grug.open({
            prefills = {
              search = word,
              filesFilter = vim.fn.expand("%:t"),
              paths = vim.fn.expand("%:h"),
              flags = "--sort=path",
            },
          })
        end,
        mode = { "n" },
        desc = "Rename Word Under Cursor in File (Grug-far)",
      },
    },
  },
}
