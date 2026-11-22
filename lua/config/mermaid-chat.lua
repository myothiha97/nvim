-- Mermaid diagrams in CodeCompanion chat buffers.
--
-- 1. Inline: when a reply finishes (`CodeCompanionChatDone`), every ```mermaid
--    block in that chat is rendered to a PNG and drawn under the block through
--    snacks.nvim's image module (Ghostty image protocol, also inside tmux;
--    snacks sets allow-passthrough itself).
-- 2. `<leader>am` (chat buffer only): opens the block under the cursor as an SVG
--    in the browser, where a big diagram can be zoomed. A terminal image can't.
--
-- Why after the reply and NOT snacks' automatic doc mode: auto mode re-scans on
-- every buffer change and starts the converter for every new block text, so
-- while a diagram streams in it spawns a render per chunk, mostly for
-- half-written diagrams. Here nothing runs at startup, while typing or while
-- streaming. Per finished reply: one treesitter query over the chat buffer, and
-- one render per NEW diagram (PNG cached by text, so repeats cost nothing).
--
-- Renderer: `mmdr` (mermaid-rs-renderer, native, ~60 ms, no browser), falling
-- back to `mmdc` (official mermaid-cli, Chromium, 1-2 s) when mmdr is missing or
-- fails on a diagram. Cache: stdpath("cache")/mermaid-chat.
--
-- Style: Obsidian's look. Obsidian renders Mermaid with the stock light theme
-- and, in dark mode, applies `invert(100%) hue-rotate(180deg)` to the SVG. The
-- dark colours below are mermaid's default theme pushed through that same
-- filter (lightness flipped, hues kept), so no post-processing is needed.
--
-- WARN: a big diagram scaled to the chat width has unreadably small text; that
-- is what <leader>am (browser) is for.
-- WARN: first render calls Snacks.image.setup(). If snacks `image` is not
-- enabled elsewhere, that also registers snacks' BufReadCmd for image files
-- (png, jpg, pdf, ...), so opening one in Neovim afterwards shows the image
-- instead of raw bytes, for the rest of the session.
-- WARN: inside tmux, an inline image can be misplaced after a scroll or resize
-- until snacks redraws it.

local M = {}

local uv = vim.uv
local cache = vim.fn.stdpath("cache") .. "/mermaid-chat"

local FONT = "-apple-system, 'Helvetica Neue', Inter, Arial, sans-serif"

-- `theme = "base"` is what makes mmdc honour themeVariables; mmdr ignores the
-- unknown name and applies the variables over its default.
local DARK = {
  fontFamily = FONT,
  primaryColor = "#101023",
  primaryBorderColor = "#9471DC",
  primaryTextColor = "#CCCCCC",
  textColor = "#CCCCCC",
  lineColor = "#CCCCCC",
  secondaryColor = "#050500",
  tertiaryColor = "#000B00",
  clusterBkg = "#050500",
  clusterBorder = "#666600",
  edgeLabelBackground = "#171717",
  actorBkg = "#101023",
  actorBorder = "#9471DC",
  actorLine = "#666666",
  noteBkg = "#1A1000",
  noteBorderColor = "#666600",
}

---@type table<string, table>
local THEMES = {
  -- inline: transparent, sits on the editor background
  dark = { theme = "base", themeVariables = vim.tbl_extend("force", DARK, { background = "transparent" }) },
  light = { theme = "default", themeVariables = { background = "transparent", fontFamily = FONT } },
  -- browser: a browser page is white, so the SVG carries Obsidian's dark background
  ["dark-page"] = { theme = "base", themeVariables = vim.tbl_extend("force", DARK, { background = "#1E1E1E" }) },
  ["light-page"] = { theme = "default", themeVariables = { background = "#FFFFFF", fontFamily = FONT } },
}

local query ---@type vim.treesitter.Query?
local pending = {} ---@type table<string, fun(err?: string)[]>
local placed = {} ---@type table<integer, snacks.image.Placement[]>
local warned = {} ---@type table<string, boolean>

---@param path string
---@param data string
local function write(path, data)
  local fd = assert(io.open(path, "w"))
  fd:write(data)
  fd:close()
end

---@param name string
local function theme_file(name)
  local path = ("%s/theme-%s.json"):format(cache, name)
  if not uv.fs_stat(path) then
    write(path, vim.json.encode(THEMES[name]))
  end
  return path
end

---@param buf integer
---@return {text: string, first: integer, last: integer}[] blocks; rows 0-based, last = last content row
local function blocks(buf)
  local ok, parser = pcall(vim.treesitter.get_parser, buf, "markdown")
  if not ok or not parser then
    return {}
  end
  query = query
    or vim.treesitter.query.parse(
      "markdown",
      [[(fenced_code_block (info_string (language) @_lang) (code_fence_content) @content
          (#eq? @_lang "mermaid"))]]
    )
  local ret = {}
  local tree = parser:parse()[1] -- root tree only; incremental, the chat is already parsed
  for id, node in query:iter_captures(tree:root(), buf) do
    if query.captures[id] == "content" then
      local text = vim.treesitter.get_node_text(node, buf)
      local srow, _, erow, ecol = node:range()
      if text:find("%S") then
        -- code_fence_content ends at column 0 of the closing fence line
        ret[#ret + 1] = { text = text, first = srow, last = ecol == 0 and erow - 1 or erow }
      end
    end
  end
  return ret
end

---@param cmd string[]
---@param cb fun(r: vim.SystemCompleted)
local function run(cmd, cb)
  vim.system(cmd, { text = true }, vim.schedule_wrap(cb))
end

--- Render `text` to `<cache>/<key>.<ext>` once; concurrent callers share the run.
---@param text string
---@param ext "png"|"svg"
---@param theme string
---@param cb fun(err?: string, file?: string)
local function render(text, ext, theme, cb)
  local key = vim.fn.sha256(theme .. "\0" .. text):sub(1, 16)
  local out = ("%s/%s.%s"):format(cache, key, ext)
  if uv.fs_stat(out) then
    return cb(nil, out)
  end
  if pending[out] then
    table.insert(pending[out], cb)
    return
  end
  pending[out] = { cb }
  vim.fn.mkdir(cache, "p")
  local src = ("%s/%s.mmd"):format(cache, key)
  write(src, text)
  local cfg = theme_file(theme)

  local function done(err)
    os.remove(src)
    if err then
      os.remove(out) -- never cache a partial file
    end
    local cbs = pending[out]
    pending[out] = nil
    for _, f in ipairs(cbs) do
      f(err, not err and out or nil)
    end
  end
  local function ok(r)
    return r.code == 0 and uv.fs_stat(out) ~= nil
  end
  local function mmdc(prev_err)
    if vim.fn.executable("mmdc") == 0 then
      return done(prev_err or "no renderer found: brew install mmdr (or npm i -g @mermaid-js/mermaid-cli)")
    end
    local bg = THEMES[theme].themeVariables.background
    run({ "mmdc", "-i", src, "-o", out, "-c", cfg, "-b", bg, "-s", "2" }, function(r)
      done(not ok(r) and ("mmdc: " .. vim.trim(r.stderr or "")) or nil)
    end)
  end
  if vim.fn.executable("mmdr") == 0 then
    return mmdc()
  end
  run({ "mmdr", "-i", src, "-o", out, "-e", ext, "-c", cfg }, function(r)
    if ok(r) then
      return done()
    end
    os.remove(out)
    mmdc("mmdr: " .. vim.trim(r.stderr or ""))
  end)
end

---@param buf integer
local function clear(buf)
  for _, p in ipairs(placed[buf] or {}) do
    pcall(p.close, p)
  end
  placed[buf] = nil
end

--- Re-place every diagram in the chat. Old placements are closed first: their
--- extmarks drift when a chat is cleared or edited, and a placement only reuses
--- the already-sent image (snacks caches it by file), so this is cheap.
---@param buf integer
function M.render_inline(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  clear(buf)
  local list = blocks(buf)
  if #list == 0 then
    return
  end
  local theme = vim.o.background == "light" and "light" or "dark"
  for _, b in ipairs(list) do
    render(b.text, "png", theme, function(err, png)
      if err then
        local key = vim.fn.sha256(b.text)
        if not warned[key] then
          warned[key] = true
          vim.notify("Mermaid render failed\n" .. err, vim.log.levels.WARN)
        end
        return
      end
      -- skip if the block moved or changed meanwhile (chat cleared, edited);
      -- the next ChatDone places it again
      if not vim.api.nvim_buf_is_valid(buf) then
        return
      end
      local lines = vim.api.nvim_buf_get_lines(buf, b.first, b.last + 1, false)
      if table.concat(lines, "\n") ~= (b.text:gsub("\n$", "")) then
        return
      end
      local line = lines[#lines]
      local p = Snacks.image.placement.new(
        buf,
        png,
        Snacks.config.merge({}, Snacks.image.config.doc, {
          inline = true,
          conceal = false,
          pos = { b.last + 1, 0 },
          -- the last code line: the image goes in virtual lines right under it
          range = { b.last + 1, 0, b.last + 1, #line },
          max_height = 30,
        })
      )
      placed[buf] = placed[buf] or {}
      table.insert(placed[buf], p)
    end)
  end
end

--- Open the ```mermaid block under the cursor as an SVG in the browser.
function M.open_in_browser()
  local buf = vim.api.nvim_get_current_buf()
  local row = vim.api.nvim_win_get_cursor(0)[1] - 1
  local text
  for _, b in ipairs(blocks(buf)) do
    -- first - 1 / last + 1: the fence lines count as inside the block
    if row >= b.first - 1 and row <= b.last + 1 then
      text = b.text
      break
    end
  end
  if not text then
    return vim.notify("No ```mermaid block under the cursor", vim.log.levels.WARN)
  end
  local theme = vim.o.background == "light" and "light-page" or "dark-page"
  render(text, "svg", theme, function(err, svg)
    if err then
      return vim.notify("Mermaid render failed\n" .. err, vim.log.levels.ERROR)
    end
    vim.ui.open(svg)
  end)
end

local did_setup = false

---@param buf integer
function M.attach(buf)
  vim.keymap.set("n", "<leader>am", M.open_in_browser, { buffer = buf, desc = "Mermaid: open diagram in browser" })
  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = buf,
    once = true,
    callback = function()
      placed[buf] = nil
    end,
  })
  if did_setup then
    return
  end
  did_setup = true
  local group = vim.api.nvim_create_augroup("mermaid_chat_inline", { clear = true })
  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "CodeCompanionChatDone",
    callback = function(ev)
      local b = ev.data and ev.data.bufnr
      if b then
        M.render_inline(b)
      end
    end,
  })
  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "CodeCompanionChatCleared",
    callback = function(ev)
      local b = ev.data and ev.data.bufnr
      if b then
        clear(b)
      end
    end,
  })
end

return M
