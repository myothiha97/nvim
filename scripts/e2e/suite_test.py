"""Test runner (neotest + custom panel/history/coverage) scenarios."""
import json, os, re, subprocess, sys, time

from dapkit import *  # noqa
from runner import test, run_all

FX = os.environ.get("E2E_FX", "/tmp/nvim-e2e-fx")
GO = FX + "/goapp"
NODE = FX + "/nodeapp"
JEST = FX + "/jestapp"
PY = FX + "/pyapp"

COUNTS = """
local nt = require('neotest')
local out = {}
for _, id in ipairs(nt.state.adapter_ids()) do
  local c = nt.state.status_counts(id, { buffer = vim.api.nvim_get_current_buf() })
  if c then out[#out+1] = c end
end
return out[1]
"""


def counts(n):
    return n.lua(COUNTS) or {}


def wait_run_done(n, total_min=1, timeout=90):
    n.wait("local nt=package.loaded['neotest'] and require('neotest'); if not nt then return false end; "
           "for _,id in ipairs(nt.state.adapter_ids()) do local c=nt.state.status_counts(id,{buffer=vim.api.nvim_get_current_buf()}); "
           f"if c and c.running == 0 and (c.passed + c.failed + c.skipped) >= {total_min} then return true end end return false",
           timeout, "test run finished")
    time.sleep(0.6)
    return counts(n)


def buftext(n, pat):
    return n.lua(f"for _,b in ipairs(vim.api.nvim_list_bufs()) do local nm=vim.api.nvim_buf_get_name(b); if nm:find('{pat}', 1, true) or vim.bo[b].filetype=='{pat}' then return table.concat(vim.api.nvim_buf_get_lines(b,0,-1,false),'\\n') end end return ''") or ""


def virt_texts(n):
    return n.lua("local out={} for _,ns in pairs(vim.api.nvim_get_namespaces()) do for _,m in ipairs(vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, {details=true})) do local d=m[4]; if d.virt_text then local t='' for _,c in ipairs(d.virt_text) do t=t..c[1] end table.insert(out, (m[2]+1)..':'..t) end end end return out")


def diags(n):
    return n.lua("local out={} for _,d in ipairs(vim.diagnostic.get(0)) do local ns=vim.diagnostic.get_namespace(d.namespace); if ns and ns.name:find('neotest') then table.insert(out, (d.lnum+1)..':'..d.message:gsub('\\n',' ')) end end return out")


def opn(c, cwd, f):
    clean_bp_store()
    c.n = open_nvim(cwd, [f])
    return c.n


@test("t/go-run-file-results-inline")
def _(c):
    n = opn(c, GO, "calc/calc_test.go")
    n.keys("<leader>tt")
    cnt = wait_run_done(n, 7)
    c.shot("after_run")
    c.note("counts " + json.dumps(cnt))
    c.check(cnt.get("passed", 0) >= 3 and cnt.get("failed", 0) >= 3 and cnt.get("skipped", 0) >= 1, "pass/fail/skip all detected", cnt)
    vt = virt_texts(n)
    c.note("virt: " + json.dumps(vt)[:600])
    d = diags(n)
    c.check(any(x.startswith("18:") and "want 10" in x for x in d), "failure message shown inline on failing line (Square)", d)
    c.check(any("want 5" in x for x in d), "subtest failure shown inline (TestTable/wrong)", d)
    c.check(any("divide by zero" in x or "panic" in x for x in d), "[known F12] panicking test reported inline", d)
    bad, _ = errors_in_messages(n)
    c.check(not bad, "no Lua errors", "\n".join(bad))


@test("t/go-run-nearest-last-subtest")
def _(c):
    n = opn(c, GO, "calc/calc_test.go")
    n.keys(":9<CR><leader>tr")
    cnt = wait_run_done(n, 1)
    c.check(cnt.get("passed") == 1 and cnt.get("failed", 0) == 0, "run nearest runs only TestAdd", cnt)
    n.keys(":34<CR><leader>tr")  # inside table loop -> nearest = TestTable
    time.sleep(1)
    cnt = wait_run_done(n, 2)
    c.note("after table nearest: " + json.dumps(cnt))
    c.check(cnt.get("failed", 0) >= 1, "nearest on table test runs it (wrong case fails)", cnt)
    n.keys("<leader>tl")
    time.sleep(1)
    cnt2 = wait_run_done(n, 2)
    c.check(cnt2 == cnt or cnt2.get("failed") == cnt.get("failed"), "run last repeats", (cnt, cnt2))


