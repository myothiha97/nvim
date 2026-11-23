"""Runtime performance in the real TUI, on large real-world files.

What one run measures, per file (see README "Runtime performance"):
- open: time to the first screen, VeryLazy, LSP attach and LSP ready (first documentSymbol answer)
- key latency: from the moment Nvim takes a key (vim.on_key) to the end of the first redraw after
  it (decoration provider on_end), or to SafeState for a key that needs no redraw (`no_redraw`
  counts those). Nvim's own work for the key; the terminal's paint is not in it.
- stalls: a 5 ms libuv timer that fires late means the main loop was blocked. Longest stall and the
  number over 50 ms, per action, catch work that is not tied to one key (LSP replies, async parses).
- CPU: user+system time of the Nvim server process per key, so work that happens after the
  redraw (debounced handlers, completion, diagnostics) is counted too.
- LSP round trips (hover / definition / references / documentSymbol / completion): server speed, for context.
- memory: RSS of Nvim and of the language server after the run.

Usage:
  python3 perf.py [go ts tsx py]                  # config under test, 1 run each
  REPEAT=3 python3 perf.py go                     # repeat
  MODE=clean python3 perf.py go                   # baseline: nvim --clean + treesitter highlight only
  PROFILE=1 python3 perf.py go                    # also LuaJIT sampling profile of scroll + typing
  AB=no-bufferline-diagnostics python3 perf.py py # one feature off, to price it (names: AB_VARIANTS)
  ACTIONS=scroll_j,typing python3 perf.py py      # only these actions (no LSP / save / profile part)
Targets come from targets.json next to this file, or E2E_TARGETS=path (see that file for the format).
Writes perf-<mode>.json. The edits it makes are undone (`:e!`) and never saved.
"""
import json, os, statistics, sys, time

from nvh import Nvim, sh, TMUX, tmux_literal, reset_fixture

HERE = os.path.dirname(os.path.abspath(__file__))
AB = os.environ.get("AB", "")
ACTIONS = [a for a in os.environ.get("ACTIONS", "").split(",") if a]  # run only these actions
# One feature off at a time. `spec` is written to lua/plugins/zz_perf_ab.lua for the run (lazy.nvim
# merges it last) and deleted afterwards; `lua` runs over RPC once VeryLazy has fired.
AB_VARIANTS = {
    "no-bufferline": {"spec": '{ "akinsho/bufferline.nvim", enabled = false }'},
    "no-bufferline-diagnostics": {"spec": '{ "akinsho/bufferline.nvim", opts = function(_, o) o.options.diagnostics = false end }'},
    "no-statuscolumn": {"lua": "vim.o.statuscolumn = ''; for _, w in ipairs(vim.api.nvim_list_wins()) do vim.wo[w].statuscolumn = '' end"},
    "no-words": {"lua": "Snacks.words.disable()"},
    "no-indent-guides": {"lua": "vim.cmd('IBLDisable')"},
    "no-bracket-match": {"lua": "pcall(vim.api.nvim_del_augroup_by_name, 'bracket_match')"},
    "no-scrollview": {"lua": "vim.cmd('ScrollViewDisable')"},
    "no-gitsigns": {"lua": "require('gitsigns').detach_all()"},
    "no-lualine": {"lua": "require('lualine').hide({ unhide = false })"},  # statusline incl. breadcrumb
    "no-ufo": {"lua": "require('ufo').disable()"},
    "no-semantic-tokens": {"lua": "vim.lsp.semantic_tokens.enable(false)"},
    # instrument self-test: 5 ms of busy work on every cursor move must show up as ~+5 ms per key
    "selftest-5ms": {"lua": "vim.api.nvim_create_autocmd('CursorMoved', { callback = function() local t = vim.uv.hrtime() while vim.uv.hrtime() - t < 5e6 do end end })"},
    # Vim's own indent instead of nvim-treesitter's indentexpr (which walks the whole file's indent
    # captures once per new tree, i.e. on the first o/O/<CR> after every edit)
    "no-ts-indent": {"lua": "vim.bo.indentexpr = ''"},
    "pyright-standard": {"spec": '{ "neovim/nvim-lspconfig", opts = { servers = { basedpyright = { settings = { basedpyright = { analysis = { typeCheckingMode = "standard" } } } } } } }'},
}
AB_SPEC = os.path.join(HERE, "..", "..", "lua", "plugins", "zz_perf_ab.lua")
MODE = os.environ.get("MODE", "config")
REPEAT = int(os.environ.get("REPEAT", "1"))
PROFILE = os.environ.get("PROFILE") == "1"

