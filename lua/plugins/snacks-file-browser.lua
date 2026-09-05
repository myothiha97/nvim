-- File-explorer mode for snacks.explorer: one directory at a time, the way
-- telescope-file-browser worked, without being a telescope picker.
--
-- WHY this exists rather than the telescope trial (see
-- notes/popup-backdrop-darkening-investigation.md for the measurements):
-- telescope's pickers are modal floats that remap `Normal` through
-- `winhighlight` and destroy themselves on focus loss. That cost two hacks to
-- survive another picker opening on top, made a dim impossible on a transparent
-- theme, and poisoned snacks' transparency detection so every popup blacked out
-- the editor. snacks pickers have neither property: they ignore focus lost to
-- another float (`Snacks.util.is_float()`, picker/core/picker.lua:288-291), so a
-- picker stacked on this one leaves it alone, and their windows use
-- `NormalFloat:…`, so nothing to work around.
--
-- TWO MODES, deliberately separate, sharing nothing but the plugin:
--   * <leader>r — the tree sidebar on the left. Configured in snacks.lua, NOT
--     touched here. Everything below is passed per call, so that mode is safe.
--   * <leader>e — this file: a flat, single-directory explorer in a dropdown,
--     fullscreen when nvim opens on a directory.
--
-- Scope is narrow so this can be deleted in one step: one file, per-call opts
-- only, no `opts` block, nothing registered globally.
--
-- RETIRED 2026-09-04: `false`. oil.nvim took <leader>e back because this
-- browser never felt as smooth as oil in daily use. Nothing here is deleted —
-- flip to `true` to bring it back, but then pick a KEY other than <leader>e,
-- which oil owns again (lua/plugins/oil.lua).
local ENABLED = false

-- The key this browser claims when ENABLED. Held by oil.nvim while retired.
local KEY = "<leader>e"

-- Matches the telescope browser's dropdown exactly, so the two are comparable.
local POPUP_WIDTH = 90
local POPUP_HEIGHT = 25

--- Same directory, ignoring a trailing slash and symlinks.
local function same_path(a, b)
  if not a or not b then
    return false
  end
  local function clean(path)
    return (vim.fs.normalize(path):gsub("/+$", ""))
  end
  return clean(a) == clean(b)
end

