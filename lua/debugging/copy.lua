-- Copy Value (VS Code / JetBrains): `y` or right-click -> Copy Value on a row
-- of the Variables or Watches panel puts that value in the clipboard.
--
-- The value comes from the adapter, not from the panel text: the row's
-- variable is looked up again with DAP requests, and when the adapter
-- supports it (debugpy, js-debug, Delve) its full value is fetched with an
-- `evaluate` in the "clipboard" context, as VS Code does. That gives the
-- whole string or struct instead of the shortened form a panel shows.
--
-- Finding the row's variable: dap-ui gives no public way to ask which variable
-- a line shows, so this reads its rendering: the name is the text it
-- highlights as DapUIVariable, the parent is the nearest row above that is
-- indented less, the root is a DapUIScope row (Variables) or a watch
-- header (DapUIWatchesValue / DapUIWatchesError).
-- !! Depends on those dap-ui highlight groups and `dapui.render.canvas`
-- `.namespace` (README "Upstream internals"). If dap-ui changes them, `y`
-- reports "Nothing to copy here" and nothing else is affected.
--
-- Copy Stack (JetBrains): `y` or right-click in the Call Stack panel copies
-- the stopped thread's frames as text, one "function  file:line" per line,
-- runtime frames included (one DAP stackTrace request).
--
-- Cost: runs only on `y` / the menu entry; a few DAP requests per copy.

local M = {}
local api = vim.api

local ROOTS = { DapUIScope = "scope", DapUIWatchesValue = "watch", DapUIWatchesError = "watch" }

-- hl group -> { col, text } for the marks that start on `row` (0-based).
local function marks(buf, ns, row)
  local line = api.nvim_buf_get_lines(buf, row, row + 1, false)[1] or ""
  local out = {}
  for _, m in ipairs(api.nvim_buf_get_extmarks(buf, ns, { row, 0 }, { row, -1 }, { details = true })) do
    local d = m[4]
    if d.hl_group and d.end_col and not out[d.hl_group] then -- first (leftmost) per group
      out[d.hl_group] = { col = m[3], text = line:sub(m[3] + 1, d.end_col) }
    end
  end
  return out
end

-- The row's path: { root = "scope"|"watch", scope = name | index = n, names = {...} }
local function row_path(buf, row)
  local ok, canvas = pcall(require, "dapui.render.canvas")
  if not ok or not canvas.namespace then
    return nil
  end
  local ns = canvas.namespace

  -- A long value spans several lines: climb to the row that has the name.
  local m = marks(buf, ns, row)
  while row > 0 and not m.DapUIVariable and not m.DapUIScope and not m.DapUIWatchesValue and not m.DapUIWatchesError do
    row = row - 1
    m = marks(buf, ns, row)
  end

  -- Depth = where the row's expand icon starts (dap-ui indents one step per
  -- level); the name column itself shifts with the icon's byte width.
  local names, depth = {}, math.huge
  for r = row, 0, -1 do
    m = r == row and m or marks(buf, ns, r)
    local var = m.DapUIVariable
    local d = var and (m.DapUIDecoration and m.DapUIDecoration.col or var.col)
    if var and d < depth then
      table.insert(names, 1, var.text)
      depth = d
    else
      for group, kind in pairs(ROOTS) do
        if m[group] and (kind == "scope" or m[group].col == 0) then
          if kind == "scope" then
            return { root = "scope", scope = m[group].text, names = names }
          end
          local index = 0 -- watch headers from the top down to this row
          for h = 0, r do
            local hm = marks(buf, ns, h)
            if (hm.DapUIWatchesValue and hm.DapUIWatchesValue.col == 0) or (hm.DapUIWatchesError and hm.DapUIWatchesError.col == 0) then
              index = index + 1
            end
          end
          return { root = "watch", index = index, names = names }
        end
      end
    end
  end
end

local function request(session, command, args)
  local err, result = session:request(command, args) -- coroutine form (:h dap-session:request())
  if err then
    error(err.message or tostring(err), 0)
  end
  return result
end

