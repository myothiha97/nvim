local backdrop_buf = nil
local backdrop_win = nil
local saved_winhl = {}

-- `true` opens Oil as a centred popup, both on <leader>e and on `nvim <dir>`.
-- `false` opens it fullscreen in the current window instead (the fullscreen
-- implementation is fully preserved below).
local USE_FLOAT = true

-- Backdrop behind the popup: ON, deliberately, 2026-09-04. And it works now.
--
-- READ THIS BEFORE "FIXING" IT. `CLAUDE.md` and
-- notes/popup-backdrop-darkening-investigation.md say never to add a backdrop
-- here. That rule had a PRECONDITION which no longer holds. It applied while the
-- colorscheme ran `transparent = true`: Nvim painted no background, so a black
-- float had nothing to blend against and emitted raw #000000 at every `winblend`
-- (blend 80 and blend 0 measured identical, zero default-background cells) --
-- an opaque sheet rather than a shade.
--
-- The theme went OPAQUE the same day (`transparent = false`, with the background
-- in lua/config/ui.lua). There is a real background to
-- blend against now, so `BACKDROP_BLEND` is live and this is a genuine dim: the
-- text underneath fades toward `BACKDROP_COLOR` instead of being covered.
--
-- Two things follow. Turning transparency back on turns this back into a black
-- sheet, so the two settings are coupled -- check this file if that ever
-- changes. And do not flip `USE_BACKDROP` off on the strength of the old note:
-- it was turned on by explicit request, with the then-current failure stated
-- first, and the failure has since been designed out.
local USE_BACKDROP = true

-- The dim, in one place. `BACKDROP_BLEND` is the strength: 0 hides the editor
-- completely, 100 shows no dim at all.
local BACKDROP_COLOR = "#000000"
local BACKDROP_BLEND = 60

-- WARN: SILENT FAILURE. A backdrop ABOVE another floating panel HIDES it --
-- `winblend` does not composite over a lower float the way it does over a
-- split. The snacks explorer sidebar goes blank, not dim, and nothing errors.
-- 40 puts the backdrop above every other floating panel in this config, so the
-- dim covers the WHOLE screen. Measured zindexes, for reference:
--
--   snacks explorer input / list   33
--   snacks picker preview          40
--   fidget notifications           45
--   the oil popup itself           45
--   ordinary splits                (none -- always under any float)
--
-- KNOWN CONSEQUENCE, accepted 2026-09-04: the snacks explorer sidebar
-- (<leader>r) goes BLANK, not dim, while the popup is open. `winblend` does not
-- composite over a lower FLOAT the way it does over split windows, so a backdrop
-- above another panel hides it outright -- measured off a screenshot, the
-- sidebar's text pixels fell from 14.8% of that region to 0.8%.
--
-- 30 WAS TRIED AND REJECTED the same day. It does fix the sidebar (30 sits under
-- the panels at 33+ while still covering the splits), but it also stops the dim
-- being full-screen: the sidebar keeps full brightness and the popup no longer
-- reads as the one thing in focus. The user's call, in their words: "i will just
-- continue with blank snacks explorer side bar with dim bg when oil float
-- appear." Do not re-fix this without asking -- the blank sidebar is the price of
-- the focus effect, and it is the price they chose.
local BACKDROP_ZINDEX = 40

local function close_backdrop()
  -- Restore search highlights in background windows
  for win, hl in pairs(saved_winhl) do
    if vim.api.nvim_win_is_valid(win) then
      vim.wo[win].winhighlight = hl
    end
  end
  saved_winhl = {}

  if backdrop_win and vim.api.nvim_win_is_valid(backdrop_win) then
    vim.api.nvim_win_close(backdrop_win, true)
  end
  if backdrop_buf and vim.api.nvim_buf_is_valid(backdrop_buf) then
    vim.api.nvim_buf_delete(backdrop_buf, { force = true })
  end
  backdrop_win = nil
  backdrop_buf = nil
