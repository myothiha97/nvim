local keywords = {
  -- Two distinct keywords on purpose. Matching is case-sensitive (highlight.lua uses `\C`),
  -- so `TODO:` and `todo:` resolve to separate tags and can be filtered independently:
  --   TODO -> teammates' shouty uppercase comments, listed by <leader>sT
  --   todo -> your own personal marker, this is what <leader>st lists
  TODO = { icon = " ", color = "hint" },
  todo = { icon = " ", color = "info", alt = { "Todo" } },
  PERF = { icon = " ", alt = { "OPTIM", "PERFORMANCE", "OPTIMIZE", "Perf", "perf", "Opt" } },
  REFACTOR = { icon = " ", color = "default", alt = { "Refactor", "REF", "ref", "REFACTOR" } },
  HACK = { icon = " ", color = "warning" },
  WARN = { icon = " ", color = "warning", alt = { "WARNING", "XXX" } },
  NOTE = { icon = " ", color = "hint", alt = { "INFO" } },
  TEST = { icon = "⏲ ", color = "test", alt = { "TESTING", "PASSED", "FAILED" } },
  -- Same split rationale as TODO/todo above: uppercase = teammates (kept out of <leader>se),
  -- lowercase/titlecase = your own, which is what <leader>se lists.
  --   ISSUE / BUG -> teammates' shouty comments
  --   issue / bug -> your own personal markers, listed by <leader>se
  ISSUE = { icon = " ", color = "error", alt = { "BUG" } },
  issue = { icon = " ", color = "error", alt = { "Issue", "bug", "Bug" } },
}

-- Comment openers a tag is allowed to sit behind. Longest first so `<!--` wins over `--`
-- and `--` wins over `-`. `*` covers continuation lines inside a `/* */` block.
local comment_leaders = { "<!--", "//", "/*", "--", "*", "#", ";" }

-- True when everything before `col` is a comment opener, i.e. the tag really starts the
-- comment rather than merely appearing somewhere inside the line. Prose that only mentions
-- a tag (in backticks, quotes, or mid-sentence) fails this and is excluded.
local function opens_comment(line, col)
  local prefix = line:sub(1, col - 1):gsub("%s+$", "")
  for _, leader in ipairs(comment_leaders) do
    if prefix:sub(-#leader) == leader then
      return true
    end
  end
  return false
end

-- The search is a ripgrep regex built from the keywords, so any line *containing* a tag
-- is listed, including prose that only mentions one, e.g. a doc line such as
--   - Comment tags: `todo:` (not TODO), ...; `NOTE:` for temporary toggles.
-- ripgrep reports the column of the tag it matched, so the transform below keeps a result
-- only when a comment opener sits in front of it. Keypress only, so this costs nothing on
-- a hot path.
-- Popup size shared with the diagnostics pickers in lua/plugins/snacks.lua.
local picker_size = require("config.picker-size")

local function picker(keyword)
  return function()
    Snacks.picker.todo_comments({
      keywords = { keyword },
      -- The grep finder runs rg with --smart-case, which turns an all-lowercase pattern
      -- like `todo` case-insensitive and would list TODO too. The later flag wins.
      args = { "--case-sensitive" },
      ---@param item snacks.picker.Item
      transform = function(item)
        -- item.text is "file:line:col:text"; strip the prefix to get the source line.
        local line = item.text:sub(#item.file + 2):match("^%d+:%d+:(.*)$")
        return line ~= nil and opens_comment(line, item.pos[2] + 1)
      end,
      layout = {
        preview = true,
        layout = { width = picker_size.preview.width, height = picker_size.preview.height },
      },
    })
  end
end

-- todo-comments' own jump_next/jump_prev stop at the buffer edge (no wrap option), so this
-- scans circularly with the same matching rules, like Vim's `wrapscan`.
-- NOTE: relies on the plugin's internal `todo-comments.highlight` module. If tt/tp error
-- after a plugin update, check whether `highlight.match` / `highlight.is_comment` moved.
local function jump(up)
  local config = require("todo-comments.config")
  local highlight = require("todo-comments.highlight")
  local buf = vim.api.nvim_get_current_buf()
  local cur = vim.api.nvim_win_get_cursor(0)[1]
  local count = vim.api.nvim_buf_line_count(buf)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

  for i = 1, count do
    local l = (cur - 1 + (up and -i or i)) % count + 1
    local ok, start, _, kw = pcall(highlight.match, lines[l])
    if ok and kw and not (config.options.highlight.comments_only and highlight.is_comment(buf, l - 1, start) == false) then
      vim.api.nvim_win_set_cursor(0, { l, start - 1 })
      return
    end
  end
  vim.notify("No todo comments in buffer", vim.log.levels.WARN)
end

return {
  {
    "folke/todo-comments.nvim",
    opts = {
      keywords = keywords,
    },
    keys = {
      {
        "tt",
        function()
          jump(false)
        end,
        desc = "Next Todo",
      },
      {
        "tp",
        function()
          jump(true)
        end,
        desc = "Prev Todo",
      },
      -- Snacks picker popup with preview. Keyword filters are case-sensitive. See `picker`
      -- above for why these add a transform instead of calling the picker plainly.
      -- Disable LazyVim's picker defaults first.
      { "<leader>st", false },
      { "<leader>sT", false },
      {
        "<leader>st",
        picker("todo"),
        desc = "Personal todos",
      },
      {
        "<leader>se",
        picker("issue"),
        desc = "Personal issues",
      },
      {
        "<leader>sT",
        picker("TODO"),
        desc = "Team todos",
      },
    },
  },
}
