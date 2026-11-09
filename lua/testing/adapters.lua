-- Fix for a duplicate adapter in the neotest summary (<leader>ts showed "neotest-golang" twice).
--
-- Cause (neotest 27bf921, same on main): entering a file in a folder outside every adapter root
-- (e.g. ledgerflow/docs/…) makes neotest register adapters for that folder. Its fallback,
-- adapters_matching_open_bufs, then treats every open test buffer that is not under the NEW
-- folder's roots as orphaned, ignoring the adapters already registered, and registers
-- neotest-golang again rooted at that folder: a second, empty tree for the same test file.
--
-- Fix: the fallback also skips test files under a root that is already registered. Roots are
-- learned from the public discover_positions event. Real separate projects (another go.mod,
-- another package.json) are found through their own root, not this fallback, so they still
-- get their own adapter.
--
-- WARNING: wraps neotest's internal AdapterGroup:adapters_matching_open_bufs (no public
-- option). If a neotest update renames it, nothing is wrapped and neotest behaves as before
-- (the duplicate can come back; restarting nvim clears it). Checked on neotest 27bf921.
--
-- Cost: none at startup (installed when neotest sets up); one extra list per fallback call.

local M = {}

function M.consumer(client)
  local roots = {} -- adapter root -> true, for every adapter that has parsed a file

  client.listeners.discover_positions = function(adapter_id)
    local root = adapter_id:match(":(.*)$")
    if root then
      roots[root] = true
    end
  end

  local ok, group = pcall(function()
    return getmetatable(require("neotest.adapters")())
  end)
  local original = ok and type(group) == "table" and group.adapters_matching_open_bufs
  if type(original) == "function" and not group.testing_known_roots then
    group.testing_known_roots = true
    group.adapters_matching_open_bufs = function(self, existing_roots)
      local all = vim.list_extend(vim.deepcopy(existing_roots or {}), vim.tbl_keys(roots))
      return original(self, all)
    end
  end
  return {}
end

return M