PROBE = r"""
if _G.__perf then return end
-- A key's latency runs from vim.on_key to the end of the first redraw after it (decoration
-- provider on_end). In Normal mode SafeState fires BEFORE that redraw, so it cannot be the end
-- point; it only closes keys that need no redraw at all (a sideways `w` with nothing to repaint):
-- if no redraw follows within 15 ms of SafeState, the key ends at SafeState.
local P = { on = false, lat = {}, keys = {}, kinds = {}, t0 = nil, k0 = nil, stalls = {}, last = vim.uv.hrtime() }
_G.__perf = P
local grace = vim.uv.new_timer()
local function finish(t, kind)
  if P.t0 then
    P.lat[#P.lat + 1] = (t - P.t0) / 1e6
    P.keys[#P.keys + 1] = P.k0
    P.kinds[#P.kinds + 1] = kind
    P.t0, P.safe = nil, nil
  end
end
vim.on_key(function(_, typed)
  if P.on and not P.t0 then
    P.t0 = vim.uv.hrtime()
    P.k0 = vim.fn.keytrans(typed or "")
  end
end, vim.api.nvim_create_namespace("perf_probe_key"))
vim.api.nvim_set_decoration_provider(vim.api.nvim_create_namespace("perf_probe_draw"), {
  on_end = function()
    grace:stop()
    finish(vim.uv.hrtime(), "redraw")
  end,
})
vim.api.nvim_create_autocmd("SafeState", {
  callback = function()
    if P.t0 and not P.safe then
      P.safe = vim.uv.hrtime()
      grace:start(15, 0, function()
        if P.safe then finish(P.safe, "safestate") end
      end)
    end
  end,
})
local tick = vim.uv.new_timer()
tick:start(5, 5, function()
  local now = vim.uv.hrtime()
  local gap = (now - P.last) / 1e6 - 5
  P.last = now
  if P.on and gap > 8 then
    P.stalls[#P.stalls + 1] = gap
  end
end)
function P.start()
  P.lat, P.keys, P.kinds, P.stalls, P.t0, P.safe = {}, {}, {}, {}, nil, nil
  P.last = vim.uv.hrtime()
  P.on = true
end
function P.stop()
  P.on = false
  local nd = 0
  for _, k in ipairs(P.kinds) do if k == "safestate" then nd = nd + 1 end end
  return { lat = P.lat, keys = P.keys, no_redraw = nd, stalls = P.stalls }
end
"""

LSP_READY = r"""
local buf = vim.api.nvim_get_current_buf()
local c = vim.lsp.get_clients({ bufnr = buf })[1]
if not c then return nil end
_G.__lsp_ready = _G.__lsp_ready or {}
local st = _G.__lsp_ready
if st.done then return st.done end
if st.inflight then return nil end
st.inflight = true
local t0 = vim.uv.hrtime()
c:request("textDocument/documentSymbol", { textDocument = vim.lsp.util.make_text_document_params(buf) }, function(err, res)
  st.inflight = false
  if not err and res and #res > 0 then st.done = c.name end
end, buf)
return nil
"""

# Round trip of one request, measured in Lua so the RPC to Python is not in the number.
LSP_RT = r"""
local method, row, col, n = ...
local buf = vim.api.nvim_get_current_buf()
local c = vim.lsp.get_clients({ bufnr = buf, method = method })[1]
if not c then return { err = "no client for " .. method } end
local times, done, sizes = {}, 0, {}
local function one(i)
  local p = { textDocument = vim.lsp.util.make_text_document_params(buf), position = { line = row, character = col } }
  if method == "textDocument/references" then p.context = { includeDeclaration = true } end
  if method == "textDocument/documentSymbol" then p.position = nil end
  local t0 = vim.uv.hrtime()
  c:request(method, p, function(err, res)
    times[#times + 1] = (vim.uv.hrtime() - t0) / 1e6
    local sz = 0
    if type(res) == "table" then sz = res.items and #res.items or #res end
    sizes[#sizes + 1] = err and ("err " .. tostring(err.message)) or sz
    done = done + 1
    if i < n then one(i + 1) end
  end, buf)
end
one(1)
vim.wait(60000, function() return done >= n end, 10)
return { times = times, sizes = sizes }
"""


