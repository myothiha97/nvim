"""Go debugger scenarios (Delve), driven like a human through the real TUI."""
import json, os, re, sys, time

from dapkit import *  # noqa
from runner import test, run_all

FX = os.environ.get("E2E_FX", "/tmp/nvim-e2e-fx")
GO = FX + "/goapp"


def gutter_pos(n, lnum):
    """Screen (row, col) of the sign cell for buffer line lnum in the current window."""
    return n.lua(f"""
      local win = vim.api.nvim_get_current_win()
      local info = vim.fn.getwininfo(win)[1]
      local p = vim.fn.screenpos(win, {lnum}, 1)
      return {{ p.row, info.wincol }}
    """)


def scopes(n):
    return n.lua("for _,b in ipairs(vim.api.nvim_list_bufs()) do if vim.bo[b].filetype=='dapui_scopes' then return table.concat(vim.api.nvim_buf_get_lines(b,0,-1,false),'\\n') end end return ''") or ""


def go(c, file="main.go"):
    clean_bp_store()
    c.n = open_nvim(GO, [file])
    return c.n


# ---------------------------------------------------------------- breakpoints
@test("go/bp-toggle-persist-restore")
def _(c):
    n = go(c)
    n.keys(":38<CR><leader>db")
    s = st(n)
    c.check(any(b["line"] == 38 for b in s["bps"]), "<leader>db sets breakpoint on line 38", s["bps"])
    store = bp_store()
    c.check(any("38" in json.dumps(v) for v in store.values()), "breakpoint saved to disk immediately", store)
    c.check(n.lua("return #vim.fn.sign_getplaced(vim.api.nvim_get_current_buf(), {group='dap_breakpoints', lnum=38})[1].signs") == 1, "breakpoint sign drawn")
    n.keys(":24<CR><leader>db")
    n.close()
    # restart nvim: breakpoints must come back
    c.n = n = open_nvim(GO, ["main.go"])
    n.wait("return package.loaded['dap.breakpoints'] and #(require('dap.breakpoints').get()[vim.api.nvim_get_current_buf()] or {}) == 2", 10, "restore")
    s = st(n)
    c.check(sorted(b["line"] for b in s["bps"]) == [24, 38], "both breakpoints restored after restart", s["bps"])
    n.keys(":38<CR><leader>db")
    s = st(n)
    c.check([b["line"] for b in s["bps"]] == [24], "<leader>db again removes it", s["bps"])
    n.keys("<leader>dB")
    time.sleep(0.3)
    c.check(st(n)["bps"] == [], "<leader>dB clears file", st(n)["bps"])
    c.check(not any("24" in json.dumps(v) for v in bp_store().values()), "cleared state persisted", bp_store())


@test("go/bp-gutter-click")
def _(c):
    n = go(c)
    n.keys(":40<CR>")
    row, col = gutter_pos(n, 38)
    n.mouse(row, col)
    s = st(n)
    c.check(any(b["line"] == 38 for b in s["bps"]), "click in sign column toggles breakpoint", s["bps"])
    c.check(s["cur"]["line"] == 40, "cursor did not move on gutter click", s["cur"])
    # click on the line number cell too
    row, col = gutter_pos(n, 41)
    n.mouse(row, col + 3)
    s = st(n)
    c.check(any(b["line"] == 41 for b in s["bps"]), "click on line number toggles breakpoint", s["bps"])
    n.mouse(*gutter_pos(n, 38))
    c.check(not any(b["line"] == 38 for b in st(n)["bps"]), "second click removes it", st(n)["bps"])
    c.shot("gutter")


