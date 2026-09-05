local function clear_smart_picker_history()
  local history = require("snacks.picker.util.history").new("picker_smart")
  history.kv.data = {}
  history.idx = 1
  history.cursor = 1
  history.kv:close()

  vim.v.oldfiles = {}
  pcall(vim.cmd, "wshada!")

  vim.notify("Cleared Snacks smart picker history", vim.log.levels.INFO)
end

-- Active-file band for the Explorer list (same color as OilCursorLine).
-- The themes disable CursorLine globally (bg NONE — see
-- colorschemes/solarized-osaka/init.lua), so the row that snacks' `follow_file`
-- parks on the active file renders invisible. A winhighlight remap (the
-- oil.nvim approach) doesn't work here: snacks rewrites the list window's
-- CursorLine winhighlight entry on every render, which also replaces the
-- window's highlight namespace. Instead, the explorer `format` wrapper below
-- appends a full-width line_hl_group extmark to the active file's row —
-- explorer-scoped by construction, one string compare per rendered row.
local explorer_active_file ---@type string?

local function explorer_track_active(picker, file)
  file = file and file ~= "" and vim.fs.normalize(file) or nil
  if not file or file == explorer_active_file then
    return
  end
  explorer_active_file = file
  if picker and not picker.closed then
    picker.list:update({ force = true })
  end
end

local snacks_keymaps = {
  ["<C-f>"] = { "close", mode = { "n", "i" } },
  ["<C-l>"] = {
    "confirm",
    mode = { "n", "i" },
    desc = "Confirm selection",
  },
}

--- Scroll a picker LIST by `delta` rows, the way <C-e> / <C-y> scroll a buffer.
---
--- Native <C-e> / <C-y> do NOTHING in here, and not because a mapping swallows
--- them -- they have nothing to move. A picker list is virtually scrolled: its
--- buffer only ever holds the rows currently on screen and `list.top` maps a row
--- back to an item, so there is no text below the last line for Neovim to scroll
--- to. The global handler in config/keymaps.lua deliberately skips any
--- `^snacks_picker` float and falls through to native, so this window has to
--- answer for itself.
---
--- `list:scroll()` moves `top` instead, and is the same call snacks' own mouse
--- wheel makes here -- so the keys and the wheel agree rather than inventing two
--- rules. At either end of the listing snacks steps the selection by `delta`
--- instead, which is what the wheel has always done here.
local function picker_scroll(picker, delta)
  -- Honour a count (`5<C-e>`) like the native keys, but only from normal mode:
  -- `v:count1` keeps the LAST normal-mode count while in insert, so reading it in
  -- the prompt would scroll by a number nobody typed. Same guard snacks puts on
  -- its own list_down / list_up actions.
  local count = vim.fn.mode():sub(1, 1) == "i" and 1 or vim.v.count1
  picker.list:scroll(delta * count)
end

local function explorer_window_keys()
  local function focus(direction)
    return function()
      local current = vim.api.nvim_get_current_win()
      local row, col = unpack(vim.api.nvim_win_get_position(current))
      local current_bounds = {
        top = row,
        bottom = row + vim.api.nvim_win_get_height(current) - 1,
        left = col,
        right = col + vim.api.nvim_win_get_width(current) - 1,
      }
      local target, target_gap, target_offset

      -- Explorer panes are floats inside a split root. Raw wincmd can enter
      -- that root and Snacks may then redirect focus in the wrong direction.
      for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        local buf = vim.api.nvim_win_get_buf(win)
        local config = vim.api.nvim_win_get_config(win)
        if win ~= current and config.relative == "" and vim.bo[buf].filetype ~= "snacks_layout_box" then
          local win_row, win_col = unpack(vim.api.nvim_win_get_position(win))
          local bounds = {
            top = win_row,
            bottom = win_row + vim.api.nvim_win_get_height(win) - 1,
            left = win_col,
            right = win_col + vim.api.nvim_win_get_width(win) - 1,
          }
          local horizontal_overlap = bounds.left <= current_bounds.right and bounds.right >= current_bounds.left
          local vertical_overlap = bounds.top <= current_bounds.bottom and bounds.bottom >= current_bounds.top
          local gap, offset

          if direction == "h" and vertical_overlap and bounds.right < current_bounds.left then
            gap = current_bounds.left - bounds.right
            offset = math.abs((bounds.top + bounds.bottom) - (current_bounds.top + current_bounds.bottom))
          elseif direction == "j" and horizontal_overlap and bounds.top > current_bounds.bottom then
            gap = bounds.top - current_bounds.bottom
            offset = math.abs((bounds.left + bounds.right) - (current_bounds.left + current_bounds.right))
          elseif direction == "k" and horizontal_overlap and bounds.bottom < current_bounds.top then
            gap = current_bounds.top - bounds.bottom
            offset = math.abs((bounds.left + bounds.right) - (current_bounds.left + current_bounds.right))
          elseif direction == "l" and vertical_overlap and bounds.left > current_bounds.right then
            gap = bounds.left - current_bounds.right
            offset = math.abs((bounds.top + bounds.bottom) - (current_bounds.top + current_bounds.bottom))
          end

          if gap and (not target_gap or gap < target_gap or (gap == target_gap and offset < target_offset)) then
            target, target_gap, target_offset = win, gap, offset
          end
        end
      end

      if target then
        vim.api.nvim_set_current_win(target)
      end
    end
  end

  return {
    ["<C-h>"] = { focus("h"), mode = "n", desc = "Focus left window" },
    ["<C-j>"] = { focus("j"), mode = "n", desc = "Focus lower window" },
    ["<C-k>"] = { focus("k"), mode = "n", desc = "Focus upper window" },
    ["<C-l>"] = { focus("l"), mode = "n", desc = "Focus right window" },
  }