def load_targets():
    p = os.environ.get("E2E_TARGETS", os.path.join(HERE, "targets.json"))
    return json.load(open(p))


def proc_cpu_ms(pid):
    try:
        f = open(f"/proc/{pid}/stat").read().rsplit(")", 1)[1].split()
        return (int(f[11]) + int(f[12])) * 1000 / os.sysconf("SC_CLK_TCK")
    except Exception:
        return None


def rss_mb(pid):
    try:
        for line in open(f"/proc/{pid}/status"):
            if line.startswith("VmRSS"):
                return int(line.split()[1]) / 1024
    except Exception:
        return None


def children(pid):
    out = sh(["ps", "-eo", "pid=,ppid=,comm="]).stdout.split("\n")
    kids = []
    for line in out:
        p = line.split(None, 2)
        if len(p) == 3 and int(p[1]) == pid:
            kids.append((int(p[0]), p[2]))
    return kids


def pct(xs, q):
    if not xs:
        return None
    xs = sorted(xs)
    return xs[min(len(xs) - 1, int(round(q * (len(xs) - 1))))]


def summary(lat, no_redraw, stalls, cpu_ms, nkeys):
    return {
        "n": len(lat),
        "median": round(statistics.median(lat), 2) if lat else None,
        "p95": round(pct(lat, 0.95), 2) if lat else None,
        "max": round(max(lat), 2) if lat else None,
        "no_redraw": no_redraw,
        "stall_max": round(max(stalls), 1) if stalls else 0,
        "stalls_over_50": sum(1 for s in stalls if s > 50),
        "cpu_per_key": round(cpu_ms / nkeys, 2) if cpu_ms is not None and nkeys else None,
    }


class Run:
    def __init__(self, t, mode):
        self.t, self.mode = t, mode
        args = []
        if mode == "clean":
            site = os.path.expanduser("~/.local/share/nvim/site")
            args = ["--clean", "--cmd", f"'set rtp^={site}'", "-c", "'lua pcall(vim.treesitter.start)'", "-c", "'set number relativenumber cursorline'"]
        reset_fixture(t["cwd"], t["file"])
        ab = AB_VARIANTS.get(AB, {}) if mode == "config" else {}
        if ab.get("spec"):
            open(AB_SPEC, "w").write("-- temporary, written by scripts/e2e/perf.py AB=" + AB + "\nreturn { " + ab["spec"] + " }\n")
        t0 = time.time()
        self.n = Nvim(t["cwd"], args + [t["file"]], name="perf")
        self.pid = self.n._rpc(lambda: self.n.nv.call("getpid"))
        self.open = {}
        if mode == "config":
            self.n.wait("local c=require('lazy.core.config').plugins['which-key.nvim']; return c and c._.loaded ~= nil", 40)
        self.open["verylazy_s"] = round(time.time() - t0, 2)
        if os.path.exists(AB_SPEC):
            os.remove(AB_SPEC)
        if ab.get("lua"):
            time.sleep(1.5)  # LazyFile plugins (gitsigns, ibl) attach after VeryLazy
            self.n.lua(ab["lua"])
        self.n.lua(PROBE)
        if mode == "config":
            self.n.wait("return #vim.lsp.get_clients({bufnr=0}) > 0", 60, "LSP attach")
            self.open["lsp_attach_s"] = round(time.time() - t0, 2)
            self.n.wait(LSP_READY, 240, "LSP ready", interval=0.25)
            self.open["lsp_ready_s"] = round(time.time() - t0, 2)
        # let startup work (gitsigns, diagnostics, mason checks) settle before measuring
        time.sleep(3)

    def measure(self, label, fn, nkeys):
        n = self.n
        c0 = proc_cpu_ms(self.pid)
        n.lua("_G.__perf.start()")
        fn(n)
        time.sleep(1.0)  # trailing async work (debounce, LSP replies) counts toward CPU and stalls
        r = n.lua("return _G.__perf.stop()")
        c1 = proc_cpu_ms(self.pid)
        s = summary(r["lat"], r["no_redraw"], r["stalls"], None if c0 is None or c1 is None else c1 - c0, nkeys)
        slow = sorted(zip(r["lat"], r["keys"]), reverse=True)[:5]
        s["slowest"] = [[round(a, 1), b] for a, b in slow]
        return s

    def goto(self, p1, p2=None):
        err = self.n.lua(
            "local a, b = ...; return select(2, pcall(function() vim.fn.cursor(1, 1);"
            " if vim.fn.search(a, 'W') == 0 then error('anchor not found: ' .. a) end;"
            " if b ~= '' and vim.fn.search(b, 'W') == 0 then error('anchor2 not found: ' .. b) end end))",
            p1, p2 or "")
        if err:
            raise RuntimeError(f"goto failed: {err} (mode={self.n.expr('mode()')})")

    def close(self):
        lsp = [(p, c) for p, c in children(self.pid) if c not in ("nvim",)]
        mem = {"nvim_mb": rss_mb(self.pid)}
        for p, c in lsp:
            mem[c] = round((rss_mb(p) or 0) + sum(rss_mb(k) or 0 for k, _ in children(p)), 1)
        self.n.close()
        return mem


