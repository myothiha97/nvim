-- The solarized-osaka builds, one `:colorscheme` away from each other.
--
--   solarized-osaka-custom-latest  the selection we run  <- default
--   solarized-osaka-custom-v1      the copper build custom-latest replaced
--   solarized-osaka-custom-v2      custom-v1 on the warm keyword (yellow)
--   solarized-osaka-custom-v3      custom-v1 on the softer terracotta punctuation
--   solarized-osaka-original       upstream craftzdog, nothing of ours applied
--
-- `custom-latest` IS A MOVING NAME -- always "whatever we run today" -- and the
-- numbered ones are frozen snapshots. WHEN custom-latest IS SUPERSEDED: number
-- its current values first, THEN move the new ones into the palette. Never edit
-- a numbered build.
--
-- Costs nothing at startup: nothing here is read until `:colorscheme` names a
-- build, because the only entry points are the one-line files in `colors/`.
--
-- How a build works, why `original` is a precise reference, how to add one, and
-- the `vim.g.colors_name` trap: notes/palette-reference.md, section "Builds".

local palette = require("colorschemes.solarized-osaka.palette")

---@class SolarizedOsakaBuild
---@field palette table<string, string>|nil role overrides, keys from the palette's return block
---@field config table|nil plugin option overrides

---Values come from `palette.variants`, so a hex is never copied.
---@type table<string, SolarizedOsakaBuild>
local builds = {
  -- `on_highlights` carries everything this repo decided about syntax colour, so
  -- switching it off is the whole difference. Deliberately NOT a full
  -- `config.setup({})`, which would also discard non-syntax plugin-spec options
  -- and make any difference you see ambiguous.
  original = { config = { on_highlights = function() end } },

  -- The daily selection. Only the roles that differ from the base palette.
  ["custom-latest"] = {
    palette = {
      type = palette.variants.type.nvim_type,

      -- Brackets and delimiters share the MAXIMIN grey rung, moved off
      -- `kanagawa_mid` (#96abd3) 2026-09-09. The periwinkle was a fourth hue in
      -- the blue band, carrying the third-highest contrast in the palette on its
      -- least meaningful ink. Measured over Go/bash/devops/js-ts/jsx-tsx/python:
      -- worst chromatic pair 14.2 -> 16.5, tightest colour-blind pair 2.3 -> 4.8.
      delimiter = palette.variants.delimiter.mid_high,
      bracket = palette.variants.delimiter.mid_high,
      -- Body text, 2026-09-09. `brighter` (#b1bebf) read as too bright and
      -- base0 (#9eabac) sat only dE00 8.7 from the delimiter grey above, inside
      -- the band where two values read as one colour. This midpoint clears it at
      -- 11.2. The JSX/TSX/HTML/Vue tag wrappers TRACK THIS VALUE in init.lua --
      -- they used to be pinned to base0 separately, which this change would have
      -- left a bare JND away from body. Ladder and rejects in palette.lua.
      body = palette.variants.body.tinted, -- the previous value is midpoint but i feel a bit fade after some use so replace it with tinted white

      func = palette.variants.func.vivid,

      -- One value for every language, Go included. Tokyo Night's hue at our
      -- L*68, chosen by eye 2026-09-08 for the widest separation from the accent
      -- yellow (dE 29.5). Knowingly over budget on chroma (C*54.8 against the
      -- C*40 this role's dose note asks for) and weak on CVD (5.4 deutan);
      -- `boolean.tokyonight_muted` is the safer swap if either starts to bite.
      boolean = palette.variants.boolean.tokyonight_dim,

      -- UNUSED since 2026-09-08, and `false` rather than nil on purpose (`M.load`
      -- iterates with `pairs`, so an absent key is a silent no-op). Go fields are
      -- painted straight from `palette.punctuation` in init.lua, and every other
      -- language keeps the theme's own cyan500. To give fields a colour of their
      -- own again: set this to `punctuation.explored.salmon` (or `.coral`, which
      -- separates marginally better) and point init.lua's Go block back at
      -- `palette.member`.
      member = false,

      -- Punctuation and parameter share the yellow, final call 2026-09-08. A
      -- terracotta red stayed close and suits my taste better, but the census
      -- gave yellow the wider separation and it has held up in daily use. No red
      -- variant beat it. Candidates live in palette.lua, not parked here.
      parameter = palette.variants.keyword.brighter,
      punctuation = palette.variants.keyword.brighter,

      -- Two stops below `readable`, 2026-09-09: 4.56:1 read as too bright and
      -- `subtle` (dE 2.8) was not enough of a drop. Gives up AA at 3.96:1,
      -- knowingly, and the upstream value this config ran for months is lower
      -- still at 3.48:1. Ladder and the remaining stops are in palette.lua.
      comment = palette.variants.comment.dimmer,
    },
  },

  -- Ran 2026-08-11 to 2026-09-05. The fallback that needs no argument: a full
  -- month of proven daily use.
  --
  -- WARN: SILENT FAILURE. The `false`s are meaningful, not padding -- they mean
  -- "follow the theme's own base0" for body and delimiters, and "follow
  -- `punctuation`" for brackets. They must be `false`, NEVER `nil`: `nil` is an
  -- absent key, so `M.load`'s `pairs` never sees it and the override silently
  -- does not happen. Same for every build below.
  ["custom-v1"] = {
    palette = {
      punctuation = palette.variants.punctuation.copper_mid,
      parameter = palette.variants.punctuation.copper_mid,
      bracket = false,
      body = false,
      delimiter = false,
    },
  },

  -- The warm keyword, kept switchable after violet won on 2026-08-10. Reach for
  -- it if violet ever reads as too recessive. Built on custom-v1 deliberately:
  -- custom-latest already spends this yellow on the warm side.
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

  -- The punctuation colour from before 2026-08-11, on the custom-v1 base. The one
  -- value that satisfies the keyword/punctuation chroma pairing perfectly.
  --
  -- WARN: SILENT FAILURE. `parameter` is named alongside `punctuation` and MUST
  -- be: it defaults to the punctuation VALUE, not the punctuation ROLE, so a
  -- build moving `punctuation` alone silently leaves parameters behind.
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

  -- Restoring afterwards is load-bearing: these tables are shared, so leaving one
  -- mutated makes a later `:colorscheme` silently keep this build's colours.
  local saved_roles = {}
  for role, value in pairs(build.palette or {}) do
    saved_roles[role] = palette[role]
    palette[role] = value
  end

  -- Reassigned rather than mutated, because the plugin's own `extend()`
  -- reassigns it too and every consumer reads it at call time.
  local plugin_config = build.config and require("solarized-osaka.config") or nil
  local saved_options = plugin_config and plugin_config.options or nil
  if plugin_config then
    plugin_config.options = vim.tbl_deep_extend("force", {}, saved_options, build.config)
  end

  -- The same path the plugin's own colors/solarized-osaka.lua uses, so every
  -- override in init.lua applies exactly as it does by default.
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

  -- `vim.g.colors_name` is deliberately LEFT as "solarized-osaka". DO NOT "fix"
  -- it to the build name: it is the key plugins look themselves up by, and
  -- lualine resolving `lualine/themes/<colors_name>` silently falls back to a
  -- duller auto theme if renamed. Build names are ENTRY POINTS, not identities.
end

return M