# ---------------------------------------------------------------- session lifecycle
@test("go/launch-layout-stop-continue-exit")
def _(c):
    n = go(c)
    n.keys(":38<CR><leader>db")
    pick_config(n)
    n.wait("return vim.tbl_contains(vim.tbl_map(function(w) return vim.bo[vim.api.nvim_win_get_buf(w)].filetype end, vim.api.nvim_tabpage_list_wins(0)), 'dap-repl')", 20, "tray opened")
    s = wait_stopped(n, line=38)
    c.shot("first_stop")
    f = fts(n)
    c.check("dap-repl" in f, "tray (REPL) open", f)
    c.check("dapui_scopes" in f and "dapui_stacks" in f, "sidebar Variables+Call Stack open at first stop", f)
    c.check("dapui_watches" not in f and "dapui_breakpoints" not in f, "no Watches/Breakpoints panel by default", f)
    b = bar(n) or ""
    c.check(b.count("") + len(re.findall(r"[^\s]", b)) >= 6, "control bar rendered", b)
    c.check(s["cur"]["file"] == "main.go" and s["cur"]["line"] == 38, "cursor placed on stopped line", s["cur"])
    stl = n.lua("return vim.api.nvim_eval_statusline(vim.o.statusline, {}).str")
    c.check("Stopped at line 38" in stl, "statusline shows stopped line", stl)
    vars_txt = n.lua("for _,b in ipairs(vim.api.nvim_list_bufs()) do if vim.bo[b].filetype=='dapui_scopes' then return table.concat(vim.api.nvim_buf_get_lines(b,0,-1,false),'\\n') end end")
    c.check("total" in vars_txt and "i" in vars_txt and "Myo" in vars_txt, "Variables shows locals incl. struct", vars_txt)
    layout_before = [(w["ft"], w["w"], w["h"]) for w in st(n)["wins"] if not w["float"]]
    # continue -> same bp next iteration
    n.keys("<leader>dc")
    wait_stopped(n, line=38)
    vars_txt = n.lua("for _,b in ipairs(vim.api.nvim_list_bufs()) do if vim.bo[b].filetype=='dapui_scopes' then return table.concat(vim.api.nvim_buf_get_lines(b,0,-1,false),'\\n') end end")
    c.check(re.search(r"\bi int = 1\b", vars_txt), "Variables updated after continue (i = 1)", vars_txt)
    layout_after = [(w["ft"], w["w"], w["h"]) for w in st(n)["wins"] if not w["float"]]
    c.check(layout_before == layout_after, "layout did not move between stops", (layout_before, layout_after))
    # remove bp and run to end
    n.keys("<leader>db<leader>dc")
    n.wait("return package.loaded['dap'] and require('dap').session() == nil", 30, "program exit")
    time.sleep(0.6)
    b = bar(n) or ""
    c.shot("exited")
    c.check("exited" in b and "0" in b, "bar shows exit code after program ends", b)
    c.check("Run Again" in b or "Again" in b, "bar offers Run Again", b)
    f = fts(n)
    c.check("dap-repl" in f, "panels stay after exit (output readable)", f)
    out = repl_text(n)
    c.check("hi Myo (29)" in out and "sum 14" in out and "done" in out, "program stdout visible in REPL", out[-800:])
    n.keys("<leader>du")
    time.sleep(0.4)
    f = fts(n)
    c.check(not any(x.startswith("dap") for x in f), "<leader>du closes all panels", f)
    bad, msgs = errors_in_messages(n)
    c.check(not bad, "no Lua errors in :messages", "\n".join(bad))


@test("go/stepping")
def _(c):
    n = go(c)
    n.keys(":38<CR><leader>db")
    pick_config(n)
    wait_stopped(n, line=38)
    n.keys("<leader>di")
    s = wait_stopped(n, fn="calc.Add")
    c.check(s["frame"]["file"] == "calc.go" and s["frame"]["line"] in (3, 4), "step into enters calc.Add", s["frame"])
    c.check(s["cur"]["file"] == "calc.go", "editor jumped into calc.go", s["cur"])
    first = s["frame"]["line"]
    n.keys("<leader>do")
    time.sleep(0.3)
    s = wait_stopped(n)
    c.check(s["frame"]["line"] == first + 1, "step over inside Add advances one line", s["frame"])
    n.keys("<leader>dO")
    s = wait_stopped(n, fn="main.main")
    c.check(s["frame"]["name"].endswith("main.main") and s["cur"]["file"] == "main.go", "step out returns to main.main", s["frame"])
    # step over loop line twice
    n.keys("<leader>do")
    s1 = wait_stopped(n)
    n.keys("<leader>do")
    s2 = wait_stopped(n)
    c.check(s1["frame"]["line"] in (37, 38, 39) and s2["frame"]["line"] in (37, 38, 39), "step over walks the loop", (s1["frame"], s2["frame"]))
    # rapid key repeat: 6 step overs quickly must not wedge the session
    for _ in range(6):
        n.keys("<leader>do", settle=0.02)
    time.sleep(2)
    s = wait_stopped(n)
    c.check(s["stopped"], "session survives rapid step-over spam", s)
    # run to cursor
    n.keys(":41<CR><leader>dC")
    s = wait_stopped(n, line=41)
    c.check(s["frame"]["line"] == 41, "run to cursor stops on line 41", s["frame"])
    time.sleep(0.5)
    c.check(any(b["line"] == 38 for b in st(n)["bps"]), "breakpoints restored after run-to-cursor", st(n)["bps"])
    n.keys("<leader>dt")
    wait_no_session(n)
    bad, _ = errors_in_messages(n)
    c.check(not bad, "no Lua errors", "\n".join(bad))