def keyloop(n, seq, gap):
    for k in seq:
        n.keys(k, settle=0)
        time.sleep(gap)


def wheel(n, count, gap):
    for _ in range(count):
        n.mouse(20, 80, "wheeldown", settle=0)
        time.sleep(gap)


def type_text(n, text, gap):
    for ch in text:
        sh(TMUX + ["send-keys", "-t", n.name, "-l", tmux_literal(ch)])
        time.sleep(gap)


def leave_insert(n):
    # blink's <Esc> only cancels an open menu (plugins/blink-cmp.lua); the second one leaves insert
    for _ in range(3):
        n.keys("<Esc>", settle=0.3)
        if n.expr("mode()") == "n":
            return
    raise RuntimeError("still in insert mode after 3 <Esc>")


def profile(run, fn):
    run.n.lua("require('jit.p').start('Fl3', '/tmp/perf-prof.txt')")
    fn(run.n)
    time.sleep(1.0)
    run.n.lua("require('jit.p').stop()")
    try:
        return open("/tmp/perf-prof.txt").read()[:6000]
    except Exception as e:
        return str(e)


def one_run(t, mode):
    out = {"file": t["file"], "lines": None, "mode": mode, "ab": AB or None}
    r = Run(t, mode)
    n = r.n
    out["open"] = r.open
    out["lines"] = n.lua("return vim.api.nvim_buf_line_count(0)")
    out["treesitter"] = n.lua("return vim.treesitter.highlighter.active[vim.api.nvim_get_current_buf()] ~= nil")
    res = {}

    def typing(n):
        n.keys("o", settle=0.15)
        type_text(n, t["type"], 0.07)
        time.sleep(0.5)
        leave_insert(n)

    def mouse_moves(n):
        # pointer drifting over code: every cell change is a <MouseMove> for config/mouse-hover.lua
        for i in range(100):
            n.mouse(10 + (i // 25) * 6, 20 + (i % 25) * 3, "move", settle=0)
            time.sleep(0.016)

    # name, setup, action, keys sent
    plan = [
        ("scroll_j", lambda: n.keys("gg", settle=0.3), lambda n: keyloop(n, ["j"] * 150, 0.033), 150),
        ("half_page", lambda: n.keys("gg", settle=0.3), lambda n: keyloop(n, ["<C-d>"] * 30 + ["<C-u>"] * 30, 0.08), 60),
        ("wheel", lambda: n.keys("gg", settle=0.3), lambda n: wheel(n, 60, 0.03), 60),
        ("word_motion", lambda: (r.goto(t["anchor"], t.get("anchor2")), n.keys("0", settle=0.2)), lambda n: keyloop(n, ["w"] * 120, 0.04), 120),
        ("jumps", lambda: None, lambda n: keyloop(n, ["G", "gg", "50%", "gg", "G", "25%", "75%", "gg"] * 2, 0.25), 16),
        ("mouse_move", lambda: (r.goto(t["anchor"], t.get("anchor2")), n.keys("zz", settle=0.3)), mouse_moves, 100),
        ("typing", lambda: (r.goto(t["anchor"], t.get("anchor2")), time.sleep(0.5)), typing, len(t["type"]) + 2),
    ]
    for name, setup, action, nkeys in plan:
        if ACTIONS and name not in ACTIONS:
            continue
        setup()
        res[name] = r.measure(name, action, nkeys)
        if name == "typing":
            # not `u`: LazyVim maps . , ; to `<c-g>u` in insert mode, so one typed line is several
            # undo steps; a leftover would be written by the save measurement below
            n.ex("e!")
    out["typed_ok"] = True
    if mode == "config" and not ACTIONS:
        # LSP round trips at the anchor (a symbol inside the function the typing happened in)
        r.goto(t["anchor"], t.get("anchor2"))
        n.keys("j", settle=0.2)
        row, col = n.lua("local p = vim.api.nvim_win_get_cursor(0); local l = vim.api.nvim_get_current_line(); local c = l:find('[%a_]') or 1; return {p[1]-1, c-1}")
        rt = {}
        for m in ["textDocument/hover", "textDocument/definition", "textDocument/references", "textDocument/documentSymbol", "textDocument/completion"]:
            v = n.lua(LSP_RT, m, row, col, 3, timeout=200)
            rt[m.split("/")[1]] = {"ms": [round(x, 1) for x in v.get("times", [])], "size": v.get("sizes"), "err": v.get("err")}
        out["lsp_rt"] = rt
        # write time with format-on-save, on an unmodified buffer (conform still runs the formatter);
        # changed_by_format = what the formatter rewrote in a file nobody edited
        n.lua(r"""
          _G.__wt = {}
          vim.api.nvim_create_autocmd('BufWritePre', { once = true, callback = function() _G.__wt.pre = vim.uv.hrtime() end })
          vim.api.nvim_create_autocmd('BufWritePost', { once = true, callback = function() _G.__wt.post = vim.uv.hrtime() end })""")
        r.measure("save", lambda n: n.keys(":w<CR>", settle=0.2), 1)
        n.wait("return _G.__wt.post ~= nil", 20, "write")
        out["save_ms"] = round(n.lua("return (_G.__wt.post - _G.__wt.pre) / 1e6"), 1)
        out["changed_by_format"] = sh(["git", "-C", t["cwd"], "diff", "--stat", "--", t["file"]]).stdout.strip()
        sh(["git", "-C", t["cwd"], "checkout", "--", t["file"]])
        n.ex("e!")
    if PROFILE and not ACTIONS:
        n.keys("gg", settle=0.3)
        out["profile_scroll"] = profile(r, lambda n: keyloop(n, ["j"] * 150, 0.033))
        r.goto(t["anchor"], t.get("anchor2"))
        out["profile_typing"] = profile(r, lambda n: (n.keys("o", settle=0.15), type_text(n, t["type"], 0.07), time.sleep(0.5), leave_insert(n), n.ex("e!")))
    out["memory"] = r.close()
    out["actions"] = res
    return out


def main():
    if AB and AB not in AB_VARIANTS:
        sys.exit(f"unknown AB variant {AB!r}; known: {', '.join(AB_VARIANTS)}")
    targets = load_targets()
    want = [a for a in sys.argv[1:]] or [k for k in targets if not k.startswith("_")]
    results = []
    for rep in range(1, REPEAT + 1):
        for k in want:
            t = targets[k]
            print(f"== {k} {t['file']} ({MODE}, run {rep})", flush=True)
            o = one_run(t, MODE)
            o["target"], o["run"] = k, rep
            results.append(o)
            print(json.dumps({x: o[x] for x in o if not x.startswith("profile")}, indent=None)[:3000], flush=True)
    json.dump(results, open(os.path.join(HERE, f"perf-{MODE}{'-' + AB if AB else ''}.json"), "w"), indent=1)


if __name__ == "__main__":
    main()
