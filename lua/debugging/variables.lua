-- Variables rows (dap-ui "variables" component), GoLand-style:
--
--   ▸ jobs = {chan main.Order} len:3, cap:8
--   ▸ srv = {*main.Server} {…}
--     err = {*errors.errorString} "order rejected: bad status"
--
-- One line per variable, cut to the panel width (formats in
-- debugging/values.lua). Upstream printed `name type = value` and wrapped up to
-- 256 characters of Delve's value onto 6-9 lines in the 46-column sidebar.
-- Used by the Variables panel, the children of a watch and the Evaluate float.
--
--   * double-click / <CR> on a row whose value is cut and has no children
--     opens the whole value in a float (GoLand's "View")
--   * a pointer or an interface expands straight to its fields: the single
--     unnamed child Delve puts under a pointer, and the `data` child under an
--     interface, are skipped (values.unwrap)
--   * e (edit), w (watch), the REPL action and the changed-value highlight
--     work as upstream; edit prefills the adapter's raw value
--
-- Same factory signature as upstream: function(client, send_ready), returning
-- { render(canvas, parent_path, parent_ref, indent, parent) }; `parent` (the
-- variable being expanded) is ours and optional.
--
-- !! WARNING: replaces a dap-ui INTERNAL module (not a public API) !!
-- Installed as `dapui.components.variables` in plugins/ui.lua before
-- dapui.setup. Based on lua/dapui/components/variables.lua at the nvim-dap-ui
-- commit pinned in lazy-lock.json (cc9dd33). Depends on: the factory shape
-- above, the canvas API (write, add_mapping, set_prompt, length, lines),
-- config.icons / config.render, client.request.variables,
-- client.lib.set_variable, util.send_to_repl / send_to_watches.
-- After updating nvim-dap-ui: stop in a Go program, expand a struct, edit a
-- value (e), add a watch (w). If Variables is empty or errors, compare with
-- upstream. Rollback: delete the `dapui.components.variables` line in
-- plugins/ui.lua (stock rows: wrapped values, type printed twice).
--
-- Cost: runs when the panel re-renders (stop, step, expand), a few string
-- operations per visible variable; never on keystrokes. Skipping a pointer's
-- wrapper costs one extra `variables` request, only when that row is expanded.

local config = require("dapui.config")
local util = require("dapui.util")
local values = require("debugging.values")
local nio = require("nio")
local partial = util.partial

-- Width of the window showing this panel; the sidebar's size when the panel
-- isn't on screen (and for the Evaluate float, whose buffer we can't tell).
local function panel_width(filetype)
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].filetype == filetype and vim.api.nvim_win_get_config(win).relative == "" then
      -- Text area only: the panel windows keep a sign/fold gutter.
      local info = vim.fn.getwininfo(win)[1]
      return info.width - info.textoff
    end
  end
  local layout = require("debugging.layout")
  return layout.layouts[layout.SIDEBAR].size
end

-- Full value of a cut row, in a wrapping float at the cursor. Re-evaluated
-- in the "clipboard" context when the adapter has it (Delve, debugpy,
-- js-debug: no 256-character cap), else the value the row already holds.
local function show_full(client, variable)
  local text = variable.value or ""
  local session = client.session
  local caps = session and session.capabilities or {}
  if variable.evaluateName and caps.supportsClipboardContext and session.current_frame then
    local ok, res = pcall(client.request.evaluate, {
      expression = variable.evaluateName,
      frameId = session.current_frame.id,
      context = "clipboard",
    })
    if ok and res and res.result then
      text = res.result
    end
  end
  vim.schedule(function()
    local lines = vim.split(text, "\n", { plain = true })
    vim.lsp.util.open_floating_preview(lines, "", {
      border = "rounded",
      wrap = true,
      max_width = math.floor(vim.o.columns * 0.6),
      max_height = math.floor(vim.o.lines * 0.5),
      focusable = true,
      focus_id = "debugging_full_value",
      title = " " .. (variable.evaluateName or variable.name) .. " ",
    })
  end)
end

local M = { show_full = show_full, panel_width = panel_width }

