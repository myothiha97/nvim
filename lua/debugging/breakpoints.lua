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
  local path = store_path(cache_cwd)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  local fd = io.open(path, "w")
  if fd then
    fd:write(vim.json.encode(data))
    fd:close()
  end
end

-- Snapshot breakpoints of every loaded file into the store. Files that are
-- not loaded keep their saved entries; loaded files are replaced (so clearing
-- a file's breakpoints clears them on disk too).
function M.save()
  if not package.loaded["dap"] then
    return -- nothing can have changed: no breakpoint was ever set this session
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
  -- Signs disappear with the buffer, so snapshot before that happens.
  vim.api.nvim_create_autocmd({ "BufUnload", "VimLeavePre" }, {
    group = group,
    callback = function()
      M.save()
    end,
  })
  vim.api.nvim_create_autocmd("DirChanged", {
    group = group,
    callback = function()
      cache = nil
    end,
  })
  -- Function breakpoints come back for the next session.
  local functions = load().functions
  if #functions > 0 then
    require("debugging.delve").fn_breakpoints = vim.deepcopy(functions)
  end
end

return M
