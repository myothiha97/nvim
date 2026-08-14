-- LSP hover on mouse hover (Zed/WebStorm parity).
-- Performance design:
--   * Cell-position dedup short-circuits ~99% of MouseMove events in O(1).
--   * Reuses a single vim.uv timer rather than allocating per event.
--   * LSP request only fires after the mouse has been still for DELAY_MS.
--   * Request token discards stale responses arriving after the mouse moved.
-- UX design:
--   * Popup stays open while the mouse is on the same word that triggered it
--     OR over the popup itself.
--   * Move off both and it closes immediately.

local M = {}

local DELAY_MS = 500

local SKIP_FT = {
  oil = true,
  Avante = true,
  AvanteInput = true,
  AvanteSelectedFiles = true,
  TelescopePrompt = true,
  noice = true,
  trouble = true,
  snacks_picker_list = true,
  snacks_picker_input = true,
  snacks_dashboard = true,
  snacks_terminal = true,
  DiffviewFiles = true,
  DiffviewFileHistory = true,
  diff = true,
  git = true,
  help = true,
  man = true,
  qf = true,
  lazy = true,
  mason = true,
}

local MENU_COOLDOWN_MS = 2000
local MOVE_THROTTLE_MS = 16 -- ~60Hz cap on MouseMove processing

local hover_timer
local restore_timer -- re-enables mousemoveevent after menu cooldown
local hover_win
local hover_anchor -- { winid, line, col_start, col_end } — the word that triggered the popup
local hover_geom -- { top, bottom, left, right } — popup's absolute screen rect, including border
local pending_focus_win -- popup window that a deferred <LeftMouse> focus is trying to enter
local enabled = true -- user-facing on/off via M.toggle; gates the menu-cooldown restore
local mousemove_mapped = false
local leftmouse_guard_mapped = false
local leftmouse_previous_maps = {}
local request_id = 0
local last_line, last_col, last_winid = 0, 0, 0
local last_move_at = 0 -- ms timestamp of last processed MouseMove
local menu_suppress_until = 0 -- ms timestamp; suppress hover while right-click menu is/was active
local LEFTMOUSE_TERMCODES -- pre-computed at setup() so the LeftMouse keymap is allocation-free on the no-popup path
local disable_leftmouse_guard

local function close_win(winid)
  if winid and vim.api.nvim_win_is_valid(winid) then
    pcall(vim.api.nvim_win_close, winid, true)
  end
end

local function dispose_timer(timer)
  if timer then
    pcall(function()
      timer:stop()
      if not timer:is_closing() then
        timer:close()
      end
    end)
  end
end

