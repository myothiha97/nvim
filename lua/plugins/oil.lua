local backdrop_buf = nil
local backdrop_win = nil
local saved_winhl = {}

-- Flip to `true` to switch <leader>e back to the floating popup (original
-- implementation, fully preserved below). `false` opens Oil fullscreen in
-- the current window instead.
local USE_FLOAT = false

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
  backdrop_buf = vim.api.nvim_create_buf(false, true)
  backdrop_win = vim.api.nvim_open_win(backdrop_buf, false, {
    relative = "editor",
    width = vim.o.columns,
    height = vim.o.lines,
    row = 0,
    col = 0,
    style = "minimal",
    focusable = false,
    zindex = 40,
  })
  vim.api.nvim_set_hl(0, "OilBackdrop", { bg = "#000000" })
  vim.wo[backdrop_win].winhighlight = "Normal:OilBackdrop"
  vim.wo[backdrop_win].winblend = 60
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

local function toggle_oil_float()
  local open, win = is_oil_float_open()
  if open then
    close_backdrop()
    if win then
      vim.api.nvim_win_close(win, true)
    end
  else
    create_backdrop()
    require("oil").open_float()
    hide_bg_search_highlights()
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

-- Path label followed by a horizontal divider that fills the rest of the
-- row, separating it from the file list on the line below.
local function set_oil_winbar(win)
  local title = require("oil.util").get_title(win)
  local used = vim.fn.strdisplaywidth(title) + 2 -- leading space + space before divider
  local divider = string.rep("─", math.max(0, vim.api.nvim_win_get_width(win) - used))
  vim.wo[win].winbar = " %#FloatTitle#" .. title .. "%* %#WinSeparator#" .. divider .. "%*"
end

return {
  "stevearc/oil.nvim",
  lazy = false,
  dependencies = { "nvim-tree/nvim-web-devicons" },
  keys = {
    { "<leader>e", toggle_oil, desc = "Toggle Oil" },
  },
  opts = {
    default_file_explorer = true,
    skip_confirm_for_simple_edits = true,
    view_options = { show_hidden = true },
    -- CursorLine is disabled globally (see colorschemes/solarized-osaka/init.lua),
    -- so remap it to OilCursorLine for Oil windows only. Applied once per
    -- window by Oil itself — no CursorMoved autocmd, zero hot-path cost.
    win_options = {
      cursorline = true,
      winhighlight = "CursorLine:OilCursorLine",
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
      max_width = 0.8,
      max_height = 0.8,
      border = "rounded",
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
