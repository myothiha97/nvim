-- C# / .NET launch configurations, on top of easy-dotnet.nvim
-- (plugins/csharp.lua says why that plugin).
--
-- easy-dotnet starts a session by building the project, starting its bundled
-- netcoredbg as a debug server and attaching nvim-dap to that port. In
-- <leader>dc this file offers:
--
--   Debug startup project     the remembered project + launch profile (asked
--                             the first time, like Rider's startup project)
--   Debug project…            pick project and launchSettings.json profile
--   Attach to .NET process…   pick a running dotnet process
--
-- The port closes with the session, so nvim-dap cannot replay it: Restart
-- and Run Again (controls.lua) call M.rerun, which repeats the command that
-- started the last session. Tests: <leader>td or right-click Debug Test.

local M = {}

local FILETYPES = { cs = true, fsharp = true, vb = true }
local ADAPTER = "easy-dotnet" -- easy-dotnet's nvim-dap adapter / config type

local pending ---@type string? command whose session has not started yet
local last ---@type string? command that started the current/last session

local function start(cmd)
  return function()
    pending = cmd
    vim.schedule(function()
      vim.cmd(cmd)
    end)
    return require("dap").ABORT -- easy-dotnet's server attaches when it is ready
  end
end

local function entry(name, cmd)
  return { type = ADAPTER, request = "attach", name = name, port = start(cmd) }
end

---@param bufnr integer
---@return table[]
function M.configs(bufnr)
  if not FILETYPES[vim.bo[bufnr].filetype] then
    return {}
  end
  return {
    entry("Debug startup project (.NET)", "Dotnet debug profile default"),
    entry("Debug project… (.NET)", "Dotnet debug profile"),
    entry("Attach to .NET process…", "Dotnet debug attach"),
  }
end

-- Called on every easy-dotnet session start (plugins/csharp.lua): remember
-- the command only if one of the entries above started it; a session from a
-- test or a typed :Dotnet command has no replayable command.
function M.on_session(session)
  if session.config.type == ADAPTER then
    last, pending = pending, nil
  end
end

function M.rerun()
  if last then
    pending = last
    vim.cmd(last)
  else
    vim.notify("Start it again from <leader>dc or the test (this session has no replayable command)", vim.log.levels.INFO)
  end
end

-- Right-click test entries (menu.lua): easy-dotnet maps <leader>td / tr /
-- tt / to (plugins/csharp.lua) in files whose tests its runner has
-- discovered; those mappings debug / run the test at the cursor, run the
-- file, and peek the failed test's stack trace.
local function test_map(lhs)
  local map = vim.fn.maparg(lhs, "n", false, true)
  return map.buffer == 1 and map.callback or nil
end

local function call(lhs)
  local fn = test_map(lhs)
  if fn then
    fn()
  end
end

function M.is_test_file(_)
  return test_map("<leader>td") ~= nil
end

function M.debug_test()
  call("<leader>td")
end

function M.run_test()
  call("<leader>tr")
end

function M.run_file()
  call("<leader>tt")
end

function M.show_output()
  call("<leader>to")
end

return M
