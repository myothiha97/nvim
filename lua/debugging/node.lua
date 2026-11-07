-- Node / JavaScript / TypeScript launch configurations.
--
-- LazyVim's typescript extra already installs js-debug (VS Code's own
-- JavaScript debugger) and gives "Launch file" (TypeScript runs through tsx,
-- else ts-node) and "Attach" (pick a process). This adds, in <leader>dc:
--
--   npm script…               `npm run <script>`, picked from the nearest
--                             package.json: `npm run dev` for an Express/Nest
--                             server. js-debug attaches to the node processes
--                             it spawns (nodemon, tsx watch, nest --watch).
--   Attach to port 9229       a process you started with `node --inspect`.
--
-- Tests: <leader>td or right-click Debug Test (neotest: vitest, jest).
--
-- Added through an nvim-dap config provider (public API), so the entries sit
-- next to LazyVim's and a project's .vscode/launch.json whatever order the
-- plugin specs load in. Cost: runs only when <leader>dc lists configurations.

local M = {}

local FILETYPES = {
  javascript = true,
  typescript = true,
  javascriptreact = true,
  typescriptreact = true,
}

local COMMON = {
  sourceMaps = true,
  skipFiles = { "<node_internals>/**", "**/node_modules/**" },
  resolveSourceMapLocations = { "${workspaceFolder}/**", "!**/node_modules/**" },
}

local function nearest_package_json(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  local start = name ~= "" and vim.fs.dirname(name) or vim.fn.getcwd()
  return vim.fs.find("package.json", { upward = true, path = start })[1]
end

-- Asks for the script when the configuration is started (nvim-dap resolves
-- a function-valued field then; a coroutine lets it wait for the picker).
local function pick_script(path)
  return coroutine.create(function(dap_co)
    local dap = require("dap")
    local ok, pkg = pcall(vim.json.decode, table.concat(vim.fn.readfile(path), "\n"))
    local scripts = ok and type(pkg) == "table" and type(pkg.scripts) == "table" and pkg.scripts or {}
    local names = vim.tbl_keys(scripts)
    table.sort(names)
    if #names == 0 then
      vim.notify("No scripts in " .. path, vim.log.levels.WARN)
      coroutine.resume(dap_co, dap.ABORT)
      return
    end
    vim.ui.select(names, {
      prompt = "npm run",
      format_item = function(n)
        return n .. "  " .. tostring(scripts[n])
      end,
    }, function(choice)
      coroutine.resume(dap_co, choice and { "run", choice } or dap.ABORT)
    end)
  end)
end

-- Right-click Debug Test (menu.lua): vitest / jest files, nearest test via
-- neotest (it picks the runner from package.json).
function M.is_test_file(name)
  return (name:match("%.test%.[cm]?[jt]sx?$") or name:match("%.spec%.[cm]?[jt]sx?$")) ~= nil
end

function M.debug_test()
  require("neotest").run.run({ strategy = "dap" })
end

---@param bufnr integer
---@return table[]
function M.configs(bufnr)
  if not FILETYPES[vim.bo[bufnr].filetype] then
    return {}
  end
  local list = {}
  local pkg = nearest_package_json(bufnr)
  if pkg then
    list[#list + 1] = vim.tbl_extend("force", COMMON, {
      type = "pwa-node",
      request = "launch",
      name = ("npm script… (%s)"):format(vim.fn.fnamemodify(pkg, ":h:t")),
      runtimeExecutable = "npm",
      runtimeArgs = function()
        return pick_script(pkg)
      end,
      cwd = vim.fs.dirname(pkg),
      -- Server logs keep their colours and Ctrl-C works: the program runs
      -- in the TERMINAL pane of the tray, the REPL stays for expressions.
      console = "integratedTerminal",
    })
  end
  list[#list + 1] = vim.tbl_extend("force", COMMON, {
    type = "pwa-node",
    request = "attach",
    name = "Attach to port 9229 (node --inspect)",
    port = 9229,
    cwd = "${workspaceFolder}",
  })
  return list
end

return M
