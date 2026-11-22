-- Mermaid diagrams in CodeCompanion chat buffers.
--
-- 1. Inline: when a reply finishes (`CodeCompanionChatDone`), every ```mermaid
--    block in that chat is rendered to a PNG and drawn under the block through
--    snacks.nvim's image module (Ghostty image protocol, also inside tmux;
--    snacks sets allow-passthrough itself). A diagram too big to read at chat
--    width gets a one-line hint pointing at the viewer.
-- 2. `<leader>am` (chat buffer only): a zoomable viewer for the block under the
--    cursor. A terminal image can't zoom, so every zoom/pan step crops the
--    full-size render to the visible area with ImageMagick and shows that crop:
--    text stays sharp at any zoom. `o` in the viewer opens the SVG in the
--    browser as a last resort.
--
-- Why after the reply and NOT snacks' automatic doc mode: auto mode re-scans on
-- every buffer change and starts the converter for every new block text, so
-- while a diagram streams in it spawns a render per chunk, mostly for
-- half-written diagrams. Here nothing runs at startup, while typing or while
-- streaming. Per finished reply: one treesitter query over the chat buffer and
-- one render per NEW diagram (cached by text). The viewer only works on a key
-- press inside it (one `magick` crop, cached per view).
--
-- Renderer order is RENDERERS below: `mmdr` (mermaid-rs-renderer, native,
-- ~60 ms) then `mmdc` (official mermaid-cli, Chromium, 1-2 s). The first that
-- succeeds wins. Cache: stdpath("cache")/mermaid-chat.
--
-- Style: Obsidian's look. Obsidian renders Mermaid with the stock light theme
-- and, in dark mode, applies `invert(100%) hue-rotate(180deg)` to the SVG. The
-- dark colours below are mermaid's default theme pushed through that same
-- filter (lightness flipped, hues kept), so no post-processing is needed.
--
-- WARN: first render calls Snacks.image.setup(). If snacks `image` is not
-- enabled elsewhere, that also registers snacks' BufReadCmd for image files
-- (png, jpg, pdf, ...), so opening one in Neovim afterwards shows the image
-- instead of raw bytes, for the rest of the session.
-- WARN: inside tmux, an inline image can be misplaced after a scroll or resize
-- until snacks redraws it.
-- WARN: the viewer needs ImageMagick (`magick`), which snacks' image module
-- already requires.

local M = {}

local uv = vim.uv
local cache = vim.fn.stdpath("cache") .. "/mermaid-chat"

local RENDERERS = { "mmdr", "mmdc" }
local FONT = "-apple-system, 'Helvetica Neue', Inter, Arial, sans-serif"
local FONT_SIZE = 16 -- px in the PNG at 100%
-- Inline hint when fitted text would be smaller than this share of FONT_SIZE.
local INLINE_MIN_SCALE = 0.6
local ZOOM_STEP = 1.5
local MAX_ZOOM = 3 -- times the PNG's own size

local DARK = {
  fontFamily = FONT,
  fontSize = FONT_SIZE, -- WARN: must be a number; "16px" makes mmdr exit with an error
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

-- `theme = "base"` is what makes mmdc honour themeVariables; mmdr ignores the
-- unknown name and applies the variables over its default.
---@type table<string, table>
local THEMES = {
  dark = { theme = "base", themeVariables = vim.tbl_extend("force", DARK, { background = "transparent" }) },
  light = {
    theme = "default",
    themeVariables = { background = "transparent", fontFamily = FONT, fontSize = FONT_SIZE },
  },
  -- browser: a page is white, so the SVG carries Obsidian's dark background
  ["dark-page"] = { theme = "base", themeVariables = vim.tbl_extend("force", DARK, { background = "#1E1E1E" }) },
  ["light-page"] = {
    theme = "default",
    themeVariables = { background = "#FFFFFF", fontFamily = FONT, fontSize = FONT_SIZE },
  },
}

local ns = vim.api.nvim_create_namespace("mermaid_chat")
local query ---@type vim.treesitter.Query?
local pending = {} ---@type table<string, fun(err?: string, file?: string)[]>
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

--- PNG width/height from the IHDR header (first 24 bytes).
---@param path string
---@return integer?, integer?
local function png_size(path)
  local fd = io.open(path, "rb")
  if not fd then
    return
  end
  local h = fd:read(24)
  fd:close()
  if not h or #h < 24 then
    return
  end
  local function u32(i)
    local a, b, c, d = h:byte(i, i + 3)
    return ((a * 256 + b) * 256 + c) * 256 + d
  end
  return u32(17), u32(21)
end

---@param buf integer
---@return {text: string, first: integer, last: integer}[] rows 0-based; last = last content row
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
  local bg = THEMES[theme].themeVariables.background

  local function finish(err)
    os.remove(src)
    local cbs = pending[out]
    pending[out] = nil
    for _, f in ipairs(cbs) do
      f(err, not err and out or nil)
    end
  end
  local errors = {}
  local function try(i)
    local name = RENDERERS[i]
    if not name then
      return finish(#errors > 0 and table.concat(errors, "\n") or "no renderer found: brew install mmdr")
    end
    if vim.fn.executable(name) == 0 then
      return try(i + 1)
    end
    local cmd = name == "mmdr" and { "mmdr", "-i", src, "-o", out, "-e", ext, "-c", cfg }
      or { "mmdc", "-i", src, "-o", out, "-c", cfg, "-b", bg }
    run(cmd, function(r)
      if r.code == 0 and uv.fs_stat(out) then
        return finish()
      end
      os.remove(out) -- never cache a partial file
      errors[#errors + 1] = name .. ": " .. vim.trim(r.stderr or "")
      try(i + 1)
    end)
  end
  try(1)
end

---@param buf integer
local function clear(buf)
  for _, p in ipairs(placed[buf] or {}) do
    pcall(p.close, p)
  end
  placed[buf] = nil
  if vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  end
end

---@return number cell_w, number cell_h pixels per cell
local function cell_px()
  local t = Snacks.image.terminal.size()
  return t.cell_width, t.cell_height
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
      local win = vim.fn.bufwinid(buf)
      -- Copilot-Chat style: full chat width, up to one screen of the chat high
      local width = win ~= -1 and vim.api.nvim_win_get_width(win) or 80
      local height = math.max(10, (win ~= -1 and vim.api.nvim_win_get_height(win) or 30) - 2)
      -- Never draw bigger than the PNG's own pixels: snacks would scale a small
      -- diagram up (PNG 72 dpi metadata x terminal scale), ~2.7x for 4 nodes.
      local w, h = png_size(png)
      local cw, ch = cell_px()
      if w and h then
        width = math.min(width, math.ceil(w / cw))
        height = math.min(height, math.ceil(h / ch))
      end
      local p = Snacks.image.placement.new(
        buf,
        png,
        Snacks.config.merge({}, Snacks.image.config.doc, {
          inline = true,
          conceal = false,
          pos = { b.last + 1, 0 },
          -- the last code line: the image goes in virtual lines right under it
          range = { b.last + 1, 0, b.last + 1, #line },
          max_width = width,
          max_height = height,
        })
      )
      placed[buf] = placed[buf] or {}
      table.insert(placed[buf], p)
      -- Hint when the fitted image would be too small to read.
      if w and h and math.min(width * cw / w, height * ch / h) < INLINE_MIN_SCALE then
        vim.api.nvim_buf_set_extmark(buf, ns, b.first, 0, {
          virt_lines_above = true,
          virt_lines = { { { "  󰈈 large diagram: <leader>am to zoom", "Comment" } } },
        })
      end
    end)
  end
end

---------------------------------------------------------------------------
-- Viewer
---------------------------------------------------------------------------

---@class mermaid.View
---@field src string full-size PNG
---@field svg_text string
---@field w integer
---@field h integer
---@field zoom number 1 = fit the window
---@field cx number view centre, image px
---@field cy number
---@field win snacks.win
---@field img? snacks.image.Placement
local view ---@type mermaid.View?

---@return integer cols, integer rows
local function view_cells()
  return math.floor(vim.o.columns * 0.92), math.floor((vim.o.lines - 2) * 0.88)
end

--- Crop + scale the full PNG to what the window shows, then show it.
---@param v mermaid.View
local function draw(v)
  local cols, rows = view_cells()
  local cw, ch = cell_px()
  local vw, vh = math.floor(cols * cw), math.floor(rows * ch)
  local fit = math.min(vw / v.w, vh / v.h)
  local scale = math.min(fit * v.zoom, MAX_ZOOM)
  -- crop rectangle in image px, kept inside the image
  local crop_w, crop_h = math.min(v.w, vw / scale), math.min(v.h, vh / scale)
  v.cx = math.min(math.max(v.cx, crop_w / 2), v.w - crop_w / 2)
  v.cy = math.min(math.max(v.cy, crop_h / 2), v.h - crop_h / 2)
  local x, y = math.floor(v.cx - crop_w / 2), math.floor(v.cy - crop_h / 2)
  crop_w, crop_h = math.floor(crop_w), math.floor(crop_h)
  local out_w, out_h = math.floor(crop_w * scale), math.floor(crop_h * scale)

  local pct = math.floor(scale * 100 + 0.5)
  v.win:set_title((" Mermaid · %d%% "):format(pct), "center")

  local out = ("%s.%dx%d+%d+%d@%dx%d.png"):format((v.src:gsub("%.png$", "")), crop_w, crop_h, x, y, out_w, out_h)
  local function show()
    -- buf_valid, not valid(): valid() also needs the window, which may not exist yet
    if view ~= v or not v.win:buf_valid() then
      return
    end
    local old = v.img
    v.img = Snacks.image.placement.new(v.win.buf, out, {
      inline = false,
      max_width = cols,
      max_height = rows,
    })
    if old then
      pcall(old.close, old)
    end
  end
  if uv.fs_stat(out) then
    return show()
  end
  -- `-scale` (box filter): ~0.75 s on a 4600 px render vs ~1.2 s for Lanczos,
  -- with no visible difference on flat diagram art. At 100% only crop (~0.4 s).
  -- WARN: cost grows with the render's size; a 4600 px PNG is the slow case.
  local cmd = { "magick", v.src, "-crop", ("%dx%d+%d+%d"):format(crop_w, crop_h, x, y), "+repage" }
  if out_w ~= crop_w or out_h ~= crop_h then
    vim.list_extend(cmd, { "-scale", ("%dx%d!"):format(out_w, out_h) })
  end
  cmd[#cmd + 1] = out
  run(cmd, function(r)
    if r.code ~= 0 then
      return vim.notify("Mermaid viewer: magick failed\n" .. vim.trim(r.stderr or ""), vim.log.levels.ERROR)
    end
    show()
  end)
end

local function close_view()
  local v = view
  view = nil -- clear first: win:close() re-enters through on_close
  if v then
    if v.img then
      pcall(v.img.close, v.img)
    end
    pcall(v.win.close, v.win)
  end
end

---@param v mermaid.View
---@param factor number
local function zoom(v, factor)
  v.zoom = math.max(1, v.zoom * factor)
  draw(v)
end

---@param v mermaid.View
---@param dx number share of the visible width
---@param dy number
local function pan(v, dx, dy)
  local cols, rows = view_cells()
  local cw, ch = cell_px()
  local fit = math.min(cols * cw / v.w, rows * ch / v.h)
  local scale = math.min(fit * v.zoom, MAX_ZOOM)
  v.cx = v.cx + dx * cols * cw / scale
  v.cy = v.cy + dy * rows * ch / scale
  draw(v)
end

---@param png string
---@param text string
local function open_view(png, text)
  close_view()
  local w, h = png_size(png)
  if not (w and h) then
    return vim.notify("Mermaid viewer: unreadable PNG", vim.log.levels.ERROR)
  end
  local v ---@type mermaid.View
  local function k(fn)
    return function()
      if view == v then
        fn()
      end
    end
  end
  local win = Snacks.win({
    show = false,
    enter = true,
    relative = "editor",
    border = "rounded",
    backdrop = false,
    title = " Mermaid ",
    title_pos = "center",
    footer = " +/- zoom · hjkl pan · 0 fit · o browser · q close ",
    footer_pos = "center",
    bo = { filetype = "mermaid_view" },
    wo = { winblend = 0, winhighlight = "FloatTitle:Title,FloatFooter:Comment" },
    keys = {
      q = "close",
      ["<Esc>"] = "close",
      ["+"] = { k(function() zoom(v, ZOOM_STEP) end), desc = "zoom in" },
      ["="] = { k(function() zoom(v, ZOOM_STEP) end), desc = "zoom in" },
      ["-"] = { k(function() zoom(v, 1 / ZOOM_STEP) end), desc = "zoom out" },
      ["0"] = { k(function()
        v.zoom, v.cx, v.cy = 1, v.w / 2, v.h / 2
        draw(v)
      end), desc = "fit" },
      h = { k(function() pan(v, -0.25, 0) end), desc = "pan left" },
      l = { k(function() pan(v, 0.25, 0) end), desc = "pan right" },
      k = { k(function() pan(v, 0, -0.25) end), desc = "pan up" },
      j = { k(function() pan(v, 0, 0.25) end), desc = "pan down" },
      o = { k(function() M.open_in_browser(text) end), desc = "open in browser" },
    },
    on_close = function()
      close_view()
    end,
  })
  -- full view size from the start: the window must not shrink to the fit image,
  -- or every zoomed crop gets scaled back down into it
  win.opts.width, win.opts.height = view_cells()
  win:open_buf()
  win:show()
  v = { src = png, svg_text = text, w = w, h = h, zoom = 1, cx = w / 2, cy = h / 2, win = win }
  view = v
  vim.api.nvim_create_autocmd({ "BufLeave", "WinLeave" }, { buffer = win.buf, once = true, callback = close_view })
  draw(v)
end

---@param text string
function M.open_in_browser(text)
  local theme = vim.o.background == "light" and "light-page" or "dark-page"
  render(text, "svg", theme, function(err, svg)
    if err then
      return vim.notify("Mermaid render failed\n" .. err, vim.log.levels.ERROR)
    end
    vim.ui.open(svg)
  end)
end

--- `<leader>am`: open the ```mermaid block under the cursor in the viewer.
function M.preview()
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
  local theme = vim.o.background == "light" and "light" or "dark"
  render(text, "png", theme, function(err, png)
    if err then
      return vim.notify("Mermaid render failed\n" .. err, vim.log.levels.ERROR)
    end
    open_view(png, text)
  end)
end

local did_setup = false

---@param buf integer
function M.attach(buf)
  vim.keymap.set("n", "<leader>am", M.preview, { buffer = buf, desc = "Mermaid: zoomable view of block" })
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
