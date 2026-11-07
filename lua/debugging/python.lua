-- Python launch configurations.
--
-- LazyVim's python extra already sets up nvim-dap-python with debugpy (from
-- Mason) and gives, in <leader>dc: file, file:args, attach (host/port),
-- file:doctest. The interpreter is your project's: $VIRTUAL_ENV (set by
-- <leader>cv VenvSelect), else ./venv or ./.venv. This adds:
--
--   Module… (python -m)   asks for one line, e.g. `uvicorn main:app`, `flask run`,
--                         `mypkg.cli --flag`, `pytest -x tests/`.
--   Django: runserver     only when a manage.py is found above the file.
--
-- Tests: <leader>td or right-click Debug Test (neotest-python / pytest);
-- <leader>dPt / dPc debug the test method / class under the cursor.
--
-- Added through an nvim-dap config provider (public API), like node.lua.
-- Cost: runs only when <leader>dc lists configurations.

local M = {}

-- One prompt, `python -m <module> <args>`, feeding two config fields. nvim-dap
-- resolves function-valued fields when the configuration starts, in no fixed
-- order, so whichever field comes first asks and both read the answer. A
-- coroutine lets nvim-dap wait for the floating input. Esc aborts the run.
local function module_prompt()
  local parts ---@type string[]|false|nil nil = not asked yet, false = cancelled
  local function field(pick)
    return function()
      local function value()
        if parts == false then
          return require("dap").ABORT
        end
        return pick(parts)
      end
      if parts ~= nil then
        return value()
      end
      return coroutine.create(function(dap_co)
        vim.ui.input({ prompt = "python -m " }, function(input)
          input = input and vim.trim(input) or ""
          parts = input ~= "" and require("dap.utils").splitstr(input) or false
          coroutine.resume(dap_co, value())
        end)
      end)
    end
  end
  return field(function(p)
    return p[1]
  end), field(function(p)
    return vim.list_slice(p, 2)
  end)
end

-- Right-click Debug Test (menu.lua): pytest files, nearest test via neotest.
function M.is_test_file(name)
  return (name:match("/test_[^/]*%.py$") or name:match("_test%.py$")) ~= nil
end

function M.debug_test()
  require("neotest").run.run({ strategy = "dap" })
end

---@param bufnr integer
---@return table[]
function M.configs(bufnr)
  if vim.bo[bufnr].filetype ~= "python" then
    return {}
  end
  local module, args = module_prompt()
  local list = {
    {
      type = "python",
      request = "launch",
      name = "Module… (python -m)",
      module = module, -- asks e.g. `uvicorn main:app --port 8000`
      args = args,
      cwd = "${workspaceFolder}",
      console = "integratedTerminal",
    },
  }
  local name = vim.api.nvim_buf_get_name(bufnr)
  local start = name ~= "" and vim.fs.dirname(name) or vim.fn.getcwd()
  local manage = vim.fs.find("manage.py", { upward = true, path = start })[1]
  if manage then
    list[#list + 1] = {
      type = "python",
      request = "launch",
      name = "Django: runserver",
      program = manage,
      -- --noreload: Django's autoreloader runs the server in a second
      -- process; with it, breakpoints in views would not be hit reliably.
      args = { "runserver", "--noreload" },
      cwd = vim.fs.dirname(manage),
      django = true,
      console = "integratedTerminal",
    }
  end
  return list
end

return M