@test("t/go-results-panel")
def _(c):
    n = opn(c, GO, "calc/calc_test.go")
    n.keys("<leader>tt")
    wait_run_done(n, 7)
    n.keys("<leader>tO")
    time.sleep(1)
    txt = n.lua("return table.concat(vim.api.nvim_buf_get_lines(0,0,-1,false),'\\n')")
    c.shot("results_panel")
    c.check(st(n)["cur"]["ft"] != "go", "focus moved into results panel", st(n)["cur"])
    scr = n.screen()
    c.check("calc_test.go" in txt and re.search(r"\d+(\.\d+)? s|\d+ ms", scr), "run header with file + counts + duration", scr[:1200])
    c.check("TestSquareFails" in txt and "want 10" in txt, "failure with message listed", txt[:2000])
    c.check("TestSkipped" in txt, "skipped test listed", txt[:2000])
    # ]f to next failure then <CR> jumps to code
    n.keys("gg]f")
    time.sleep(0.3)
    line = n.lua("return vim.api.nvim_get_current_line()")
    c.check("" in line or "✗" in line or "Test" in line, "]f moves to a failure row", line)
    n.keys("<CR>")
    time.sleep(0.6)
    s = st(n)
    c.check(s["cur"]["file"] == "calc_test.go" and s["cur"]["ft"] == "go", "<CR> on failure jumps to the test in code", s["cur"])
    c.check(any(w["ft"] == "testing-results" or "Results" in (w.get("winbar") or "") for w in s["wins"]) or len([w for w in s["wins"] if not w["float"]]) >= 2, "panel stays open after jump (like JetBrains)", s["wins"])
    n.keys("<leader>tO")  # toggle: closes
    time.sleep(0.6)
    n.keys("<leader>tO")  # opens again, focused
    time.sleep(0.8)
    n.keys("q")
    time.sleep(0.4)
    c.check(not any("Test Results" in (w.get("winbar") or "") for w in st(n)["wins"]) and st(n)["cur"]["ft"] == "go", "q closes the panel", st(n)["wins"])
    # reopen -> still works (old bug: q worked only once)
    n.keys("<leader>tO")
    time.sleep(0.8)
    ft = st(n)["cur"]["ft"]
    n.keys("q")
    time.sleep(0.4)
    c.check(st(n)["cur"]["ft"] == "go", "q closes the panel the 2nd time too", (ft, st(n)["cur"]))


@test("t/go-summary-output-rerun-failed")
def _(c):
    n = opn(c, GO, "calc/calc_test.go")
    n.keys("<leader>tt")
    wait_run_done(n, 7)
    n.keys("<leader>ts")
    time.sleep(1.2)
    summ = buftext(n, "neotest-summary")
    c.shot("summary")
    c.check("TestAdd" in summ and "TestTable" in summ, "summary tree lists tests", summ[:800])
    n.keys("<leader>ts")
    time.sleep(0.4)
    # output float on failing test
    n.keys(":16<CR><leader>to")
    time.sleep(1.2)
    fl = [w for w in st(n)["wins"] if w["float"] and w["ft"] != "scrollview"]
    c.shot("output_float")
    out = n.lua("return table.concat(vim.api.nvim_buf_get_lines(0,0,-1,false),'\\n')")
    c.check(fl and "want 10" in out, "<leader>to shows failing test output", out[:600])
    n.keys("q")
    time.sleep(0.4)
    # Rerun failed
    t0 = time.time()
    n.keys("<leader>tF")
    time.sleep(2)
    cnt = wait_run_done(n, 7, timeout=120)
    c.note(f"rerun failed took {time.time()-t0:.1f}s; counts {cnt}")
    c.check(cnt.get("failed", 0) >= 3, "failed tests still failed after rerun", cnt)


@test("t/go-stop-long-test")
def _(c):
    n = opn(c, GO, "calc/calc_test.go")
    # make a long test on the fly (not saved to git)
    n.keys(":54<CR>")
    n.keys("<leader>tr")
    time.sleep(0.8)
    n.keys("<leader>tS")
    time.sleep(2.5)
    left = subprocess.run("ps -eo pid,etime,args | grep -E 'calc.test|go test' | grep -v grep", shell=True, capture_output=True, text=True).stdout.strip()
    c.note("processes after stop: " + (left or "none"))
    cnt = counts(n)
    c.check(cnt.get("running", 0) == 0, "stop clears running state", cnt)


