-- Alternative solarized-osaka colour selections, one `:colorscheme` away.
--
-- The default theme (`solarized-osaka`) holds the considered selection, in
-- solarized-osaka-palette.lua. This file exists so a measured-but-not-chosen
-- candidate stays SWITCHABLE rather than deleted, without becoming a second
-- palette that has to be kept in sync with the first.
--
-- Costs nothing at startup: nothing here is read until `:colorscheme` names a
-- variant, because the only entry points are the one-line files in `colors/`.
--
-- HOW IT WORKS. `on_highlights` in solarized-osaka.lua is a closure that reads
-- `palette.keyword` when it RUNS, and `require` hands every caller the same
-- cached table. So a variant does not re-paint a list of highlight groups --
-- it swaps the value in the palette, rebuilds the theme, and puts the value
-- back. Every group that uses the role follows automatically, including ones
-- added later, so there is no group list here to drift out of sync with the
-- theme. Restoring afterwards is load-bearing: the table is shared, so leaving
-- it mutated would make a later `:colorscheme solarized-osaka` silently keep
-- the variant's colour.
--
-- ADDING v3, v4, ...:
--   1. add an entry to `variants` below -- any role in the palette works, not
--      just `keyword`, and a variant may change several at once
--   2. create colors/solarized-osaka-v3.lua containing one line:
--        require("colorschemes.solarized-osaka-variants").load("v3")

local palette = require("colorschemes.solarized-osaka-palette")

---Role overrides per variant. Keys must be role names from the palette's
---return block; values come from `palette.variants`, so a hex is never copied.
local variants = {
  -- The warm keyword, kept switchable after violet won the default on
  -- 2026-08-10. Yellow rather than olive, which was the other warm candidate:
  -- the two measure within 0.7 points of each other on visual pull (9.4% vs
  -- 8.7% of the screen's total, at the same dose), and that margin does not pay
  -- for olive's two recorded faults -- it shifts 4.2 degrees toward green
  -- between the laptop panel and the external monitor where yellow shifts 0.5,
  -- and it lands dE 0.2 from the git-added green. Yellow is also the higher
  -- contrast of the two, 7.23:1 against 5.93:1 as emitted.
  --
  -- Reach for this if violet ever reads as too recessive -- it buys a much
  -- wider worst-neighbour separation, 32.5 against violet's 19.1.
  v2 = { keyword = palette.variants.keyword.balanced },
}

local M = {}

---Load an alternative selection as a colorscheme.
---@param name string variant key, e.g. "v2"
function M.load(name)
  local overrides = variants[name]
  if not overrides then
    vim.notify(
      ("solarized-osaka: unknown variant %q"):format(tostring(name)),
      vim.log.levels.ERROR
    )
    return
  end

  local saved = {}
  for role, value in pairs(overrides) do
    saved[role] = palette[role]
    palette[role] = value
  end

  -- Rebuilds the whole theme through the same path the plugin's own
  -- colors/solarized-osaka.lua uses, so every override in solarized-osaka.lua
  -- is applied exactly as it is by default.
  local ok, err = pcall(function()
    require("solarized-osaka")._load()
  end)

  for role, value in pairs(saved) do
    palette[role] = value
  end

  if not ok then
    vim.notify(
      ("solarized-osaka: variant %q failed to load: %s"):format(name, err),
      vim.log.levels.ERROR
    )
  end

  -- `vim.g.colors_name` is deliberately LEFT as "solarized-osaka", which is what
  -- `_load()` just set it to. Do not "fix" this to the variant name.
  --
  -- It is not a label, it is the key plugins look themselves up by. lualine
  -- resolves `lualine/themes/<colors_name>`, and the theme ships exactly one, so
  -- naming this "solarized-osaka-v2" orphans that lookup and lualine silently
  -- falls back to its auto theme -- a visibly duller statusline, with no error.
  -- Anything else keyed the same way would break the same way.
  --
  -- Since a variant only ever changes syntax colours, it IS solarized-osaka as
  -- far as the rest of the editor is concerned, so it keeps the name. Verified
  -- by diffing all 629 highlight groups across the two: only the keyword groups
  -- differ. The trade is that `:colorscheme` reports the base name, and a plugin
  -- that reloads via `:colorscheme <g:colors_name>` drops back to the default --
  -- which is the safe direction to fail.
end

return M