end

local function create_backdrop()
  -- Never stack two: an interrupted close would otherwise leave one behind.
  close_backdrop()
  backdrop_buf = vim.api.nvim_create_buf(false, true)
  backdrop_win = vim.api.nvim_open_win(backdrop_buf, false, {
    relative = "editor",
    width = vim.o.columns,
    height = vim.o.lines,
    row = 0,
    col = 0,
    style = "minimal",
    focusable = false,
    zindex = BACKDROP_ZINDEX,
  })
  vim.api.nvim_set_hl(0, "OilBackdrop", { bg = BACKDROP_COLOR })
  vim.wo[backdrop_win].winhighlight = "Normal:OilBackdrop"
  vim.wo[backdrop_win].winblend = BACKDROP_BLEND
end

local function hide_bg_search_highlights()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    local name = vim.api.nvim_buf_get_name(buf)
    -- Skip Oil buffer and backdrop
    if not name:match("^oil://") and win ~= backdrop_win then
      saved_winhl[win] = vim.wo[win].winhighlight
      local current = vim.wo[win].winhighlight
      local hide_search = "Search:None,IncSearch:None,CurSearch:None"
      if current ~= "" then
        vim.wo[win].winhighlight = current .. "," .. hide_search
      else
        vim.wo[win].winhighlight = hide_search
      end
    end
  end
end

local function is_oil_float_open()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    local name = vim.api.nvim_buf_get_name(buf)
    local config = vim.api.nvim_win_get_config(win)
    if name:match("^oil://") and config.relative ~= "" then
      return true, win
    end
  end
  return false, nil
end

--- The one way the popup is opened, so `<leader>e` and the `nvim <dir>` hook at
--- the bottom of this file both get the backdrop and neither can drift.
local function open_oil_float(dir)
  if USE_BACKDROP then
    create_backdrop()
  end
  require("oil").open_float(dir)
  if USE_BACKDROP then
    -- Search highlights in the windows underneath would otherwise glow through
    -- the backdrop; restored by close_backdrop.
    hide_bg_search_highlights()
  end
end

local function toggle_oil_float()
  local open, win = is_oil_float_open()
  if open then
    close_backdrop()
    if win then
      vim.api.nvim_win_close(win, true)
    end
  else
    open_oil_float()
  end
end

local function toggle_oil_fullscreen()
  if vim.bo.filetype == "oil" then
    local win = vim.api.nvim_get_current_win()
    require("oil").close()
    if vim.api.nvim_win_is_valid(win) then
      vim.wo[win].winbar = " "
    end
  else
    require("oil").open()
  end
end

local function toggle_oil()
  if USE_FLOAT then
    toggle_oil_float()
  else
    toggle_oil_fullscreen()
  end
end

-- ---------------------------------------------------------------------------
-- The path label
--
-- Rendered in two places, from one segment list, because Oil has two shells:
--   * popup  -> the border title, via `float.get_win_title` (chunk list)
--   * window -> the winbar, via `set_oil_winbar` (statusline string)
-- ---------------------------------------------------------------------------

