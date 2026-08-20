-- TRIAL: third file explorer, evaluated against oil.nvim and snacks.explorer.
--
-- Layout/style matches craftzdog/dotfiles-public
-- (.config/nvim/lua/plugins/editor.lua): the dropdown theme, no preview pane.
--
-- Behaviour and keymaps are this config's own, not craftzdog's:
--   * oil-mirrored close and navigation keys
--   * stat columns shown by default, toggled with STAT_KEY
--   * opens in normal mode
--   * confined to the current window, with a dim behind it
--
-- Scope is deliberately narrow so this can be deleted in one step:
--   * lazy-loaded by a single key, so startup cost is zero
--   * hijack_netrw = false — oil.nvim owns netrw, this must not fight it
--   * telescope is NOT registered as LazyVim's picker; snacks.picker stays
--     the default for every other picker keymap
--   * the two `optional` telescope specs in LazyVim's terraform extra are
--     force-disabled below (see the note on them)
--
-- Flip to `false` to park the trial without deleting the file. To remove it
-- for good: delete this file, then `NVIM_LAZY_UNLOCK=1 nvim` + `:Lazy clean`.
local ENABLED = true

-- <leader>e opens the browser. The other two explorers keep their own keys:
-- <leader>E is oil.nvim, <leader>r is snacks.explorer.
local TRIAL_KEY = "<leader>e"

-- Sizing matches craftzdog: the dropdown look, no preview pane.
--
-- The dropdown is spelled out below rather than set with `theme = "dropdown"`.
-- The theme string cannot be used here: file_browser expands it through
-- `themes.get_dropdown()` and merges the result into the PICKER opts, which
-- puts `layout_strategy` there, and telescope hard-errors on
-- "layout_strategy and get_window_options are not compatible keys"
-- (pickers.lua:232). Since get_window_options is what keeps the picker off your
-- other buffers, the theme's parts are applied individually instead:
-- layout_strategy goes in `defaults` (where it is not part of the picker opts),
-- and the rest — width, borders, results_title — are set explicitly.

-- Bounds used only when DYNAMIC_SIZE is on: height follows the number of
-- entries.
local MIN_HEIGHT = 25
local MAX_HEIGHT = 40

-- The layout `height` covers the WHOLE popup, and it spends some of that on the
-- prompt row plus borders/padding before the result rows get any
-- (layout_strategies.lua: `results.height = height - prompt.height - h_space`).
-- This is that overhead, so MIN/MAX above read as entry counts.
local HEIGHT_CHROME = 4

-- Content-aware sizing is OFF. The popup opens at DEFAULT_WIDTH/HEIGHT below.
--
-- It works, and the code is kept intact — flip this to true to get it back.
-- It is parked because the cost outweighed the benefit: file_browser derives
-- its filename column from the window width when the entry maker is built and
-- only recomputes on VimResized, whose handler calls picker:refresh(). Any
-- post-hoc resize therefore either left names truncated or re-ran the whole
-- finder (scan + git subprocess + fs_stat per entry). See popup_width.
local DYNAMIC_SIZE = false

-- Fixed size when DYNAMIC_SIZE is off.
local DEFAULT_WIDTH = 90
local DEFAULT_HEIGHT = 25

-- Bounds used only when DYNAMIC_SIZE is on.
local MIN_WIDTH = 80
local MAX_WIDTH = 120

-- What a row needs besides the bare filename.
--   NAME_CHROME: selection caret, devicon, git-status column and their spacing
--   STAT_BLOCK:  the permissions/size/date group, measured at exactly 30
--                columns and right-aligned, so a long name runs into it
--   GAP:         breathing room between the name and that block
--   BORDERS:     the popup's own left and right border columns
local WIDTH_NAME_CHROME = 8
local WIDTH_STAT_BLOCK = 30
local WIDTH_GAP = 4
local WIDTH_BORDERS = 2