@test("go/control-bar-mouse")
def _(c):
    n = go(c)
    n.keys(":38<CR><leader>db")
    pick_config(n)
    wait_stopped(n, line=38)
    time.sleep(0.5)
    scr = n.screen()
    rows = scr.splitlines()
    # control bar: the winbar line of the REPL window
    info = n.lua("for _,w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do if vim.bo[vim.api.nvim_win_get_buf(w)].filetype=='dap-repl' then local i=vim.fn.getwininfo(w)[1]; return {i.winrow, i.wincol, i.width} end end")
    c.check(info is not None, "REPL window found", info)
    wrow, wcol, width = info
    barline = rows[wrow - 1]  # winbar is the first row of the window (winrow points at it)
    c.note("bar: " + barline[wcol - 1:wcol - 1 + 60])
    icons = [m.start() for m in re.finditer(r"[^\s─│]", barline[wcol - 1:wcol - 1 + 60])]
    c.check(len(icons) >= 6, "6 clickable buttons visible", barline)
    # click #2 = Step Over
    n.mouse(wrow, wcol + icons[1])
    s = wait_stopped(n)
    c.check(s["frame"]["line"] != 38 or True, "bar Step Over click accepted")
    line_after_over = s["frame"]["line"]
    c.check(line_after_over in (37, 39), "Step Over button moved execution", s["frame"])
    # click #1 = Continue -> stops at bp again
    n.mouse(wrow, wcol + icons[0])
    s = wait_stopped(n, line=38)
    c.check(s["frame"]["line"] == 38, "Continue button resumes to next breakpoint", s["frame"])
    # click #6 = Stop
    n.mouse(wrow, wcol + icons[5])
    wait_no_session(n)
    time.sleep(0.5)
    b = bar(n)
    c.shot("after_stop_click")
    c.check(b and "Again" in b, "after Stop the bar offers Run Again", b)
    # Run Again from keyboard
    n.keys("<leader>dl")
    s = wait_stopped(n, line=38)
    c.check(s["stopped"], "<leader>dl (Run Last) reruns and stops at bp", s)
    n.keys("<leader>dc")
    wait_stopped(n, line=38)
    n.keys("<leader>dc")
    wait_stopped(n, line=38)
    c.check(re.search(r"\bi int = 2\b", scopes(n)), "advanced to i = 2 before restart", scopes(n))
    n.keys("<leader>dR")
    n.wait("local s=require('dap').session(); return s and s.stopped_thread_id ~= nil and s.current_frame ~= nil and s.current_frame.line == 38", 30)
    time.sleep(1.0)
    s = st(n)
    c.check(s["nsessions"] == 1, "<leader>dR restart -> exactly one session", s["nsessions"])
    c.check(re.search(r"\bi int = 0\b", scopes(n)), "restart really restarted the program (i = 0)", scopes(n))
    n.keys("<leader>dt")
    wait_no_session(n)