-- ` › ` (U+203A, single guillemet). Spaces included: `a›b›c` reads as one word.
--
-- Five revisions on 2026-09-04 -- ` > `, ` / `, `/`, ` > `, then this -- so the
-- reasoning is written down rather than re-derived. ASCII `/` and `>` were both
-- rejected on sight, and each fails for a DIFFERENT reason. Both measured in the
-- real font (Maple Mono NF Regular, 1000 units/em, x-height 550, cap-height 730):
--
--   `/`  fails on HEIGHT. 960 units tall -- 175% of the x-height, and taller than a
--        capital H (750) -- running from 130 below the baseline to 830 above. It
--        cuts through the line of lowercase names as a tick rather than sitting
--        between them.
--
--   `>`  fails on VERTICAL POSITION and WEIGHT. It is an operator, so the font
--        centres it on the math axis shared by `< > = +` -- measured midpoint 330,
--        identical to `=`. Lowercase centres at 275 (`x` glyph). So `>` floats 55
--        units (~5% of the font size) above the visual line of the words, which is
--        what reads as gappy. It is also 430 units wide against U+203A's 307 (29%
--        wider, 31% more ink in the bounding box), and `font-thicken = true` in the
--        Ghostty config adds weight to the heavier glyph. NOTE: `>` is NOT too
--        tall -- 494 units against U+203A's 480, near-identical. Height is only
--        the slash's problem.
--
-- U+203A is punctuation, not an operator, so the font draws it to sit among
-- lowercase words: midpoint 280 against lowercase's 275, i.e. optically centred.
-- It also keeps the "drill down" sense of `>` -- it is the chevron browsers and
-- VSCode actually draw for path steps, rather than the ASCII stand-in.
--
-- U+203A IS THE BEST AVAILABLE, and that was checked rather than assumed. Every
-- arrow-like punctuation mark in the font was measured and ranked by how far its
-- optical centre sits from the lowercase line (offset / height-vs-x-height / ink
-- relative to `>`):
--
--   › U+203A      5   87%    69%   <- centred AND lighter than `>`
--   » U+00BB      5   87%   120%   <- also centred, but heavier than `>`
--   > U+003E     55   90%   100%
--   → U+2192     55  102%   150%
--   · U+00B7     70   31%    14%
--   ⟩ U+27E9     75  169%   149%
--   ‣ ▸ ▹        85  48-55%  32-44%
--    U+E0B1     85  240%   373%   <- NOT a mild trade; 3.7x the ink of `>`
--   ❯ U+276F     90  133%   138%
--
-- Only U+203A and U+00BB are optically centred on lowercase at all; everything
-- else repeats `>`'s defect. Of those two, U+203A is the lighter. STOP RULE if
-- this ever reopens: centre offset <= 15, height 80-95% of x-height, ink <= 100%
-- of `>`. U+203A is the only candidate that passes all three, so there is nothing
-- further to look for.
--
-- Runner-up: `·` (U+00B7). NOT because it is centred -- it is not, offset 70 --
-- but because at 14% of `>`'s ink the eye does not register the misalignment. It
-- gives up direction, which the left-to-right order already carries.
--
-- `˃` (U+02C3), `➤` (U+27A4) and `≻` (U+227B) are NOT in Maple Mono NF and would
-- fall back to another font. Do not reach for them.
--
-- Every candidate measured 1 display cell, so swapping this cannot affect the
-- indent or the width budgets. Metrics come from fontTools reading
-- ~/Library/Fonts/MapleMono-NF-Regular.ttf; repeat that rather than eyeballing.
local SEPARATOR = " › "
local ELLIPSIS = "…"
local RULE = "─"

local function clean_path(path)
  return (vim.fs.normalize(path):gsub("/+$", ""))
end