-- Verbatim from themes.get_dropdown(), for prompt_position = "top".
local DROPDOWN_BORDERCHARS = {
  prompt = { "─", "│", " ", "│", "╭", "╮", "│", "│" },
  results = { "─", "│", "─", "│", "├", "┤", "╯", "╰" },
  preview = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },
}

-- Permissions / size / date columns, shown by default. STAT_KEY toggles them
-- off and on within an open picker.
--
-- Only the result list needs handling: the previewer is off, so there is no
-- second place for the metadata to appear.
local STAT_KEY = "gs"
local STAT_COLUMNS = { mode = true, size = true, date = true }

-- Session state for the toggle. Deliberately not persisted: each session starts
-- back at the default listing.
local show_stat = true

-- Dim behind the popup, so the browser is what your eye lands on. Covers only
-- the window the picker opened in — the other splits are left at full
-- brightness, matching the window-scoped popup.
--
-- Matched to a MUI dialog backdrop, which is rgba(0, 0, 0, 0.5). `winblend` is
-- transparency rather than opacity (0 = solid black, 100 = invisible), so 50%
-- opacity is winblend 50. The previous 30 was ~70% opaque, far darker than the
-- reference.
local DIM_BLEND = 50

-- Telescope's own floats are zindex 50, so the backdrop must sit below them.
local BACKDROP_ZINDEX = 40

local backdrop_win, backdrop_buf

local function close_backdrop()
  if backdrop_win and vim.api.nvim_win_is_valid(backdrop_win) then
    vim.api.nvim_win_close(backdrop_win, true)
  end
  if backdrop_buf and vim.api.nvim_buf_is_valid(backdrop_buf) then
    vim.api.nvim_buf_delete(backdrop_buf, { force = true })
  end
  backdrop_win, backdrop_buf = nil, nil
end

--- Dim just `win`, not the whole editor.
local function open_backdrop(win)
  close_backdrop() -- never stack two backdrops
  vim.api.nvim_set_hl(0, "TelescopeFbBackdrop", { bg = "#000000", default = true })

  local pos = vim.api.nvim_win_get_position(win)

  backdrop_buf = vim.api.nvim_create_buf(false, true)
  backdrop_win = vim.api.nvim_open_win(backdrop_buf, false, {
    relative = "editor",
    row = pos[1],
    col = pos[2],
    width = vim.api.nvim_win_get_width(win),
    height = vim.api.nvim_win_get_height(win),
    focusable = false,
    style = "minimal",
    zindex = BACKDROP_ZINDEX,
  })
  vim.wo[backdrop_win].winhighlight = "Normal:TelescopeFbBackdrop"
  vim.wo[backdrop_win].winblend = DIM_BLEND
end

--- Size and position the picker inside `win` instead of over the whole editor.
---
--- Telescope always sizes its float to the editor: pickers.lua calls
--- `picker:get_window_options(vim.o.columns, ...)` with the editor dimensions
--- hardcoded at the call site, so no layout_config value can escape that frame.
--- Overriding `get_window_options` is the only hook that changes it. This runs
--- the normal layout strategy against the window's width/height, then shifts
--- the result into place.
---
--- Note: `get_window_options` and `layout_strategy` are mutually exclusive
--- (telescope errors if both are passed in the picker opts), so the strategy
--- is pinned in `defaults` instead — see the note there.
local function window_local_layout(win)
  return function(picker, _, _)
    local target = vim.api.nvim_win_is_valid(win) and win or vim.api.nvim_get_current_win()
    local pos = vim.api.nvim_win_get_position(target)

    local strategies = require("telescope.pickers.layout_strategies")
    local layout = strategies[picker.layout_strategy](
      picker,
      vim.api.nvim_win_get_width(target),
      vim.api.nvim_win_get_height(target)
    )

    -- The strategy returns editor-relative 1-indexed line/col for each part
    -- (prompt/results/preview). Shift them into the target window's corner.
    for _, part in pairs(layout) do
      if type(part) == "table" and part.line and part.col then
        part.line = part.line + pos[1]
        part.col = part.col + pos[2]
      end
    end
    return layout
  end