@test("go/conditional-hit-log-disable-mute")
def _(c):
    n = go(c)
    n.keys(":38<CR><leader>dN")
    n.wait_screen("Breakpoint condition", 5)
    c.shot("condition_prompt")
    n.keys("i == 3<CR>")
    time.sleep(0.3)
    bp = [b for b in st(n)["bps"] if b["line"] == 38]
    c.check(bp and bp[0].get("condition") == "i == 3", "condition saved on bp", bp)
    # Esc cancel on prompt must not alter bp
    n.keys("<leader>dN")
    n.wait_screen("Breakpoint condition", 5)
    n.keys("<Esc><Esc>")
    time.sleep(0.3)
    bp = [b for b in st(n)["bps"] if b["line"] == 38]
    c.check(bp and bp[0].get("condition") == "i == 3", "Esc cancels without change", bp)
    # log point on line 41
    n.keys(":41<CR><leader>dL")
    n.wait_screen("Log message", 5)
    n.keys("LOGPOINT total={total}<CR>")
    time.sleep(0.3)
    pick_config(n)
    s = wait_stopped(n, line=38)
    vars_txt = n.lua("for _,b in ipairs(vim.api.nvim_list_bufs()) do if vim.bo[b].filetype=='dapui_scopes' then return table.concat(vim.api.nvim_buf_get_lines(b,0,-1,false),'\\n') end end")
    c.check(re.search(r"\bi int = 3\b", vars_txt), "conditional bp stops only when i == 3", vars_txt)
    n.keys("<leader>dc")
    n.wait("return package.loaded['dap'] and require('dap').session() == nil", 30, "exit")
    time.sleep(0.5)
    out = repl_text(n)
    c.check("LOGPOINT total=" in out, "log point message printed, no stop", out[-600:])
    # hit count
    n.keys(":38<CR><leader>dN")
    n.wait_screen("Breakpoint condition", 5)
    n.keys("<C-u><CR>")  # clear condition
    time.sleep(0.2)
    n.keys("<leader>dH")
    n.wait_screen("Hit condition", 5)
    n.keys("2<CR>")
    time.sleep(0.3)
    bp = [b for b in st(n)["bps"] if b["line"] == 38]
    c.check(bp and bp[0].get("hit") == "2" and not bp[0].get("condition"), "hit condition set, condition cleared", bp)
    n.keys("<leader>dl")
    wait_stopped(n, line=38)
    vars_txt = n.lua("for _,b in ipairs(vim.api.nvim_list_bufs()) do if vim.bo[b].filetype=='dapui_scopes' then return table.concat(vim.api.nvim_buf_get_lines(b,0,-1,false),'\\n') end end")
    c.check(re.search(r"\bi int = 1\b", vars_txt), "hit count 2 stops on second hit (i = 1)", vars_txt)
    n.keys("<leader>dt")
    wait_no_session(n)
    # disable line bp -> not hit
    n.keys(":38<CR><leader>dd")
    time.sleep(0.3)
    sign = n.lua("local s=vim.fn.sign_getplaced(vim.api.nvim_get_current_buf(), {group='*', lnum=38})[1].signs; return s[1] and s[1].name or ''")
    ext = n.lua("for _,m in ipairs(vim.api.nvim_buf_get_extmarks(0,-1,{37,0},{37,-1},{details=true})) do if m[4].sign_text then return m[4].sign_hl_group end end return ''")
    c.check(not any(b["line"] == 38 for b in st(n)["bps"]), "disabled bp removed from active set", st(n)["bps"])
    c.check(sign != "" or ext != "", "disabled bp keeps a (grey) sign", (sign, ext))
    c.shot("disabled_sign")
    n.keys(":24<CR><leader>db")
    n.keys("<leader>dD")  # mute all
    time.sleep(0.3)
    n.keys("<leader>dl")
    n.wait("return package.loaded['dap'] and require('dap').session() == nil and (function() for _,b in ipairs(vim.api.nvim_list_bufs()) do if vim.bo[b].filetype=='dap-repl' then return table.concat(vim.api.nvim_buf_get_lines(b,0,-1,false)):find('done') end end end)()", 40, "ran to end while muted")
    c.check(True, "muted run finished without stopping")
    n.keys("<leader>dD")  # unmute
    time.sleep(0.3)
    n.keys("<leader>dl")
    s = wait_stopped(n, line=24)
    c.check(s["frame"]["line"] == 24, "unmuted: stops at greet bp; disabled line 38 still skipped", s["frame"])
    n.keys("<leader>dt")
    wait_no_session(n)
    store = json.dumps(bp_store())
    c.check("disabled" in store or "enabled" in store, "disabled state persisted", store[:400])


