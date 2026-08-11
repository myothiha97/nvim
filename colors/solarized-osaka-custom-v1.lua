-- `:colorscheme solarized-osaka-custom-v1` -- the selection we run, violet
-- keyword. Identical to bare `:colorscheme solarized-osaka`; this name exists so
-- the default can be stated explicitly rather than implied by the plugin's name.
-- Everything that decides what this is lives in the variants module.
require("colorschemes.solarized-osaka-variants").load("custom-v1")
