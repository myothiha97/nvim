-- cursortab.nvim: Cursor-Tab-style next-edit suggestions (multi-line edits, jump
-- to the next edit, Tab-Tab chains). Two providers, switchable at runtime:
--   mercuryapi  hosted Mercury Edit 2 (Inception Labs). Needs $MERCURY_AI_TOKEN.
--               Code context is sent to Inception Labs.
--   zeta-2.1    Zed's model, run locally by llama.cpp. Code stays on the machine:
--               llama-server -hf mradermacher/zeta-2.1-GGUF:Q8_0 --ctx-size 16384 --port 8000
--
-- Off until <leader>an. The plugin is lazy and setup() only runs on that first
-- press, so a session that never turns it on starts no daemon and adds no
-- autocmds. Once on, cursortab adds global CursorMoved(I)/TextChanged(I)/BufEnter
-- autocmds (a few API reads + one async rpcnotify each) and one vim.on_key handler.
--
-- <Tab> stays owned by lua/config/keymaps.lua: both <Tab> handlers call
-- require("cursortab").accept() first. cursortab's own <Tab>/<S-Tab> maps (insert
-- AND normal mode) are turned off below because they would replace NES accept,
-- float focus, jump-forward and insert outdent.
--
-- WARNING: the Go daemon is shared by every nvim through a socket in
-- stdpath("state")/cursortab and re-starts when setup() is called with another
-- config. Two nvims on different providers keep restarting it; use one provider.
--
-- WARNING: while cursortab accepts an edit it sets vim.b.completion = false to
-- hide blink, then resets it to nil. A buffer where blink was turned off with
-- <leader>ab gets blink back after an accept. Known, minor, not fixed.
--
-- WARNING: ignore_paths is checked in Lua before events are sent, but an <Esc>
-- reject (sent on BufEnter too) is not checked. If a reply is still streaming
-- when you enter an ignored file, the daemon re-reads the current buffer and
-- may keep its first lines as "recent file" context for the next request. With
-- mercuryapi that context leaves the machine. Narrow race, upstream behaviour.

local providers = {
  mercuryapi = { type = "mercuryapi", api_key_env = "MERCURY_AI_TOKEN" },
  ["zeta-2.1"] = { type = "zeta-2.1", url = "http://localhost:8000" },
}
local provider_order = { "mercuryapi", "zeta-2.1" }

-- Credential files never sent as context. Mirrors secret_names / secret_dirs in
-- plugins/copilot.lua (keep both in sync). cursortab matches globs: a pattern
-- without "/" is matched against the file name, one with "/" against the path
-- relative to cwd (absolute path outside cwd), so each directory is listed both
-- at the root and nested. Matching is case-sensitive.
-- WARNING: lists replace cursortab's defaults (vim.tbl_deep_extend), so its own
-- defaults are repeated in the first block.
local ignore_paths = {
  -- cursortab defaults (v0.8.1)
  "*.min.js", "*.min.css", "*.map", "*-lock.json", "*.lock", "*.sum", "*.csv", "*.tsv",
  "*.parquet", "*.zip", "*.tar", "*.gz", "*.pem", "*.key", ".env", ".env.*", "*.log",
  -- secrets (plugins/copilot.lua)
  ".env*", "*.env", "*secret*", "*Secret*", ".dev.vars", ".pgpass", ".vault-token",
  "*kubeconfig*", "*.jks", "*.keystore", "*.ovpn", "service-account*.json",
  "*.p12", "*.pfx", "*.tfvars", "*.tfstate*", "id_rsa*", "id_dsa*", "id_ecdsa*",
  "id_ed25519*", ".npmrc", ".pypirc", ".netrc", ".git-credentials", "credentials*",
  ".ssh/**", "**/.ssh/**", ".kube/**", "**/.kube/**", ".aws/**", "**/.aws/**",
  ".gnupg/**", "**/.gnupg/**", ".docker/**", "**/.docker/**",
  "secret/**", "**/secret/**", "secrets/**", "**/secrets/**",
}

local state = { setup_done = false, enabled = false }

local function build_opts()
  return {
    enabled = state.enabled,
    keymaps = { accept = false, partial_accept = false, trigger = false },
    behavior = {
      -- Normal-mode suggestions after the cursor rests. 300 ms (default 50) cuts
      -- requests (Mercury bills per token, zeta-2.1 uses local CPU/GPU).
      idle_completion_delay = 300,
      enabled_modes = { "insert", "normal" },
      ignore_paths = ignore_paths,
    },
    provider = providers[vim.g.cursortab_provider],
  }
end

-- Mercury needs the key in nvim's environment when the daemon starts.
local function provider_ready()
  if vim.g.cursortab_provider == "mercuryapi" and (vim.env.MERCURY_AI_TOKEN or "") == "" then
    local msg = "MERCURY_AI_TOKEN is not set. Export it, or switch provider with <leader>aN."
    vim.notify(msg, vim.log.levels.WARN, { title = "cursortab" })
    return false
  end
  return true
end

local function notify_state()
  local msg = ("Cursortab: %s (%s)"):format(state.enabled and "on" or "off", vim.g.cursortab_provider)
  vim.notify(msg, state.enabled and vim.log.levels.INFO or vim.log.levels.WARN, { title = "cursortab" })
end

local function toggle()
  local ct = require("cursortab")
  if not state.setup_done then
    if not provider_ready() then
      return
    end
    state.enabled, state.setup_done = true, true
    ct.setup(build_opts())
    return notify_state()
  end
  if not state.enabled and not provider_ready() then
    return
  end
  -- cursortab.toggle() flips the daemon flag, clears visible edits and notifies.
  ct.toggle()
  state.enabled = not state.enabled
end

local function switch_provider()
  local current = vim.g.cursortab_provider
  local next_provider = provider_order[1]
  for i, name in ipairs(provider_order) do
    if name == current then
      next_provider = provider_order[i % #provider_order + 1]
    end
  end
  vim.g.cursortab_provider = next_provider
  -- Only re-run setup once it ran: setup() with a changed config restarts the
  -- daemon on the new provider. Before that the choice is just remembered.
  if state.setup_done then
    if state.enabled and not provider_ready() then
      vim.g.cursortab_provider = current
      return
    end
    require("cursortab").setup(build_opts())
  end
  notify_state()
end

return {
  {
    "cursortab/cursortab.nvim",
    version = "*", -- tagged releases only
    -- Needs Go 1.25+. With an older Go, GOTOOLCHAIN=auto (the default) downloads 1.25.
    build = "cd server && go build",
    lazy = true,
    init = function()
      -- Default provider; change here, or at runtime with <leader>aN.
      vim.g.cursortab_provider = vim.g.cursortab_provider or "mercuryapi"
    end,
    -- setup() is deferred to the first <leader>an (see toggle) so loading the
    -- plugin never starts the daemon by itself.
    config = function() end,
    keys = {
      { "<leader>an", toggle, desc = "Cursortab: Toggle Next-Edit" },
      { "<leader>aN", switch_provider, desc = "Cursortab: Switch Provider" },
    },
  },
}
