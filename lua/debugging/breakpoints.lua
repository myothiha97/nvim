-- Persistent breakpoints, per project (the cwd Neovim was started in).
--
-- Stored in stdpath("data")/debugging/breakpoints/<cwd>.json:
--   { files = { [abs path] = { {line, condition, hitCondition, logMessage} } },
--     functions = { "main.worker", ... } }
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
        data.files[name] = #list > 0 and list or nil
      end
    end
  end
  data.functions = vim.deepcopy(require("debugging.delve").fn_breakpoints)
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
  for _, bp in ipairs(saved) do
    if bp.line <= line_count then
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

-- Toggle the breakpoint on one line (gutter click, right-click menu) and
-- push the file's list to running sessions.
function M.toggle(buf, line)
  local bps = require("dap.breakpoints") -- loads nvim-dap on first use
  bps.toggle({}, buf, line)
  -- Running sessions need the buffer's full list; the key must be present
  -- even when the list is now empty, or the removal isn't sent.
  local list = { [buf] = bps.get(buf)[buf] or {} }
  for _, session in pairs(require("dap").sessions()) do
    session:set_breakpoints(list)
  end
  M.save()
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
  if #in_buf == 0 then
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
  vim.notify(("Cleared %d breakpoint%s"):format(#in_buf, #in_buf == 1 and "" or "s"))
end

-- Clear everything for this project: loaded files, unloaded saved files and
-- function breakpoints.
function M.clear_all()
  require("dap").clear_breakpoints()
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