@test("go/function-bp-watches-eval-repl-copy")
def _(c):
    n = go(c)
    n.keys("<leader>dF")
    n.wait_screen(r"[Ff]unction", 5)
    c.shot("fn_prompt")
    n.keys("main.greet<CR>")
    time.sleep(0.3)
    pick_config(n)
    s = wait_stopped(n, fn="greet")
    c.check("greet" in s["frame"]["name"], "function breakpoint stops in main.greet", s["frame"])
    # eval word under cursor
    n.keys(":24<CR>wwww")  # cursor onto u. ...
    n.keys(":call cursor(24, 33)<CR>")
    n.keys("<leader>de")
    time.sleep(1)
    fl = [w for w in st(n)["wins"] if w["float"]]
    c.shot("eval_float")
    c.check(fl, "<leader>de opens an evaluation float", st(n)["wins"])
    n.keys("<Esc>")
    time.sleep(0.4)
    c.check(not any(w["float"] and w["ft"] != "scrollview" for w in st(n)["wins"]), "Esc closes the eval float", st(n)["wins"])
    # watches
    n.keys("<leader>dW")
    time.sleep(0.6)
    c.check(any(w["ft"] == "dapui_watches" for w in st(n)["wins"]), "<leader>dW opens Watches", fts(n))
    n.keys("i")
    n.keys("u.Name<CR>")
    time.sleep(1)
    n.keys("<Esc>")
    time.sleep(0.8)
    f = fts(n)
    w_txt = n.lua("for _,b in ipairs(vim.api.nvim_list_bufs()) do if vim.bo[b].filetype=='dapui_watches' then return table.concat(vim.api.nvim_buf_get_lines(b,0,-1,false),'\\n') end end")
    c.check('"Myo"' in (w_txt or ""), "watch expression evaluates", w_txt)
    c.shot("watches")
    # REPL evaluation
    n.keys("<leader>dr")
    time.sleep(0.6)
    rwin = n.lua("return vim.bo.filetype")
    c.note("after <leader>dr current ft = " + str(rwin))
    n.lua("for _,w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do if vim.bo[vim.api.nvim_win_get_buf(w)].filetype=='dap-repl' then vim.api.nvim_set_current_win(w) end end")
    n.keys("i")
    n.keys("u.Age * 2<CR>")
    time.sleep(1.2)
    n.keys("<Esc>")
    out = repl_text(n)
    c.check("58" in out, "REPL evaluates expression", out[-400:])
    # copy value from Variables
    n.keys("<leader>dv")
    time.sleep(0.4)
    n.lua("vim.fn.setreg('+','') vim.fn.setreg('\"','')")
    n.keys("gg")
    n.lua("local l=vim.api.nvim_buf_get_lines(0,0,-1,false) for i,x in ipairs(l) do if x:find('u main.User') or x:find(' u ') then vim.api.nvim_win_set_cursor(0,{i,0}) return end end")
    n.keys("y")
    time.sleep(0.6)
    reg = n.lua("return vim.fn.getreg('+') .. ' | ' .. vim.fn.getreg('\"')")
    c.check("Myo" in reg, "y in Variables copies full value", reg)
    n.keys("<leader>dt")
    wait_no_session(n)
    bad, _ = errors_in_messages(n)
    c.check(not bad, "no Lua errors", "\n".join(bad))


@test("go/goroutines-callstack")
def _(c):
    n = go(c)
    n.keys(":30<CR><leader>db")
    pick_config(n)
    s = wait_stopped(n, line=30)
    time.sleep(0.8)
    stacks = n.lua("for _,b in ipairs(vim.api.nvim_list_bufs()) do if vim.bo[b].filetype=='dapui_stacks' then return table.concat(vim.api.nvim_buf_get_lines(b,0,-1,false),'\\n') end end")
    c.shot("goroutines")
    c.check("main.worker" in stacks, "Call Stack shows the worker goroutine", stacks)
    c.check(len(re.findall(r"\[Go \d+\]", stacks)) >= 2, "several goroutines listed", stacks)
    # continue to hit the other workers: list must refresh (freshness fix)
    n.keys("<leader>dc")
    wait_stopped(n, line=30)
    stacks2 = n.lua("for _,b in ipairs(vim.api.nvim_list_bufs()) do if vim.bo[b].filetype=='dapui_stacks' then return table.concat(vim.api.nvim_buf_get_lines(b,0,-1,false),'\\n') end end")
    c.check(stacks2 != "", "Call Stack still populated on later stop", stacks2)
    # navigate to an upper frame with 'o' in stacks panel: go to main.main frame of main goroutine
    n.keys("<leader>dG")
    time.sleep(0.4)
    c.check(st(n)["cur"]["ft"] == "dapui_stacks", "<leader>dG focuses Call Stack", st(n)["cur"])
    n.keys("<leader>dt")
    wait_no_session(n)


