-- Active colorscheme registry. Imported explicitly by lua/config/lazy.lua so
-- the sibling theme files in lua/colorschemes/ stay reference-only (not
-- installed). To switch themes: change `colorscheme` below and require the
-- matching module.
return {
  {
    "LazyVim/LazyVim",
    -- Named explicitly rather than as bare "solarized-osaka", because what we
    -- run is no longer stock and the bare name reads as if it were. The three
    -- builds and the reference `solarized-osaka-original` are in
    -- lua/colorschemes/solarized-osaka-variants.lua.
    opts = { colorscheme = "solarized-osaka-custom-v1" },
    -- opts = {
    --   colorscheme = "gruvbox",
    -- },
    -- Variant is selected by the colorscheme NAME (material-oceanic), not a
    -- setup opt. Each variant ships colors/material-<variant>.lua which sets
    -- vim.g.material_style. Plain "material" would fall back to darker.
    -- opts = { colorscheme = "material-deep-ocean" },
  },
  -- require("colorschemes.gruvbox"),
  require("colorschemes.solarized-osaka"),
  -- require("colorschemes.material"),
}
