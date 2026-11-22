-- Mermaid preview for CodeCompanion chat buffers.
--
-- `<leader>am` (chat buffer only) renders the ```mermaid block under the cursor
-- to a PNG and shows it in a centred float through snacks.nvim's image module
-- (Ghostty's image protocol, also inside tmux; snacks sets allow-passthrough).
--
-- Why on demand and NOT snacks' automatic doc mode: auto mode re-scans on every
-- buffer change and starts the converter for every new block text, so while a
-- diagram is streaming in it spawns a render per chunk, mostly for half-written
-- diagrams. Nothing here runs at startup, while typing or while streaming: the
-- only cost is one FileType autocmd that sets a buffer-local keymap.
--
-- Renderer: `mmdr` (mermaid-rs-renderer, native, a few ms, no browser), falling
-- back to `mmdc` (official mermaid-cli, Chromium, 1-2 s) when mmdr is missing or
-- fails on a diagram. Output is cached by diagram text + background, so a
-- second view is instant. Cache: stdpath("cache")/mermaid-chat.
--
-- Style: Obsidian's look. Obsidian renders Mermaid with the stock light theme
-- and, in dark mode, applies `invert(100%) hue-rotate(180deg)` to the SVG. The
-- dark colours below are mermaid's default theme pushed through that same
-- filter (lightness flipped, hues kept), so no runtime post-processing is needed.
--
-- WARN: first use calls Snacks.image.setup(). If snacks `image` is not enabled
-- elsewhere, that also registers snacks' BufReadCmd for image files (png, jpg,
-- pdf, ...), so opening one in Neovim afterwards shows the image instead of
-- raw bytes, for the rest of the session.
-- WARN: inside tmux, an image can be misplaced after a scroll or resize; close
-- the float and press the key again.

local M = {}

local uv = vim.uv
local cache = vim.fn.stdpath("cache") .. "/mermaid-chat"

local FONT = "-apple-system, 'Helvetica Neue', Inter, Arial, sans-serif"

-- `theme = "base"` is what makes mmdc honour themeVariables; mmdr ignores the
-- unknown name and applies the variables over its default.
local THEMES = {
  dark = {
    theme = "base",
    themeVariables = {
      background = "transparent",
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
    },
  },
  light = { theme = "default", themeVariables = { background = "transparent", fontFamily = FONT } },
}

local pending = {} ---@type table<string, boolean>
local current ---@type {win: snacks.win, img: snacks.image.Placement}?

---@return string? text of the ```mermaid block under the cursor
local function block_at_cursor()
  local buf = vim.api.nvim_get_current_buf()
  local ok, parser = pcall(vim.treesitter.get_parser, buf, "markdown")
  if not ok or not parser then
    return
  end
  parser:parse() -- root tree only; incremental, the chat buffer is already parsed
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local node = parser:named_node_for_range({ row - 1, col, row - 1, col }, { ignore_injections = true })
  while node and node:type() ~= "fenced_code_block" do
    node = node:parent()
  end
  if not node then
    return
  end
  local lang, text
  for child in node:iter_children() do
    if child:type() == "info_string" then
      lang = vim.treesitter.get_node_text(child, buf)
    elseif child:type() == "code_fence_content" then
      text = vim.treesitter.get_node_text(child, buf)
    end
  end
  if lang and vim.trim(lang):match("^mermaid") and text and text:find("%S") then
    return text
  end
end

---@param path string
---@param data string
local function write(path, data)
  local fd = assert(io.open(path, "w"))
  fd:write(data)
  fd:close()
end

---@param bg string
local function theme_file(bg)
  local path = ("%s/theme-%s.json"):format(cache, bg)
  if not uv.fs_stat(path) then
    write(path, vim.json.encode(THEMES[bg] or THEMES.dark))
  end
  return path
end

local function close()
  local c = current
  current = nil -- clear first: win:close() re-enters through on_close
  if c then
    pcall(c.img.close, c.img)
    pcall(c.win.close, c.win)
  end
end

---@param png string
local function show(png)
  close()
  local doc = Snacks.image.config.doc
  local win = Snacks.win({
    show = false,
    enter = true,
    relative = "editor",
    border = true,
    backdrop = false,
    title = " Mermaid ",
    title_pos = "center",
    keys = { q = "close", ["<Esc>"] = "close" },
    wo = { winblend = Snacks.image.terminal.env().placeholders and 0 or nil },
    on_close = function()
      close()
    end,
  })
  win:open_buf()
  local shown = false
  local img = Snacks.image.placement.new(
    win.buf,
    png,
    Snacks.config.merge({}, doc, {
      inline = false,
      max_width = math.floor(vim.o.columns * 0.9),
      max_height = math.floor(vim.o.lines * 0.85),
      on_update_pre = function(p)
        if not shown then
          shown = true
          local loc = p:state().loc
          win.opts.width, win.opts.height = loc.width, loc.height
          win:show()
        end
      end,
    })
  )
  current = { win = win, img = img }
  vim.api.nvim_create_autocmd({ "BufLeave", "WinLeave" }, { buffer = win.buf, once = true, callback = close })
end

---@param cmd string[]
---@param cb fun(r: vim.SystemCompleted)
local function run(cmd, cb)
  vim.system(cmd, { text = true }, vim.schedule_wrap(cb))
end

---@param src string
---@param png string
---@param cfg string
---@param done fun(err?: string)
local function render(src, png, cfg, done)
  local function ok(r)
    return r.code == 0 and uv.fs_stat(png) ~= nil
  end
  local function mmdc(prev_err)
    if vim.fn.executable("mmdc") == 0 then
      return done(prev_err or "no renderer found: brew install mmdr (or npm i -g @mermaid-js/mermaid-cli)")
    end
    run({ "mmdc", "-i", src, "-o", png, "-c", cfg, "-b", "transparent", "-s", "2" }, function(r)
      done(not ok(r) and ("mmdc: " .. vim.trim(r.stderr or "")) or nil)
    end)
  end
  if vim.fn.executable("mmdr") == 0 then
    return mmdc()
  end
  run({ "mmdr", "-i", src, "-o", png, "-e", "png", "-c", cfg }, function(r)
    if ok(r) then
      return done()
    end
    os.remove(png) -- never cache a partial file
    mmdc("mmdr: " .. vim.trim(r.stderr or ""))
  end)
end

function M.preview()
  local text = block_at_cursor()
  if not text then
    return vim.notify("No ```mermaid block under the cursor", vim.log.levels.WARN)
  end
  local bg = vim.o.background
  local key = vim.fn.sha256(bg .. "\0" .. text):sub(1, 16)
  local png = ("%s/%s.png"):format(cache, key)
  if uv.fs_stat(png) then
    return show(png)
  end
  if pending[key] then
    return
  end
  pending[key] = true
  vim.fn.mkdir(cache, "p")
  local src = ("%s/%s.mmd"):format(cache, key)
  write(src, text)
  render(src, png, theme_file(bg), function(err)
    pending[key] = nil
    os.remove(src)
    if err then
      return vim.notify("Mermaid render failed\n" .. err, vim.log.levels.ERROR)
    end
    show(png)
  end)
end

---@param buf integer
function M.attach(buf)
  vim.keymap.set("n", "<leader>am", M.preview, { buffer = buf, desc = "Mermaid: preview block under cursor" })
end

return M