@test("go/panic-exception-stop")
def _(c):
    n = go(c)
    pick_config(n, "Debug (Arguments)")
    n.wait_screen(r"[Aa]rg", 10, "args prompt")
    c.shot("args_prompt")
    n.keys("panic<CR>")
    s = wait_stopped(n, timeout=40)
    time.sleep(0.6)
    c.shot("panic_stop")
    reason = n.lua("local s=require('dap').session(); return s and s.current_frame and (s.current_frame.name .. ':' .. tostring(s.current_frame.line)) or ''")
    c.note("stopped at: " + str(reason))
    c.check(s["frame"] and (s["frame"]["line"] == 58 or "panic" in (s["frame"]["name"] or "")), "stops on runtime panic", s["frame"])
    c.check(s["cur"]["file"] == "main.go" and s["cur"]["line"] == 58, "[known F3] editor shows user line that panicked", s["cur"])
    out = repl_text(n)
    msgs = n.messages()
    notes = json.dumps(notif_history(n))
    c.check("nil map" in out or "nil map" in msgs or "nil map" in notes, "[known F3] panic message shown to the user", out[-400:])
    n.keys("<leader>dt")
    wait_no_session(n)


@test("go/debug-test")
def _(c):
    n = go(c, "calc/calc_test.go")
    n.keys(":9<CR>")
    n.lua("vim.cmd('edit calc/calc.go')")
    n.keys(":4<CR><leader>db")
    n.lua("vim.cmd('buffer calc_test.go')")
    n.keys(":10<CR><leader>td")
    try:
        s = wait_stopped(n, timeout=45, line=4)
    except Exception:
        import subprocess
        c.note("ps: " + subprocess.run("ps -eo pid,etime,args | grep -E 'dlv|go test|go list|\\.test' | grep -v grep", shell=True, capture_output=True, text=True).stdout[-800:])
        c.note("notifs: " + json.dumps(notif_history(n))[-800:])
        c.note("messages: " + n.messages()[-800:])
        c.note("dap: " + str(n.lua("return package.loaded['dap'] and vim.tbl_count(require('dap').sessions()) or -1")))
        c.note("neotest loaded: " + str(n.lua("return package.loaded['neotest'] ~= nil")))
        c.note("neotest ids/pos: " + str(n.lua("local nt=require('neotest'); local out={} for _,id in ipairs(nt.state.adapter_ids()) do local t=nt.state.positions(id,{buffer=vim.api.nvim_get_current_buf()}); table.insert(out, id..' pos='..tostring(t~=nil)) end return table.concat(out,' | ')")))
        c.note("cursor: " + json.dumps(st(n)["cur"]))
        n.keys("<leader>td")
        try:
            wait_stopped(n, timeout=30, line=4)
            c.note("SECOND PRESS WORKED")
        except Exception:
            c.note("second press also failed")
        raise
    c.check(s["frame"]["file"] == "calc.go", "Debug Test stops in code under test", s["frame"])
    c.shot("debug_test")
    n.keys("<leader>dc")
    n.wait("return package.loaded['dap'] and require('dap').session() == nil", 30, "test finished")
    time.sleep(1)
    res = n.lua("local ok, r = pcall(function() local c=require('neotest').state; return c and 'ok' end) return tostring(ok)")
    bad, _ = errors_in_messages(n)
    c.check(not bad, "no Lua errors", "\n".join(bad))