local function find(session, ref, name)
  for _, v in ipairs(request(session, "variables", { variablesReference = ref }).variables or {}) do
    if v.name == name then
      return v
    end
  end
  error("'" .. name .. "' is no longer in scope", 0)
end

local function put(value, label)
  vim.fn.setreg('"', value)
  if vim.fn.has("clipboard") == 1 then
    vim.fn.setreg("+", value) -- system clipboard (pbcopy on macOS)
  end
  local lines = select(2, value:gsub("\n", "")) + 1
  vim.notify(("Copied %s%s"):format(label, lines > 1 and (" (" .. lines .. " lines)") or ""), vim.log.levels.INFO)
end

function M.copy()
  local session = package.loaded["dap"] and require("dap").session()
  local path = session and row_path(api.nvim_get_current_buf(), vim.fn.line(".") - 1)
  if not path or (path.root == "scope" and #path.names == 0) then
    vim.notify("Nothing to copy here", vim.log.levels.INFO)
    return
  end
  local frame_id = session.current_frame and session.current_frame.id
  local clipboard = (session.capabilities or {}).supportsClipboardContext

  coroutine.wrap(function()
    local ok, err = pcall(function()
      local ref, expr
      if path.root == "scope" then
        for _, s in ipairs(request(session, "scopes", { frameId = frame_id }).scopes or {}) do
          if s.name == path.scope then
            ref = s.variablesReference
          end
        end
        if not ref then
          error("scope '" .. path.scope .. "' not found", 0)
        end
      else
        local watch = require("dapui").elements.watches.get()[path.index]
        if not watch then
          error("watch not found", 0)
        end
        expr = watch.expression
        if #path.names > 0 then
          ref = request(session, "evaluate", { expression = expr, frameId = frame_id, context = "watch" }).variablesReference
        end
      end

      local value, label = nil, expr
      for i, name in ipairs(path.names) do
        local v = find(session, ref, name)
        if i == #path.names then
          value, label, expr = v.value, name, v.evaluateName
        else
          ref = v.variablesReference
        end
      end
      if expr then
        local ctx = clipboard and "clipboard" or (value == nil and "watch" or nil)
        if ctx then
          local got, res = pcall(request, session, "evaluate", { expression = expr, frameId = frame_id, context = ctx })
          if got and res.result then
            value = res.result
          end
        end
      end
      if value == nil then
        error("no value", 0)
      end
      vim.schedule(function()
        put(value, label or "value")
      end)
    end)
    if not ok then
      vim.schedule(function()
        vim.notify("Copy Value: " .. tostring(err), vim.log.levels.WARN)
      end)
    end
  end)()
end

function M.copy_stack()
  local session = package.loaded["dap"] and require("dap").session()
  local thread = session and session.stopped_thread_id
  if not thread then
    vim.notify("Copy Stack: not stopped", vim.log.levels.INFO)
    return
  end
  coroutine.wrap(function()
    local ok, res = pcall(request, session, "stackTrace", { threadId = thread })
    vim.schedule(function()
      if not ok then
        vim.notify("Copy Stack: " .. tostring(res), vim.log.levels.WARN)
        return
      end
      local lines = {}
      for _, f in ipairs(res.stackFrames or {}) do
        local path = f.source and (f.source.path or f.source.name)
        lines[#lines + 1] = path and ("%s  %s:%d"):format(f.name, vim.fn.fnamemodify(path, ":~:."), f.line) or f.name
      end
      put(table.concat(lines, "\n"), "call stack")
    end)
  end)()
end

-- `y` in the Variables, Watches and Call Stack panels. Normal-mode only: to
-- copy panel text itself, select it (v / V) and press y as usual.
function M.setup()
  api.nvim_create_autocmd("FileType", {
    group = api.nvim_create_augroup("debugging_copy", { clear = true }),
    pattern = { "dapui_scopes", "dapui_watches", "dapui_stacks" },
    callback = function(args)
      if vim.bo[args.buf].filetype == "dapui_stacks" then
        vim.keymap.set("n", "y", M.copy_stack, { buffer = args.buf, desc = "Copy Stack" })
      else
        vim.keymap.set("n", "y", M.copy, { buffer = args.buf, desc = "Copy Value" })
      end
    end,
  })
end

return M