local function close_hover()
  close_win(hover_win)

  -- Also close any LSP hover float that was opened by a normal K/right-click
  -- path instead of this mouse-hover module, so right-click behavior stays
  -- consistent regardless of how the hover appeared.
  local current_win = vim.api.nvim_get_current_win()
  local candidates = {}
  if vim.api.nvim_win_is_valid(current_win) then
    candidates[#candidates + 1] = vim.api.nvim_win_get_buf(current_win)
    local ok_source, source_buf = pcall(vim.api.nvim_win_get_var, current_win, "lsp_floating_bufnr")
    if ok_source and type(source_buf) == "number" then
      candidates[#candidates + 1] = source_buf
    end
  end
  if hover_anchor and vim.api.nvim_win_is_valid(hover_anchor.winid) then
    candidates[#candidates + 1] = vim.api.nvim_win_get_buf(hover_anchor.winid)
  end
  for _, bufnr in ipairs(candidates) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      close_win(vim.b[bufnr].lsp_floating_preview)
      vim.b[bufnr].lsp_floating_preview = nil
    end
  end

  hover_win = nil
  hover_anchor = nil
  hover_geom = nil
  pending_focus_win = nil
  disable_leftmouse_guard()
end

-- Walk left/right from (line, col) to find word boundaries. Returns nil if
-- the column isn't on a word character (operator, whitespace, punctuation).
local function word_bounds(bufnr, line, col)
  if line < 1 or col < 1 then
    return nil
  end
  local lines = vim.api.nvim_buf_get_lines(bufnr, line - 1, line, false)
  local text = lines[1]
  if not text or col > #text then
    return nil
  end
  if not text:sub(col, col):match("[%w_]") then
    return nil
  end

  local s = col
  while s > 1 and text:sub(s - 1, s - 1):match("[%w_]") do
    s = s - 1
  end
  local e = col
  while e < #text and text:sub(e + 1, e + 1):match("[%w_]") do
    e = e + 1
  end
  return s, e
end

-- Capture the popup's absolute screen rect (including border padding) so
-- on_mouse_move can detect "mouse is over the popup" without relying on
-- getmousepos().winid (which is unreliable for non-focusable floats).
local function capture_geom(winid)
  local ok_pos, rc = pcall(vim.api.nvim_win_get_position, winid)
  local ok_h, h = pcall(vim.api.nvim_win_get_height, winid)
  local ok_w, w = pcall(vim.api.nvim_win_get_width, winid)
  local ok_cfg, cfg = pcall(vim.api.nvim_win_get_config, winid)
  if not (ok_pos and ok_h and ok_w and ok_cfg) then
    return nil
  end

  local has_border = cfg.border and cfg.border ~= "none" and (type(cfg.border) ~= "string" or cfg.border ~= "")
  local pad = has_border and 1 or 0

  return {
    top = rc[1] + 1 - pad,
    bottom = rc[1] + 1 + h + pad, -- exclusive
    left = rc[2] + 1 - pad,
    right = rc[2] + 1 + w + pad, -- exclusive
  }
end

local function mouse_over_popup(pos)
  if not hover_geom then
    return false
  end
  return pos.screenrow >= hover_geom.top
    and pos.screenrow < hover_geom.bottom
    and pos.screencol >= hover_geom.left
    and pos.screencol < hover_geom.right
end

local function mouse_click_on_popup(pos, winid)
  if not winid or not vim.api.nvim_win_is_valid(winid) then
    return false
  end
  hover_geom = capture_geom(winid) or hover_geom
  return pos.winid == winid or mouse_over_popup(pos)
end

disable_leftmouse_guard = function()
  if leftmouse_guard_mapped then
    for _, mode in ipairs({ "n", "i", "v" }) do
      pcall(vim.keymap.del, mode, "<LeftMouse>")
      local previous = leftmouse_previous_maps[mode]
      if previous and previous.lhs then
        pcall(vim.fn.mapset, mode, false, previous)
      end
    end
    leftmouse_previous_maps = {}
    leftmouse_guard_mapped = false
  end
end

local function on_left_mouse()
  local target_win = hover_win
  if target_win and vim.api.nvim_win_is_valid(target_win) then
    local pos = vim.fn.getmousepos()
    if mouse_click_on_popup(pos, target_win) then
      pending_focus_win = target_win
      vim.schedule(function()
        if hover_win == target_win and vim.api.nvim_win_is_valid(target_win) then
          vim.api.nvim_set_current_win(target_win)
        end
        if pending_focus_win == target_win then
          pending_focus_win = nil
        end
      end)
      return
    end
    close_hover()
  end
  vim.api.nvim_feedkeys(LEFTMOUSE_TERMCODES, "n", false)
end

local function enable_leftmouse_guard()
  if not leftmouse_guard_mapped then
    leftmouse_previous_maps = {}
    for _, mode in ipairs({ "n", "i", "v" }) do
      local previous = vim.fn.maparg("<LeftMouse>", mode, false, true)
      if previous and previous.lhs then
        leftmouse_previous_maps[mode] = previous
      end
    end
    vim.keymap.set({ "n", "i", "v" }, "<LeftMouse>", on_left_mouse, { silent = true })
    leftmouse_guard_mapped = true
  end
end

local function fire_hover(pos)
  local now = vim.fn.getmousepos()
  if now.line ~= pos.line or now.column ~= pos.column or now.winid ~= pos.winid then
    return
  end
  if not vim.api.nvim_win_is_valid(pos.winid) then
    return
  end

  local bufnr = vim.api.nvim_win_get_buf(pos.winid)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  -- LSP servers may return the nearest parent symbol for whitespace or
  -- punctuation. Require an actual word under the pointer before requesting.
  local word_start, word_end = word_bounds(bufnr, pos.line, pos.column)
  if not word_start then
    return
  end

  local clients = vim.lsp.get_clients({ bufnr = bufnr, method = "textDocument/hover" })
  if #clients == 0 then
    return
  end

  request_id = request_id + 1
  local my_id = request_id
  local shown = false

  local params = {
    textDocument = { uri = vim.uri_from_bufnr(bufnr) },
    position = { line = pos.line - 1, character = pos.column - 1 },
  }

  vim.lsp.buf_request(bufnr, "textDocument/hover", params, function(err, result)
    if my_id ~= request_id or shown then
      return
    end
    if err or not result or not result.contents then
      return
    end

    local current = vim.fn.getmousepos()
    if current.line ~= pos.line or current.column ~= pos.column or current.winid ~= pos.winid then
      return
    end

    local contents = vim.lsp.util.convert_input_to_markdown_lines(result.contents)
    if not contents or vim.tbl_isempty(contents) then
      return
    end
    -- Bail when there is no visible text. open_floating_preview strips blank
    -- markdown lines internally; whitespace-only contents would collapse to
    -- zero lines and crash nvim_open_win with "Invalid 'height'".
    local has_text = false
    for _, line in ipairs(contents) do
      if line:match("%S") then
        has_text = true
        break
      end
    end
    if not has_text then
      return
    end

    close_hover()
    local ok, pbuf, winid = pcall(vim.lsp.util.open_floating_preview, contents, "markdown", {
      border = "rounded",
      max_width = 80,
      max_height = 20,
      focusable = true, -- needed so getmousepos().winid matches when mouse is over the popup
      relative = "mouse",
      anchor_bias = "below",
      close_events = {},
    })
    if not ok then
      return
    end
    hover_win = winid
    shown = true

    if winid then
      hover_geom = capture_geom(winid)
      enable_leftmouse_guard()
      -- Marker so the <Tab> keymap in config.keymaps doesn't accidentally
      -- focus this popup when iterating focusable floats.
      if pbuf then
        pcall(vim.api.nvim_buf_set_var, pbuf, "mouse_hover_popup", true)
      end
    end

    hover_anchor = {
      winid = pos.winid,
      line = pos.line,
      col_start = word_start,
      col_end = word_end,
    }
  end)
end

local function on_mouse_move()
  local pos = vim.fn.getmousepos()

  if pos.line == last_line and pos.column == last_col and pos.winid == last_winid then
    return
  end
  last_line, last_col, last_winid = pos.line, pos.column, pos.winid

  local now_ms = vim.uv.now()

  -- Suppressed during right-click menu interaction (and a short cooldown after).
  if now_ms < menu_suppress_until then
    if hover_timer then
      hover_timer:stop()
    end
    return
  end

  if last_move_at > 0 and now_ms - last_move_at < MOVE_THROTTLE_MS then
    return
  end
  last_move_at = now_ms

  -- Over the popup itself: prefer winid match (focusable=true makes this reliable),
  -- fall back to geometry for safety.
  if hover_win and (pos.winid == hover_win or mouse_over_popup(pos)) then
    if hover_timer then
      hover_timer:stop()
    end
    return
  end

  -- Still on the word that triggered the popup.
  if
    hover_anchor
    and pos.winid == hover_anchor.winid
    and pos.line == hover_anchor.line
    and pos.column >= hover_anchor.col_start
    and pos.column <= hover_anchor.col_end
  then
    if hover_timer then
      hover_timer:stop()
    end
    return
  end

  -- Mouse drifted off the anchor — usually close. EXCEPTION: if the popup
  -- is currently focused, the user is inspecting it (clicked into it for
  -- scrolling/reading), so leave it alone — Esc or focusing another window
  -- will close it via the existing autocmd handlers.
  if hover_win and vim.api.nvim_win_is_valid(hover_win) then
    if vim.api.nvim_get_current_win() == hover_win then
      if hover_timer then
        hover_timer:stop()
      end
      return
    end
    close_hover()
  end
  if hover_timer then
    hover_timer:stop()
  end

  if pos.winid == 0 or pos.line == 0 then
    return
  end
  if not vim.api.nvim_win_is_valid(pos.winid) then
    return
  end
  local bufnr = vim.api.nvim_win_get_buf(pos.winid)
  if SKIP_FT[vim.bo[bufnr].filetype] or vim.bo[bufnr].buftype ~= "" then
    return
  end

  hover_timer:start(
    DELAY_MS,
    0,
    vim.schedule_wrap(function()
      fire_hover(pos)
    end)
  )
end

local function enable_mousemove()
  if not mousemove_mapped then
    vim.keymap.set({ "n", "i", "v" }, "<MouseMove>", on_mouse_move, { silent = true })
    mousemove_mapped = true
  end
  vim.o.mousemoveevent = true
end

local function disable_mousemove()
  if mousemove_mapped then
    for _, mode in ipairs({ "n", "i", "v" }) do
      pcall(vim.keymap.del, mode, "<MouseMove>")
    end
    mousemove_mapped = false
  end
  vim.o.mousemoveevent = false
end

local function suppress_for_menu()
  menu_suppress_until = vim.uv.now() + MENU_COOLDOWN_MS
  request_id = request_id + 1
  last_move_at = 0
  if hover_timer then
    hover_timer:stop()
  end
  close_hover()

  -- Disable mousemove handling entirely while the menu is active. Neovim's
  -- popup menu treats <MouseMove> input as a reason to dismiss, so the hover
  -- feature must remove both the event source and its mapping during this
  -- interaction.
  disable_mousemove()
  if restore_timer then
    restore_timer:stop()
  end
  restore_timer:start(
    MENU_COOLDOWN_MS,
    0,
    vim.schedule_wrap(function()
      -- Skip re-enable if the user toggled hover off during the cooldown,
      -- otherwise the menu interaction would silently revive the feature.
      if enabled then
        enable_mousemove()
      end
    end)
  )
end

function M.toggle()
  enabled = not enabled
  if enabled then
    -- Discard stale request_ids and reset position cache so the first
    -- post-enable MouseMove can't trigger an immediate hover from old state.
    request_id = request_id + 1
    last_line, last_col, last_winid = 0, 0, 0
    last_move_at = 0
    menu_suppress_until = 0
    enable_mousemove()
  else
    if hover_timer then
      hover_timer:stop()
    end
    if restore_timer then
      restore_timer:stop()
    end
    close_hover()
    disable_mousemove()
  end
  vim.notify("Mouse hover " .. (enabled and "enabled" or "disabled"), vim.log.levels.INFO, { title = "Mouse Hover" })
end

function M.setup()
  close_hover()
  dispose_timer(hover_timer)
  dispose_timer(restore_timer)

  hover_timer = vim.uv.new_timer()
  restore_timer = vim.uv.new_timer()
  LEFTMOUSE_TERMCODES = vim.api.nvim_replace_termcodes("<LeftMouse>", true, true, true)
  enabled = true
  request_id = request_id + 1
  last_line, last_col, last_winid = 0, 0, 0
  last_move_at = 0
  menu_suppress_until = 0

  local group = vim.api.nvim_create_augroup("config_mouse_hover", { clear = true })

  enable_mousemove()

  vim.keymap.set("n", "<leader>uH", M.toggle, { desc = "Toggle Mouse Hover" })

  -- Fires just before the native right-click popup menu is shown. Keep
  -- <RightMouse> unmapped so Neovim's mousemodel path behaves normally.
  vim.api.nvim_create_autocmd("MenuPopup", {
    group = group,
    callback = suppress_for_menu,
  })

  -- BufLeave/ModeChanged fire BEFORE the new window is current, so we defer
  -- one tick to check whether focus actually shifted into the popup. If yes,
  -- skip close — otherwise the popup would self-destruct on click-to-focus.
  -- FocusLost (Neovim loses OS focus) always closes, no deferral needed.
  vim.api.nvim_create_autocmd({ "ModeChanged", "BufLeave" }, {
    group = group,
    callback = function()
      vim.schedule(function()
        if pending_focus_win and hover_win == pending_focus_win and vim.api.nvim_win_is_valid(pending_focus_win) then
          return
        end
        if hover_win and vim.api.nvim_win_is_valid(hover_win) and vim.api.nvim_get_current_win() == hover_win then
          return
        end
        -- If focus shifted into ANY floating window (e.g. native LSP hover
        -- via gk, signature help, diagnostic float), the user wants to
        -- inspect it — don't tear down LSP previews from under them.
        local cur = vim.api.nvim_get_current_win()
        if
          vim.api.nvim_win_is_valid(cur)
          and vim.api.nvim_win_get_config(cur).relative ~= ""
        then
          return
        end
        close_hover()
      end)
    end,
  })

  vim.api.nvim_create_autocmd("FocusLost", { group = group, callback = close_hover })

  vim.api.nvim_create_autocmd("WinClosed", {
    group = group,
    callback = function(args)
      if hover_win and tonumber(args.match) == hover_win then
        hover_win = nil
        hover_anchor = nil
        hover_geom = nil
        pending_focus_win = nil
        disable_leftmouse_guard()
      end
    end,
  })
end

return M
