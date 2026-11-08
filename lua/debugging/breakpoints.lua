-- Persistent breakpoints, per project (the cwd Neovim was started in).
--
-- Stored in stdpath("data")/debugging/breakpoints/<cwd>.json:
--   { files = { [abs path] = { {line, condition, hitCondition, logMessage, disabled?} } },
--     functions = { "main.worker", ... } }
--
-- Disabled breakpoints (JetBrains "Disable", <leader>dd / right-click): nvim-dap
-- has no disabled state, so a disabled breakpoint is removed from nvim-dap
-- (never sent to the adapter) and kept here as a grey sign in our own sign
-- group, which moves with edits like nvim-dap's own signs. Mute All
-- (<leader>dD) disables every breakpoint the same way, marked `muted`, until
-- unmuted; muting is not saved (a restart comes back unmuted).
--
-- Cost: one BufReadPost autocmd that does a table lookup on a cached decode.
-- nvim-dap is only loaded when a file that HAS saved breakpoints is opened
-- (its signs must be defined before they can be placed). Saving runs on
-- breakpoint actions, buffer unload, session start and VimLeavePre, never on
-- keystrokes or cursor moves.

local M = {}

local cache ---@type {files: table<string, table[]>, functions: string[]}?
local cache_cwd
local last_written ---@type string? JSON last written, to skip identical writes

local GROUP = "debugging_disabled" -- sign group of disabled breakpoints
local SIGN = "DapBreakpointDisabled"
local disabled = {} ---@type table<integer, table<integer, table>> buf -> sign id -> {condition, hitCondition, logMessage, muted}
local muted = false
local muted_fns ---@type string[]? function breakpoints put aside while muted

local function store_path(cwd)
  local name = cwd:gsub("[/\\:]", "%%")
  return vim.fs.joinpath(vim.fn.stdpath("data"), "debugging", "breakpoints", name .. ".json")
end

local function load()
  local cwd = vim.fn.getcwd()
  if cache and cache_cwd == cwd then
    return cache
  end
  cache_cwd, cache = cwd, { files = {}, functions = {} }
  local fd = io.open(store_path(cwd), "r")
  if fd then
    local ok, data = pcall(vim.json.decode, fd:read("*a"))
    fd:close()
    if ok and type(data) == "table" then
      cache.files = type(data.files) == "table" and data.files or {}
      cache.functions = type(data.functions) == "table" and data.functions or {}
    end
  end
  return cache
end

local function write(data)
  local json = vim.json.encode(data)
  if json == last_written then
    return
  end
  local path = store_path(cache_cwd)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  local fd = io.open(path, "w")
  if fd then
    fd:write(json)
    fd:close()
    last_written = json
  end
end

