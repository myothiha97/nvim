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

-- `TodoLocList keywords=x` filters at the ripgrep level only, then todo-comments re-reads
-- each matched line with a greedy pattern (`.*<(KEYWORDS)\s*:`) built from every keyword.
-- That has two consequences worth working around:
--   1. Any line *containing* the tag is listed, so a doc line such as
--        - Comment tags: `todo:` (not TODO), ...; `NOTE:` for temporary toggles.
--      shows up even though it is prose, not a todo.
--   2. The greedy `.*` labels a multi-tag line with the LAST tag on it, so the line above
--      is matched on `todo:` but listed as NOTE.
-- ripgrep reports the column of the tag it actually matched, so anchor on that: require a
-- comment opener in front of it, and rebuild the displayed text from it. Keypress only,
-- so this costs nothing on a hot path.
local function loclist(keyword)
  return function()
    require("todo-comments.search").search(function(results)
      local items = {}
      for _, item in ipairs(results) do
        if opens_comment(item.line, item.col) then
          item.tag = keyword
          item.text = vim.trim(item.line:sub(item.col))
          table.insert(items, item)
        end
      end

      if #items == 0 then
        vim.notify("no " .. keyword .. ": comments found", vim.log.levels.INFO)
        return
      end

      vim.fn.setloclist(0, {}, " ", { title = "Todo", id = "$", items = items })
      vim.cmd("lopen")

      local win = vim.fn.getloclist(0, { winid = true }).winid
      require("todo-comments.highlight").attach(win, true)

      -- Same selection key as the Snacks pickers and Oil: <C-l> confirms the entry under
      -- the cursor. `remap` so it inherits whatever <CR> already does in this buffer rather
      -- than hardcoding the jump. <CR> keeps working. Buffer-local, so this only gives up
      -- <C-l> right-pane focus inside this list — use <C-w>l there.
      vim.keymap.set("n", "<C-l>", "<CR>", {
        buffer = vim.api.nvim_win_get_buf(win),
        remap = true,
        desc = "Select item",
      })
    end, { keywords = keyword, disable_not_found_warnings = true })
  end
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
          require("todo-comments").jump_next()
        end,
        desc = "Next Todo",
      },
      {
        "tp",
        function()
          require("todo-comments").jump_prev()
        end,
        desc = "Prev Todo",
      },
      -- Use a location list instead of a floating picker. The list opens in a bottom split
      -- and stays open after <cr>, so multiple items can be visited without reopening it. A
      -- location list keeps these results separate from the normal quickfix list on
      -- <leader>cc. Keyword filters are case-sensitive. See `loclist` above for why these
      -- call the search API directly rather than `:TodoLocList`.
      -- Disable LazyVim's picker defaults first.
      { "<leader>st", false },
      { "<leader>sT", false },
      {
        "<leader>st",
        loclist("todo"),
        desc = "Personal todos",
      },
      {
        "<leader>se",
        loclist("issue"),
        desc = "Personal issues",
      },
      {
        "<leader>sT",
        loclist("TODO"),
        desc = "Team todos",
      },
    },
  },
}
