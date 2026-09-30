-- Active colorscheme registry. Imported explicitly by lua/config/lazy.lua so
-- the sibling theme files in lua/colorschemes/ stay reference-only (not
-- installed). To switch themes: change `colorscheme` below and require the
-- matching module.
return {
  {
    "LazyVim/LazyVim",
    -- Named explicitly rather than as bare "solarized-osaka", because what we
    -- run is no longer stock and the bare name reads as if it were.
    --
    -- `custom-latest` is a MOVING name -- it always points at whatever we run
    -- today -- so this line does not need changing when the palette does. The
    -- numbered builds beside it are frozen snapshots of what it used to be. All
    -- of them, and the reference `solarized-osaka-original`, are in
    -- lua/colorschemes/solarized-osaka/variants.lua.
    -- opts = ,
    opts = {
      colorscheme = "solarized-osaka-custom-latest",
      -- {  colorscheme = "onedark", }
    },

    -- Variant is selected by the colorscheme NAME (material-oceanic), not a
    -- setup opt. Each variant ships colors/material-<variant>.lua which sets
    -- vim.g.material_style. Plain "material" would fall back to darker.
    -- opts = { colorscheme = "material-deep-ocean" },
  },

  require("colorschemes.solarized-osaka"),
  -- onedark
  -- require("colorschemes.onedark"),
  -- require("colorschemes.onedark-pro"),

  -- require("colorschemes.gruvbox"),
  -- require("colorschemes.kanagawa"),
  -- require("colorschemes.material"),
  -- require("colorschemes.rose-pine"),
  -- require("colorschemes.catppuccin"),
  -- nightfox
  -- require("colorschemes.nighfox"),
}