@test("t/go-history-marks-coverage-discover")
def _(c):
    n = opn(c, GO, "calc/calc_test.go")
    n.keys("<leader>tt")
    wait_run_done(n, 7)
    n.keys("<leader>th")
    time.sleep(1.2)
    c.shot("history")
    scr = n.screen()
    c.check("calc_test" in scr or "Test" in scr, "<leader>th shows run history picker", scr[-2500:])
    n.keys("<Esc><Esc>")
    time.sleep(0.3)
    vt_before = len(virt_texts(n))
    n.keys("<leader>tx")
    time.sleep(0.5)
    vt_after = len(virt_texts(n))
    c.check(vt_after < vt_before, "<leader>tx hides inline test marks", (vt_before, vt_after))
    n.keys("<leader>tx")
    time.sleep(0.5)
    c.check(len(virt_texts(n)) >= vt_before, "<leader>tx again shows them without rerun", len(virt_texts(n)))
    # coverage: (1) with a panicking test in the package Go writes an empty profile -> clear warning
    n.keys("<leader>tcf")
    time.sleep(1)
    wait_run_done(n, 7, timeout=120)
    time.sleep(2.5)
    msgs = n.messages()
    c.check("panicked" in msgs, "empty Go profile: warning names the panic cause", msgs[-400:])
    # (2) without the panicking test: real coverage in the gutter
    n.lua("vim.cmd('silent! %s/_ = Div(1, 0)/_ = Div(1, 1)/') vim.cmd('silent write')")
    n.keys("<leader>tcf")
    time.sleep(1)
    wait_run_done(n, 7, timeout=120)
    time.sleep(2.5)
    n.lua("vim.cmd('edit calc/calc.go')")
    time.sleep(1.5)
    cov = n.lua("local cnt=0 for _,m in ipairs(vim.api.nvim_buf_get_extmarks(0,-1,0,-1,{details=true})) do local g=(m[4].sign_hl_group or '')..(m[4].line_hl_group or '')..(m[4].number_hl_group or '') if g:find('[Cc]over') then cnt=cnt+1 end end return cnt")
    c.shot("coverage")
    c.check(cov and cov >= 3, "coverage marks (Coverage* highlight) on calc.go lines", cov)
    n.keys("<leader>tcs")
    time.sleep(1)
    c.shot("coverage_summary")
    c.check("calc" in n.screen() and "%" in n.screen(), "coverage summary opens with percentages", n.screen()[-1500:])
    n.keys("q")
    time.sleep(0.4)
    n.lua("vim.cmd('buffer calc_test.go')")
    n.keys("<leader>tD")
    time.sleep(1)
    found = ""
    for _ in range(30):
        found = n.screen()
        if re.search(r"\d+ tests? in \d+ files?", found):
            break
        time.sleep(0.2)
    c.check(re.search(r"\d+ tests? in \d+ files?", found), "<leader>tD reports 'N tests in M files' (fidget)", found[-600:])


@test("t/vitest-run-file")
def _(c):
    n = opn(c, NODE, "src/math.test.ts")
    n.keys("<leader>tt")
    cnt = wait_run_done(n, 5, timeout=90)
    c.shot("vitest")
    c.note("counts " + json.dumps(cnt))
    c.check(cnt.get("passed", 0) >= 3 and cnt.get("failed", 0) == 1, "[known F7] vitest: passes + 1 failure detected", cnt)
    d = diags(n)
    c.check(any("10" in x and "9" in x for x in d), "vitest failure expected/received inline", d)
    vt = [x for x in virt_texts(n) if "expected 9 to be 10" in x]
    c.check(vt and len(vt[0]) < 200 and "node_modules" not in vt[0], "inline failure text is compact (no JS stack frames)", vt)
    n.keys("<leader>tO")
    time.sleep(1)
    txt = n.lua("return table.concat(vim.api.nvim_buf_get_lines(0,0,-1,false),'\\n')")
    c.shot("vitest_panel")
    c.check("fails on purpose" in txt, "results panel lists vitest failure", txt[:1500])


@test("t/jest-run-file")
def _(c):
    n = opn(c, JEST, "calc.test.js")
    n.keys("<leader>tt")
    cnt = wait_run_done(n, 2, timeout=90)
    c.note("counts " + json.dumps(cnt))
    c.check(cnt.get("passed") == 1 and cnt.get("failed") == 1, "jest: 1 pass 1 fail", cnt)
    d = diags(n)
    c.check(d, "jest failure inline", d)
    vt = [x for x in virt_texts(n) if "Expected" in x or "expect(" in x]
    c.note("jest inline: " + json.dumps(vt)[:400])
    c.check(vt and all("node_modules" not in x and len(x) < 400 for x in vt), "jest inline text has no stack frames", vt)


@test("t/pytest-run-file")
def _(c):
    n = opn(c, PY, "test_app.py")
    n.keys("<leader>tt")
    cnt = wait_run_done(n, 4, timeout=90)
    c.shot("pytest")
    c.note("counts " + json.dumps(cnt))
    c.check(cnt.get("passed", 0) >= 2 and cnt.get("failed", 0) >= 2, "pytest: parametrized + class tests detected", cnt)
    d = diags(n)
    c.check(any("assert 4 == 5" in x or "4 == 5" in x for x in d), "pytest assertion inline", d)


@test("t/right-click-run-test")
def _(c):
    n = opn(c, GO, "calc/calc_test.go")
    n.keys(":9<CR>zz")
    time.sleep(0.5)
    pos = n.lua("local p=vim.fn.screenpos(0, 9, 3); return {p.row, p.col}")
    n.mouse(pos[0], pos[1], "right")
    time.sleep(0.8)
    scr = n.screen()
    c.shot("menu")
    c.check("Run Test" in scr and "Debug Test" in scr, "right-click in test file offers Run Test / Debug Test", scr[-2500:])
    n.keys("<Esc>")


if __name__ == "__main__":
    rep = int(os.environ.get("REPEAT", "1"))
    run_all(rep, sys.argv[1:] or None, out=os.environ.get("OUT", "results_test.json"))