--- Current directory, shown in the input's border title.
---
--- snacks has no `{cwd}` title placeholder — `update_titles` only knows
--- `{source}`, `{title}`, `{live}` and `{preview}` (picker.lua:385). `picker.title`
--- is what `{title}` renders, and it is writable, so the location goes there and
--- is re-rendered on every navigation. This is the equivalent of telescope's
--- `prompt_path`.
local function location(cwd)
  local function clean(path)
    return (vim.fs.normalize(path):gsub("/+$", ""))
  end
  local root, dir = clean(vim.fn.getcwd()), clean(cwd)
  if dir == root then
    return "./"
  end
  if dir:sub(1, #root + 1) == root .. "/" then
    return "./" .. dir:sub(#root + 2) .. "/"
  end
  -- Outside the project: an absolute path is the only honest label. `:~` keeps
  -- it short without pretending it is relative.
  return vim.fn.fnamemodify(dir, ":~") .. "/"
end

--- Put the current path in the PROMPT, the way telescope does it.
---
--- telescope-file-browser sets the path as `prompt_prefix`
--- (file_browser/picker.lua:189, refreshed with `new_prefix` on every
--- navigation) and keeps a static "File Browser" on the prompt border
--- (utils.lua:115). Same split here: snacks renders `opts.prompt` into the
--- input's statuscolumn (picker/core/input.lua:139), so the path lives there and
--- the border title stays constant.
local function set_location(picker)
  -- The colour is injected rather than configured. snacks renders `opts.prompt`
  -- into the statuscolumn hardcoded as `SnacksPickerPrompt`
  -- (picker/core/input.lua:139), which is the orange prompt icon shared by every
  -- picker — recolouring that group would repaint all of them. A statuscolumn
  -- string may carry its own `%#Group#`, so the path brings its highlight with it
  -- and nothing global changes. telescope links its prompt prefix to `Identifier`
  -- (plugin/telescope.lua:46), which is the blue in the screenshots.
  --
  -- `%` is doubled: it is a statusline format character, and a directory is
  -- allowed to have one in its name.
  local path = location(picker:cwd()):gsub("%%", "%%%%")
  picker.opts.prompt = "%#SnacksPickerFileBrowserPath#" .. path .. "%*"
  picker.input:update()
end

--- Re-root the listing on `dir`: the one navigation primitive of this mode.
---
--- `Tree:close_all` is the part that is easy to miss. The explorer keeps a tree
--- of visited nodes, and `set_cwd` alone does not collapse it — walking into
--- `after/` and back OUT left `after/queries` sitting in the root listing, which
--- is exactly the file-tree behaviour this mode exists to avoid.
---
--- So it collapses on the way up only. Going down keeps whatever is expanded,
--- because expanding a folder in place (mouse double-click, or <Tab>) is worth
--- having here: you can peek inside without losing your position.
---@param collapse? boolean collapse visited nodes first (only needed going up)
local function reroot(picker, dir, collapse)
  picker:set_cwd(dir)
  if collapse then
    require("snacks.explorer.tree"):close_all(dir)
  end
  -- telescope refreshes with `reset_prompt = true` on every navigation
  -- (file_browser/actions.lua:650), so the query never carries into the new
  -- directory. Without this, walking into a folder keeps filtering by whatever
  -- you typed to get there and the listing looks half-empty.
  picker.input:set("")
  set_location(picker)
  picker:find()
end

--- `l` / <CR>: enter the directory, or open the file and close.
---
--- snacks' own `confirm` cannot be reused for directories: it calls
--- `Tree:toggle()` (explorer/actions.lua:317), which expands a node in place.
--- That is the file-TREE behaviour this mode exists to replace, so directories
--- re-root the picker instead.
local function enter(picker, item, action)
  item = item or picker:current()
  if not item then
    return
  end
  if item.dir then
    reroot(picker, item.file)
    return
  end

  -- Opening a FILE has to leave the prompt first.
  --
  -- snacks' `jump()` defers itself while in insert mode: `stopinsert` then
  -- reschedule (picker/actions.lua:36-45). That never resolves here, because the
  -- input window re-enters insert whenever it has focus (BufEnter ->
  -- `startinsert!`, picker/core/input.lua:54) — so the mode is insert again by the
  -- time the deferred call runs, and it defers again, forever. The file never
  -- opened, the browser stayed up, and the loop kept spinning in the background.
  --
  -- Moving the focus to the list first breaks that cycle: nothing there restarts
  -- insert, so the scheduled jump runs in normal mode and closes the picker the
  -- way it does from the list.
  local Snacks = require("snacks")
  if vim.fn.mode():sub(1, 1) ~= "i" then
    Snacks.picker.actions.jump(picker, item, action)
    return
  end

  -- From insert mode, do it by hand instead of calling `jump`.
  --
  -- `jump()` refuses to run in insert mode: it calls `stopinsert` and reschedules
  -- itself (picker/actions.lua:36-45). In this picker the mode is insert again by
  -- the time the deferred call lands — the prompt restarts it on focus — so it
  -- reschedules forever. Measured: 143868 calls and climbing, the file never
  -- opening, the browser never closing. Leaving the prompt first did not help,
  -- the insert flag survived that too.
  --
  -- Closing first and editing on the next tick is deterministic and is exactly
  -- what telescope's select_default did: the picker goes away, focus lands back in
  -- the window it was opened from, and the file opens there.
  --
  -- The two things `jump()` does that a bare `:edit` would drop are kept: it opens
  -- the whole SELECTION when rows are marked (`picker:selected` with a fallback to
  -- the row under the cursor), and it leaves a jumplist mark first so `<C-o>` gets
  -- you back (picker/actions.lua:73-78). The items are captured before closing,
  -- since the picker is gone by the time the edit runs.
  local paths = {} ---@type string[]
  for _, selected in ipairs(picker:selected({ fallback = true })) do
    -- Directories are skipped: `:edit` on one hands you oil (it owns netrw), which
    -- is not what selecting files is meant to do. A marked directory is entered
    -- with `l`, one at a time.
    if selected.file and not selected.dir then
      paths[#paths + 1] = selected.file
    end
  end
  if #paths == 0 then
    paths = { item.file }
  end

  vim.cmd("stopinsert")
  picker:close()
  vim.schedule(function()
    vim.cmd("normal! m'")
    for _, path in ipairs(paths) do
      vim.cmd.edit(vim.fn.fnameescape(path))
    end
  end)
end

--- `h` / `-`: up one directory.
local function up(picker)
  reroot(picker, vim.fs.dirname(picker:cwd()), true)
end

--- Scroll the LIST by `delta` rows, the way <C-e> / <C-y> scroll a buffer.
---
--- Native <C-e> / <C-y> do nothing in here, which is why this exists. The list
--- is virtually scrolled: its buffer only ever holds the rows currently on
--- screen, and `list.top` is what maps a row back to an item
--- (picker/core/list.lua:189-203). There is no text below the last line for
--- Neovim to scroll to, so the keys were not being swallowed by a mapping —
--- they had nothing to move. The global normal-mode <C-e> / <C-y> already skip
--- snacks pickers on purpose and fall through to native (config/keymaps.lua:352),
--- so this window has to answer for itself.
---
--- `list:scroll()` moves `top` instead, and is the same call snacks' own mouse
--- wheel makes in this window (list.lua:55). The selection comes along only when
--- it would otherwise leave the view (list.lua:251) — what <C-e> / <C-y> do in a
--- file window too. At either end of the listing there is nothing left to scroll,
--- so snacks steps the selection by `delta` instead (list.lua:247-249); the wheel
--- has always behaved that way here, so the keys match it rather than inventing a
--- second rule.
local function scroll(picker, delta)
  -- Honour a count (`5<C-e>`) like the native keys, but only from normal mode:
  -- `v:count1` keeps the LAST normal-mode count while in insert, so reading it in
  -- the prompt scrolls by a number nobody typed. Same guard snacks puts on
  -- list_down / list_up (picker/actions.lua:29-33).
  local count = vim.fn.mode():sub(1, 1) == "i" and 1 or vim.v.count1
  picker.list:scroll(delta * count)
end

--- Type the key literally, bypassing this mapping.
---
--- "tn" is what telescope-file-browser uses for the same fall-through
--- (file_browser/actions.lua:841): `t` so it behaves like typed input, `n` so the
--- mapping cannot fire again and recurse.
local function passthrough(key)
  vim.api.nvim_feedkeys(vim.keycode(key), "tn", false)
end

--- Backspace in insert mode: go to the parent when the query is empty.
---
--- Copies fb_actions.backspace. It is what makes the prompt feel like a path
--- editor — you delete your way back up the tree instead of reaching for `h`.
local function backspace(picker)
  if picker.input:get() == "" then
    up(picker)
  else
    passthrough("<BS>")
  end
end

--- `/` in insert mode: enter the typed directory.
---
--- Copies fb_actions.path_separator. Typing `lua/plugins/oil` walks two
--- directories and leaves `oil` filtering the listing, so a whole path can be
--- typed in one go — the query is cleared at each separator because the listing
--- underneath has been re-rooted. Anything that is not a real directory falls
--- through as a literal `/`, which keeps searching for names containing a slash
--- possible.
local function path_separator(picker)
  local query = picker.input:get()
  local target = picker:cwd() .. "/" .. query
  if query ~= "" and vim.fn.isdirectory(target) == 1 then
    picker.input:set("")
    reroot(picker, target)
  else
    passthrough("/")
  end
end

-- Permissions / size / date, shown by default and toggled with STAT_KEY, the
-- same block telescope drew with `display_stat`.
local STAT_KEY = "gs"
local show_stat = true

-- Byte size the way telescope prints it: one decimal below 10, none above, so
-- `3.8K` and `35K` line up in six columns.
local function human_size(bytes)
  -- Bytes carry NO unit, matching telescope (fs_stat.lua's SIZE_TYPES starts
  -- with an empty string), so a directory reads `96` and not `96B`.
  local units = { "", "K", "M", "G", "T" }
  local n, unit = bytes, 1
  while n >= 1024 and unit < #units do
    n, unit = n / 1024, unit + 1
  end
  if unit == 1 then
    return ("%d%s"):format(n, units[unit])
  end
  return (n < 10 and "%.1f%s" or "%.0f%s"):format(n, units[unit])
end

-- Per-character colours for the mode column, copied from telescope's own map
-- (fs_stat.lua `color_hash` + the links in telescope's plugin/telescope.lua):
-- `-` is NonText, `d` a directory blue, `r`/`x` teal, `w` a statement colour.
-- That is why the permissions read mostly white-grey with the odd accent instead
-- of one flat colour.
local MODE_HL = {
  ["-"] = "NonText",
  d = "Directory",
  l = "Special",
  s = "Statement",
  r = "Constant",
  w = "Statement",
  x = "String",
}

-- `-rw-r--r--`, from the mode bits. `bit` is LuaJIT's, always present in Neovim.
local function mode_string(stat)
  local kind = stat.type == "directory" and "d" or (stat.type == "link" and "l" or "-")
  local flags = { 0x100, 0x80, 0x40, 0x20, 0x10, 0x8, 0x4, 0x2, 0x1 }
  local chars = { "r", "w", "x", "r", "w", "x", "r", "w", "x" }
  local perms = {}
  for i, flag in ipairs(flags) do
    perms[i] = bit.band(stat.mode, flag) ~= 0 and chars[i] or "-"
  end
  return kind .. table.concat(perms)
end

--- Row rendering: the file formatter plus a right-aligned stat block.
---
--- Cheaper than the telescope version by construction. file_browser ran
--- `fs_stat` for EVERY entry while building the finder, which is what made large
--- directories cost; snacks calls `format` only for rows that are actually on
--- screen, and the result is cached on the item, so a directory of 5000 files
--- still costs about 25 stats.
---
--- Right alignment is snacks' own idiom for this: a `col = 0` segment with
--- `virt_text_pos = "right_align"` (see picker/format.lua:19 for the diagnostic
--- severity column doing the same thing).
--- Rows carry NO selection caret.
---
--- telescope drew `> ` in a reserved gutter because its results window never has
--- the cursor. Here the list is a real window, so the block cursor already sits on
--- the current row — a caret next to it read as two indicators for one thing. The
--- cursor is the indicator; `CursorLine` still bands the row.
local function format(item, picker)
  local Snacks = require("snacks")

  -- Directory names in blue, INCLUDING dotfiles. `format.filename` picks
  -- `SnacksPickerDirectory` for a directory but overrides it with
  -- `SnacksPickerPathHidden` for anything starting with a dot (format.lua:80-86),
  -- which is why `.claude/` came out dimmer than `after/`. `item.filename_hl` is
  -- the documented override and it beats that hidden branch.
  if item.dir then
    item.filename_hl = "Directory"
  end

  local ret = Snacks.picker.format.file(item, picker)

  -- One-cell gutter at the start of every row.
  --
  -- The cursor sits at column 0, so without a gutter it pressed right up against
  -- the folder icon. telescope reserved two cells here for its `> ` caret, but
  -- there is no caret — the block cursor is the indicator — and two cells left a
  -- visibly wide gap, so one is enough: the cursor occupies it and the icon starts
  -- immediately after. snacks' own selection marks (the ○ / ● for multi-select)
  -- also render in this column.
  table.insert(ret, 1, { " " })

  -- Trim one level of indentation.
  --
  -- `format.file` prefixes explorer items with a `SnacksPickerTree` segment
  -- whenever `item.parent` is set, and the browsed directory itself counts as a
  -- parent — so every row in a plain listing carried one indent unit and the
  -- whole list sat two cells to the right of telescope's. Dropping exactly one
  -- level puts a plain listing flush left while children of an expanded folder
  -- keep theirs. The glyphs are blank (see `icons.tree`), so this is only spaces.
  if ret[2] and ret[2][2] == "SnacksPickerTree" then
    local indent = ret[2][1]:sub(3)
    if indent == "" then
      table.remove(ret, 2)
    else
      ret[2] = { indent, "SnacksPickerTree" }
    end
  end

  -- Telescope's folder glyph, one for every directory
  -- (make_entry.lua:140 `opts.dir_icon or ""`), replacing mini.icons' per-folder
  -- coloured set. The segment stays `virtual = true` so the icon is decoration
  -- and never part of the text the matcher sees.
  --
  -- White glyph, blue name: telescope sets `dir_icon_hl` to "Default", a group
  -- that does not exist, so its folder glyph falls back to the results window's
  -- normal foreground while the name stays a directory colour.
  -- The icon is located by its `virtual` flag, not by position: a nested row
  -- carries an indent segment first, so `ret[1]` is only the icon on a top-level
  -- row. Checking position alone left the children of an expanded folder with
  -- mini.icons' coloured glyph while their parent had telescope's white one.
  local icon_idx
  for i, seg in ipairs(ret) do
    if seg.virtual then
      icon_idx = i
      break
    end
  end
  if item.dir and icon_idx then
    ret[icon_idx] = { " ", "SnacksPickerFileBrowserDirIcon", virtual = true }
  end

  -- Trailing separator on directories, like telescope
  -- (make_entry.lua:135 appends `os_sep`). It goes BEFORE the formatter's final
  -- padding segment, not after it, or the row reads `.agents /`. The name itself
  -- is a lazily-resolved segment, so it cannot be edited in place.
  if item.dir then
    table.insert(ret, #ret, { "/", "Directory" })
  end

  if not show_stat then
    return ret
  end
  if item._fb_stat == nil then
    item._fb_stat = vim.uv.fs_stat(item.file) or false
  end
  local stat = item._fb_stat
  if not stat then
    return ret
  end
  -- Three segments so each column can be coloured on its own. telescope paints
  -- the mode per character (fs_stat.lua maps d/r/w/x/- to TelescopePreview*) and
  -- the size and date with TelescopePreviewSize/Date; those groups exist only
  -- while telescope is installed, so all three link to the theme's own
  -- `Constant` (#29a298) here, which is the teal the screenshots show.
  local align = require("snacks").picker.util.align
  local virt = {}
  for char in mode_string(stat):gmatch(".") do
    virt[#virt + 1] = { char, MODE_HL[char] or "NonText" }
  end
  virt[#virt + 1] = { "  " }
  virt[#virt + 1] = { align(human_size(stat.size), 6, { align = "right" }), "SnacksPickerFileBrowserSize" }
  virt[#virt + 1] = { "  " }
  virt[#virt + 1] = { os.date("%b %d %H:%M", stat.mtime.sec), "SnacksPickerFileBrowserDate" }
  virt[#virt + 1] = { " " }
  ret[#ret + 1] = { col = 0, virt_text = virt, virt_text_pos = "right_align", hl_mode = "combine" }
  return ret
end

--- STAT_KEY: flip the columns. `format` reads the flag, so a re-render is all it
--- takes — no reopening, unlike telescope where `display_stat` was baked into the
--- entry maker and the picker had to be rebuilt.
local function toggle_stat(picker)
  show_stat = not show_stat
  picker.list:update({ force = true })
end

--- Put the cursor on the file you were editing, telescope's `select_buffer`.
---
--- Not `follow_file`: that one re-roots the listing to wherever the file lives
--- and makes it the selection, which broke `l`. This only moves the cursor, and
--- only when the file happens to be in the directory already being shown.
local function select_current_file(picker)
  local file = vim.api.nvim_buf_get_name(vim.fn.bufnr("#") ~= -1 and vim.fn.bufnr("#") or 0)
  if file == "" then
    return
  end
  for idx, item in ipairs(picker:items()) do
    if item.file == file then
      picker.list:view(idx)
      return
    end
  end
end

--- Layout: the dropdown, or edge-to-edge for the startup open.
---
--- Absolute numbers are intentional and supported — snacks treats width/height
--- below 1 as a fraction of the editor and 1 or more as columns/rows, so the
--- popup is byte-for-byte the telescope browser's 90x25. `width = 0` /
--- `height = 0` is snacks' own idiom for "fill" (the sidebar preset uses
--- `height = 0` for full height).
local function layout(fullscreen)
  return {
    preset = "default",
    preview = false,
    layout = {
      box = "vertical",
      width = fullscreen and 0 or POPUP_WIDTH,
      height = fullscreen and 0 or POPUP_HEIGHT,
      -- Same frame in both modes. Fullscreen used `border = "none"`, which also
      -- removed the title (a title needs a border to sit on) and left the input
      -- row floating against the top edge with no separator — the startup
      -- explorer looked nothing like the popup. A rounded border at the screen
      -- edge costs one cell per side and keeps them identical.
      border = "rounded",
      -- The title has to sit on the OUTER box, not on the input. The input's
      -- border is `bottom` only — a separator line, matching the dropdown — and a
      -- bottom border has nowhere to draw a title, which is why "File Browser"
      -- was missing from the frame while telescope showed it.
      title = " Explorer ", -- File Browser
      title_pos = "center",
      { win = "input", height = 1, border = "bottom" },
      { win = "list", border = "none" },
    },
  }
end

--- Directory to open in, derived from the current buffer.
---
--- `%:p:h` is not safe alone: for a scheme buffer it returns the URL verbatim
--- (`oil:///path`, `term://…`, `fugitive://…`). Strip a leading scheme, then fall
--- back to the cwd for anything that is still not a real directory.
local function resolve_dir()
  local dir = vim.fn.expand("%:p:h")
  if type(dir) == "string" then
    dir = (dir:gsub("^%w[%w+.-]*://", ""))
    if vim.fn.isdirectory(dir) == 1 then
      return dir
    end
  end
  return vim.fn.getcwd()
end

--- The listing finder, with snacks' recursive search switched off.
---
--- The explorer's finder branches on the query: `M.explorer` calls
--- `state:setup(ctx)`, which is nothing but `not ctx.filter:is_empty()`, and on a
--- non-empty query it hands over to `M.search` — an `fd` run over the whole tree
--- below the cwd (source/explorer.lua:195 and :268). Typing `lua` at the repo
--- root therefore returned 166 matches from every directory, where the telescope
--- browser filtered the 4 entries in front of you. That is right for a tree
--- explorer and wrong here, and it is not an option — it is hard-coded.
---
--- So the context is shimmed: the finder sees a filter that always reports empty,
--- takes the listing branch, and the picker's matcher then narrows THAT listing.
--- Only `is_empty` is faked; `cwd` and everything else pass through, and the
--- listing branch reads nothing else from the filter.
local function flat_finder(opts, ctx)
  local filter = setmetatable({
    is_empty = function()
      return true
    end,
  }, { __index = ctx.filter })
  local shim = setmetatable({ filter = filter }, { __index = ctx })
  return require("snacks.picker.source.explorer").explorer(opts, shim)
end

--- Open the explorer in file-explorer mode.
---@param opts? { fullscreen?: boolean, cwd?: string }
local function open(opts)
  opts = opts or {}
  -- Keys reference ACTIONS BY NAME, never a raw function. A function in a
  -- `win.*.keys` table is a Snacks.win handler and is called with the WINDOW;
  -- only registered actions get `(picker, item, action)`. Passing `enter`
  -- directly failed with "attempt to call method 'current' (a nil value)".
  -- Keys are built PER WINDOW, not shared.
  --
  -- Sharing one table cost two bugs. `<C-h>` collided with the tree sidebar's
  -- own focus-left-window binding (explorer_window_keys in snacks.lua) and that
  -- one won, throwing the focus out of the picker mid-navigation. And a single
  -- `/` mapping had to branch on `vim.fn.mode()`, which races with the
  -- `startinsert!` that focusing the input performs — the window a key arrives
  -- in is knowable, the mode at that instant is not.
  --
  -- Navigation lives in both windows so `h` / `l` work wherever you are, the way
  -- they did in telescope's single prompt buffer. `<C-h>` / `<C-l>` are bound
  -- nowhere: the telescope config killed both on purpose, and the sidebar wants
  -- them.
  local nav = {
    ["l"] = { "fb_enter", mode = { "n" }, desc = "Enter directory / open file" },
    ["="] = { "fb_enter", mode = { "n" }, desc = "Enter directory / open file" },
    ["h"] = { "fb_up", mode = { "n" }, desc = "Parent directory" },
    ["-"] = { "fb_up", mode = { "n" }, desc = "Parent directory" },
    ["q"] = { "close", mode = { "n" }, desc = "Close" },
    -- Same fine viewport nudge they are in a file window
    -- (config/keymaps.lua:363-368), for a listing taller than the popup. Insert
    -- mode is included because in the prompt the native meaning (insert the
    -- character below / above the cursor) has nothing to act on, while scrolling
    -- the rows you are filtering does.
    ["<C-e>"] = { "fb_scroll_down", mode = { "n", "i" }, desc = "Scroll list down" },
    ["<C-y>"] = { "fb_scroll_up", mode = { "n", "i" }, desc = "Scroll list up" },
    ["<C-f>"] = { "close", mode = { "n", "i" }, desc = "Close" },
    -- oil binds `q` to close and makes <Esc> clear search highlights WITHOUT
    -- closing; the telescope browser mirrored that, so this does too. snacks'
    -- default <Esc> closes the picker, which is the disagreement.
    ["<Esc>"] = { "fb_nohlsearch", mode = { "n" }, desc = "Clear search highlight" },
    -- Parity with the telescope browser's own extras.
    [STAT_KEY] = { "fb_toggle_stat", mode = { "n" }, desc = "Toggle permissions/size/date" },
    ["H"] = { "toggle_hidden", mode = { "n" }, desc = "Toggle hidden files" },
    ["N"] = { "explorer_add", mode = { "n" }, desc = "Create file/directory" },
    -- Expand a folder in place instead of entering it — the keyboard twin of the
    -- double-click that snacks.lua already binds (explorer_open_keep_focus ->
    -- confirm -> Tree:toggle). `l` re-roots, this peeks.
    --
    -- On `s`, which nothing else claims: snacks binds no `s` in a picker list, and
    -- <Tab> / <S-Tab> have to stay on `select_and_next` / `select_and_prev`
    -- because explorer_move / explorer_copy / explorer_del all act on
    -- `picker:selected()` — taking <Tab> for expansion made those look broken.
    -- Keeping off <C-s> also leaves snacks' `edit_split` alone.
    ["s"] = { "confirm", mode = { "n" }, desc = "Expand / collapse in place" },
    -- Clear every mark at once. snacks' `<C-a>` is select_all, which only clears
    -- when ALL rows are already selected (list.lua:429) — with 7 of 28 marked it
    -- selects the other 21 first, so clearing meant two presses or one <Tab> per
    -- row. This takes snacks' `edit_split` off <C-s>; <C-v> still opens a
    -- vertical split.
    ["<C-s>"] = { "fb_clear_selection", mode = { "n", "i" }, desc = "Clear all marks" },
    -- Explicitly OFF. snacks.lua binds these four to focus-left/down/up/right
    -- for the whole `explorer` source (explorer_window_keys), which is right for
    -- a sidebar sitting next to your code and wrong for a centred dropdown —
    -- pressing one threw the focus into a file window and left the popup
    -- orphaned. `false` disables a key without binding anything, the same way
    -- the sidebar disables `/` and `?`.
    ["<C-h>"] = { "fb_up", mode = { "n" }, desc = "Parent directory" },
    ["<C-l>"] = { "fb_enter", mode = { "n" }, desc = "Enter directory / open file" },
    ["<C-j>"] = false,
    ["<C-k>"] = false,
  }

  local list_keys = vim.tbl_extend("force", nav, {
    -- telescope's `/` ran `startinsert`; here it hands over to the prompt.
    ["/"] = { "focus_input", mode = { "n" }, desc = "Filter" },
    ["<CR>"] = { "fb_enter", mode = { "n" }, desc = "Enter directory / open file" },
  })

  local input_keys = vim.tbl_extend("force", nav, {
    -- The prompt as a path editor, both copied from telescope-file-browser
    -- (config.lua:29-30 binds exactly these two, insert mode): <BS> on an empty
    -- query walks up, `/` enters the typed directory.
    ["<BS>"] = { "fb_backspace", mode = { "i" }, desc = "Delete, or parent when empty" },
    ["/"] = { "fb_path_separator", mode = { "i" }, desc = "Enter the typed directory" },
    ["<CR>"] = { "fb_enter", mode = { "n", "i" }, desc = "Enter directory / open file" },
    -- Move the highlight without leaving the prompt. snacks binds these to
    -- list_down/list_up in both modes (config/defaults.lua:251); `nav` above
    -- disables them because snacks.lua rebinds them to window focus for the
    -- explorer source — but only in NORMAL mode, so insert can keep the
    -- defaults. Without this, <C-j> while typing did nothing at all.
    ["<C-j>"] = { "list_down", mode = { "i" }, desc = "Next entry" },
    ["<C-k>"] = { "list_up", mode = { "i" }, desc = "Previous entry" },
    -- Also insert-mode only, and also lost to the `nav` blanket: `<C-l>` is what
    -- the telescope browser bound to select in insert, and what snacks.lua binds
    -- to confirm in every other picker, so it must keep working here. `<C-h>` is
    -- the matching way back up. Both stay dead in normal mode, where h / l / -
    -- do the job and the sidebar wants the chords.
    ["<C-l>"] = { "fb_enter", mode = { "i" }, desc = "Enter directory / open file" },
    ["<C-h>"] = { "fb_up", mode = { "i" }, desc = "Parent directory" },
    -- <Esc> hands the cursor to the LIST instead of parking it in the prompt.
    --
    -- telescope had one window, so <Esc> put you in normal mode where the
    -- selection keys already were. snacks splits input and list, so leaving
    -- insert used to leave the cursor in the prompt in normal mode — where bulk
    -- select, visual mode and the file operations simply do not exist, and the
    -- only way back to the rows was clicking one.
    ["<Esc>"] = { "fb_leave_prompt", mode = { "i", "n" }, desc = "Back to the list" },
  })

  local picker = require("snacks").explorer.open({
    finder = flat_finder,
    -- Open on the directory of the file you are editing, the way the telescope
    -- browser did, so <leader>e is "show me where I am" and not "show me the
    -- project root".
    cwd = opts.cwd or resolve_dir(),
    -- `tree = true`, despite this being a flat browser.
    --
    -- The option does two things at once (picker/source/explorer.lua:176,322):
    -- it drives the indentation AND sets `formatters.file.filename_only`. With
    -- `false`, expanding a folder listed its children as paths relative to the
    -- cwd — `lua/colorschemes/`, `lua/config/` — flush left instead of indented
    -- basenames under the parent. Since expanding in place is worth keeping
    -- (double-click, <Tab>), the option stays on and the GUIDE GLYPHS are blanked
    -- instead, below: indentation without any lines drawn.
    tree = true,
    icons = { tree = { vertical = "  ", middle = "  ", last = "  " } },
    -- Land on the list in normal mode, the way the browser opened. Typing still
    -- filters after <Tab>/`i` into the input.
    focus = "list",
    -- Rank by match score, like telescope.
    --
    -- The explorer source replaces snacks' default sort with
    -- `{ fields = { "sort" } }` (config/sources.lua:52) so a tree keeps its
    -- structural order. But `item.sort` is only ever built in the RECURSIVE
    -- SEARCH branch (source/explorer.lua:288-311) — in a plain listing the field
    -- does not exist, so nothing was ranked and `nvim` searched next to
    -- `avante.nvim` came out in directory order instead of best-match-first.
    --
    -- This is snacks' own default restored: score descending, then `idx`. With no
    -- query every item carries the same default score, so `idx` decides and the
    -- listing keeps the Tree's order — directories first, then alphabetical,
    -- which is what telescope's `grouped = true` gave.
    sort = { fields = { { name = "score", desc = true }, "idx" } },
    -- Fuzzy, like telescope's sorter. The explorer source ships
    -- `fuzzy = false` (substring only), which is right for a tree you scan by eye
    -- but wrong for a prompt you type paths into.
    matcher = { fuzzy = true, sort_empty = false },
    -- Same listing rules the telescope browser ran with: dotfiles and
    -- gitignored paths visible (`hidden`/`respect_gitignore = false` there), and
    -- git status OFF — it cost ~75ms of the ~124ms per directory change, the
    -- single largest component, and this mode changes directory constantly.
    hidden = true,
    ignored = true,
    git_status = false,
    -- OFF for this mode. `follow_file` makes the selected row the file you are
    -- editing rather than the first entry of the listing, so `l` acted on that
    -- file and opened it instead of entering the highlighted directory. The
    -- sidebar mode keeps it on, which is where following actually helps.
    follow_file = false,
    -- ON, unlike the explorer source's default (config/sources.lua:63).
    --
    -- `auto_close` does NOT mean "close whenever focus leaves". snacks' handler
    -- returns early for any float (picker/core/picker.lua:288-291, via
    -- `Snacks.util.is_float()`), so another picker opening on top of the browser
    -- never closes it — which is the property this mode was built for and the
    -- reason `false` was set here at first. What `false` additionally suppresses
    -- is the close when focus lands in a NORMAL window, and that case is the
    -- whole point: opening a file from a picker stacked on the browser (e.g.
    -- <leader><leader>, confirm) left the popup floating over the file with the
    -- cursor already editing underneath it. `true` closes it there and nowhere
    -- else.
    --
    -- Nothing else changes. The other half of the `false` branch only toggles a
    -- main-window preview off (picker/core/picker.lua:300-306), and this mode
    -- runs `preview = false`. Closing is snacks' own scheduled `picker:close()`,
    -- which unregisters from `_active` so <leader>e keeps toggling correctly, and
    -- it does not touch the focus unless the current window is a picker window.
    auto_close = true,
    -- Opening a file ends the browse, matching telescope's select_default. The
    -- sidebar mode keeps `close = false` because it stays open beside your work.
    jump = { close = true },
    layout = layout(opts.fullscreen),
    win = {
      input = { keys = input_keys },
      list = { keys = list_keys },
    },
    actions = {
      fb_enter = enter,
      fb_up = up,
      fb_backspace = backspace,
      fb_path_separator = path_separator,
      fb_toggle_stat = toggle_stat,
      fb_scroll_down = function(picker)
        scroll(picker, 1)
      end,
      fb_scroll_up = function(picker)
        scroll(picker, -1)
      end,
      -- `stopinsert` then focus on the NEXT tick, in that order.
      --
      -- Both halves are needed. `focus()` only moves the window, it does not
      -- change mode. And `stopinsert` inside an insert-mode mapping does not take
      -- effect until the mapping returns, so focusing in the same tick moved the
      -- window while Neovim was still in insert — and snacks' input window runs
      -- `startinsert!` from a BufEnter handler (picker/core/input.lua:54), which
      -- put the cursor straight back in the prompt. That is the "first <Esc> does
      -- nothing, second one works" behaviour: the second press was already in
      -- normal mode, so nothing fought it.
      fb_leave_prompt = function(picker)
        vim.cmd("stopinsert")
        vim.schedule(function()
          if not picker.closed then
            require("snacks").picker.actions.focus_list(picker)
          end
        end)
      end,
      fb_clear_selection = function(picker)
        picker.list:set_selected({})
        picker.list:update({ force = true })
      end,
      fb_nohlsearch = function()
        if vim.v.hlsearch == 1 then
          vim.cmd("nohlsearch")
        end
      end,
    },
    format = format,
    -- The flat listing includes the browsed directory itself as its first row.
    -- Harmless (entering it is a no-op) but it reads as a stray row, so drop it.
    -- `transform` gets (item, ctx) and dropping is `return false`
    -- (picker/core/finder.lua:130).
    transform = function(item, ctx)
      if item.dir and same_path(item.file, ctx.picker:cwd()) then
        return false
      end
      -- Match on the NAME, not the path. snacks matches `item.text`, which the
      -- explorer sets to the item's absolute path, so any query that happens to
      -- appear in a parent directory matched every row — in `~/.config/nvim`,
      -- searching `config` or `nvim` returned the whole listing. telescope
      -- matched `entry.ordinal`, the tail, and the tree display shows basenames
      -- anyway, so this makes what you type line up with what you see.
      item.text = vim.fs.basename(item.file)
      return item
    end,
    on_show = function(picker)
      set_location(picker)
      select_current_file(picker)
    end,
  })

  -- `Snacks.explorer.open()` TOGGLES: called while an explorer is already open it
  -- closes that one and returns nil. So <leader>e is a toggle, and everything
  -- below has to be guarded — indexing the nil return is what threw
  -- "attempt to index local 'picker' (a nil value)" on the second press.
  if not picker then
    return
  end

  -- In this mode "the directory" is always the one in the prompt.
  --
  -- `Picker:dir()` returns the directory of the row under the CURSOR
  -- (picker/core/picker.lua:594), which is right for a tree and wrong here:
  -- standing on `.claude/` in a listing of `./` and pressing `a` created the new
  -- folder inside `.claude/`. telescope always created in the browsed directory
  -- (`finder.path`), and so does this now.
  --
  -- Shadowing the method on the instance fixes every action that targets a
  -- directory in one place — add, move, copy and paste all call `picker:dir()`
  -- (explorer/actions.lua:207, 245, 269, 186).
  picker.dir = function(self)
    return self:cwd()
  end

  return picker
end

return {
  {
    "folke/snacks.nvim",
    -- Deliberately NO `enabled = ENABLED` here. lazy.nvim chains every fragment
    -- of the same plugin through `__index` (core/meta.lua), so the last fragment
    -- that sets `enabled` wins for the WHOLE plugin — and `plugins.snacks-file-
    -- browser` sorts after `plugins.snacks`. `enabled = false` in this file would
    -- therefore switch off snacks.nvim itself, taking LazyVim's pickers, explorer,
    -- notifier and dashboard with it. Gate the keymap and the init hook instead.
    --
    -- No `opts` block on purpose: everything is per-call, so the tree sidebar in
    -- snacks.lua and every other picker are untouched by this file.
    keys = ENABLED and {
      {
        KEY,
        function()
          open()
        end,
        desc = "File Explorer (snacks, browser mode)",
      },
    } or {},
    -- Startup explorer: `nvim <dir>` opens this fullscreen.
    --
    -- oil.nvim keeps netrw (`default_file_explorer = true`), so `:e <dir>`
    -- mid-session still opens oil — unchanged on purpose. Only the startup case
    -- is claimed here, which is why snacks' own `replace_netrw` is NOT used: it
    -- hooks every directory buffer and would take `:e <dir>` as well.
    --
    -- WARN: SILENT FAILURE. lazy.nvim keeps only the LAST fragment's `init` per
    -- plugin, ordered by module name. Defining one here kills snacks.lua's
    -- entirely, with no error -- highlight groups simply never get set.
    -- `init` COLLIDES with lua/plugins/snacks.lua, which also defines one for
    -- snacks.nvim. lazy.nvim chains the fragments of a plugin through `__index`,
    -- so only the LAST fragment's `init` runs -- and `plugins.snacks-file-browser`
    -- sorts after `plugins.snacks`. While this key existed, snacks.lua's `init`
    -- never ran at all: no `SnacksPickerMatch`, the indent guides stayed on the
    -- theme's near-invisible colour, and `SnacksExplorerActiveFile` was undefined,
    -- so the explorer's active-file band silently did nothing.
    --
    -- Hence `ENABLED and ... or nil`: while retired this key is ABSENT, not empty,
    -- which is what lets the lookup fall through to snacks.lua's. An `init` that
    -- merely returns early is NOT good enough -- it still wins the lookup.
    --
    -- If this browser is ever revived, do not just flip ENABLED: move the body
    -- below into snacks.lua's `set_snacks_hl` / `init` instead, or the same
    -- silent breakage comes back.
    init = ENABLED and function()
      -- Dim by default, and `default = true` so the colorscheme wins if it ever
      -- defines this group.
      local function set_hl()
        local hl = {
          -- Telescope's own links: TelescopePreviewSize -> String,
          -- TelescopePreviewDate -> Directory (plugin/telescope.lua:63,66). So the
          -- size is teal and the date is blue, and the mode is coloured per
          -- character by MODE_HL rather than by a group of its own. `Comment` was
          -- tried for the mode and was wrong twice over: too dim, and italic in
          -- this theme, so the permissions leaned while the numbers stood upright.
          SnacksPickerFileBrowserSize = "String",
          SnacksPickerFileBrowserDate = "Directory",
          -- telescope's TelescopePromptPrefix links here too.
          SnacksPickerFileBrowserPath = "Identifier",
          -- The folder glyph only, so it reads white next to the blue name.
          SnacksPickerFileBrowserDirIcon = "Normal",
        }
        for group, link in pairs(hl) do
          vim.api.nvim_set_hl(0, group, { link = link, default = true })
        end
      end
      set_hl()
      vim.api.nvim_create_autocmd("ColorScheme", { callback = set_hl })
      vim.api.nvim_create_autocmd("VimEnter", {
        once = true,
        callback = function()
          -- Only the plain `nvim <dir>` case: one argument, and it is a
          -- directory. Files, stdin and sessions are left alone.
          if vim.fn.argc() ~= 1 then
            return
          end
          local target = vim.fn.argv(0)
          if type(target) ~= "string" then
            return
          end
          -- oil has already rewritten the arglist entry to `oil:///path/` by the
          -- time VimEnter runs; without stripping the scheme the check below
          -- rejects every startup directory.
          target = (target:gsub("^oil://", ""))
          if vim.fn.isdirectory(target) ~= 1 then
            return
          end
          local dir = vim.fn.fnamemodify(target, ":p")
          vim.schedule(function()
            -- oil owns the directory buffer at this point. Left alone it sits
            -- behind the explorer, so closing the explorer would drop you into
            -- oil instead of an empty editor. Swap it for a blank buffer first.
            local dir_buf = vim.api.nvim_get_current_buf()
            if vim.bo[dir_buf].filetype == "oil" then
              local blank = vim.api.nvim_create_buf(true, false)
              vim.api.nvim_win_set_buf(0, blank)
              pcall(vim.api.nvim_buf_delete, dir_buf, { force = true })
            end
            open({ fullscreen = true, cwd = dir })
          end)
        end,
      })
    end or nil,
  },
}
