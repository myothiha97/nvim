-- The solarized-osaka builds, one `:colorscheme` away from each other.
--
--   solarized-osaka-custom-latest  the selection we run  <- default
--                                  yellow warm side, grey punctuation on two
--                                  rungs, raised body text (2026-09-05)
--   solarized-osaka-custom-v1      the copper build custom-latest replaced
--   solarized-osaka-custom-v2      custom-v1 on the warm keyword (yellow)
--   solarized-osaka-custom-v3      custom-v1 on the softer terracotta punctuation
--   solarized-osaka-original       upstream craftzdog, nothing of ours applied
--
-- `custom-latest` IS A MOVING NAME and the numbered ones are not. It always
-- means "whatever we run today", so `config.lua` never has to be repointed and
-- muscle memory never goes stale. The numbered builds are frozen snapshots of
-- what it used to be, newest first.
--
-- SO WHEN custom-latest IS SUPERSEDED: give its current values a number (the
-- next one up, e.g. `custom-v4`) with the reasoning that justified them, THEN
-- move the new values into the palette. Never edit a numbered build -- the whole
-- value of one is that it still renders what it rendered on the day it was
-- named. Verify with the group diff described at the bottom of M.load.
--
-- The point of `original` is to have a reference build to diff against, because
-- what we run is no longer stock. It is a precise thing rather than a vague one:
-- the ONLY deviation this config makes from upstream is `on_highlights` in
-- solarized-osaka/init.lua. `transparent = true` is not ours -- it is the plugin's own
-- default (see `defaults` in solarized-osaka/config.lua). So `original` is
-- exactly "the same theme with our on_highlights switched off", and any
-- difference you see between it and custom-latest is a difference we introduced.
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
--   2. create colors/solarized-osaka-<name>.lua containing one line:
--        require("colorschemes.solarized-osaka.variants").load("<name>")
-- Builds are for values worth LIVING with, not for comparing candidates. A
-- candidate belongs in the palette's variant tables with its numbers; it only
-- earns a build once you would actually switch to it. The 2026-09-05 rebuild
-- broke that rule on purpose -- ten builds existed at once so they could be
-- compared side by side in real files -- and then collapsed back to the winner.
-- Do that again the same way: many builds while deciding, none afterwards.

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
  --
  -- IT IS EMPTY FOR A SECOND REASON, and this is why `custom-latest` rather than
  -- a numbered build holds the palette's own values. `vim.g.colors_name` stays "solarized-osaka" whatever
  -- you load (see the note at the bottom of M.load), so anything that reloads
  -- the theme with `:colorscheme <g:colors_name>` gets the palette defaults. If
  -- the default build carried overrides instead, every such reload would
  -- silently drop the editor back to a different colour scheme. Keeping the live
  -- values in the palette makes that reload a no-op.
  --
  -- WHAT IT IS, in one line each. Full argument and measurements:
  -- notes/syntax-palette-decisions.md, "The 2026-09-05 rebuild".
  --
  --   punctuation + parameter  yellow `#aea134`, replacing copper. Copper was
  --     the palette's only sub-AA colour and its tightest pair against the error
  --     red; removing it also drops the chroma outlier from the accent set, so
  --     hue spacing holds a 60 degree minimum and emitted spread falls 31.2 to
  --     24.0. That evenness is what reads as "it mixes with the cyan and violet".
  --   bracket  grey `#7f9195`, NOT an accent. Brackets are the most scattered
  --     glyph on screen -- 3.21% of ink in 17210 marks, 1.20 chars each -- so
  --     colouring them turns the accent into confetti. Measured across 237 real
  --     files: with brackets on the accent it made 21518 marks at 2.25 chars;
  --     with them grey, 5887 marks at 4.72 chars. Same hex, 73% fewer marks.
  --     This is also what gives a yellow parameter an edge against its own
  --     brackets, which no other build has.
  --   delimiter  grey `#7f9195`, the SAME value as bracket since 2026-09-06.
  --     It spent one day a rung above, on the argument that operators carry more
  --     than brackets do; the gap measured dE 3.5 and was dropped. Colour was
  --     tried here too, and lost -- see `variants.delimiter` in palette.lua.
  --   body  `#b1bebf`, +7.0 L*. Fixes "variables look faded": upstream framed
  --     every name in olive punctuation, and moving punctuation to base0 in
  --     2026-08 had put it on the SAME value as `@variable`. Raising the body
  --     and lowering the punctuation restores the edge from both sides.
  --
  -- The shape to preserve if any of this is retuned: THREE LIGHTNESS STEPS
  -- ordered by meaning -- body 76.0, names 65.5, punctuation 58.9, comments 44.6
  -- -- and ONE warm accent hue, not two.
  --
  -- CLOSED 2026-09-06. Every value above was verified against rendered pixels of
  -- real Go, TSX, TS and Lua screens, not judged by eye. Do not reopen this to
  -- "try something"; see the change gate in neovim-config-change-gate.md.
  -- issue: currently there is one color issue
  -- since both dictionary keys and values are painted as cyan green, in some area the colors are very mixed up
  -- especially in js,ts files where there are a lot of objects are declared
  -- the current solution - set both delimiters and brackets to the same color, which is a bit of a compromise but it works
  ["custom-latest"] = {
    palette = {
      type = palette.variants.type.nvim_type,
      -- punctuation = palette.variants.punctuation.copper_mid,
      punctuation = palette.variants.punctuation.terracotta, -- very close and competetive to subdued yellow but for some reason my eye favor terracotta
      delimiter = palette.variants.body.base0,
      bracket = palette.variants.body.base0,
      parameter = palette.variants.punctuation.terracotta,
    },
  },

  -- The build that ran from 2026-08-11 to 2026-09-05: copper punctuation, body
  -- and punctuation both on the theme's base0. Kept because it is a full month
  -- of proven daily use and the only fallback that needs no argument.
  --
  -- Explicit rather than empty now that `custom-latest` holds the palette's
  -- values -- it was the empty one until 2026-09-05. The three
  -- `false`s are meaningful, not padding: they mean "follow the theme's own
  -- base0" for body and delimiters, and "follow `punctuation`" for brackets,
  -- which is exactly how those roles behaved before they were split out.
  ["custom-v1"] = {
    palette = {
      punctuation = palette.variants.punctuation.copper_mid,
      parameter = palette.variants.punctuation.copper_mid,
      bracket = false,
      body = false,
      delimiter = false,
    },
  },

  -- The warm keyword, kept switchable after violet won the default on
  -- 2026-08-10. Yellow rather than olive, which is display-unstable -- see the
  -- notes. Reach for this if violet ever reads as too recessive: it buys a much
  -- wider worst-neighbour separation, 32.5 against violet's 19.1.
  --
  -- Built on custom-v1, not on v4: v4 already spends this yellow on the warm
  -- side, and a yellow keyword beside a yellow bracket is the collision the
  -- whole 2026-09-05 rebuild removed.
  ["custom-v2"] = {
    palette = {
      keyword = palette.variants.keyword.balanced,
      punctuation = palette.variants.punctuation.copper_mid,
      parameter = palette.variants.punctuation.copper_mid,
      bracket = false,
      body = false,
      delimiter = false,
    },
  },

  -- The punctuation colour from before 2026-08-11, on the custom-v1 base. Kept
  -- because it is the one value that satisfies the keyword/punctuation chroma
  -- pairing perfectly -- gap 0.4 against copper's 23.2.
  --
  -- `parameter` is named alongside `punctuation` and MUST be: it defaults to the
  -- punctuation VALUE, not the punctuation ROLE, so a build that moves
  -- `punctuation` alone silently leaves parameters behind. Any future build has
  -- the same decision to make, and nothing errors if it gets it wrong.
  ["custom-v3"] = {
    palette = {
      punctuation = palette.variants.punctuation.terracotta,
      parameter = palette.variants.punctuation.terracotta,
      bracket = false,
      body = false,
      delimiter = false,
    },
  },
}

local M = {}

---Load one of the builds as a colorscheme.
---@param name string build key: "custom-latest", "custom-v1" .. "custom-v3", "original"
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
