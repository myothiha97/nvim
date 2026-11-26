-- Watches rows (dap-ui "watches" component): the same GoLand-style row as
-- Variables (debugging/variables.lua), one line per watch:
--
--   ▸ srv.jobs = {chan main.Order} len:3, cap:8
--   ▸ u.Name = {string} "Myo"
--
-- Upstream printed `expr type = value` and wrapped the value over several
-- lines. Everything else is upstream's: i adds, e edits, d removes, the
-- changed-value highlight, expand shows the children (rendered by
-- debugging/variables.lua, so a pointer or interface opens on its fields).
-- Double-click / <CR> on a watch whose value is cut and has no children opens
-- the whole value in a float.
--
-- !! WARNING: replaces a dap-ui INTERNAL module (not a public API) !!
-- Installed as `dapui.components.watches` in plugins/ui.lua before
-- dapui.setup. Based on lua/dapui/components/watches.lua at the nvim-dap-ui
-- commit pinned in lazy-lock.json (cc9dd33); the returned table (add, edit,
-- remove, get, expand, render) is what dapui.elements.watches and
-- debugging/layout.lua / copy.lua call. The header row keeps upstream's
-- highlight groups (DapUIWatchesValue / DapUIWatchesError at column 0), which
-- copy.lua reads.
-- After updating nvim-dap-ui: add a watch (<leader>dW, i), expand it, edit
-- (e), remove (d). Rollback: delete the `dapui.components.watches` line in
-- plugins/ui.lua.
--
-- Cost: one `evaluate` per watch per render (as upstream), string work per row.

local config = require("dapui.config")
local util = require("dapui.util")
local values = require("debugging.values")
local variables = require("debugging.variables")
local nio = require("nio")

local partial = util.partial

---@class dapui.watches.Watch
---@field expression string
---@field expanded boolean

---@param client dapui.DAPClient
return function(client, send_ready)
  local running = false
  client.listen.scopes(function()
    running = true
    send_ready()
  end)
  local on_exit = function()
    running = false
    send_ready()
  end

  client.listen.terminated(on_exit)
  client.listen.exited(on_exit)
  client.listen.disconnect(on_exit)

  ---@type dapui.watches.Watch[]
  local watches = {}
  local edit_index = nil
  local rendered_exprs = {}
  local rendered_step = client.lib.step_number()
  local render_vars = variables.new(client, send_ready, { filetype = "dapui_watches" })

  local function add_watch(value)
    if #value > 0 then
      watches[#watches + 1] = {
        expression = value,
        expanded = false,
      }
      send_ready()
    end
  end

  local function edit_expr(new_value, index)
    index = index or edit_index
    edit_index = nil
    if #new_value > 0 then
      watches[index].expression = new_value
    end
    send_ready()
  end

  local function remove_expr(expr_i)
    table.remove(watches, expr_i)
    send_ready()
  end

  local function toggle_expression(expr_i)
    watches[expr_i].expanded = not watches[expr_i].expanded
    send_ready()
  end

  return {
    add = add_watch,
    edit = edit_expr,
    remove = remove_expr,
    get = function()
      return vim.deepcopy(watches)
    end,
    expand = toggle_expression,
    ---@param canvas dapui.Canvas
    render = function(canvas)
      if not edit_index then
        canvas:set_prompt("> ", add_watch)
      else
        canvas:set_prompt("> ", edit_expr, { fill = watches[edit_index].expression })
      end

      if vim.tbl_count(watches) == 0 then
        canvas:write("No Expressions\n", { group = "DapUIWatchesEmpty" })
        return
      end
      local frame_id = client.session and client.session.current_frame and client.session.current_frame.id
      local step = client.lib.step_number()
      for i, watch in pairs(watches) do
        local success, evaluated
        if running then
          success, evaluated =
            pcall(client.request.evaluate, { context = "watch", expression = watch.expression, frameId = frame_id })
        else
          success, evaluated = false, { message = "No active session" }
        end
        if vim.in_fast_event() then
          nio.scheduler()
        end
        local width = variables.panel_width("dapui_watches") - 1
        local prefix = config.icons[watch.expanded and "expanded" or "collapsed"]

        canvas:write({
          { prefix, group = success and "DapUIWatchesValue" or "DapUIWatchesError" },
          " " .. watch.expression,
        })

        local text, cut, var_ref = "", false, 0
        if not success then
          watch.expanded = false
          canvas:write(": ")
          local used = vim.fn.strdisplaywidth(canvas.lines[canvas:length()])
          local message = util.format_error(evaluated):gsub("%s*\n%s*", " ")
          text, cut = values.fit(message, width - used)
        else
          var_ref = evaluated.variablesReference or 0
          canvas:write(" = ")
          local used = vim.fn.strdisplaywidth(canvas.lines[canvas:length()])
          local type_text = values.type_text(evaluated.type, math.floor((width - used) * 0.6))
          if type_text ~= "" then
            canvas:write({ { type_text, group = "DapUIType" }, " " })
            used = used + vim.fn.strdisplaywidth(type_text) + 1
          end
          text, cut = values.value_text(evaluated.type, evaluated.result, width - used, var_ref > 0)
        end

        local var_group
        if not success or rendered_exprs[i] == evaluated.result then
          var_group = "DapUIValue"
        else
          var_group = "DapUIModifiedValue"
        end

        canvas:write(text, { group = var_group })
        canvas:add_mapping("remove", partial(remove_expr, i))
        canvas:add_mapping("edit", function()
          edit_index = i
          send_ready()
        end)
        if success then
          if var_ref > 0 then
            canvas:add_mapping("expand", partial(toggle_expression, i))
          elseif cut then
            local whole = { name = watch.expression, evaluateName = watch.expression, value = evaluated.result }
            canvas:add_mapping("expand", function()
              nio.run(function()
                variables.show_full(client, whole)
              end)
            end)
          end
          canvas:add_mapping("repl", partial(util.send_to_repl, watch.expression))
        end
        canvas:write("\n")

        if watch.expanded and var_ref > 0 then
          render_vars.render(
            canvas,
            watch.expression,
            var_ref,
            config.render.indent,
            { type = evaluated.type, variablesReference = var_ref }
          )
        end
        if rendered_step ~= step then
          rendered_exprs[i] = evaluated.result
        end
      end
      if rendered_step ~= step then
        rendered_step = step
      end
    end,
  }
end