end

return {
  "folke/snacks.nvim",
  ---@type snacks.Config
  lazy = false,
  init = function()
    -- Brighter indent-guide color — the theme's default links SnacksIndent to a
    -- near-invisible group. Safe to override globally: SnacksIndent is used only
    -- when Snacks indent is enabled. Tweak INDENT_GUIDE_FG to taste
    -- (#586e75 = solarized base01 / comment brightness; #839496 = body-text bright).
    local INDENT_GUIDE_FG = "#586e75"
    local function set_snacks_hl()
      vim.api.nvim_set_hl(0, "SnacksPickerMatch", { link = "DiffText" })
      vim.api.nvim_set_hl(0, "SnacksIndent", { fg = INDENT_GUIDE_FG, nocombine = true })
      -- Full-width band on the active file's row in the Explorer. Only used by
      -- the explorer format wrapper, so no other picker or window is affected.
      --
      -- Raised from #073642 (solarized base02) on 2026-09-04. Both axes moved a
      -- little, and the CEILING is what decided how far: the cursor-row band is
      -- `Visual` (#3b4261, L* 28.6), and these two must stay tellable apart.
      --
      --   #073642  L* 20.3  C* 15.6   was: 8.3 L* below the cursor row
      --   #003f52  L* 24.2  C* 19.4   now: 4.4 L* below it, +3.9 L*, +3.8 chroma
      --
      -- Going to L* 26 would leave a 2.6 L* gap and L* 28 only 0.6 -- at which
      -- point you cannot see which row the cursor is on. Chroma is the axis with
      -- room here (and the one that reads as "intensity"), but it is nearly out of
      -- room too: every candidate above C* 20 clips the red channel to 0 at this
      -- lightness. The hue gap does the rest of the work -- 229 vs the cursor
      -- row's 287.
      vim.api.nvim_set_hl(0, "SnacksExplorerActiveFile", { bg = "#003f52" })
      -- Invisible text: fg matched to the background. Used only through the
      -- explorer input's `winhighlight`, to blank the `x/y` counter (see the
      -- explorer source below).
      vim.api.nvim_set_hl(0, "SnacksExplorerBlank", { fg = require("config.ui").bg })
      -- Invisible border: glyphs the same colour as the background, so the box
      -- around the explorer's search row disappears while the row itself, and the
      -- "Explorer" title drawn ON that border, both stay. Same trick as oil's
      -- `OilFloatBorder`. The border cannot simply be removed -- Neovim renders a
      -- window title on the border, so with `border = "none"` the title goes too.
      vim.api.nvim_set_hl(0, "SnacksExplorerInvisibleBorder", {
        fg = require("config.ui").bg,
        bg = require("config.ui").bg,
      })
    end
    set_snacks_hl()
    -- Re-apply on theme switch: snacks links its own groups with default=true,
    -- so this explicit (non-default) definition always wins.
    vim.api.nvim_create_autocmd("ColorScheme", { callback = set_snacks_hl })
  end,
  opts = {
    -- Enabled for the <leader>r tree sidebar, but it must not claim directory
    -- buffers: oil.nvim owns netrw and is the file explorer, on <leader>e and
    -- on `nvim <dir>` (lua/plugins/oil.lua).
    explorer = { enabled = true, replace_netrw = false },
    dashboard = { enabled = true },
    scroll = { enabled = false },
    animate = { enabled = false },
    words = { enabled = false }, -- CursorMoved buffer-wide search on every j/k
    indent = { enabled = false }, -- decoration provider + scope listener on hot paths
    scope = { enabled = false }, -- treesitter scope tracking on every cursor move
    dim = { enabled = false },
    picker = {
      -- PICKER-WIDE, deliberately: every picker needs these, not just the
      -- explorer. See the note on `picker_scroll` for why the native keys are
      -- inert in a picker list.
      --
      -- Binding them here also fixes a second symptom: the global <C-e>/<C-y>
      -- handler (config/keymaps.lua) scrolls the first focusable NON-picker
      -- float it finds, so with a picker open on top of the oil popup it
      -- scrolled OIL. A buffer-local mapping in the picker window takes
      -- precedence over that global one, so the picker now answers first.
      -- NAMES MATTER HERE. `list_scroll_down` / `list_scroll_up` are snacks
      -- BUILT-IN actions bound to <C-d>/<C-u> (a page scroll). Defining actions
      -- with those names here silently REPLACES them for every picker, turning
      -- <C-d>/<C-u> into a one-line scroll. Done by accident on 2026-09-05 and
      -- caught before it shipped -- keep these names distinct from snacks'.
      actions = {
        list_scroll_line_down = function(picker)
          picker_scroll(picker, 1)
        end,
        list_scroll_line_up = function(picker)
          picker_scroll(picker, -1)
        end,
      },
      win = {
        input = {
          keys = {
            ["<C-l>"] = { "confirm", mode = { "n", "i" }, desc = "Confirm selection" },
            -- Insert mode included: in the prompt the native meaning (insert the
            -- character below / above the cursor) has nothing to act on, while
            -- scrolling the rows you are filtering does.
            ["<C-e>"] = { "list_scroll_line_down", mode = { "n", "i" }, desc = "Scroll list down" },
            ["<C-y>"] = { "list_scroll_line_up", mode = { "n", "i" }, desc = "Scroll list up" },
          },
        },
        list = {
          keys = {
            ["<C-l>"] = { "confirm", mode = { "n", "i" }, desc = "Confirm selection" },
            ["<C-e>"] = { "list_scroll_line_down", mode = { "n" }, desc = "Scroll list down" },
            ["<C-y>"] = { "list_scroll_line_up", mode = { "n" }, desc = "Scroll list up" },
          },
        },
      },
      sources = {
        ---@class snacks.picker.smart.Config: snacks.picker.Config
        smart = {
          multi = {
            { source = "buffers", hidden = true, current = false },
            { source = "recent", filter = { cwd = true } },
            { source = "files" },
          },
          keys = snacks_keymaps,
          format = "file",
          matcher = {
            frecency = false,
            sort_empty = false,
          },
        },
        grep = {
          keys = snacks_keymaps,
          layout = {
            preview = false,
            layout = {
              box = "horizontal",
              width = 0.8,
              height = 0.5,
              -- Repeated from the picker-wide layout below, and it has to be:
              -- a source layout that spells out its own `box` REPLACES the
              -- picker-wide one instead of merging with it
              -- (Snacks.picker.config.layout skips preset resolution once
              -- `layout.layout[1]` exists). Without this line grep is the one
              -- picker that still draws the full-screen black veil. Reasoning
              -- for the setting itself is on the picker-wide copy.
              backdrop = false,
              {
                box = "vertical",
                border = true,
                title = "{title} {live} {flags}",
                { win = "input", height = 1, border = "bottom" },
                { win = "list", border = "none" },
              },
              { win = "preview", title = "{preview}", border = true, width = 0.45 },
            },
          },
        },
        explorer = {
          -- The sidebar preset, spelled out.
          --
          -- It HAS to be spelled out. Two of the three changes below live on box
          -- entries rather than on the picker, and providing any `box` of our own
          -- REPLACES the preset's rather than merging into it (snacks skips preset
          -- resolution once `layout.layout[1]` exists) -- so a partial override
          -- would silently drop the list and preview entries. Kept in sync with
          -- snacks' `M.sidebar` (picker/config/layouts.lua); only `width` and the
          -- input's `wo` differ.
          --
          -- WHY the input's `winhighlight` is HERE and nowhere else. Two earlier
          -- placements were tried and both silently did nothing:
          --   * `win.input.wo` -- snacks builds the input as
          --     `Snacks.win.resolve(opts.win.input, { ...defaults })`, and resolve
          --     lets the LAST table win, which is snacks' defaults.
          --   * assigning to the live window in `on_show` -- the layout snapshots
          --     `win.opts` when it adopts a window and RESTORES that snapshot on
          --     every update (snacks/layout.lua, `update_win`), so the assignment
          --     is overwritten on the next redraw.
          -- `update_win` merges the box entry over that snapshot, so a `wo` here is
          -- the one thing the layout cannot undo.
          layout = {
            -- `false`, NOT the sidebar preset's "main". The preset previews into
            -- the main window on every cursor move; snacks' own explorer SOURCE
            -- overrides that with `preview = false` (picker/config/sources.lua),
            -- because a tree you navigate with j/k should not be loading a file
            -- into the right pane on every row. Spelling the layout out means
            -- inheriting the preset instead of the source, so this has to be
            -- restated -- it was briefly lost that way on 2026-09-05.
            preview = false,
            layout = {
              backdrop = false,
              width = 0.25,
              min_width = 40,
              height = 0,
              position = "left",
              border = "none",
              box = "vertical",
              {
                win = "input",
                height = 1,
                -- "top" not `true`: a full border box drew a visible rectangle
                -- around the blank search row (reported 2026-09-04). Only the top
                -- edge is kept, because that is where Nvim draws the title, and
                -- that edge is then made invisible via the winhighlight below. Net
                -- result above the tree: the "Explorer" row, then one blank row.
                border = "top",
                title = "{title} {live} {flags}",
                title_pos = "center",
                wo = {
                  -- The five SnacksPickerInput* entries reproduce what snacks
                  -- sets for this window (`highlight.winhl("SnacksPickerInput")`);
                  -- this table replaces that string rather than extending it, so
                  -- leaving them out would strip the input's own colours.
                  winhighlight = table.concat({
                    "NormalFloat:SnacksPickerInput",
                    "FloatBorder:SnacksExplorerInvisibleBorder",
                    "FloatTitle:SnacksPickerInputTitle",
                    "FloatFooter:SnacksPickerInputFooter",
                    "CursorLine:SnacksPickerInputCursorLine",
                    "SnacksPickerTotals:SnacksExplorerBlank",
                  }, ","),
                },
              },
              { win = "list", border = "none" },
              { win = "preview", title = "{preview}", height = 0.4, border = "top" },
            },
          },
          -- Blank the search row, keep the "Explorer" title above it.
          --
          -- The row is NOT removed from the layout. `hidden = { "input" }` would
          -- do that, but the title lives on the input box's border, so hiding the
          -- window takes the title with it and the layout has to be respelled to
          -- move the title onto the list. Emptying the row instead keeps the title
          -- exactly where it is and turns the row itself into the gap between the
          -- title and the tree -- which is what was wanted -- and typing still
          -- filters, with the pattern appearing where the prompt used to be.
          --
          -- Two things are drawn in that row and each needs its own switch:
          --   * the `>` prompt icon, rendered into the input's statuscolumn from
          --     `opts.prompt` (snacks picker/core/input.lua) -- emptied here.
          --   * the `x/y` counter, a right-aligned virt_text extmark on the input
          --     line carrying `SnacksPickerTotals`. There is no option for it, so
          --     the group is remapped to an invisible one through this window's
          --     `winhighlight`, in the layout below. Window-scoped, so every other
          --     picker keeps its counter.
          prompt = "",
          -- Default file format plus the active-file band (see
          -- explorer_track_active at the top of this file).
          format = function(item, picker)
            local ret = Snacks.picker.format.file(item, picker)
            if explorer_active_file and item.file == explorer_active_file then
              ret[#ret + 1] = { col = 0, line_hl_group = "SnacksExplorerActiveFile" }
            end
            return ret
          end,
          -- Mirror snacks' own follow_file autocmd (registered on the list
          -- window's augroup, so it dies with the window): re-render the band
          -- when the edited buffer changes. Runs only while the explorer is
          -- open, and only re-renders when the active file actually changed.
          on_show = function(picker)
            -- Seed the band for the FIRST render, whatever opened the explorer.
            -- `picker.main` is the window the picker attached to, so its buffer is
            -- the file being edited -- `nvim_get_current_buf()` is unreliable here,
            -- because by now it can already be the picker's own input.
            local main = picker.main
            if main and vim.api.nvim_win_is_valid(main) then
              local main_buf = vim.api.nvim_win_get_buf(main)
              local name = vim.api.nvim_buf_get_name(main_buf)
              if name ~= "" and vim.bo[main_buf].buftype == "" then
                explorer_active_file = vim.fs.normalize(name)
              end
            end

            local ref = picker:ref()
            picker.list.win:on({ "WinEnter", "BufEnter" }, function()
              vim.schedule(function()
                local p = ref()
                if not p or p.closed then
                  return
                end
                local buf = vim.api.nvim_get_current_buf()
                if vim.bo[buf].buftype ~= "" then
                  return
                end
                local win = vim.api.nvim_get_current_win()
                if vim.api.nvim_win_get_config(win).relative ~= "" then
                  return
                end
                explorer_track_active(p, vim.api.nvim_buf_get_name(buf))
              end)
            end)
          end,
          actions = {
            explorer_single_click = function(picker)
              local pos = vim.fn.getmousepos()
              local list_win = picker.list.win.win

              -- Click outside the explorer list: replicate default
              -- <LeftMouse> behavior (focus the clicked window, place
              -- cursor at the click point). We have to do this manually
              -- because intercepting <LeftMouse> suppresses the default.
              if pos.winid ~= list_win then
                if pos.winid > 0 and vim.api.nvim_win_is_valid(pos.winid) then
                  vim.api.nvim_set_current_win(pos.winid)
                  if pos.line > 0 then
                    local col = math.max(0, pos.column - 1)
                    pcall(vim.api.nvim_win_set_cursor, pos.winid, { pos.line, col })
                  end
                end
                return
              end

              if pos.line < 1 then
                return
              end

              local idx = picker.list:row2idx(pos.line)
              local item = picker.list:get(idx)
              if not item or not vim.api.nvim_win_is_valid(list_win) then
                return
              end

              picker.list:view(idx)

              if item.dir or picker.input.filter.meta.searching then
                picker:action("confirm")
                return
              end

              if not vim.api.nvim_win_is_valid(picker.main) then
                return
              end

              local path = Snacks.picker.util.path(item)
              if not path then
                return
              end

              local buf = item.buf or vim.fn.bufadd(path)
              vim.bo[buf].buflisted = true

              if vim.api.nvim_win_get_buf(picker.main) ~= buf then
                local ok, err = pcall(vim.fn.bufload, buf)
                if not ok then
                  Snacks.notify.error("Failed to load `" .. path .. "`:\n- " .. err)
                  return
                end

                ok, err = pcall(vim.api.nvim_win_set_buf, picker.main, buf)
                if not ok then
                  Snacks.notify.error("Failed to open `" .. path .. "`:\n- " .. err)
                  return
                end
              end

              -- nvim_win_set_buf doesn't fire BufEnter, so move the
              -- active-file band explicitly.
              explorer_track_active(picker, path)

              if vim.api.nvim_win_is_valid(list_win) then
                vim.api.nvim_set_current_win(list_win)
              end
            end,
            -- Open the focused file in picker.main without ever moving focus
            -- there. Uses nvim_win_set_buf (sets a buffer in a target window
            -- without changing the current window) instead of snacks's default
            -- `confirm` (which switches focus to the file's window). Avoids
            -- the focus round-trip flicker and spurious WinLeave/WinEnter.
            -- Folder / search-mode items fall through to confirm; that path
            -- still triggers the upstream toggle flicker documented in
            -- todos/snacks-explorer-folder-click-cursor-flicker.md.
            explorer_open_keep_focus = function(picker)
              local item = picker:current()
              if not item then
                return
              end

              if item.dir or picker.input.filter.meta.searching then
                picker:action("confirm")
                return
              end

              if not vim.api.nvim_win_is_valid(picker.main) then
                return
              end

              local path = Snacks.picker.util.path(item)
              if not path then
                return
              end

              local buf = item.buf or vim.fn.bufadd(path)
              vim.bo[buf].buflisted = true

              if vim.api.nvim_win_get_buf(picker.main) ~= buf then
                local ok, err = pcall(vim.fn.bufload, buf)
                if not ok then
                  Snacks.notify.error("Failed to load `" .. path .. "`:\n- " .. err)
                  return
                end

                ok, err = pcall(vim.api.nvim_win_set_buf, picker.main, buf)
                if not ok then
                  Snacks.notify.error("Failed to open `" .. path .. "`:\n- " .. err)
                  return
                end
              end

              -- nvim_win_set_buf doesn't fire BufEnter, so move the
              -- active-file band explicitly.
              explorer_track_active(picker, path)
            end,
            explorer_toggle_focus = function(picker)
              local root = vim.uv.cwd()
              if picker:cwd() ~= root then
                local target = picker:cwd()
                picker:set_cwd(root)
                picker:find()
                -- After items load, move cursor to the previously focused folder
                vim.defer_fn(function()
                  local items = picker.list.items
                  for i, item in ipairs(items) do
                    if item.file and item.file == target then
                      picker.list:view(i)
                      return
                    end
                  end
                end, 50)
                return
              else
                picker:set_cwd(picker:dir())
                picker:find()
              end
            end,
          },
          win = {
            -- Snacks normally uses <C-j>/<C-k> for picker-list movement.
            -- In Explorer, reserve the complete Ctrl-hjkl set for window
            -- navigation, matching LazyVim everywhere else.
            input = {
              -- Insert mode is included because in the prompt the native meaning
              -- (insert the character below / above the cursor) has nothing to act
              -- on, while scrolling the rows you are filtering does.
              keys = vim.tbl_extend("force", explorer_window_keys(), {
                -- Tree keys, NORMAL MODE ONLY, so the prompt still types `h`/`l`
                -- while filtering.
                --
                -- Snacks binds these on the LIST window only, and binds `j`/`k`
                -- here to list_down/list_up but not `h`/`l`. The result after
                -- typing a filter -- when focus sits in this window -- is that
                -- j/k walk the tree while h/l silently move the prompt's text
                -- cursor instead of collapsing/expanding. Same two actions the
                -- list uses, so both windows behave the same.
                --
                -- This does give up native `h`/`l` cursor motion inside the filter
                -- text in normal mode. Consistent with `j`/`k`, which snacks
                -- already took for the same reason; `w`/`b`/`0`/`$` and the arrows
                -- still move the cursor.
                ["h"] = { "explorer_close", mode = { "n" }, desc = "Collapse directory" },
                ["l"] = { "confirm", mode = { "n" }, desc = "Expand directory / open file" },
              }),
            },
            list = {
              keys = vim.tbl_extend("force", explorer_window_keys(), {
                ["<Esc>"] = false, -- don't close on Esc
                ["q"] = { "close", mode = { "n" }, desc = "Close explorer" },
                ["/"] = false, -- use vim search instead of explorer filter
                ["?"] = false, -- use vim search instead of help
                ["<C-f>"] = { "explorer_close_all", mode = { "n" } },
                ["<C-c>"] = { "close", mode = { "n" } },
                ["."] = { "explorer_toggle_focus", mode = { "n" }, desc = "Toggle focus folder" },
                -- Double-click opens the file in the right pane without moving
                -- focus there. <CR> is intentionally not bound — keyboard flow
                -- uses snacks's default confirm (which switches focus to the
                -- opened file). Single-click is also unbound, so snacks's
                -- default (focus row, no open) runs.
                ["<2-LeftMouse>"] = { "explorer_open_keep_focus", mode = { "n" }, desc = "Open (keep focus)" },
                -- Previous single-click intercept (kept for reference). Re-enable
                -- by uncommenting if you want click-to-open on the press event,
                -- which avoids the cursor jump between click column and post-
                -- render column 1 but requires manual handling for clicks
                -- outside the list. See `explorer_single_click` action above.
                -- ["<LeftMouse>"] = { "explorer_single_click", mode = { "n" }, desc = "Open or toggle" },
                -- ["<3-LeftMouse>"] = { "explorer_single_click", mode = { "n" }, desc = "Open or toggle" },
                -- ["<4-LeftMouse>"] = { "explorer_single_click", mode = { "n" }, desc = "Open or toggle" },
              }),
            },
          },
        },
      },
      layout = {
        preview = false,
        layout = {
          width = 0.3,
          height = 0.4,
          -- No dim behind a picker. The theme runs `transparent = true`, so the
          -- editor background is Ghostty's, while snacks' backdrop is a
          -- full-editor float of pure black at winblend 60 — with nothing else
          -- painting a background, it renders as a pitch-black screen.
          --
          -- snacks already skips its backdrop for a transparent colorscheme, but
          -- the detection is unreliable here. `Snacks.util.is_transparent()`
          -- samples `Normal`'s background ONCE per session, and `nvim_get_hl`
          -- resolves in the context of the CURRENT WINDOW's `winhighlight`.
          -- Telescope's floats set `Normal:TelescopePromptNormal` and the
          -- lazy.nvim UI sets `Normal:LazyNormal`, both carrying the theme's
          -- opaque `bg_float` (#001419). A picker opened from inside the file
          -- browser — the startup explorer, where <leader><leader> gets pressed
          -- constantly — therefore samples #001419, concludes the theme is
          -- opaque, and caches that until the next ColorScheme. Every popup for
          -- the rest of the session then gets the veil, browser or no browser.
          -- Measurements and the rejected alternatives are in
          -- notes/popup-backdrop-darkening-investigation.md.
          --
          -- Turning it off is what correct detection would do for this theme
          -- anyway, and it cannot regress: no cache, no sampling order, no
          -- dependence on another plugin's winhighlight. Pickers only —
          -- Snacks.input, the notifier and the lazygit terminal keep their own
          -- backdrop settings.
          --
          -- It has to live HERE, inside this table: `picker` already has a
          -- `layout` key, and a second one in the same constructor is silently
          -- dropped by Lua.
          backdrop = false,
        },
      },
    },
  },
  keys = {
    { "<leader>sc", false },
    { "<leader>sC", false },
    { "<leader>so", false },
    -- Disable LazyVim default so diffview.nvim owns <leader>gd
    { "<leader>gd", false },
    { "<leader>gD", false },
    {
      "<leader>xd",
      function()
        Snacks.picker.diagnostics({
          filter = { buf = true },
          layout = {
            preview = true,
            layout = { width = 0.85, height = 0.75 },
          },
        })
      end,
      desc = "Diagnostics (current file)",
    },
    {
      "<leader>xD",
      function()
        Snacks.picker.diagnostics({
          layout = {
            preview = true,
            layout = { width = 0.85, height = 0.75 },
          },
        })
      end,
      desc = "Diagnostics (workspace)",
    },
    {
      "<leader>ss",
      function()
        Snacks.picker.lsp_symbols({
          filter = {
            default = {
              "Function",
              "Method",
              "Class",
              "Interface",
              "Enum",
              "EnumMember",
              "Constructor",
              "TypeParameter",
            },
            typescript = {
              "Function",
              "Method",
              "Class",
              "Interface",
              "Enum",
              "EnumMember",
              "Constructor",
              "TypeParameter",
            },
            typescriptreact = {
              "Function",
              "Method",
              "Class",
              "Interface",
              "Enum",
              "EnumMember",
              "Constructor",
              "TypeParameter",
            },
          },
        })
      end,
      desc = "LSP Symbols (functions/types)",
    },
    {
      "<leader>sc",
      function()
        Snacks.picker.commands()
      end,
      desc = "Commands",
    },
    {
      "<leader>sC",
      function()
        clear_smart_picker_history()
      end,
      desc = "Clear Smart Picker History",
    },
    {
      "<leader>so",
      function()
        Snacks.picker.command_history()
      end,
      desc = "Command History",
    },
    {
      "<leader><leader>",
      function()
        require("snacks").picker.smart()
      end,
      desc = "Find Files smart (both recent and open buffers)",
    },
    {
      "<leader>ff",
      function()
        require("snacks").picker.files()
      end,
      desc = "Find Files (root)",
    },
    {
      "<leader>fi",
      function()
        require("snacks").picker.files({ cwd = vim.fn.expand("%:p:h") })
      end,
      desc = "Find Files (current file dir)",
    },
    { "<leader>e", false },
    { "<leader>E", false },
    {
      "<leader>r",
      function()
        -- Seed the active-file band before the first render (the BufEnter
        -- hook in on_show only covers later buffer switches).
        local name = vim.api.nvim_buf_get_name(0)
        if name ~= "" and vim.bo.buftype == "" then
          explorer_active_file = vim.fs.normalize(name)
        end
        require("snacks").picker.explorer()
      end,
      desc = "Toggle Explorer",
    },
    {
      "<leader>fp",
      function()
        require("snacks").picker.projects()
      end,
      desc = "Switch Project",
    },
  },
}