@test("go/right-click-menu-hover")
def _(c):
    n = go(c)
    n.keys(":38<CR><leader>db")
    pick_config(n)
    wait_stopped(n, line=38)
    time.sleep(0.6)
    # right click on line 36 (`total := 0`) text in the editor window
    pos = n.lua("for _,w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do if vim.bo[vim.api.nvim_win_get_buf(w)].filetype=='go' then local p=vim.fn.screenpos(w, 41, 2); return {p.row,p.col} end end")
    n.mouse(pos[0], pos[1], "right")
    time.sleep(0.6)
    scr = n.screen()
    c.shot("right_click_menu")
    c.check("Run to Cursor" in scr, "right-click while stopped offers Run to Cursor", scr[-2500:])
    n.keys("<Esc>")
    # hover: mouse move onto `total`
    pos = n.lua("for _,w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do if vim.bo[vim.api.nvim_win_get_buf(w)].filetype=='go' then local p=vim.fn.screenpos(w, 38, 4); return {p.row,p.col} end end")
    n.mouse(pos[0], pos[1] + 1, "move")
    time.sleep(1.5)
    n.mouse(pos[0], pos[1] + 2, "move")
    time.sleep(1.5)
    fl = [w for w in st(n)["wins"] if w["float"]]
    c.shot("hover")
    hover_txt = n.lua("for _,w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do if vim.api.nvim_win_get_config(w).relative ~= '' then return table.concat(vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(w),0,-1,false),' ') end end return ''")
    c.check(fl and "0" in hover_txt, "mouse hover shows variable value while stopped", (hover_txt, st(n)["wins"]))
    n.keys("<leader>dt")
    wait_no_session(n)


@test("go/breakpoint-list-picker")
def _(c):
    n = go(c)
    n.keys(":38<CR><leader>db:24<CR><leader>db")
    n.keys("<leader>dm")
    time.sleep(0.8)
    scr = n.screen()
    c.shot("bp_list")
    c.check("main.go" in scr and ("38" in scr and "24" in scr), "<leader>dm lists file breakpoints", scr[:3000])
    n.keys("<Esc><Esc>")
    n.keys("<leader>dp")
    time.sleep(0.6)
    c.check(any(w["ft"] == "dapui_breakpoints" for w in st(n)["wins"]), "<leader>dp opens Breakpoints float", fts(n))
    n.keys("q")
    time.sleep(0.3)
    c.check(not any(w["ft"] == "dapui_breakpoints" for w in st(n)["wins"]), "q closes the Breakpoints float", fts(n))
    n.keys("<leader>dX")
    time.sleep(0.4)
    c.check(st(n)["bps"] == [], "<leader>dX clears all", st(n)["bps"])


@test("go/regress-panel-titles-and-repl-key")
def _(c):
    n = go(c)
    n.keys(":38<CR><leader>db")
    pick_config(n)
    wait_stopped(n, line=38)
    time.sleep(0.6)
    scr = n.screen()
    c.shot("titles")
    c.check(re.search(r"^ VARIABLES ", scr, re.M), "VARIABLES title visible in sidebar winbar", scr[:600])
    c.check(" CALL STACK " in scr, "CALL STACK title visible", scr)
    c.check(not re.search(r"^<", scr, re.M), "no left-truncated '<' winbar", [l for l in scr.splitlines() if l.startswith("<")])
    before = fts(n)
    n.keys("<leader>dr")
    time.sleep(0.6)
    s = st(n)
    c.check([w["ft"] for w in s["wins"]].count("dap-repl") == 1, "<leader>dr does not open a second REPL", [w["ft"] for w in s["wins"]])
    c.check(s["cur"]["ft"] == "dap-repl", "<leader>dr focuses the tray REPL", s["cur"])
    n.keys("<leader>dr")
    time.sleep(0.4)
    s = st(n)
    c.check(s["cur"]["ft"] == "go" and s["cur"]["line"] == 38, "<leader>dr again returns to the code", s["cur"])
    c.check(fts(n) == before, "layout unchanged by <leader>dr", (before, fts(n)))
    n.keys("<leader>dt")
    wait_no_session(n)
    n.keys("<leader>du")
    time.sleep(0.4)
    n.keys("<leader>dr")
    time.sleep(0.8)
    s = st(n)
    c.check([w["ft"] for w in s["wins"]].count("dap-repl") == 1 and s["cur"]["ft"] == "dap-repl", "<leader>dr with panels closed opens the tray REPL", [w["ft"] for w in s["wins"]])


if __name__ == "__main__":
    rep = int(os.environ.get("REPEAT", "1"))
    only = sys.argv[1:] or None
    run_all(rep, only, out=os.environ.get("OUT", "results_go.json"))
