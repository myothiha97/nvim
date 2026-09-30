return {
  "navarasu/onedark.nvim",
  opts = {
    style = "darker", -- current best with a good constrast with darker bg with balance color
    -- style = "dark", -- same as dark but lower contrast
    -- style = "cool", -- the color is good but the contrast is a bit low
    -- style = "deep", -- the contrast beoome too high
    -- style = "warm", -- 2nd best now similar to darker, but with a warmer bg and color
    -- style = "warmer", -- simialr to warm, but with higher contrast colors
    transparent = false,
    term_colors = true,
    colors = {
      red = "#d0707a",
      purple = "#b57bc9",
    },
    highlights = {
      -- Visual = { bg = "#264f78" },
      -- VisualNOS = { bg = "#264f78" },
      Comment = {
        fg = "#7f848e",
        ["@comment"] = { fg = "#7f848e" },
      },
    },
  },
}
