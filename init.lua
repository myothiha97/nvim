-- Neovide must be configured before lazy loads
require("config.neovide")

-- Disable built-in matchparen — fires Highlight_Matching_Pair() on every
-- CursorMoved (1200+ calls/session). Must be set before lazy loads.
vim.g.loaded_matchparen = 1

-- `:restart` (0.12) relaunches Nvim with the original argv and only then sources
-- the session it saved, so startup and the restore run over each other. Both
-- halves below are scoped to that one start, and cost nothing otherwise. They
-- have to live here: the restore can arrive before `VeryLazy`, so anything set
-- up from `config/autocmds.lua` would be registered too late to see it.
if vim.v.startreason == "restart" then
  -- `nvim <dir>` comes back with the directory still in the arglist and already
  -- open in a buffer, so the snacks explorer opens over the restore, and oil
  -- claims that buffer and finishes its async load in the window the session has
  -- meanwhile moved to the restored file, tagging that file `filetype=oil`. The
  -- session carries the layout, so leave startup nothing to act on. Only the
  -- directory start is dropped: with file arguments Nvim opens them itself and
  -- the session reuses those buffers, and dropping one there would just pull the
  -- next argument in early.
  if vim.fn.argc() == 1 and vim.fn.isdirectory(vim.fn.argv(0)) == 1 then
    vim.cmd("%argdelete")
    vim.api.nvim_buf_delete(0, { force = true })
  end

  -- A file the session opens is read after startup, and by then another autocmd
  -- in the same chain has already fired FileType for it, so Nvim's own `setf` is
  -- a no-op and the buffer stays filetype-less: no treesitter, no LSP, plain
  -- text. `did_filetype()` holds for the whole chain, hence the deferred detect.
  vim.api.nvim_create_autocmd("SessionLoadPost", {
    group = vim.api.nvim_create_augroup("restart_session_filetype", { clear = true }),
    callback = function(ev)
      if vim.bo[ev.buf].buftype ~= "" or vim.bo[ev.buf].filetype ~= "" or vim.api.nvim_buf_get_name(ev.buf) == "" then
        return
      end
      vim.schedule(function()
        if vim.api.nvim_buf_is_valid(ev.buf) and vim.bo[ev.buf].filetype == "" then
          vim.api.nvim_buf_call(ev.buf, function()
            vim.cmd("filetype detect")
          end)
        end
      end)
    end,
  })
end

-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")
