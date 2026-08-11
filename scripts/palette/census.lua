-- Dose census: what a real file actually looks like, per colour.
--
--   nvim --headless path/to/File.tsx \
--     -c 'luafile scripts/palette/census.lua' -c 'qa!'
--
-- NOT `nvim -l`. That form skips your config entirely -- no lazy.nvim, no
-- colorscheme -- so every glyph resolves to nvim's built-in defaults and the
-- numbers are silently meaningless. Verified 2026-08-11: `-l` reports
-- colors_name=nil. The file must be opened as a normal buffer argument so the
-- theme is loaded by the time this runs.
--
-- Answers the question that decides most palette arguments: not "is this hex
-- nice" but "how much of the screen does it cover, and in how many pieces".
--
-- WHY MARKS AND NOT JUST AREA. Two colours with the same coverage can read
-- completely differently. Measured on one real TSX file: cyan covered 44.9% and
-- terracotta 12.7% -- 3.5x apart -- yet both produced about 950 separate marks,
-- because cyan arrives as 8-character class strings and terracotta as
-- 2.3-character fragments. Large contiguous blocks read as ONE object; scattered
-- fragments are counted individually. "The whole screen is X" is a statement
-- about mark count, not coverage.
--
-- HOW TO READ THE OUTPUT
--   area%     share of non-space glyphs painted this colour
--   marks     runs of it, counting a new one whenever the colour changes or
--             whitespace breaks the run
--   avg run   area/marks -- under ~3 is fragmented, over ~8 reads as blocks
--
-- STOP RULES currently in force (see notes/syntax-palette-decisions.md):
--   keyword colour   re-measure past ~7% of ink
--   punctuation      highest-dose accent; watch it in markup-heavy TSX
--
-- Judge a colour on the language it hurts most, not the one it flatters. The
-- same value measured 1.6% in Go and 11.6% in Lua.

local buf = vim.api.nvim_get_current_buf()
local path = vim.api.nvim_buf_get_name(buf)
if path == "" or vim.api.nvim_buf_line_count(buf) <= 1 then
  io.write("usage: nvim --headless <file> -c 'luafile scripts/palette/census.lua' -c 'qa!'\n")
  return
end
if vim.g.colors_name == nil then
  io.write("WARNING: no colorscheme loaded -- these numbers are meaningless.\n")
  io.write("You are probably using `nvim -l`, which skips the config. See the header.\n")
  return
end
pcall(vim.treesitter.start, buf)
vim.cmd("redraw")

-- Resolve a highlight group to its foreground once, then remember it.
local cache = {}
local function fg_of(group)
  if cache[group] == nil then
    local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = group, link = false })
    cache[group] = (ok and hl and hl.fg and string.format("#%06x", hl.fg)) or "none"
  end
  return cache[group]
end

-- Name the colours we already know, so the output reads as roles not hexes.
local palette = require("colorschemes.solarized-osaka.palette")
local named = {
  [palette.keyword] = "keyword",
  [palette.punctuation] = "punctuation",
  [palette.func] = "function",
  [palette.type] = "type",
}

local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
local total, area, marks, captures = 0, {}, {}, {}

for row, line in ipairs(lines) do
  local previous = nil
  for col = 1, #line do
    local ch = line:sub(col, col)
    if not ch:match("%S") then
      previous = nil -- whitespace breaks a run
    else
      total = total + 1
      local info = vim.inspect_pos(buf, row - 1, col - 1, {
        treesitter = true,
        syntax = false,
        extmarks = false,
        semantic_tokens = false,
      })
      -- The LAST treesitter entry is the winner: later captures in the
      -- concatenated query are applied on top.
      local ts = info.treesitter or {}
      local top = ts[#ts]
      local group = top and (top.hl_group_link or top.hl_group) or "Normal"
      local colour = fg_of(group)
      if colour == "none" then
        colour = fg_of("Normal")
      end

      area[colour] = (area[colour] or 0) + 1
      if previous ~= colour then
        marks[colour] = (marks[colour] or 0) + 1
      end
      captures[colour] = captures[colour] or {}
      local cap = top and top.capture or "none"
      captures[colour][cap] = (captures[colour][cap] or 0) + 1
      previous = colour
    end
  end
end

local order = {}
for colour in pairs(area) do
  order[#order + 1] = colour
end
table.sort(order, function(a, b)
  return area[a] > area[b]
end)

io.write(("\n%s  --  %d non-space glyphs, filetype %s\n"):format(
  vim.fn.fnamemodify(path, ":t"),
  total,
  vim.bo[buf].filetype
))
io.write(("  %-9s %-13s %7s %7s %8s   %s\n"):format("colour", "role", "area%", "marks", "avg run", "top captures"))
for _, colour in ipairs(order) do
  if area[colour] / total >= 0.004 then
    local top = {}
    for cap, n in pairs(captures[colour]) do
      top[#top + 1] = { cap, n }
    end
    table.sort(top, function(a, b)
      return a[2] > b[2]
    end)
    local names = {}
    for i = 1, math.min(3, #top) do
      names[i] = ("%s %d"):format(top[i][1], top[i][2])
    end
    io.write(("  %-9s %-13s %6.2f%% %7d %8.1f   %s\n"):format(
      colour,
      named[colour] or "",
      area[colour] / total * 100,
      marks[colour],
      area[colour] / marks[colour],
      table.concat(names, ", ")
    ))
  end
end
io.write("\n")