end

--- Longest filename in `path`, in display cells.
---
--- A bare readdir: no fs_stat, no git, just names. Costs well under a
--- millisecond even on large directories.
local function scan_longest_name(path)
  local handle = vim.uv.fs_scandir(path)
  if not handle then
    return 0
  end
  local longest = 0
  while true do
    local name = vim.uv.fs_scandir_next(handle)
    if not name then
      break
    end
    longest = math.max(longest, vim.fn.strdisplaywidth(name))
  end
  return longest
end

--- Popup width for the contents of `path`, clamped.
---
--- Computed ONCE per open, before the picker is built, and passed as a fixed
--- number. It deliberately does not track the directory you navigate into.
---
--- The reason is performance. file_browser derives its filename column from
--- the results-window width when the entry maker is built, and only recomputes
--- it on VimResized — and its VimResized handler calls `picker:refresh()`.
--- Resizing the popup after the fact therefore meant firing that event, which
--- re-ran the whole finder (directory scan + a git subprocess + fs_stat per
--- entry) a second time on every directory change. Worse, those autocmds are
--- registered per entry maker and are only cleaned up lazily, so they pile up
--- as you browse: measured at 2 per open, all of them firing on each event.
--- Rapid h/l navigation compounded that into visible seconds of lag.
---
--- Sizing up front means the entry maker gets the right width first time, so
--- nothing has to be refreshed afterwards.
local function popup_width(path)
  local needed = scan_longest_name(path) + WIDTH_NAME_CHROME + WIDTH_BORDERS
  if show_stat then
    needed = needed + WIDTH_STAT_BLOCK + WIDTH_GAP
  end
  return math.max(MIN_WIDTH, math.min(needed, MAX_WIDTH))
end