-- Disabled breakpoints of a buffer: { {id, line, bp}, ... } from our signs.
local function disabled_in(buf)
  local meta = disabled[buf]
  if not meta or not next(meta) then
    return {}
  end
  local out = {}
  local placed = vim.fn.sign_getplaced(buf, { group = GROUP })[1]
  for _, sign in ipairs(placed and placed.signs or {}) do
    if meta[sign.id] then
      out[#out + 1] = { id = sign.id, line = sign.lnum, bp = meta[sign.id] }
    end
  end
  return out
end

local function disabled_at(buf, line)
  for _, d in ipairs(disabled_in(buf)) do
    if d.line == line then
      return d
    end
  end
end

local function place_disabled(buf, line, bp)
  if vim.tbl_isempty(vim.fn.sign_getdefined(SIGN)) then
    -- Same icon as an enabled breakpoint (LazyVim defines DapBreakpoint when
    -- nvim-dap loads), greyed. Theme it via the DapBreakpointDisabled group.
    local base = vim.fn.sign_getdefined("DapBreakpoint")[1]
    vim.api.nvim_set_hl(0, SIGN, { link = "Comment", default = true })
    vim.fn.sign_define(SIGN, { text = base and base.text or "●", texthl = SIGN })
  end
  local id = vim.fn.sign_place(0, GROUP, SIGN, buf, { lnum = line, priority = 21 })
  disabled[buf] = disabled[buf] or {}
  disabled[buf][id] = bp
end

local function unplace_disabled(buf, id)
  vim.fn.sign_unplace(GROUP, { buffer = buf, id = id })
  disabled[buf][id] = nil
end

local function bp_at(buf, line)
  for _, bp in ipairs(require("dap.breakpoints").get(buf)[buf] or {}) do
    if bp.line == line then
      return bp
    end
  end
end

-- Send a buffer's breakpoints to running sessions. The key must be present
-- even when the list is empty, or a removal isn't sent.
local function push(buf)
  local list = { [buf] = require("dap.breakpoints").get(buf)[buf] or {} }
  for _, session in pairs(require("dap").sessions()) do
    session:set_breakpoints(list)
  end
end

-- Snapshot breakpoints of every loaded file into the store. Files that are
-- not loaded keep their saved entries; loaded files are replaced (so clearing
-- a file's breakpoints clears them on disk too).
function M.save()
  if not package.loaded["dap"] then
    return -- nothing can have changed: no breakpoint was ever set this session
  end
  -- Run to Cursor removes every breakpoint until the next stop; nvim-dap
  -- registers this listener (public listeners table, nvim-dap's own key) to
  -- put them back. Saving now would persist the cleared state, so skip it:
  -- every real change was already saved when it was made.
  if require("dap").listeners.before.event_stopped["dap.run_to_cursor"] then
    return
  end
  local data = load()
  local current = require("dap.breakpoints").get()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) and vim.bo[bufnr].buftype == "" then
      local name = vim.api.nvim_buf_get_name(bufnr)
      if name ~= "" then
        local list = {}
        for _, bp in ipairs(current[bufnr] or {}) do
          table.insert(list, {
            line = bp.line,
            condition = bp.condition,
            hitCondition = bp.hitCondition,
            logMessage = bp.logMessage,
          })
        end
        local off = disabled_in(bufnr)
        for _, d in ipairs(off) do
          table.insert(list, {
            line = d.line,
            condition = d.bp.condition,
            hitCondition = d.bp.hitCondition,
            logMessage = d.bp.logMessage,
            disabled = not d.bp.muted or nil, -- muting is not saved
          })
        end
        if #off > 0 then
          table.sort(list, function(a, b)
            return a.line < b.line
          end)
        end
        data.files[name] = #list > 0 and list or nil
      end
    end
  end
  data.functions = vim.deepcopy(muted_fns or require("debugging.delve").fn_breakpoints)
  write(data)
end

-- Place saved breakpoints in a freshly read buffer.
local function restore(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  local saved = load().files[name]
  if not saved then
    return
  end
  local bps = require("dap.breakpoints") -- loads nvim-dap (defines the signs)
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  -- Also runs when a loaded buffer is re-read (:e), which keeps its signs:
  -- drop ours first so disabled breakpoints aren't placed twice.
  vim.fn.sign_unplace(GROUP, { buffer = bufnr })
  disabled[bufnr] = nil
  for _, bp in ipairs(saved) do
    if bp.line <= line_count and (bp.disabled or muted) then
      place_disabled(bufnr, bp.line, {
        condition = bp.condition,
        hitCondition = bp.hitCondition,
        logMessage = bp.logMessage,
        muted = not bp.disabled or nil,
      })
    elseif bp.line <= line_count then
      bps.set({
        condition = bp.condition,
        hit_condition = bp.hitCondition,
        log_message = bp.logMessage,
      }, bufnr, bp.line)
    end
  end
  -- A session may already be running (file opened mid-debug).
  for _, session in pairs(require("dap").sessions()) do
    session:set_breakpoints(bps.get(bufnr))
  end
end

-- nvim-dap swaps a breakpoint's sign to DapBreakpointRejected when the
-- adapter answers `verified = false`, and never swaps it back when the session
-- ends, so a stale red "rejected" icon stayed after Stop. Re-place every
-- breakpoint with its normal sign (same line, condition, hit count, log).
function M.reset_signs()
  if not package.loaded["dap"] then
    return
  end
  local bps = require("dap.breakpoints")
  -- Re-place ALL of them, not only `verified == false`: nvim-dap paints the
  -- rejected sign for any falsy `verified`, and Delve can also flag them
  -- while detaching. Cheap: a handful of sign_place calls at session end.
  for bufnr, list in pairs(bps.get()) do
    for _, bp in ipairs(list) do
      if bp.state then
        bps.set({
          condition = bp.condition,
          hit_condition = bp.hitCondition,
          log_message = bp.logMessage,
        }, bufnr, bp.line)
      end
    end
  end
end

-- Remove a disabled breakpoint on the line; true if there was one.
-- (A click or <leader>db on a disabled breakpoint removes it, as in JetBrains.)
function M.remove_disabled(buf, line)
  local d = disabled_at(buf, line)
  if d then
    unplace_disabled(buf, d.id)
    M.save()
  end
  return d ~= nil
end

-- The disabled breakpoint's details on the line, if any (prompts.lua edits it).
function M.disabled_bp(buf, line)
  local d = disabled_at(buf, line)
  return d and d.bp
end

-- Toggle the breakpoint on one line (gutter click, right-click menu) and
-- push the file's list to running sessions.
function M.toggle(buf, line)
  if M.remove_disabled(buf, line) then
    return
  end
  local bps = require("dap.breakpoints") -- loads nvim-dap on first use
  bps.toggle({}, buf, line)
  push(buf)
  M.save()
end

-- Disable / enable the breakpoint on a line, keeping its condition, hit
-- count and log message. Nothing happens on a line with no breakpoint.
function M.toggle_enabled(buf, line)
  local d = disabled_at(buf, line)
  local bps = require("dap.breakpoints")
  if d then
    unplace_disabled(buf, d.id)
    bps.set({ condition = d.bp.condition, hit_condition = d.bp.hitCondition, log_message = d.bp.logMessage }, buf, line)
  else
    local bp = bp_at(buf, line)
    if not bp then
      vim.notify("No breakpoint on this line", vim.log.levels.INFO)
      return
    end
    bps.remove(buf, line)
    place_disabled(buf, line, { condition = bp.condition, hitCondition = bp.hitCondition, logMessage = bp.logMessage })
  end
  push(buf)
  M.save()
end

function M.is_muted()
  return muted
end

-- Mute All / Unmute (JetBrains "Mute Breakpoints"): line breakpoints in open
-- files and function breakpoints stop being sent; individually disabled
-- breakpoints stay disabled after unmuting. Breakpoints added while muted
-- are active (unlike JetBrains, which mutes those too).
function M.toggle_mute()
  local bps = require("dap.breakpoints")
  local delve = require("debugging.delve")
  local count = 0
  if not muted then
    for buf, list in pairs(bps.get()) do
      for _, bp in ipairs(list) do
        bps.remove(buf, bp.line)
        place_disabled(buf, bp.line, {
          condition = bp.condition,
          hitCondition = bp.hitCondition,
          logMessage = bp.logMessage,
          muted = true,
        })
        count = count + 1
      end
      push(buf)
    end
    muted_fns, delve.fn_breakpoints = delve.fn_breakpoints, {}
  else
    for buf in pairs(disabled) do
      if vim.api.nvim_buf_is_valid(buf) then
        for _, d in ipairs(disabled_in(buf)) do
          if d.bp.muted then
            unplace_disabled(buf, d.id)
            bps.set({ condition = d.bp.condition, hit_condition = d.bp.hitCondition, log_message = d.bp.logMessage }, buf, d.line)
            count = count + 1
          end
        end
        push(buf)
      end
    end
    for _, name in ipairs(delve.fn_breakpoints) do -- added while muted
      if not vim.tbl_contains(muted_fns, name) then
        table.insert(muted_fns, name)
      end
    end
    delve.fn_breakpoints, muted_fns = muted_fns, nil
  end
  muted = not muted
  for _, session in pairs(require("dap").sessions()) do
    if session.capabilities.supportsFunctionBreakpoints and (#delve.fn_breakpoints > 0 or (muted_fns and #muted_fns > 0)) then
      delve.sync_fn_breakpoints(session)
    end
  end
  M.save()
  vim.notify(muted and ("Breakpoints muted (%d)"):format(count) or ("Breakpoints unmuted (%d)"):format(count))
end

-- Picker items (debugging/list.lua) for one buffer, or the whole project
-- when bufnr is nil. Project scope also lists saved breakpoints of files that
-- aren't open. Runs only when the list is opened.
function M.list(bufnr)
  local items, open_files = {}, {}
  local function add(file, bp, code)
    local notes = {}
    if bp.condition then
      notes[#notes + 1] = "if " .. bp.condition
    end
    if bp.hitCondition then
      notes[#notes + 1] = "hit " .. bp.hitCondition
    end
    if bp.logMessage then
      notes[#notes + 1] = "log " .. bp.logMessage
    end
    if bp.disabled then
      notes[#notes + 1] = "disabled"
    end
    local comment = #notes > 0 and table.concat(notes, " · ") or nil
    code = code and vim.trim(code) or nil
    items[#items + 1] = {
      file = file,
      pos = { bp.line, 0 },
      comment = comment,
      line = code,
      text = ("%s:%d %s %s"):format(file, bp.line, comment or "", code or ""),
    }
  end
  if package.loaded["dap"] then
    for buf, list in pairs(require("dap.breakpoints").get(bufnr)) do
      local name = vim.api.nvim_buf_get_name(buf)
      for _, bp in ipairs(list) do
        add(name, bp, vim.api.nvim_buf_get_lines(buf, bp.line - 1, bp.line, false)[1])
      end
    end
    for buf in pairs(disabled) do
      if vim.api.nvim_buf_is_valid(buf) and (not bufnr or buf == bufnr) then
        local name = vim.api.nvim_buf_get_name(buf)
        for _, d in ipairs(disabled_in(buf)) do
          local bp = vim.tbl_extend("force", d.bp, { line = d.line, disabled = true })
          add(name, bp, vim.api.nvim_buf_get_lines(buf, d.line - 1, d.line, false)[1])
        end
      end
    end
  end
  if not bufnr then
    -- Open files are covered above (their saved entries may be stale).
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(buf) then
        open_files[vim.api.nvim_buf_get_name(buf)] = true
      end
    end
    for name, list in pairs(load().files) do
      if not open_files[name] then
        for _, bp in ipairs(list) do
          local ok, lines = pcall(vim.fn.readfile, name, "", bp.line)
          add(name, bp, ok and lines[bp.line] or nil)
        end
      end
    end
  end
  table.sort(items, function(a, b)
    if a.file ~= b.file then
      return a.file < b.file
    end
    return a.pos[1] < b.pos[1]
  end)
  return items
end

-- Clear every breakpoint in the current file, in the store and in any
-- running session.
function M.clear_buffer()
  local bps = require("dap.breakpoints")
  local bufnr = vim.api.nvim_get_current_buf()
  local in_buf = bps.get(bufnr)[bufnr] or {}
  local off = disabled_in(bufnr)
  for _, d in ipairs(off) do
    unplace_disabled(bufnr, d.id)
  end
  if #in_buf == 0 and #off == 0 then
    vim.notify("No breakpoints in this file", vim.log.levels.INFO)
    return
  end
  for _, bp in ipairs(in_buf) do
    bps.remove(bufnr, bp.line)
  end
  for _, session in pairs(require("dap").sessions()) do
    session:set_breakpoints({ [bufnr] = {} })
  end
  M.save()
  local n = #in_buf + #off
  vim.notify(("Cleared %d breakpoint%s"):format(n, n == 1 and "" or "s"))
end

-- Clear everything for this project: loaded files, unloaded saved files and
-- function breakpoints.
function M.clear_all()
  require("dap").clear_breakpoints()
  vim.fn.sign_unplace(GROUP)
  disabled, muted, muted_fns = {}, false, nil
  require("debugging.delve").fn_breakpoints = {}
  require("debugging.delve").sync_fn_breakpoints()
  load()
  cache.files, cache.functions = {}, {}
  write(cache)
  vim.notify("Cleared all breakpoints in this project")
end

-- Called from the nvim-dap spec's `init`, i.e. at startup without loading dap.
function M.setup()
  local group = vim.api.nvim_create_augroup("debugging_breakpoints", { clear = true })
  vim.api.nvim_create_autocmd("BufReadPost", {
    group = group,
    callback = function(args)
      if vim.bo[args.buf].buftype == "" then
        restore(args.buf)
      end
    end,
  })
  -- Signs disappear with the buffer, so snapshot before that happens. Only
  -- file buffers can hold breakpoints; pickers, panels and terminals skip it.
  vim.api.nvim_create_autocmd("BufUnload", {
    group = group,
    callback = function(args)
      if vim.bo[args.buf].buftype == "" and args.file ~= "" then
        M.save()
      end
    end,
  })
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      M.save()
    end,
  })
  vim.api.nvim_create_autocmd("DirChanged", {
    group = group,
    callback = function()
      cache, last_written = nil, nil
    end,
  })
  -- Function breakpoints come back for the next session.
  local functions = load().functions
  if #functions > 0 then
    require("debugging.delve").fn_breakpoints = vim.deepcopy(functions)
  end
end

return M
