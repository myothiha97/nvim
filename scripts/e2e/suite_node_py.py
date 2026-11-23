"""Node/TS (js-debug) and Python (debugpy) debugger scenarios."""
import json, os, re, subprocess, sys, time

from dapkit import *  # noqa
from runner import test, run_all

FX = os.environ.get("E2E_FX", "/tmp/nvim-e2e-fx")
NODE = FX + "/nodeapp"
JEST = FX + "/jestapp"
PY = FX + "/pyapp"


def panel(n, ft):
    return n.lua(f"for _,b in ipairs(vim.api.nvim_list_bufs()) do if vim.bo[b].filetype=='{ft}' then return table.concat(vim.api.nvim_buf_get_lines(b,0,-1,false),'\\n') end end return ''") or ""


def node_procs():
    out = subprocess.run("ps -eo pid,args | grep -E 'node .*(index.js|run.ts|vitest|jest)' | grep -v grep", shell=True, capture_output=True, text=True).stdout
    return out.strip()


def launch(c, cwd, file):
    clean_bp_store()
    c.n = open_nvim(cwd, [file])
    return c.n


@test("node/launch-file-step-exit")
def _(c):
    n = launch(c, NODE, "src/index.js")
    n.keys(":4<CR><leader>db")
    pick_config(n, "Launch file")
    s = wait_stopped(n, line=4, timeout=40)
    c.shot("stop")
    v = panel(n, "dapui_scopes")
    c.check("Myo" in v or "u:" in v or " u " in v, "Variables shows function locals (u)", v)
    stacks = panel(n, "dapui_stacks")
    c.check("greet" in stacks, "Call Stack shows greet frame", stacks[:800])
    internals = len(re.findall(r"node:internal|ModuleJob|processTicksAndRejections|task_queues|loader:", stacks))
    c.note(f"node-internal frames visible in Call Stack: {internals}")
    n.keys("<leader>do")
    s = wait_stopped(n, line=5)
    c.check(s["frame"]["line"] == 5, "step over -> line 5", s["frame"])
    n.keys("<leader>dO")
    s = wait_stopped(n)
    c.check(s["frame"]["line"] in (12, 13) and s["cur"]["file"] == "index.js", "step out -> back in caller (js-debug stops after the call)", s["frame"])
    n.keys("<leader>dc")
    n.wait("return package.loaded['dap'] and require('dap').session() == nil", 30, "exit")
    time.sleep(1)
    b = bar(n) or ""
    out = panel(n, "dap-repl")
    c.check("hi Myo (29)" in out and "done" in out, "console.log output visible in REPL", out[-500:])
    c.check("exited" in b or "Again" in b, "bar shows ended state", b)
    time.sleep(1)
    c.check(node_procs() == "", "no orphan node process after exit", node_procs())
    bad, _ = errors_in_messages(n)
    c.check(not bad, "no Lua errors", "\n".join(bad))


@test("node/stop-restart-child-session")
def _(c):
    n = launch(c, NODE, "src/index.js")
    n.keys(":4<CR><leader>db")
    pick_config(n, "Launch file")
    wait_stopped(n, line=4, timeout=40)
    stacks = panel(n, "dapui_stacks")
    c.check("Launch file" in stacks, "sessions list heads Call Stack (parent + child)", stacks[:400])
    n.keys("<leader>dR")
    time.sleep(1.5)
    s = wait_stopped(n, line=4, timeout=40)
    c.check(s["stopped"], "restart stops again at breakpoint", s)
    n.keys("<leader>dt")
    n.wait("return package.loaded['dap'] and vim.tbl_count(require('dap').sessions()) == 0", 20, "all sessions gone")
    time.sleep(1.5)
    c.check(node_procs() == "", "stop leaves no orphan node process", node_procs())
    n.keys("<leader>dl")
    s = wait_stopped(n, line=4, timeout=40)
    c.check(s["stopped"], "Run Again after stop works", s)
    n.keys("<leader>dt")
    time.sleep(1.5)


@test("node/npm-script")
def _(c):
    n = launch(c, NODE, "src/index.js")
    n.keys(":4<CR><leader>db")
    pick_config(n, "npm script")
    time.sleep(1.2)
    c.shot("script_picker")
    scr = n.screen()
    c.check("start" in scr, "npm script picker lists package.json scripts", scr[-3000:])
    n.keys("start", settle=0.3)
    n.keys("<CR>")
    s = wait_stopped(n, line=4, timeout=40)
    c.check(s["frame"]["file"] == "index.js", "npm script `start` stops at breakpoint", s["frame"])
    n.keys("<leader>dt")
    time.sleep(1.5)


