-- Keystroke latency instrumentation. Loaded with -c after startup.
_G.MEAS = {}
local hr = vim.uv.hrtime
local rec, label = false, nil
local keys, lags = {}, {}
local open_safe, open_draw = {}, {} -- key records waiting for SafeState / redraw end
local ru0, wall0
local ns = vim.api.nvim_create_namespace("meas")

vim.on_key(function(k, typed)
  if not rec then return end
  -- A key still waiting for a redraw when the next key arrives needed none of its
  -- own (cursor-only moves flush the cursor without a redraw cycle): it was
  -- visible once processed.
  for _, o in ipairs(open_draw) do o.nodraw = true end
  open_draw = {}
  local r = { t0 = hr(), key = vim.fn.keytrans(typed ~= nil and typed ~= "" and typed or k), mode = vim.api.nvim_get_mode().mode }
  keys[#keys + 1] = r
  open_safe[#open_safe + 1] = r
  open_draw[#open_draw + 1] = r
end, ns)

vim.api.nvim_create_autocmd("SafeState", {
  group = vim.api.nvim_create_augroup("meas", { clear = true }),
  callback = function()
    if #open_safe == 0 then return end
    local t = hr()
    for _, r in ipairs(open_safe) do r.safe = (t - r.t0) / 1e6 end
    open_safe = {}
  end,
})

vim.api.nvim_set_decoration_provider(ns, {
  on_end = function()
    if #open_draw == 0 then return end
    local t = hr()
    for _, r in ipairs(open_draw) do r.drawn = (t - r.t0) / 1e6 end
    open_draw = {}
  end,
})

local INTERVAL = 4
local timer = vim.uv.new_timer()
local last = hr()
timer:start(INTERVAL, INTERVAL, function()
  local t = hr()
  if rec then lags[#lags + 1] = math.max(0, (t - last) / 1e6 - INTERVAL) end
  last = t
end)

local function pct(t, p)
  if #t == 0 then return 0 end
  table.sort(t)
  return t[math.max(1, math.ceil(#t * p))]
end

function MEAS.start(l, ms)
  label, keys, lags, open_safe, open_draw = l, {}, {}, {}, {}
  vim.defer_fn(MEAS.stop, ms)
  local ru = vim.uv.getrusage()
  ru0 = ru.utime.sec + ru.utime.usec / 1e6 + ru.stime.sec + ru.stime.usec / 1e6
  wall0 = hr()
  rec = true
end

function MEAS.stop()
  rec = false
  local ru = vim.uv.getrusage()
  local cpu = ru.utime.sec + ru.utime.usec / 1e6 + ru.stime.sec + ru.stime.usec / 1e6 - ru0
  local wall = (hr() - wall0) / 1e9
  local safe, drawn, worst = {}, {}, {}
  for _, r in ipairs(keys) do
    if r.safe then safe[#safe + 1] = r.safe end
    local vis = r.drawn and not r.nodraw and r.drawn or r.safe
    if vis then drawn[#drawn + 1] = vis end
    worst[#worst + 1] = r
  end
  table.sort(worst, function(a, b) return (a.safe or 0) > (b.safe or 0) end)
  local top = {}
  for i = 1, math.min(4, #worst) do top[#top + 1] = ("%s(%s)=%.1f"):format(worst[i].key, worst[i].mode, worst[i].safe or -1) end
  local big = 0
  for _, l in ipairs(lags) do if l > 16 then big = big + 1 end end
  local clients = {}
  for _, c in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do clients[#clients + 1] = c.name end
  local line = ("%-22s keys=%3d proc p50=%5.2f p95=%5.2f max=%6.2f | visible p50=%5.2f p95=%5.2f max=%6.2f | lag p95=%5.2f max=%6.2f >16ms=%d | cpu=%4.1f%% | lsp=%s | worst: %s"):format(
    label, #keys, pct(safe, .5), pct(safe, .95), pct(safe, 1), pct(drawn, .5), pct(drawn, .95), pct(drawn, 1),
    pct(lags, .95), pct(lags, 1), big, 100 * cpu / wall, table.concat(clients, ","), table.concat(top, " "))
  local d = io.open(vim.env.MEAS_OUT .. ".detail", "a")
  for i, r in ipairs(keys) do
    d:write(("%s\t%d\t%s\t%s\t%.2f\t%.2f\n"):format(label, i, r.key, r.mode, r.safe or -1, r.drawn or -1))
  end
  d:close()
  local f = io.open(vim.env.MEAS_OUT, "a")
  f:write(line .. "\n")
  f:close()
end
