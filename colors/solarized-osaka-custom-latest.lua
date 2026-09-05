-- `:colorscheme solarized-osaka-custom-latest` -- the selection we run, and what
-- lua/colorschemes/config.lua loads. Yellow warm side, grey punctuation on two
-- rungs, raised body text. It carries no overrides: the values are the palette's
-- own, which is what keeps a `:colorscheme <g:colors_name>` reload a no-op.
-- Everything that decides what this is lives in the variants module.
require("colorschemes.solarized-osaka.variants").load("custom-latest")