--- `dir` split into segments, starting at the PROJECT ROOT instead of the
--- filesystem root: `~/dev/api/internal/store` under cwd `~/dev/api` becomes
--- { "api", "internal", "store" }.
---
--- The project root here is the cwd, not LazyVim's LSP-derived root. The cwd is
--- the directory Nvim was opened in, it does not move mid-session, and reading
--- it costs nothing -- an LSP root would make the label depend on which server
--- had attached, for a label whose whole job is to say "where am I".
---
--- Outside the cwd there is no root to anchor to, so the `:~` absolute path is
--- used and its own first element becomes the root segment.
local function path_segments(dir)
  local root, cur = clean_path(vim.fn.getcwd()), clean_path(dir)
  local segments = {}

  if cur == root or cur:sub(1, #root + 1) == root .. "/" then
    -- `:t` of "/" is empty, so name the filesystem root explicitly.
    segments[1] = vim.fn.fnamemodify(root, ":t")
    if segments[1] == "" then
      segments[1] = "/"
    end
    if cur ~= root then
      for segment in cur:sub(#root + 2):gmatch("[^/]+") do
        segments[#segments + 1] = segment
      end
    end
    return segments
  end

  local short = vim.fn.fnamemodify(cur, ":~")
  if short:sub(1, 1) == "/" then
    segments[1] = "/"
  end
  for segment in short:gmatch("[^/]+") do
    segments[#segments + 1] = segment
  end
  if #segments == 0 then
    segments[1] = "/"
  end
  return segments
end

local function segments_width(segments)
  local width = 0
  for i, segment in ipairs(segments) do
    width = width + vim.fn.strdisplaywidth(segment)
    if i > 1 then
      width = width + vim.fn.strdisplaywidth(SEPARATOR)
    end
  end
  return width
end

--- Drop leading segments until the label fits, replacing them with one ellipsis.
--- A border title wider than its window is silently truncated by Nvim, and the
--- tail is the half worth keeping -- so cut the head deliberately.
local function fit_segments(segments, max_width)
  if max_width <= 0 or segments_width(segments) <= max_width then
    return segments
  end
  for first = 2, #segments do
    local out = vim.list_slice(segments, first)
    table.insert(out, 1, ELLIPSIS)
    if segments_width(out) <= max_width then
      return out
    end
  end
  return { ELLIPSIS, segments[#segments] }
end

--- Directory shown by an Oil window, or nil if it is not one.
local function oil_dir(win)
  local buf = vim.api.nvim_win_get_buf(win)
  if vim.bo[buf].filetype ~= "oil" then
    return nil
  end
  local ok, dir = pcall(require("oil").get_current_dir, buf)
  return ok and dir or nil
end

--- The label the popup's border carries, as a chunk list.
---
--- `nvim_win_set_config` takes `title` as either a string or a list of
--- { text, group } pairs, and Oil passes whatever `get_win_title` returns
--- straight through (oil/init.lua, the float's BufWinEnter handler), so the label
--- is re-rendered on every navigation for free.
---
--- The label sits on the border row and the blank `winbar` row sits under it, so
--- the spacing lands BELOW the label. Putting the label in the winbar instead was
--- tried on 2026-09-04 -- that moves the spacing above it -- and reverted the same
--- day. Both arrangements use the same two rows; only which one holds the text
--- changes.
local function path_title(win)
  local dir = oil_dir(win)
  if not dir then
    -- NOT `oil.util.get_title`, which calls back into this function.
    return vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win))
  end

  -- Line the label up with the file icons below it rather than with the border
  -- corner. A left-positioned border title starts one column inside the border,
  -- which is where the window's TEXT area starts -- but the first thing in the
  -- text area is the number column, so the icons sit `textoff` columns further
  -- right. Padding the title by exactly that much puts the root segment directly
  -- above the first icon.
  --
  -- `textoff` is read per call because it is not a constant: it covers the
  -- number, sign and fold columns together, and the number column widens with
  -- the entry count (`numberwidth`).
  local ok, info = pcall(vim.fn.getwininfo, win)
  local indent = (ok and info[1] and info[1].textoff) or 0

  -- The indent, both border corners, and the padding space after the label.
  local budget = vim.api.nvim_win_get_width(win) - indent - 3
  local segments = fit_segments(path_segments(dir), budget)

  local chunks = { { string.rep(" ", indent) } }
  for i, segment in ipairs(segments) do
    if i > 1 then
      chunks[#chunks + 1] = { SEPARATOR, "OilPathSeparator" }
    end
    chunks[#chunks + 1] = { segment, "OilPathSegment" }
  end
  chunks[#chunks + 1] = { " " }
  return chunks
end

-- Winbar form: the same label as a statusline string, followed by a horizontal
-- divider filling the rest of the row. Only reached when Oil opens in a real
-- window (`:e <dir>`, or USE_FLOAT = false) -- the popup puts the label on its
-- border and keeps its winbar blank as the spacing row.
--
-- Indented to line up with the file icons, same reasoning as `path_title`.
local function set_oil_winbar(win)
  local dir = oil_dir(win)
  if not dir then
    vim.wo[win].winbar = " "
    return
  end
  local total = vim.api.nvim_win_get_width(win)
  local ok, info = pcall(vim.fn.getwininfo, win)
  local indent = (ok and info[1] and info[1].textoff) or 0
  local segments = fit_segments(path_segments(dir), total - indent - 6)

  local parts = {}
  for i, segment in ipairs(segments) do
    if i > 1 then
      parts[#parts + 1] = "%#OilPathSeparator#" .. SEPARATOR .. "%*"
    end
    -- A `%` in a directory name is a statusline item; double it to print it.
    parts[#parts + 1] = "%#OilPathSegment#" .. segment:gsub("%%", "%%%%") .. "%*"
  end

  local used = indent + segments_width(segments) + 1 -- + the space before the divider
  local divider = string.rep(RULE, math.max(0, total - used))
  vim.wo[win].winbar = string.rep(" ", indent) .. table.concat(parts) .. " %#WinSeparator#" .. divider .. "%*"
end

-- WARN: SILENT FAILURE. Must be set in BOTH `win_options` and
-- `float.win_options`. Oil applies the top-level table AFTER the float one, so
-- a float-only value is silently overwritten.
-- Oil windows only, so every other float keeps its visible border. Set in BOTH
-- `win_options` and `float.win_options` -- see the note at the second one.
-- `FloatBorder` is simply unused in a real (non-float) Oil window.
local OIL_WINHIGHLIGHT = "FloatBorder:OilFloatBorder,CursorLine:OilCursorLine"

-- Oil's own highlight groups.
--
-- The label is the theme's azure blue, read from the syntax palette by ROLE
-- (`func`, which also paints `Function`/`Identifier`) rather than copied as a
-- hex, so it cannot drift out of sync with the blue already on screen. It is the
-- same blue the retired snacks browser used for its path input, which linked to
-- `Identifier`. `palette.punctuation` is the copper it wore before 2026-09-04 --
-- a one-word swap back.
--
-- The separators link to NonText, not Comment: Comment is italic in this theme,
-- which would lean the marks away from the upright names. Body-text white
-- (`Normal`) was tried on 2026-09-04 and reverted the same day.
--
-- The BORDER IS DELIBERATELY INVISIBLE: same fg as bg, so the ring disappears
-- while the border still exists. It has to still exist, because Nvim renders a
-- window title on the border and there is nowhere else to put the label -- the
-- winbar is already the padding row, and it cannot be two rows tall. What
-- separates the popup from the buffer underneath is the backdrop dim, not a ring.
--
-- NOTE: the popup needs no BACKGROUND groups of its own. It used to -- the theme
-- gave floats a darker background than `Normal`, spread over `NormalFloat`,
-- `FloatBorder`/`FloatTitle` and `WinBar`, measured #001419/#001419/#002c38
-- against a `Normal` of #031116 as it was then. That is fixed at source now:
-- `on_colors` in
-- lua/colorschemes/solarized-osaka/init.lua points all of them at
-- `require("config.ui").bg`. Do not re-add per-window background remaps here.
local function set_oil_highlights()
  local ok, palette = pcall(require, "colorschemes.solarized-osaka.palette")
  if ok then
    vim.api.nvim_set_hl(0, "OilPathSegment", { fg = palette.func, default = true })
  else
    vim.api.nvim_set_hl(0, "OilPathSegment", { link = "Identifier", default = true })
  end
  vim.api.nvim_set_hl(0, "OilPathSeparator", { link = "NonText", default = true })

  local bg = vim.api.nvim_get_hl(0, { name = "NormalFloat", link = false }).bg
  vim.api.nvim_set_hl(0, "OilFloatBorder", bg and { fg = bg, bg = bg } or { link = "FloatBorder" })
end

-- HOW THE POPUP'S THREE TOP ROWS ARE BUILT, and why it is this way.
--
--   row 1  the border's top edge, carrying the title -> the path label
--   row 2  the winbar, one space                     -> the blank spacing
--   row 3  the first entry
--
-- Swapping the two -- label in the winbar, blank border row above it -- puts the
-- spacing ABOVE the label. That was tried on 2026-09-04 and reverted the same
-- day. Both arrangements use the same two rows; only which one holds the text
-- changes, so it is a small edit either way.
--
-- A winbar DOES occupy a row in a floating window -- measured on 0.12.5, buffer
-- line 1 moves from screen row 5 to 6 when one is set.
--
-- WARN: SILENT FAILURE. Neovim does not DRAW `virt_lines_above` on the FIRST
-- buffer line, yet `nvim_win_text_height` counts it -- so the extmark looks
-- applied and measures correctly while rendering nothing.
-- REJECTED, and do not retry it: an extmark with `virt_lines_above` on the first
-- buffer line. It looks like the right tool -- no text, so Oil's line-to-entry
-- map and its save-time diff never see it -- and `nvim_win_text_height` even
-- counts it. But Neovim does not DRAW virtual lines above line 1. Measured the
-- same way: with the extmark on row 0, line 1 stayed on screen row 5; moved to
-- row 1, line 2 shifted 6 -> 7. Same limitation gitsigns hits with deleted-line
-- markers at the top of a file.
--
-- A real blank line is not an option either: Oil diffs the buffer text on save,
-- so an empty first line reads as a rename to "".
--
-- Oil-in-a-window (`:e <dir>`, or USE_FLOAT = false) has no border row, so it
-- gets no spacing -- the winbar there carries the label plus a divider, and a
-- winbar cannot be two rows tall. Accepted: the popup is the mode in use.

return {
  "stevearc/oil.nvim",
  lazy = false,
  dependencies = { "nvim-tree/nvim-web-devicons" },
  keys = {
    -- <leader>e is the main file explorer again (2026-09-04). It used to open
    -- the snacks browser in snacks-file-browser.lua, which is now retired
    -- there. <leader>E stays mapped to the same thing so the muscle memory
    -- built up while oil lived on it still works.
    { "<leader>e", toggle_oil, desc = "Toggle Oil (file explorer)" },
    { "<leader>E", toggle_oil, desc = "Toggle Oil (file explorer)" },
  },
  opts = {
    -- oil owns netrw outright again: both `:e <dir>` mid-session and the
    -- startup case (`nvim <dir>`). The two browsers that used to steal startup
    -- with a VimEnter hook are both retired (snacks-file-browser.lua,
    -- telescope-file-browser.lua).
    default_file_explorer = true,
    skip_confirm_for_simple_edits = true,
    view_options = { show_hidden = true },
    -- CursorLine is disabled globally (see colorschemes/solarized-osaka/init.lua),
    -- so remap it to OilCursorLine for Oil windows only. Applied once per
    -- window by Oil itself — no CursorMoved autocmd, zero hot-path cost.
    win_options = {
      cursorline = true,
      winhighlight = OIL_WINHIGHLIGHT,
    },
    keymaps = {
      -- Keep LazyVim's window navigation on <C-j>/<C-k>. Oil defaults
      -- <C-h> to horizontal open and <C-l> to refresh; <CR> remains the
      -- conventional way to select an entry.
      ["<C-j>"] = false,
      ["<C-k>"] = false,

      -- Earlier alternative: disable Oil's <C-l> mapping so LazyVim's <C-l>
      -- could focus the right pane, then use <C-o> as another selection key:
      -- ["<C-l>"] = false,
      -- ["<C-o>"] = "actions.select",

      -- Decision (20 Jul 2026): <C-o> proved less ergonomic for frequent
      -- selection, so <C-l> is used below. This intentionally gives up
      -- Oil-local <C-l> right-pane navigation; use <C-w>l when needed.
      ["<C-l>"] = "actions.select",

      -- Backward / forward navigation, mirrored on two key pairs:
      -- <C-h> + `-` go up to the parent, <C-l> + `=` go back down.
      -- `=` sits on the same physical key as `+`, without the Shift.
      --
      -- <C-h> was previously disabled to keep LazyVim's window-left
      -- navigation inside Oil. Same trade as <C-l> above: Oil opens
      -- fullscreen, so there is rarely a left window to reach; use <C-w>h.
      ["<C-h>"] = "actions.parent",

      -- `-` (Oil default) leaves the cursor on the directory it came out of
      -- (oil.open -> view.set_last_cursor), so selecting that entry is the
      -- natural "forward". Guarded to directories, otherwise `=` on a file
      -- row would open the file instead of navigating.
      ["="] = {
        function()
          local oil = require("oil")
          local entry = oil.get_cursor_entry()
          if entry and entry.type == "directory" then
            oil.select()
          end
        end,
        mode = "n",
        desc = "Navigate forward (into directory)",
        -- Yanky (LazyVim extra) maps `=p` / `=P` globally, so without nowait
        -- Nvim waits out `timeoutlen` (300ms) on every `=` to see whether a
        -- p/P follows. nowait takes the exact match immediately.
        nowait = true,
      },
    },
    float = {
      -- 20% narrower than the 0.8 it opened at, 2026-09-04. Height unchanged.
      max_width = 0.64,
      max_height = 0.8,
      border = "rounded",
      -- The border title IS the path label. Oil re-reads this on every
      -- directory change, so nothing has to watch for navigation.
      get_win_title = path_title,
      -- Label in the top-left corner. Centring it was tried on 2026-09-04 and
      -- reverted the same day.
      --
      -- Set here rather than alongside the title because Oil's per-navigation
      -- `nvim_win_set_config` passes `title` WITHOUT `title_pos`, and Nvim keeps
      -- the window's existing `title_pos` in that case (measured on 0.12.5), so
      -- once at open time is enough. The placeholder title is needed because
      -- `title_pos` on its own is an error, and Oil's initial `nvim_open_win`
      -- carries no title -- the real label lands a moment later, from the
      -- `:edit` that loads the directory.
      override = function(conf)
        conf.title = " "
        conf.title_pos = "left"
        return conf
      end,
      -- Oil applies `float.win_options` to the popup instead of the top-level
      -- `win_options`, so the CursorLine remap has to be repeated here.
      -- Only `CursorLine` is named: in a float, Nvim maps `Normal` to
      -- `NormalFloat` on its own as long as winhighlight leaves it alone.
      win_options = {
        winblend = 0,
        cursorline = true,
        -- WARN: SILENT FAILURE. Anything per-directory placed in `float.win_options`
        -- is overwritten on every navigation, because Oil re-applies this whole table.
        -- Repeated from the top-level `win_options` on purpose: Oil sets the
        -- float's options first and then loads the directory, and loading it
        -- applies the top-level table over the top. Measured -- a value set only
        -- here comes up overwritten.
        winhighlight = OIL_WINHIGHLIGHT,
        -- The blank spacing row under the border title. Safe as a constant
        -- BECAUSE it is constant: Oil re-applies this whole table on every
        -- navigation, so anything per-directory (the label) cannot live here.
        winbar = " ",
      },
    },
    confirmation = {
      keymaps = {
        ["<CR>"] = "actions.confirm",
        ["y"] = "actions.confirm",
        ["n"] = "actions.close",
        ["<Esc>"] = "actions.close",
      },
    },
  },
  config = function(_, opts)
    require("oil").setup(opts)

    set_oil_highlights()
    vim.api.nvim_create_autocmd("ColorScheme", { callback = set_oil_highlights })

    -- `nvim <dir>` opens the popup over a blank buffer.
    --
    -- Oil owns netrw, so by VimEnter it has already claimed the directory
    -- buffer and put itself in the window fullscreen. Left alone that sits
    -- behind the popup, and closing the popup would drop you into fullscreen
    -- Oil instead of an empty editor -- so the directory buffer is swapped for
    -- a blank listed one first.
    --
    -- Only the plain single-directory start is claimed. File arguments, stdin
    -- and `:restart`'s session restore are left alone (init.lua already clears
    -- the arglist for the restart case, so argc is 0 there and this never runs).
    if USE_FLOAT then
      vim.api.nvim_create_autocmd("VimEnter", {
        once = true,
        callback = function()
          if vim.fn.argc() ~= 1 then
            return
          end
          local target = vim.fn.argv(0)
          if type(target) ~= "string" then
            return
          end
          -- Oil has already rewritten the arglist entry to `oil:///path/`;
          -- without stripping the scheme the directory check below fails.
          target = (target:gsub("^oil://", ""))
          if vim.fn.isdirectory(target) ~= 1 then
            return
          end
          local dir = vim.fn.fnamemodify(target, ":p")
          vim.schedule(function()
            local dir_buf = vim.api.nvim_get_current_buf()
            if vim.bo[dir_buf].filetype == "oil" then
              local blank = vim.api.nvim_create_buf(true, false)
              vim.api.nvim_win_set_buf(0, blank)
              pcall(vim.api.nvim_buf_delete, dir_buf, { force = true })
            end
            open_oil_float(dir)
          end)
        end,
      })
    end

    vim.api.nvim_create_autocmd("FileType", {
      pattern = "oil",
      callback = function()
        local close_oil = function()
          close_backdrop()
          local win = vim.api.nvim_get_current_win()
          require("oil").close()
          if vim.api.nvim_win_is_valid(win) then
            vim.wo[win].winbar = " "
          end
        end

        vim.keymap.set("n", "q", close_oil, { buffer = true })

        -- <Esc> only clears search highlights — does not close the popup.
        -- Use `q` to close.
        vim.keymap.set("n", "<ESC>", function()
          if vim.v.hlsearch == 1 then
            vim.cmd("nohlsearch")
          end
        end, { buffer = true })
      end,
    })

    vim.api.nvim_create_autocmd("WinClosed", {
      callback = function()
        vim.schedule(function()
          local open = is_oil_float_open()
          if not open then
            close_backdrop()
          end
        end)
      end,
    })

    -- Fullscreen Oil has no float border to show a title on, so the global
    -- 1-row winbar (set in options.lua) is repurposed to show the current
    -- directory path. Fires on every directory navigation (each becomes a
    -- new "oil" buffer) and resets to the default " " once Oil buffer leaves.
    vim.api.nvim_create_autocmd("BufWinEnter", {
      callback = function(args)
        local win = vim.api.nvim_get_current_win()
        -- Floats are skipped entirely: the popup's label is a border title and its
        -- winbar is the constant blank row from `float.win_options`, while every
        -- other float in the config (pickers, completion docs, the lazy UI) owns
        -- its own winbar and must not be touched.
        if vim.api.nvim_win_get_config(win).relative ~= "" then
          return
        end
        if vim.bo[args.buf].filetype == "oil" then
          set_oil_winbar(win)
        else
          vim.wo[win].winbar = " "
        end
      end,
    })

    -- Recompute the divider width when the Oil window is resized (e.g.
    -- terminal resize, split toggled) so it keeps spanning the full row.
    vim.api.nvim_create_autocmd("WinResized", {
      callback = function()
        for _, win in ipairs(vim.v.event.windows) do
          if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_config(win).relative == "" then
            local buf = vim.api.nvim_win_get_buf(win)
            if vim.bo[buf].filetype == "oil" then
              set_oil_winbar(win)
            end
          end
        end
      end,
    })
  end,
}