---@param client dapui.DAPClient
---@param opts? { filetype: string } panel whose window width rows are cut to
function M.new(client, send_ready, opts)
  local filetype = opts and opts.filetype or "dapui_scopes"
  local expanded_children = {}

  ---@type fun(value: string) | nil
  local prompt_func
  ---@type string | nil
  local prompt_fill
  ---@type table<string, string>
  local rendered_vars = {}

  local function reference_prefix(path, variable)
    if variable.variablesReference == 0 then
      return " "
    end
    return config.icons[expanded_children[path] and "expanded" or "collapsed"]
  end

  local function path_changed(path, value)
    return rendered_vars[path] and rendered_vars[path] ~= value
  end

  local function fetch(ref)
    local ok, data = pcall(client.request.variables, { variablesReference = ref })
    return ok and data.variables or {}
  end

  ---@param canvas dapui.Canvas
  ---@param parent_path string
  ---@param parent_ref integer
  ---@param indent integer
  ---@param parent? table the variable being expanded (nil for a scope / watch root)
  local function render(canvas, parent_path, parent_ref, indent, parent)
    if not canvas.prompt and prompt_func then
      canvas:set_prompt("> ", prompt_func, { fill = prompt_fill })
    end
    indent = indent or 0
    local variables = fetch(parent_ref)
    -- Pointer / interface: show the pointee's fields directly.
    local hops = 0
    while parent and hops < 3 do
      local inner = values.unwrap(parent.type, variables)
      if not inner then
        break
      end
      parent, parent_ref, hops = inner, inner.variablesReference, hops + 1
      variables = fetch(parent_ref)
    end
    if config.render.sort_variables then
      table.sort(variables, config.render.sort_variables)
    end
    if vim.in_fast_event() then
      nio.scheduler()
    end
    local width = panel_width(filetype) - 1 -- a cell of slack: an exact fit must not wrap

    for _, variable in pairs(variables) do
      local var_path = parent_path .. "." .. variable.name
      local expandable = variable.variablesReference > 0

      canvas:write({
        string.rep(" ", indent),
        { reference_prefix(var_path, variable), group = "DapUIDecoration" },
        " ",
        { variable.name, group = "DapUIVariable" },
        " = ",
      })
      local used = vim.fn.strdisplaywidth(canvas.lines[canvas:length()])
      -- The type gets at most 60% of what is left, so the value keeps room.
      local type_text = values.type_text(variable.type, math.floor((width - used) * 0.6))
      if type_text ~= "" then
        canvas:write({ { type_text, group = "DapUIType" }, " " })
        used = used + vim.fn.strdisplaywidth(type_text) + 1
      end
      local text, cut = values.value_text(variable.type, variable.value, width - used, expandable)

      local var_group = path_changed(var_path, variable.value) and "DapUIModifiedValue" or "DapUIValue"
      rendered_vars[var_path] = variable.value

      if expandable then
        canvas:add_mapping("expand", function()
          expanded_children[var_path] = not expanded_children[var_path]
          send_ready()
        end)
        if variable.evaluateName then
          canvas:add_mapping("repl", partial(util.send_to_repl, variable.evaluateName))
          canvas:add_mapping("watch", partial(util.send_to_watches, variable.evaluateName))
        end
      elseif cut then
        canvas:add_mapping("expand", function()
          nio.run(function()
            show_full(client, variable)
          end)
        end)
      end
      canvas:add_mapping("edit", function()
        prompt_func = function(new_value)
          nio.run(function()
            prompt_func = nil
            prompt_fill = nil
            client.lib.set_variable(parent_ref, variable, new_value)
            send_ready()
          end)
        end
        prompt_fill = variable.value
        send_ready()
      end)
      canvas:write(text .. "\n", { group = var_group })

      if expanded_children[var_path] and expandable then
        render(canvas, var_path, variable.variablesReference, indent + config.render.indent, variable)
      end
    end
  end

  return {
    render = render,
  }
end

-- Callable like upstream's module: require("dapui.components.variables")(client, send_ready)
return setmetatable(M, {
  __call = function(_, ...)
    return M.new(...)
  end,
})