--- Popup height for the number of entries currently listed, clamped.
---
--- Telescope passes the picker as the first argument to a height resolver, so
--- the live result count is reachable here. `max_lines` is the origin window's
--- height (window_local_layout feeds the strategy the window's dimensions), so
--- the popup can never outgrow the window it sits in.
local function content_height(picker, _, max_lines)
  local count = 0
  if picker and picker.manager then
    count = picker.manager:num_results() or 0
  end
  return math.max(MIN_HEIGHT, math.min(count + HEIGHT_CHROME, MAX_HEIGHT, max_lines))
end

--- Re-run the layout when the number of entries changes.
---
--- The layout is computed once at mount, before the finder has produced
--- anything, so content_height would otherwise always see zero. Telescope
--- recomputes it via full_layout_update(), which calls get_window_options
--- again (pickers.lua Layout.update).
---
--- Guarded on the count so this is a no-op for the common case of a keystroke
--- that does not change how many entries match — full_layout_update rebuilds
--- and repositions three floats, which is not something to do per keypress.
local function resize_to_content(picker)
  local count = picker.manager and picker.manager:num_results() or 0
  if picker._fb_last_count ~= count then
    picker._fb_last_count = count
    -- Height only. The width is fixed for the life of the picker (see
    -- popup_width), so this never invalidates file_browser's filename column
    -- and never needs a VimResized to repair it.
    picker:full_layout_update()
  end
end

-- Prompt buffer of the picker currently on screen, or nil. Used so the trial
-- key toggles: <leader>r is not mapped inside the picker, so pressing it again
-- reached the global mapping and opened a SECOND browser on top of the first.
local active_prompt_buf

--- Directory to open in, derived from the current buffer.
---
--- `%:p:h` is not safe on its own: for a scheme buffer it returns the URL
--- verbatim — `oil:///path`, `term://…`, `fugitive://…` — and file_browser then
--- errors with "Given path ... doesn't exist". Pressing the browser key from
--- inside oil is the common way to hit that. Strip a leading scheme, then fall
--- back to the cwd for anything that still is not a real directory.
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

local open_browser -- forward declaration: the stat toggle reopens the picker

--- Toggle the stat columns.
---
--- `display_stat` is baked into the entry maker when the picker is built
--- (make_entry.lua reads and mutates it while constructing the displayer), so
--- there is no way to flip it on a live picker. Reopening is the only option.
--- The directory and the selected row are carried across, so it reads as a
--- toggle rather than a restart: display_stat changes the rendering only, never
--- the entry list or its order, which is why the row index stays valid.
local function toggle_stat(prompt_bufnr)
  local action_state = require("telescope.actions.state")
  local picker = action_state.get_current_picker(prompt_bufnr)
  if not picker then
    return
  end

  -- The browsed directory, not the picker's cwd: cwd stays anchored at the
  -- project root so the prompt prefix keeps working (see open_browser).
  local path = picker.finder and picker.finder.path or nil
  local row = picker:get_selection_row()
  local index = row and picker:get_index(row) or nil
  local win = picker.original_win_id

  require("telescope.actions").close(prompt_bufnr)
  show_stat = not show_stat

  -- Scheduled so the closing picker has finished tearing down its windows
  -- before the replacement mounts in the same spot.
  vim.schedule(function()
    open_browser({ path = path, origin_win = win, selection_index = index })
  end)
end

--- Open the file browser inside `opts.origin_win` (default: the current window).
---@param opts? { path?: string, origin_win?: integer, selection_index?: integer, fullscreen?: boolean }
open_browser = function(opts)
  opts = opts or {}

  -- Captured before the picker opens: this is the window it sits inside.
  local origin_win = opts.origin_win
  if not origin_win or not vim.api.nvim_win_is_valid(origin_win) then
    origin_win = vim.api.nvim_get_current_win()
  end
  -- `path` is the directory being browsed; `cwd` is the project root, and the
  -- two must NOT be the same value. prompt_path renders
  -- `Path:new(finder.path):make_relative(finder.cwd)` as the prompt prefix
  -- (file_browser/utils.lua: relative_path_prefix), so path == cwd makes that
  -- relative path "." and the prompt shows a bare "/" until you navigate
  -- somewhere else. Anchoring cwd at the project root makes the prefix read as
  -- `lua/plugins/` — the actual location — from the first frame.
  local path = opts.path or resolve_dir()
  local root = vim.fn.getcwd()

  open_backdrop(origin_win)

  require("telescope").extensions.file_browser.file_browser({
    -- Window-local for the normal popup; omitted for the startup fullscreen
    -- open, where the point is to fill the editor rather than one window.
    get_window_options = not opts.fullscreen and window_local_layout(origin_win) or nil,
    path = path,
    cwd = root,
    display_stat = show_stat and STAT_COLUMNS or false,
    -- Land on the file you are editing rather than the top of the list, the
    -- way reopening oil keeps you where you were. Only used on a plain open —
    -- STAT_KEY's reopen passes an explicit row to restore instead.
    select_buffer = opts.selection_index == nil,
    default_selection_index = opts.selection_index,
    previewer = false, -- craftzdog runs the dropdown without a preview pane
    initial_mode = "normal", -- land in normal mode, so h/j/k work at once
    -- The center strategy clamps both to what the window can actually give,
    -- and window_local_layout feeds it the window's dimensions rather than the
    -- editor's, so "available" here means the current window.
    --
    -- opts.fullscreen is only set by the startup path (see the `init` hook):
    -- opening nvim on a directory fills the screen, every later <leader>e is
    -- the normal popup. Resolver functions rather than a literal 1.0, which
    -- makes telescope hand plenary a non-integer and throws E5108.
    layout_config = opts.fullscreen and {
      width = function(_, max_columns)
        return max_columns
      end,
      height = function(_, _, max_lines)
        return max_lines
      end,
    } or {
      height = DYNAMIC_SIZE and content_height or DEFAULT_HEIGHT,
      width = DYNAMIC_SIZE and popup_width(path) or DEFAULT_WIDTH,
    },
    -- Re-layout once the entries are known, and again whenever navigating or
    -- filtering changes how many there are. Only wired up when DYNAMIC_SIZE is
    -- on; with a fixed size there is nothing to recompute.
    on_complete = DYNAMIC_SIZE and { resize_to_content } or nil,
  })

  local prompt_buf = vim.api.nvim_get_current_buf()
  active_prompt_buf = prompt_buf

  -- `-` / `=` are the back/forward pair, oil-style: `-` goes to the parent
  -- (bound with the other navigation keys), `=` selects — entering a directory
  -- or opening a file, the same as <C-l>. No directory guard: the pair is meant
  -- to be symmetric.
  --
  -- `=` and STAT_KEY are set directly on the prompt buffer rather than through
  -- telescope's `mappings` table: telescope drops the `opts` table for
  -- extension mappings (file_browser.lua calls `map()` with no opts argument),
  -- and it does not reach vim.keymap.set from defaults.mappings either —
  -- verified, `nowait` came back 0 both ways. Without nowait, yanky's global
  -- `=p` / `=P` make every `=` wait out timeoutlen (300ms).
  -- These run after telescope has applied its own maps, so they win.
  vim.keymap.set("n", "=", function()
    require("telescope.actions").select_default(prompt_buf)
  end, {
    buffer = prompt_buf,
    nowait = true,
    silent = true,
    desc = "Select (enter directory / open file)",
  })

  vim.keymap.set("n", STAT_KEY, function()
    toggle_stat(prompt_buf)
  end, {
    buffer = prompt_buf,
    nowait = true,
    silent = true,
    desc = "Toggle permissions/size/date columns",
  })

  -- Tear the backdrop down on whatever ends the picker — `q`, <CR>, <C-l>,
  -- actions.close, or the window being closed some other way. BufWinLeave on
  -- the prompt buffer covers every one of those paths, so there is no
  -- per-keymap cleanup to keep in sync.
  --
  -- STAT_KEY reopens the picker, which calls open_backdrop again; that closes
  -- the previous backdrop first, so the two never stack.
  vim.api.nvim_create_autocmd("BufWinLeave", {
    buffer = prompt_buf,
    once = true,
    callback = function()
      vim.schedule(function()
        close_backdrop()
        -- Only clear if this is still the picker on screen. STAT_KEY closes and
        -- immediately reopens, and that reopen has already claimed the slot by
        -- the time this scheduled callback runs.
        if active_prompt_buf == prompt_buf then
          active_prompt_buf = nil
        end
      end)
    end,
  })
end

return {
  {
    "nvim-telescope/telescope.nvim",
    enabled = ENABLED,
    lazy = true, -- only pulled in as the file-browser dependency below
    dependencies = { "nvim-lua/plenary.nvim" },
    -- `opts` is a function, not a table: it must not run until telescope is
    -- actually loaded, or the `require`s below would drag telescope into
    -- startup and defeat the lazy-load.
    opts = function()
      local actions = require("telescope.actions")

      -- <C-u>/<C-d>: step the selection 10 rows at a time.
      local function step(n, direction)
        local move = direction == "previous" and actions.move_selection_previous or actions.move_selection_next
        return function(prompt_bufnr)
          for _ = 1, n do
            move(prompt_bufnr)
          end
        end
      end

      -- fb_actions is resolved at keypress, not at setup: the extension is
      -- guaranteed loaded once the browser is open, whereas at setup time its
      -- module may not be on rtp yet.
      local function parent(prompt_bufnr)
        require("telescope").extensions.file_browser.actions.goto_parent_dir(prompt_bufnr)
      end

      return {
        defaults = {
          sorting_strategy = "ascending",
          -- "center" is the dropdown's strategy. It has to live here rather
          -- than in the picker opts: window_local_layout reads
          -- picker.layout_strategy, but passing layout_strategy alongside
          -- get_window_options is a hard error (pickers.lua:232). Values in
          -- `defaults` reach the picker without being part of its opts table.
          layout_strategy = "center",
          layout_config = { prompt_position = "top" },
        },
        extensions = {
          file_browser = {
            -- The dropdown's non-layout_strategy parts (see the note at the top
            -- of this file for why the theme string itself cannot be used).
            results_title = false,
            border = true,
            borderchars = DROPDOWN_BORDERCHARS,
            prompt_path = true, -- current dir shown as the prompt prefix
            hidden = { file_browser = true, folder_browser = true },
            respect_gitignore = false,
            grouped = true, -- directories first
            -- `../` is hidden because `l` on it was an easy mis-hit that threw
            -- you back up a level. Going up is still `h` or `-`
            -- (goto_parent_dir), which do not depend on the row existing.
            hide_parent_dir = true,
            -- Recursive search (`auto_depth = true`) is deliberately OFF.
            -- Typing then searches the whole tree, and with
            -- respect_gitignore = false that means walking node_modules: a
            -- project measured here went from 1,277 entries to 42,255, all of
            -- which telescope re-sorts on every keystroke. Searching stays
            -- scoped to the current directory instead.
            -- Off for speed. It spawns a `git status` subprocess on every
            -- directory change, measured at ~75ms of the ~124ms each change
            -- cost — the single largest component, and more than oil spends
            -- on a whole refresh (23ms). Turning it off drops a change to
            -- ~50ms. The cost is that added/modified markers no longer show
            -- next to filenames.
            git_status = false,
            -- display_stat is NOT set here: it is passed per-open in
            -- open_browser() so STAT_KEY can flip it.
            --
            -- oil.nvim owns netrw, so this must stay false.
            hijack_netrw = false,
            mappings = {
              ["i"] = {
                -- Accept the highlighted entry without leaving insert mode.
                -- Filtering happens in insert, so selecting used to mean <Esc>
                -- then <CR>; this makes it one keystroke, and matches the
                -- normal-mode `l`.
                --
                -- Telescope's insert-mode default here is actions.complete_tag
                -- (prompt tag completion), which a file browser has no use for.
                ["<C-l>"] = actions.select_default,
              },
              ["n"] = {
                -- ---- close: mirrors oil.lua ------------------------------
                -- oil binds `q` to close and deliberately makes <Esc> clear
                -- search highlights *without* closing. Telescope's default
                -- <Esc> closes the picker, so it has to be overridden here or
                -- the two explorers would disagree on the same key.
                ["q"] = actions.close,
                ["<Esc>"] = function()
                  if vim.v.hlsearch == 1 then
                    vim.cmd("nohlsearch")
                  end
                end,

                -- ---- navigate ---------------------------------------------
                -- <C-h> / <C-l> rather than bare h / l: the plain letters were
                -- too easy to hit by accident and would jump a directory.
                ["<C-h>"] = parent,
                ["<C-l>"] = actions.select_default,
                ["-"] = parent,

                -- h / l are deliberately dead. Leaving them unset is not the
                -- same thing: file_browser's own normal-mode default for `h`
                -- is toggle_hidden, so an accidental press would silently
                -- change what the listing shows. `false` blocks that default
                -- without binding anything, so the keys just move the cursor.
                ["h"] = parent,
                ["l"] = false,

                -- Move the selection, same keys in both modes. Insert already
                -- has these from telescope; normal mode does not.
                ["<C-n>"] = actions.move_selection_next,
                ["<C-p>"] = actions.move_selection_previous,
                -- `=` and STAT_KEY are NOT here: see open_browser(). Extension
                -- mappings are applied by file_browser.lua with `map(mode, key,
                -- action)` and no opts argument, so telescope never extracts
                -- their `opts` table and `nowait` would be silently dropped.

                ["N"] = function(prompt_bufnr)
                  require("telescope").extensions.file_browser.actions.create(prompt_bufnr)
                end,
                ["/"] = function()
                  vim.cmd("startinsert")
                end,
                ["<C-u>"] = step(10, "previous"),
                ["<C-d>"] = step(10, "next"),
                ["<PageUp>"] = actions.preview_scrolling_up,
                ["<PageDown>"] = actions.preview_scrolling_down,

                -- fb's normal-mode default for `h` is toggle_hidden; `h` is now
                -- oil-style parent. Rehomed here rather than dropped.
                ["H"] = function(prompt_bufnr)
                  require("telescope").extensions.file_browser.actions.toggle_hidden(prompt_bufnr)
                end,
              },
            },
          },
        },
      }
    end,
  },

  {
    "nvim-telescope/telescope-file-browser.nvim",
    enabled = ENABLED,
    dependencies = { "nvim-telescope/telescope.nvim" },
    -- Startup explorer: `nvim .` (or any directory) opens the browser
    -- fullscreen instead of leaving you in a directory buffer. oil.nvim used to
    -- own this via default_file_explorer, which is now false there.
    --
    -- This lives in `init` (which lazy.nvim runs at startup) rather than an
    -- `event`, so the plugin itself stays lazy: nothing is required until the
    -- autocmd actually fires on a directory argument.
    init = function()
      if not ENABLED then
        return
      end
      vim.api.nvim_create_autocmd("VimEnter", {
        once = true,
        callback = function()
          -- Only the plain `nvim <dir>` case: one argument, and it is a
          -- directory. Opening files, stdin, or a session is left alone.
          if vim.fn.argc() ~= 1 then
            return
          end
          local target = vim.fn.argv(0)
          if type(target) ~= "string" then
            return
          end
          -- oil.nvim still owns directories opened mid-session, and by the time
          -- VimEnter runs it has already rewritten the arglist entry to
          -- `oil:///path/`. Strip the scheme so the check sees a real path —
          -- without this the guard rejects every startup directory.
          target = (target:gsub("^oil://", ""))
          if vim.fn.isdirectory(target) ~= 1 then
            return
          end
          local dir = vim.fn.fnamemodify(target, ":p")
          -- Scheduled so the UI has attached; telescope sizes itself from the
          -- window and gets that wrong if it mounts too early.
          vim.schedule(function()
            require("lazy").load({ plugins = { "telescope-file-browser.nvim" } })

            -- oil has already claimed the directory buffer by now (it still
            -- owns `:e <dir>` mid-session). Left alone it sits behind the
            -- picker, so closing the browser drops you into oil instead of an
            -- empty editor. Swap it for a blank buffer first.
            local dir_buf = vim.api.nvim_get_current_buf()
            if vim.bo[dir_buf].filetype == "oil" then
              local blank = vim.api.nvim_create_buf(true, false)
              vim.api.nvim_win_set_buf(0, blank)
              pcall(vim.api.nvim_buf_delete, dir_buf, { force = true })
            end

            -- Through open_browser, not the picker directly, so the startup
            -- window gets the same keymaps, backdrop and teardown as every
            -- other open.
            open_browser({ path = dir, fullscreen = true })
          end)
        end,
      })
    end,
    keys = {
      {
        TRIAL_KEY,
        function()
          -- Toggle: a second press closes the open browser rather than
          -- stacking another one on top of it.
          if active_prompt_buf and vim.api.nvim_buf_is_valid(active_prompt_buf) then
            require("telescope.actions").close(active_prompt_buf)
            return
          end
          open_browser()
        end,
        desc = "File Browser (Telescope, trial)",
      },
    },
    -- telescope.nvim is set up first (dependency), so its `opts` above have
    -- already been applied by the time this runs. Only register the extension
    -- here — a second telescope.setup() call would reset `defaults`.
    config = function()
      require("telescope").load_extension("file_browser")
    end,
  },

  -- Installing telescope.nvim silently activates LazyVim's `optional` telescope
  -- specs. `extras.lang.terraform` carries two of them, which would start
  -- loading on every .tf/.hcl buffer. That is behavior this config did not have
  -- before the trial, so keep them off — this file must not change anything
  -- outside the trial key.
  { "cappyzawa/telescope-terraform.nvim", enabled = false },
  { "ANGkeith/telescope-terraform-doc.nvim", enabled = false },
}
