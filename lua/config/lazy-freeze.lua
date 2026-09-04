-- Freeze plugin versions: block accidental updates via :Lazy update/sync/restore,
-- the UI buttons, and any keymap wired to those commands. New plugin installs
-- and clean still work, so adding/removing plugins from the spec is unaffected.
--
-- To unlock for a planned update run:  NVIM_LAZY_UNLOCK=1 nvim
-- Then use :Lazy sync as usual. The next plain `nvim` is locked again.

local M = {}

local UNLOCK_ENV = "NVIM_LAZY_UNLOCK"

local function blocked(action)
  return function()
    vim.notify(
      ("lazy.nvim is frozen — `%s` blocked.\nRun `%s=1 nvim` to unlock for one session."):format(action, UNLOCK_ENV),
      vim.log.levels.WARN,
      { title = "lazy-freeze" }
    )
  end
end

function M.setup()
  if vim.env[UNLOCK_ENV] == "1" then
    vim.schedule(function()
      vim.notify("lazy-freeze: UNLOCKED for this session", vim.log.levels.INFO, { title = "lazy-freeze" })
    end)
    return
  end

  -- Patch the public API (covers `:Lazy update`, `:Lazy sync`, `:Lazy restore`
  -- and anything calling require("lazy").update() etc).
  local ok_lazy, lazy = pcall(require, "lazy")
  if ok_lazy then
    lazy.update = blocked("Lazy update")
    lazy.sync = blocked("Lazy sync")
    lazy.restore = blocked("Lazy restore")
  end

  -- Patch the underlying manager (covers the :Lazy UI buttons, which call
  -- require("lazy.manage") directly and bypass the public API).
  local ok_manage, manage = pcall(require, "lazy.manage")
  if ok_manage then
    manage.update = blocked("Lazy update")
    manage.sync = blocked("Lazy sync")
    manage.restore = blocked("Lazy restore")
  end
end

return M