@test("node/typescript-launch-sourcemaps")
def _(c):
    n = launch(c, NODE, "src/math.ts")
    n.keys(":2<CR><leader>db")
    n.lua("vim.cmd('edit src/run.ts')")
    pick_config(n, "Launch file")
    s = wait_stopped(n, timeout=40)
    c.shot("ts_stop")
    c.check(s["frame"]["file"] == "math.ts" and s["frame"]["line"] == 2, "TS breakpoint hit via tsx + source maps", s["frame"])
    n.keys("<leader>dt")
    time.sleep(1.5)


@test("node/vitest-debug-test")
def _(c):
    n = launch(c, NODE, "src/math.test.ts")
    n.lua("vim.cmd('edit src/math.ts')")
    n.keys(":2<CR><leader>db")
    n.lua("vim.cmd('buffer math.test.ts')")
    n.keys(":6<CR><leader>td")
    s = wait_stopped(n, timeout=60)
    c.shot("vitest_stop")
    c.check(s["frame"]["file"] == "math.ts" and s["frame"]["line"] == 2, "vitest Debug Test stops in math.ts", s["frame"])
    n.keys("<leader>dc")
    time.sleep(4)
    n.keys("<leader>dt")
    time.sleep(2)
    c.check(node_procs() == "", "no orphan vitest/node process", node_procs())


@test("node/jest-debug-test")
def _(c):
    n = launch(c, JEST, "calc.test.js")
    n.lua("vim.cmd('edit calc.js')")
    n.keys(":2<CR><leader>db")
    n.lua("vim.cmd('buffer calc.test.js')")
    n.keys(":4<CR><leader>td")
    s = wait_stopped(n, timeout=60)
    c.shot("jest_stop")
    c.check(s["frame"]["file"] == "calc.js" and s["frame"]["line"] == 2, "jest Debug Test stops in calc.js", s["frame"])
    n.keys("<leader>dt")
    time.sleep(2)
    c.check(node_procs() == "", "no orphan jest process", node_procs())


@test("py/launch-step-console")
def _(c):
    n = launch(c, PY, "app.py")
    n.keys(":2<CR><leader>db")
    pick_config(n)
    s = wait_stopped(n, line=2, timeout=40)
    time.sleep(0.8)
    c.shot("py_stop")
    v = panel(n, "dapui_scopes")
    c.check(re.search(r"\ba\b", v) and re.search(r"\bb\b", v), "Variables shows a, b", v)
    f = fts(n)
    c.note("windows: " + str(f))
    n.keys("<leader>do")
    s = wait_stopped(n, line=3)
    c.check(s["frame"]["line"] == 3, "step over", s["frame"])
    n.keys("<leader>dO")
    s = wait_stopped(n)
    c.check(s["frame"]["name"] == "main" or "main" in s["frame"]["name"], "step out to main", s["frame"])
    n.lua("vim.cmd('edit app.py')")
    n.keys(":2<CR><leader>db")
    n.keys("<leader>dc")
    n.wait("return package.loaded['dap'] and require('dap').session() == nil", 30, "exit")
    time.sleep(1)
    f = fts(n)
    c.shot("py_end")
    con = panel(n, "dapui_console") + panel(n, "dap-repl") + n.lua("local t={} for _,b in ipairs(vim.api.nvim_list_bufs()) do if vim.bo[b].buftype=='terminal' then table.insert(t, table.concat(vim.api.nvim_buf_get_lines(b,0,-1,false),'\\n')) end end return table.concat(t,'\\n')")
    c.check("done" in con, "program output visible (console/terminal)", con[-500:])
    bad, _ = errors_in_messages(n)
    c.check(not bad, "no Lua errors", "\n".join(bad))


@test("py/debug-test")
def _(c):
    n = launch(c, PY, "test_app.py")
    n.lua("vim.cmd('edit app.py')")
    n.keys(":2<CR><leader>db")
    n.lua("vim.cmd('buffer test_app.py')")
    n.keys(":6<CR><leader>td")
    s = wait_stopped(n, timeout=60)
    c.shot("pytest_stop")
    c.check(s["frame"]["file"] == "app.py" and s["frame"]["line"] == 2, "pytest Debug Test stops in add()", s["frame"])
    n.keys("<leader>dt")
    time.sleep(1.5)


if __name__ == "__main__":
    rep = int(os.environ.get("REPEAT", "1"))
    run_all(rep, sys.argv[1:] or None, out=os.environ.get("OUT", "results_np.json"))
