-- Call Stack (dap-ui "stacks" element) with collapsible goroutines/threads.
--
-- Upstream renders every thread with all its frames and has no way to fold a
-- thread, so 6 runtime goroutines bury your own. This replaces dap-ui's
-- `dapui.components.threads` (installed in plugins/ui.lua before
-- dapui.setup) and reuses its frame renderer unchanged.
--
--   * the stopped goroutine is expanded, every other one starts collapsed
--   * click (or <CR> / za) on a goroutine line toggles it; your choice is
--     kept per goroutine id until the session ends
--   * click (or <CR> / o) on a frame jumps to it and repoints Variables
--   * t toggles runtime-internal ("subtle") frames of that goroutine
--
-- Same factory signature as upstream: function(client, send_ready).
--
-- !! WARNING: replaces a dap-ui INTERNAL module (not a public API) !!
-- Depends on, at the nvim-dap-ui commit pinned in lazy-lock.json:
--   * `dapui.components.threads` being required by the stacks element as a
--     factory `function(client, send_ready) -> { render(canvas, indent) }`
--   * `dapui.components.frames` (same factory shape, render(canvas, thread_id,
--     show_subtle, indent)) and the canvas API: write, add_mapping,
--     length, `canvas.mappings.open[line]`
--   * client.listen.{threads,scopes,terminated,exited,disconnect}
-- After updating nvim-dap-ui: start a Go session and open Call Stack. If it
-- is empty or errors, compare with upstream lua/dapui/components/threads.lua.
-- Rollback: delete the `package.loaded["dapui.components.threads"]` line in
-- plugins/ui.lua (stock Call Stack, no collapsing).

local config = require("dapui.config")
local frame_renderer = require("dapui.components.frames")

return function(client, send_ready)
  local _threads = nil
  local expanded = {} ---@type table<integer, boolean> user choice per thread id
  local subtle = {} ---@type table<integer, boolean>

  client.listen.threads(function(args)
    _threads = args.response.threads
  end)
  client.listen.scopes(function()
    send_ready()
  end)

  local on_exit = function()
    _threads = nil
    expanded, subtle = {}, {}
    send_ready()
  end
  client.listen.terminated(on_exit)
  client.listen.exited(on_exit)
  client.listen.disconnect(on_exit)

  local render_frames = frame_renderer(client, send_ready)

  return {
    ---@param canvas dapui.Canvas
    render = function(canvas, indent)
      local threads = _threads -- may be wiped during render
      local session = client.session
      if not threads or not session then
        return
      end
      indent = indent or 0
      local stopped_id = session.stopped_thread_id

      local function is_open(id)
        if expanded[id] ~= nil then
          return expanded[id]
        end
        return id == stopped_id
      end

      local function render_thread(thread, group)
        local id = thread.id
        local open = is_open(id)
        local header = math.max(canvas:length(), 1)

        canvas:write(open and config.icons.expanded or config.icons.collapsed, { group = "DapUIDecoration" })
        canvas:write(" ")
        canvas:write(thread.name, { group = group })
        canvas:write("\n")

        canvas:add_mapping("expand", function()
          expanded[id] = not is_open(id)
          send_ready()
        end, { line = header })
        canvas:add_mapping("toggle", function()
          subtle[id] = not subtle[id]
          send_ready()
        end, { line = header })

        if not open then
          return
        end

        local first = canvas:length()
        render_frames.render(canvas, id, subtle[id] or false, indent + config.render.indent)
        local last = canvas:length()
        -- A click/<CR> on a frame line opens that frame: give the frame
        -- lines' "open" callbacks to "expand" as well.
        for line = first, last do
          local callbacks = canvas.mappings.open[line]
          if callbacks then
            for _, cb in ipairs(callbacks) do
              canvas:add_mapping("expand", cb, { line = line })
            end
          end
        end
        canvas:write("\n")
      end

      for _, thread in pairs(threads) do
        if thread.id == stopped_id then
          render_thread(thread, "DapUIStoppedThread")
        end
      end
      for _, thread in pairs(threads) do
        if thread.id ~= stopped_id then
          render_thread(thread, "DapUIThread")
        end
      end
    end,
  }
end
