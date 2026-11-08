-- Database inspection: vim-dadbod + vim-dadbod-ui + vim-dadbod-completion.
--
-- Why not the LazyVim `lang.sql` extra: it appends `dadbod` to blink's
-- `sources.default` (every filetype), makes blink depend on the completion
-- plugin (so dadbod loads on the first InsertEnter anywhere), and adds
-- sqlfluff with `--dialect=ansi` to format-on-save for SQL files. Each of those
-- changes existing behaviour. This file keeps only the parts that are inert
-- until you use them.
--
-- Load cost: nothing at startup. vim-dadbod / dadbod-ui load on their commands
-- or <leader>D; the completion plugin loads on the SQL filetypes only. The blink
-- source is registered per filetype in blink-cmp.lua, never in `default`.
--
-- Connections (do NOT commit secrets):
--   * $DBUI_URL (+ optional $DBUI_NAME) in the shell -> one connection.
--   * Per project: `.lazy.lua` in the project root (gitignored) setting
--     `vim.g.dbs = { { name = "dev", url = os.getenv("DEV_DATABASE_URL") } }`
--     then `return {}`. lazy.nvim asks once before trusting that file.
--   * `A` in the drawer saves the URL in plain text under
--     stdpath("data")/dadbod_ui. Fine for local dev DBs only.
--
-- Queries run through each database's own CLI (psql, mysql, sqlite3, sqlcmd,
-- mongosh, redis-cli), which must be on $PATH.

local sql_ft = { "sql", "mysql", "plsql" }

return {
  {
    "tpope/vim-dadbod",
    cmd = "DB",
  },

  {
    "kristijanhusak/vim-dadbod-ui",
    dependencies = "tpope/vim-dadbod",
    cmd = { "DBUI", "DBUIToggle", "DBUIAddConnection", "DBUIFindBuffer" },
    keys = {
      { "<leader>D", "<cmd>DBUIToggle<cr>", desc = "Toggle DB UI" },
    },
    -- Double-click expand/collapse in the drawer is built in (ftplugin/dbui.vim
    -- maps <2-LeftMouse> buffer-locally, which wins over the global gutter-click
    -- maps in lua/debugging/mouse.lua). Nothing to add here.
    init = function()
      local data = vim.fn.stdpath("data")
      vim.g.db_ui_save_location = data .. "/dadbod_ui"
      vim.g.db_ui_tmp_query_location = data .. "/dadbod_ui/tmp"
      vim.g.db_ui_use_nerd_fonts = 1
      vim.g.db_ui_show_database_icon = 1
      vim.g.db_ui_use_nvim_notify = 1
      -- Picking a table helper (List, Columns, Indexes...) runs it at once.
      vim.g.db_ui_auto_execute_table_helpers = 1
      -- Run queries with <leader>S (dadbod-ui's buffer-local map), not on :w,
      -- so saving a big or destructive query never executes it by accident.
      vim.g.db_ui_execute_on_save = 0
    end,
  },

  {
    "kristijanhusak/vim-dadbod-completion",
    dependencies = "tpope/vim-dadbod",
    ft = sql_ft,
  },
}
