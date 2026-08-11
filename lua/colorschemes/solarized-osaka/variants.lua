-- The solarized-osaka builds, one `:colorscheme` away from each other.
--
--   solarized-osaka-original    upstream craftzdog, nothing of ours applied
--   solarized-osaka-custom-v1   the selection we run  <- default
--                               violet keyword + copper punctuation
--   solarized-osaka-custom-v2   the same, on the warm keyword (yellow)
--   solarized-osaka-custom-v3   the same, on the softer terracotta punctuation
--
-- The point of `original` is to have a reference build to diff against, because
-- what we run is no longer stock. It is a precise thing rather than a vague one:
-- the ONLY deviation this config makes from upstream is `on_highlights` in
-- solarized-osaka/init.lua. `transparent = true` is not ours -- it is the plugin's own
-- default (see `defaults` in solarized-osaka/config.lua). So `original` is
-- exactly "the same theme with our on_highlights switched off", and any
-- difference you see between it and custom-v1 is a difference we introduced.
--
-- Costs nothing at startup: nothing here is read until `:colorscheme` names a
-- build, because the only entry points are the one-line files in `colors/`.
--
-- HOW IT WORKS. Two kinds of override, applied the same way -- swap, rebuild,
-- swap back:
--
--   `palette`  swaps a role value in solarized-osaka/palette.lua. `on_highlights`
--              is a closure that reads the palette when it RUNS, and `require`
--              hands every caller the same cached table, so a build does not
--              re-paint a list of highlight groups. Every group using the role
--              follows automatically, including ones added later, so there is no
--              group list here to drift out of sync with the theme.
--   `config`   swaps an entry in the plugin's own resolved options. Only
--              `original` uses it, to disable `on_highlights`.
--
-- Restoring afterwards is load-bearing in both cases: the tables are shared, so
-- leaving one mutated would make a later `:colorscheme solarized-osaka` silently
-- keep this build's colours.
--
-- ADDING A BUILD:
--   1. add an entry to `builds` below -- any role in the palette works, not just
--      `keyword`, and a build may change several at once
--   2. create colors/solarized-osaka-custom-vN.lua containing one line:
--        require("colorschemes.solarized-osaka.variants").load("custom-vN")
-- Builds are for values worth LIVING with, not for comparing candidates. A
-- candidate belongs in the palette's variant tables with its numbers; it only
-- earns a build once you would actually switch to it.

local palette = require("colorschemes.solarized-osaka.palette")

---@class SolarizedOsakaBuild
---@field palette table<string, string>|nil role overrides, keys from the palette's return block
---@field config table|nil plugin option overrides

---Values come from `palette.variants`, so a hex is never copied.
---@type table<string, SolarizedOsakaBuild>
local builds = {
  -- Upstream, untouched. Everything this repo decided about syntax colour is
  -- carried by `on_highlights`, so switching it off is the whole difference.
  -- Deliberately NOT a full `config.setup({})`: that would also throw away
  -- anything the plugin spec sets for non-syntax reasons, and then a difference
  -- you saw could be ours or could be a side effect of the reset.
  original = { config = { on_highlights = function() end } },

  -- The live selection, exactly as solarized-osaka/palette.lua has it. Empty on
  -- purpose: it exists so the name can be typed and so `config.lua` can name the
  -- build it wants rather than relying on the bare plugin name meaning "ours".
  ["custom-v1"] = {},

  -- The warm keyword, kept switchable after violet won the default on
  -- 2026-08-10. Yellow rather than olive, which is display-unstable -- see the
  -- notes. Reach for this if violet ever reads as too recessive: it buys a much
  -- wider worst-neighbour separation, 32.5 against violet's 19.1.
  ["custom-v2"] = { palette = { keyword = palette.variants.keyword.balanced } },

  -- The previous punctuation colour, held until 2026-08-11. Kept as a build
  -- because it is the one value that satisfies the keyword/punctuation chroma
  -- pairing perfectly -- gap 0.4 against the selection's 23.2 -- so it is the
  -- fallback if copper ever reads too hot in a long session.
  ["custom-v3"] = { palette = {
    punctuation = palette.variants.punctuation.terracotta,
  } },
}

local M = {}

---Load one of the builds as a colorscheme.
---@param name string build key: "original", "custom-v1", "custom-v2", "custom-v3"
function M.load(name)
  local build = builds[name]
  if not build then
    vim.notify(("solarized-osaka: unknown build %q"):format(tostring(name)), vim.log.levels.ERROR)
    return
  end

  local saved_roles = {}
  for role, value in pairs(build.palette or {}) do
    saved_roles[role] = palette[role]
    palette[role] = value
  end

  -- `options` is reassigned rather than mutated because the plugin's own
  -- `extend()` reassigns it too, and every consumer reads it through
  -- `require("solarized-osaka.config").options` at call time.
  local plugin_config = build.config and require("solarized-osaka.config") or nil
  local saved_options = plugin_config and plugin_config.options or nil
  if plugin_config then
    plugin_config.options = vim.tbl_deep_extend("force", {}, saved_options, build.config)
  end

  -- Rebuilds the whole theme through the same path the plugin's own
  -- colors/solarized-osaka.lua uses, so every override in solarized-osaka/init.lua
  -- is applied exactly as it is by default.
  local ok, err = pcall(function()
    require("solarized-osaka")._load()
  end)

  for role, value in pairs(saved_roles) do
    palette[role] = value
  end
  if plugin_config then
    plugin_config.options = saved_options
  end

  if not ok then
    vim.notify(("solarized-osaka: build %q failed to load: %s"):format(name, err), vim.log.levels.ERROR)
  end

  -- `vim.g.colors_name` is deliberately LEFT as "solarized-osaka", which is what
  -- `_load()` just set it to. Do not "fix" this to the build name.
  --
  -- It is not a label, it is the key plugins look themselves up by. lualine
  -- resolves `lualine/themes/<colors_name>`, and the theme ships exactly one, so
  -- naming this "solarized-osaka-custom-v1" orphans that lookup and lualine
  -- silently falls back to its auto theme -- a visibly duller statusline, with no
  -- error. Anything else keyed the same way would break the same way.
  --
  -- So the build names are ENTRY POINTS, not identities: they are what you type,
  -- not what the editor calls itself afterwards. A build only ever changes syntax
  -- colour, so it IS solarized-osaka as far as the rest of the editor is
  -- concerned. Verified by diffing all 629 highlight groups across custom-v1 and
  -- custom-v2: only the keyword groups differ. The trade is that `:colorscheme`
  -- reports the base name, and a plugin that reloads via
  -- `:colorscheme <g:colors_name>` drops back to custom-v1 -- which is the safe
  -- direction to fail, and the reason bare `solarized-osaka` must keep meaning
  -- custom-v1 rather than being repointed at `original`.
end

return M
