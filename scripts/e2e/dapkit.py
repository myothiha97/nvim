"""Shared helpers for debugger scenarios."""
import glob, json, os, subprocess, time

from nvh import Nvim, Timeout

STATE_LUA = r"""
local dap = package.loaded['dap']
local s = dap and dap.session()
local wins = {}
for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
  local b = vim.api.nvim_win_get_buf(w)
  local cfg = vim.api.nvim_win_get_config(w)
  table.insert(wins, { ft = vim.bo[b].filetype, h = vim.api.nvim_win_get_height(w), w = vim.api.nvim_win_get_width(w),
    float = cfg.relative ~= '', winbar = vim.wo[w].winbar ~= '' and vim.api.nvim_eval_statusline(vim.wo[w].winbar, {winid=w, use_winbar=true}).str or nil })
end
local bps = {}
if package.loaded['dap.breakpoints'] then
  for buf, list in pairs(require('dap.breakpoints').get()) do
    for _, bp in ipairs(list) do
      table.insert(bps, { file = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ':t'), line = bp.line,
        condition = bp.condition, hit = bp.hitCondition, log = bp.logMessage })
    end
  end
end
local f = s and s.current_frame
return {
  session = s and s.config.name or nil,
  nsessions = dap and vim.tbl_count(dap.sessions()) or 0,
  stopped = s and s.stopped_thread_id ~= nil or false,
  frame = f and { name = f.name, line = f.line, file = f.source and f.source.path and vim.fn.fnamemodify(f.source.path, ':t') } or nil,
  cur = { file = vim.fn.expand('%:t'), line = vim.fn.line('.'), ft = vim.bo.filetype },
  wins = wins, bps = bps, mode = vim.api.nvim_get_mode().mode,
}
"""


def st(n):
    return n.lua(STATE_LUA)


def fts(n):
    return [w["ft"] for w in st(n)["wins"]]


def bar(n):
    for w in st(n)["wins"]:
        if w["ft"] == "dap-repl" and w.get("winbar"):
            return w["winbar"]
    return None


# Saved breakpoints / swap files are keyed by path ("/" -> "%"). Only the fixtures' own files
# are touched: never delete the user's real breakpoints or swap files.
FX = os.environ.get("E2E_FX", "/tmp/nvim-e2e-fx")
_FX_KEY = FX.replace("/", "%")
BP_DIR = os.path.join(os.environ.get("XDG_DATA_HOME", os.path.expanduser("~/.local/share")), "nvim/debugging/breakpoints")
SWAP_DIR = os.path.join(os.environ.get("XDG_STATE_HOME", os.path.expanduser("~/.local/state")), "nvim/swap")


def _fx_files(d, pattern):
    return [f for f in glob.glob(os.path.join(d, pattern)) if _FX_KEY in os.path.basename(f)]


def clean_bp_store():
    for f in _fx_files(BP_DIR, "*.json"):
        os.remove(f)


def bp_store():
    out = {}
    for f in _fx_files(BP_DIR, "*.json"):
        out[os.path.basename(f)] = json.load(open(f))
    return out


def open_nvim(cwd, args, **kw):
    for f in _fx_files(SWAP_DIR, "*"):
        os.remove(f)
    subprocess.run(["git", "-C", cwd, "checkout", "-q", "."])  # fixtures back to committed state
    n = Nvim(cwd, args, **kw)
    n.wait("local c=require('lazy.core.config').plugins['which-key.nvim']; return c and c._.loaded ~= nil", 40, "VeryLazy")
    time.sleep(0.8)
    resolve_aliases(n)
    return n


# Keys looked up by their which-key description, so remapping a feature doesn't break tests.
ALIASES = {"<BP>": "Toggle Breakpoint", "<BPD>": "Disable/Enable Breakpoint"}


def resolve_aliases(n):
    n.aliases = {}
    for alias, desc in ALIASES.items():
        lhs = n.lua("for _,m in ipairs(vim.api.nvim_get_keymap('n')) do if m.desc == ... then return m.lhs end end return nil", desc)
        if not lhs:
            raise RuntimeError(f"no normal-mode key with desc {desc!r}")
        n.aliases[alias] = lhs.replace(" ", "<leader>", 1) if lhs.startswith(" ") else lhs


def wait_stopped(n, timeout=40, line=None, fn=None):
    cond = "local s=require('dap').session(); return s and s.stopped_thread_id ~= nil and s.current_frame ~= nil"
    if line:
        cond += f" and s.current_frame.line == {line}"
    if fn:
        cond += f" and s.current_frame.name:find('{fn}', 1, true)"
    n.wait(cond + " and true or false", timeout, f"stopped line={line} fn={fn}")
    time.sleep(0.4)  # let dap-ui render
    return st(n)


def wait_running(n, timeout=5):
    n.wait("local s=require('dap').session(); return s and not s.stopped_thread_id", timeout, "running")


def wait_no_session(n, timeout=20):
    n.wait("return package.loaded['dap'] and require('dap').session() == nil", timeout, "session ended")


def pick_config(n, filter_text=None):
    n.keys("<leader>dc")
    n.wait_screen(r"Configuration|Select config|configuration", 10, "config picker")
    if filter_text:
        n.keys(filter_text, settle=0.3)
    n.keys("<CR>")


def repl_text(n):
    return n.lua("for _,b in ipairs(vim.api.nvim_list_bufs()) do if vim.bo[b].filetype=='dap-repl' then return table.concat(vim.api.nvim_buf_get_lines(b,0,-1,false),'\\n') end end return ''")


def errors_in_messages(n):
    msgs = n.messages()
    bad = [l for l in msgs.splitlines() if any(k in l for k in ("E5108", "stack traceback", "Error executing", "E5113", "attempt to", "Error in"))]
    return bad, msgs


def notif_history(n):
    fid = n.lua("local ok,f=pcall(require,'fidget.notification') if not ok or not f.get_history then return {} end local out={} for _,x in ipairs(f.get_history()) do table.insert(out, {level=x.level, title=x.group_name or x.annote, msg=tostring(x.message)}) end return out") or []
    return fid + _snacks_hist(n)


def _snacks_hist(n):
    return n.lua("local ok,h=pcall(function() return require('snacks').notifier.get_history() end) if not ok then return {} end local out={} for _,x in ipairs(h) do table.insert(out, {level=x.level, title=x.title, msg=tostring(x.msg)}) end return out")
