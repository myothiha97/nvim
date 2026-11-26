"""Everyday editing on large real-world files: Go, TS, TSX, Python (targets.json).

Each scenario runs once per target, as `<target>: <scenario>`. Real TUI, real keys (see nvh.py).
  python3 suite_bigfile.py                 # all targets, all scenarios
  python3 suite_bigfile.py go: open        # name filter (substring)
  REPEAT=3 python3 suite_bigfile.py
Fixtures: setup_bigfile.sh clones the stand-in projects. Nothing is saved: edits are undone with :e!.
"""
import json, os, re, sys, time

import runner
from runner import test
from nvh import Nvim, sh, reset_fixture

HERE = os.path.dirname(os.path.abspath(__file__))
T = json.load(open(os.environ.get("E2E_TARGETS", os.path.join(HERE, "targets.json"))))
# targets without UI test data (the *-mid perf-only files) are skipped here
TARGETS = [k for k in T if not k.startswith("_") and "gd_from" in T[k]]

VERYLAZY = "local c=require('lazy.core.config').plugins['which-key.nvim']; return c and c._.loaded ~= nil"
LSP_READY = r"""
local c = vim.lsp.get_clients({ bufnr = 0, name = ... })[1]
if not c then return false end
_G.__rdy = _G.__rdy or {}
if _G.__rdy.ok then return true end
if not _G.__rdy.busy then
  _G.__rdy.busy = true
  c:request('textDocument/documentSymbol', { textDocument = vim.lsp.util.make_text_document_params(0) }, function(err, res)
    _G.__rdy.busy = false
    _G.__rdy.ok = (not err and res and #res > 0) or nil
  end, 0)
end
return false
"""


DEF_TARGET = r"""
local res
vim.lsp.buf_request_all(0, 'textDocument/definition', vim.lsp.util.make_position_params(0, 'utf-16'), function(x) res = x end)
vim.wait(3000, function() return res ~= nil end, 10)
for _, v in pairs(res or {}) do
  for _, loc in ipairs(v.result or {}) do
    if (loc.uri or loc.targetUri):sub(-#FILE) == FILE then return true end
  end
end
return false
"""


WARM_COMPLETE = r"""
local params = { textDocument = vim.lsp.util.make_text_document_params(0), position = { line = vim.fn.line('.'), character = COL } }
local res
vim.lsp.buf_request_all(0, 'textDocument/completion', params, function(x) res = x end)
vim.wait(5000, function() return res ~= nil end, 10)
for _, v in pairs(res or {}) do
  for _, it in ipairs((v.result or {}).items or v.result or {}) do
    if it.label == LABEL then return true end
  end
end
return false
"""


def start(c, t, lsp=True):
    reset_fixture(t["cwd"], t["file"])
    # NVIM_APPNAME: run the suite against another config side by side (e.g. a trial merge)
    env = {"NVIM_APPNAME": os.environ["NVIM_APPNAME"]} if os.environ.get("NVIM_APPNAME") else None
    n = c.n = Nvim(t["cwd"], [t["file"]], name="big", env=env)
    n.wait(VERYLAZY, 40, "VeryLazy")
    if lsp:
        n.wait(LSP_READY.replace("...", repr(t["lsp"])), 240, t["lsp"] + " ready", interval=0.3)
    time.sleep(0.5)
    return n


def goto(n, pat, pat2=None):
    err = n.lua("local a, b = ...; return select(2, pcall(function() vim.fn.cursor(1, 1);"
                " if vim.fn.search(a, 'W') == 0 then error('not found: ' .. a) end;"
                " if b ~= '' and vim.fn.search(b, 'W') == 0 then error('not found: ' .. b) end end))", pat, pat2 or "")
    if err:
        raise AssertionError(err)
    time.sleep(0.15)


def statusline(n):
    return n.screen().splitlines()[n.rows - 2]


def no_errors(c, n):
    m = n.messages()
    bad = [l for l in m.splitlines() if re.search(r"E\d{3,4}:|Error|stack traceback", l)]
    c.check(not bad, "no errors in :messages", "\n".join(bad[-6:]))


def per_target(name):
    def deco(fn):
        for k in TARGETS:
            test(f"{k}: {name}")(lambda c, k=k: fn(c, k, T[k]))
        return fn
    return deco


@per_target("open")
def open_file(c, k, t):
    n = start(c, t)
    c.shot("open")
    v = n.lua("return vim.fn.winsaveview()")
    # F16: bufferline turned the tab bar on after the first draw; with splitkeep=screen the
    # view slid down a line and scrolloff=10 dragged the cursor to line 12.
    c.check(v["topline"] == 1 and v["lnum"] == 1, "file opens at the top, cursor on line 1", v)
    c.check(n.lua("return vim.treesitter.highlighter.active[vim.api.nvim_get_current_buf()] ~= nil"),
            "treesitter highlighting active")
    scr = n.screen().splitlines()
    c.check(os.path.basename(t["file"]) in scr[0], "bufferline shows the file name", scr[0])
    c.check("NORMAL" in statusline(n), "statusline shows the mode", statusline(n))
    names = n.lua("return vim.tbl_map(function(x) return x.name end, vim.lsp.get_clients({ bufnr = 0 }))")
    c.check(t["lsp"] in names, f"{t['lsp']} attached", names)
    no_errors(c, n)


@per_target("scroll")
def scroll(c, k, t):
    n = start(c, t, lsp=False)
    last = n.lua("return vim.api.nvim_buf_line_count(0)")
    n.keys("G", settle=0.3)
    c.check(n.lua("return vim.fn.line('.')") == last, "G goes to the last line")
    n.keys("gg", settle=0.3)
    c.check(n.lua("return vim.fn.line('.')") == 1, "gg goes back to line 1")
    n.keys("<C-d><C-d><C-d>", settle=0.4)
    v = n.lua("return vim.fn.winsaveview()")
    h = n.lua("return vim.api.nvim_win_get_height(0)")
    # <C-d> is mapped to <C-d>zz: the cursor line ends up in the middle of the window
    mid = v["lnum"] - v["topline"]
    c.check(v["lnum"] > 40 and abs(mid - h // 2) <= 2, "<C-d> pages down and recentres", (v, h))
    top0, cur0 = v["topline"], v["lnum"]
    # lines per wheel step come from the mapping (config/keymaps.lua scroll_depth; Ghostty multiplies)
    rhs = n.lua("return vim.fn.maparg('<ScrollWheelDown>', 'n')")
    step = int(re.match(r"(\d*)", rhs).group(1) or 1)
    for _ in range(10):
        n.mouse(20, 80, "wheeldown", settle=0.03)
    time.sleep(0.4)
    v1 = n.lua("return vim.fn.winsaveview()")
    c.check(v1["topline"] - top0 == 10 * step, f"10 wheel steps scroll 10x{step} lines ({rhs})", (top0, v1["topline"]))
    c.check(v1["lnum"] == cur0 or v1["lnum"] >= v1["topline"], "wheel scrolls the view, cursor stays in it", (cur0, v1))
    sv = n.lua("return #vim.tbl_filter(function(w) local b = vim.api.nvim_win_get_buf(w); return vim.bo[b].filetype == 'scrollview' end, vim.api.nvim_list_wins())")
    c.check(sv > 0, "scrollview bar is drawn", sv)
    c.shot("after_wheel")
    no_errors(c, n)


@per_target("goto definition")
def goto_def(c, k, t):
    n = start(c, t)
    goto(n, t["gd_from"])
    from_line = n.lua("return vim.fn.line('.')")
    # vtsls answers `definition` with the import line for ~2.5 s after its first reply (project
    # still loading); a gd pressed then lands on the import. Wait for the real target first.
    t0 = time.time()
    n.wait(DEF_TARGET.replace("FILE", repr(t["gd_to_file"])), 40, "server resolves the definition", interval=0.5)
    c.note(f"definition resolvable {time.time() - t0:.1f}s after the server's first reply")
    n.keys("gd", settle=0.2)
    ok = True
    try:
        n.wait(f"return vim.api.nvim_buf_get_name(0):sub(-{len(t['gd_to_file'])}) == {t['gd_to_file']!r} and vim.fn.match(vim.api.nvim_get_current_line(), {t['gd_to_line']!r}) >= 0",
               20, "gd lands on the definition")
    except Exception as e:  # noqa
        ok = False
        c.check(False, "gd lands on the definition", str(e)[:400])
    if ok:
        c.check(True, "gd lands on the definition")
    c.shot("after_gd")
    v = n.lua("return vim.fn.winsaveview()")
    h = n.lua("return vim.api.nvim_win_get_height(0)")
    c.check(v["lnum"] - v["topline"] >= 5, "definition line is not at the very top edge", v)
    n.keys("<C-o>", settle=0.4)
    n.wait(f"return vim.fn.line('.') == {from_line}", 5, "<C-o> returns to the call site")
    c.check(True, "<C-o> returns to the call site")
    no_errors(c, n)


@per_target("hover and references")
def hover_refs(c, k, t):
    n = start(c, t)
    goto(n, t["gd_from"])
    n.keys("<leader>k", settle=0.2)
    n.wait("for _, w in ipairs(vim.api.nvim_list_wins()) do if vim.api.nvim_win_get_config(w).relative ~= '' and vim.bo[vim.api.nvim_win_get_buf(w)].filetype == 'markdown' then return true end end", 15, "hover float")
    c.check(True, "<leader>k opens the hover float")
    time.sleep(0.4)  # let the float paint before the screenshot
    c.shot("hover")
    n.keys("<Esc>", settle=0.4)
    floats = n.lua("return #vim.tbl_filter(function(w) return vim.api.nvim_win_get_config(w).relative ~= '' and vim.bo[vim.api.nvim_win_get_buf(w)].filetype == 'markdown' end, vim.api.nvim_list_wins())")
    c.check(floats == 0, "Esc closes the hover float", floats)
    goto(n, t["refs_from"])
    n.keys("gr", settle=0.2)
    n.wait("local p = Snacks.picker.get()[1]; return p and p:count() > 0", 30, "references picker with results")
    cnt = n.lua("return Snacks.picker.get()[1]:count()")
    c.check(cnt >= 1, "gr lists references", cnt)
    c.shot("references")
    n.keys("<Esc>", settle=0.4)
    n.keys("<Esc>", settle=0.5)
    c.check(n.lua("return #Snacks.picker.get() == 0"), "Esc Esc closes the references picker")
    no_errors(c, n)


@per_target("completion")
def completion(c, k, t):
    n = start(c, t)
    # server warm-up (F23): for ~1.5 s after its first reply vtsls answers `this.` without the
    # inherited members (TSX: no `state`/`setState`), and blink keeps filtering that early list
    # while you type. Wait until a plain completion request at the same spot has the item.
    goto(n, t["anchor"], t.get("anchor2"))
    prefix = t["complete"][: t["complete"].rindex(".") + 1]
    t0 = time.time()
    # same indentation as the code below the anchor (a Python dedent would leave `self` out of scope)
    ind = n.lua("local i = vim.fn.indent(vim.fn.nextnonblank(vim.fn.line('.') + 1)); local l = string.rep(' ', i) .. ...; vim.api.nvim_buf_set_lines(0, vim.fn.line('.'), vim.fn.line('.'), false, { l }); return i", prefix)
    n.wait(WARM_COMPLETE.replace("COL", str(ind + len(prefix))).replace("LABEL", repr(t["complete_label"])), 40, "server warm", interval=0.5)
    c.note(f"completion list complete {time.time() - t0:.1f}s after the server's first reply")
    n.lua("vim.api.nvim_buf_set_lines(0, vim.fn.line('.'), vim.fn.line('.') + 1, false, {})")
    n.keys("o", settle=0.2)
    for ch in t["complete"]:
        n.keys(ch, settle=0.08)
    try:
        n.wait("return require('blink.cmp').is_menu_visible()", 15, "completion menu")
        c.check(True, "completion menu opens while typing")
    except Exception as e:  # noqa
        c.check(False, "completion menu opens while typing", str(e)[:300])
    top10 = "local l = require('blink.cmp').get_items() or {}; for i = 1, math.min(#l, 10) do if l[i].label == LABEL then return i end end"
    try:
        pos = n.wait(top10.replace("LABEL", repr(t["complete_label"])), 6, "label in top 10")
        c.check(True, f"'{t['complete_label']}' is in the first 10 items (#{pos})")
    except Exception:  # noqa
        labels = n.lua("local l = require('blink.cmp').get_items() or {}; local o = {}; for i = 1, math.min(#l, 15) do o[#o + 1] = l[i].label end; return o")
        c.check(False, f"'{t['complete_label']}' is in the first 10 items", labels)
    c.shot("completion")
    # plugins/blink-cmp.lua: the first <Esc> only cancels the menu, the second leaves insert
    n.keys("<Esc>", settle=0.4)
    c.check(n.expr("mode()") == "i" and not n.lua("return require('blink.cmp').is_menu_visible()"),
            "first Esc closes the menu and stays in insert", n.expr("mode()"))
    n.keys("<Esc>", settle=0.4)
    c.check(n.expr("mode()") == "n", "second Esc leaves insert mode", n.expr("mode()"))
    n.ex("e!")
    no_errors(c, n)


@per_target("context: breadcrumb, brackets, references, scope")
def context(c, k, t):
    n = start(c, t)
    goto(n, t["anchor"], t.get("anchor2"))
    n.keys("jj", settle=0.2)
    # aerial skips buffers over disable_max_lines (10000 by default): no symbols, no breadcrumb
    big = n.lua("return vim.api.nvim_buf_line_count(0) > require('aerial.config').disable_max_lines")
    tag = " [known F24]" if big else ""
    t0 = time.time()
    while time.time() - t0 < 6 and t["func"] not in statusline(n):
        time.sleep(0.2)
    c.check(t["func"] in statusline(n), f"statusline breadcrumb shows {t['func']}{tag}", statusline(n))
    # cursor inside a call's parentheses: the enclosing ( ) pair is marked (config/bracket-match.lua)
    # first "(" that is a real bracket node (not text in a docstring or comment), then step inside
    n.lua(r"""
      for _ = 1, 200 do
        if vim.fn.search('(', 'W') == 0 then return end
        local p = vim.api.nvim_win_get_cursor(0)
        local ok, node = pcall(vim.treesitter.get_node, { pos = { p[1] - 1, p[2] }, include_anonymous = true })
        if ok and node and node:type() == '(' then vim.api.nvim_win_set_cursor(0, { p[1], p[2] + 1 }) return end
      end""")
    n.keys("l", settle=0.1)
    n.keys("h", settle=0.4)
    marks = n.lua("local ns = vim.api.nvim_get_namespaces().bracket_match; local o = {}; for _, m in ipairs(vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, {})) do local l = vim.api.nvim_buf_get_lines(0, m[2], m[2] + 1, false)[1]; o[#o + 1] = l:sub(m[3] + 1, m[3] + 1) end; return o")
    c.check(marks in (["(", ")"], ["[", "]"], ["{", "}"]), "bracket-match marks one matching pair around the cursor", marks)
    # move onto an identifier that has other uses (real keys, as CursorMoved drives snacks.words),
    # then wait for its LSP reference highlights
    goto(n, t["refs_from"])
    n.keys("l", settle=0.1)
    n.keys("h", settle=0.2)
    try:
        n.wait("for _, m in ipairs(vim.api.nvim_buf_get_extmarks(0, -1, 0, -1, { details = true })) do local g = m[4].hl_group; if g and g:find('^LspReference') then return true end end", 12, "reference highlights")
        c.check(True, "other uses of the word are highlighted (snacks.words)")
    except Exception as e:  # noqa
        c.check(False, "other uses of the word are highlighted (snacks.words)", str(e)[:200])
    ibl = n.lua("local ns = vim.api.nvim_get_namespaces(); local c = 0; for name, id in pairs(ns) do if name:find('indent_blankline') then c = c + #vim.api.nvim_buf_get_extmarks(0, id, 0, -1, {}) end end; return c")
    c.check(ibl > 0, "indent guides drawn", ibl)
    c.shot("context")
    no_errors(c, n)


@per_target("find files and grep")
def pickers(c, k, t):
    n = start(c, t, lsp=False)
    base = os.path.basename(t["file"])
    stem = os.path.splitext(base)[0]
    n.keys("<leader>ff", settle=0.4)
    n.wait("local p = Snacks.picker.get()[1]; return p ~= nil", 10, "files picker")
    for ch in stem:
        n.keys(ch, settle=0.05)
    n.wait(f"local p = Snacks.picker.get()[1]; if not p then return false end; for _, it in ipairs(p:items()) do if (it.file or ''):sub(-{len(t['file'])}) == {t['file']!r} then return true end end", 20, "file found")
    c.check(True, f"<leader>ff finds {base}")
    c.shot("files")
    # snacks default: the first Esc only leaves insert mode in the filter, the second closes
    n.keys("<Esc>", settle=0.4)
    c.check(n.lua("return #Snacks.picker.get() == 1") and n.expr("mode()") == "n", "first Esc: filter in normal mode, picker open")
    n.keys("<Esc>", settle=0.5)
    c.check(n.lua("return #Snacks.picker.get() == 0"), "second Esc closes the files picker")
    n.keys("<leader>/", settle=0.4)
    n.wait("return Snacks.picker.get()[1] ~= nil", 10, "grep picker")
    for ch in t["func"]:
        n.keys(ch, settle=0.04)
    n.wait("local p = Snacks.picker.get()[1]; return p and p:count() > 0", 20, "grep results")
    c.check(True, f"<leader>/ greps {t['func']}")
    c.shot("grep")
    n.keys("<Esc>", settle=0.4)
    n.keys("<Esc>", settle=0.5)
    c.check(n.lua("return #Snacks.picker.get() == 0"), "Esc Esc closes the grep picker")
    no_errors(c, n)


@per_target("explorer sticky folders")
def explorer(c, k, t):
    n = start(c, t, lsp=False)
    n.keys("<leader>r", settle=0.5)
    n.wait("local p = Snacks.picker.get({ source = 'explorer' })[1]; return p and p:count() > 0", 15, "explorer")
    time.sleep(0.8)
    # the explorer reveals the current file, so its ancestor folders are expanded
    cur = n.lua("local p = Snacks.picker.get({ source = 'explorer' })[1]; local it = p:current(); return it and it.file or ''")
    c.check(cur.endswith(t["file"]), "explorer reveals the current file", cur)
    # scroll the list until the file's own folder row has left the window: that folder and its
    # ancestors must then be the pinned rows (config/explorer-sticky.lua)
    parts = t["file"].split("/")[:-1]
    win = n.lua("return Snacks.picker.get({ source = 'explorer' })[1].list.win.win")
    n.lua("vim.api.nvim_set_current_win(...)", win)
    rows = n.lua("local w = ...; return vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(w), 0, -1, false)", win)
    folder_row = next((i for i, l in enumerate(rows) if parts and l.rstrip().endswith(" " + parts[-1])), None)
    # if the folder row is already above the window (deep reveal), its name must be pinned already
    for _ in range((folder_row + 2) if folder_row is not None else 1):
        n.mouse(20, 10, "wheeldown", settle=0.05)
    time.sleep(0.6)
    if True:
        sticky = n.lua("local ns = vim.api.nvim_get_namespaces().explorer_sticky; for _, w in ipairs(vim.api.nvim_list_wins()) do local b = vim.api.nvim_win_get_buf(w); if #vim.api.nvim_buf_get_extmarks(b, ns, 0, -1, {}) > 0 then return vim.api.nvim_buf_get_lines(b, 0, -1, false) end end; return {}")
        c.shot("explorer_scrolled")
        names = [l.split()[-1] for l in sticky if l.strip()]
        c.check(names and names[-1] == parts[-1], f"deepest pinned row is the file's folder '{parts[-1]}'", sticky)
        c.check(all(x in parts for x in names), "every pinned row is an ancestor folder of the file", (names, parts))
    n.keys("<Esc>", settle=0.4)
    no_errors(c, n)


@per_target("diagnostics")
def diagnostics(c, k, t):
    n = start(c, t)
    time.sleep(4)
    d = n.lua("local c = { 0, 0, 0, 0 }; for _, x in ipairs(vim.diagnostic.get(0)) do c[x.severity] = c[x.severity] + 1 end; return c")
    c.note(f"diagnostics E/W/I/H = {d}")
    vt = n.lua("local n = 0; for ns in pairs(vim.diagnostic.get_namespaces()) do local id = vim.diagnostic.get_namespaces()[ns].user_data.virt_text_ns; if id then for _, m in ipairs(vim.api.nvim_buf_get_extmarks(0, id, 0, -1, { details = true })) do n = n + 1 end end end; return n")
    c.check(vt <= d[0], "end-of-line text only for errors", (vt, d))
    if sum(d) == 0:
        c.note("no diagnostics in this file; jump checks skipped")
        no_errors(c, n)
        return
    n.keys("gg", settle=0.2)
    n.keys("]d", settle=0.5)
    ln = n.lua("return vim.fn.line('.')")
    c.check(ln > 1, "]d jumps to a diagnostic", ln)
    n.keys("<leader>cd", settle=0.6)
    fl = n.lua("return #vim.tbl_filter(function(w) return vim.api.nvim_win_get_config(w).relative ~= '' end, vim.api.nvim_list_wins())")
    c.check(fl >= 1, "<leader>cd opens the diagnostic float", fl)
    c.shot("diag_float")
    n.keys("<Esc>", settle=0.3)
    no_errors(c, n)


@test("all: four large files as buffers")
def buffers(c):
    t0 = T[TARGETS[0]]
    n = start(c, t0, lsp=False)
    for k in TARGETS[1:]:
        t = T[k]
        n.ex("edit " + os.path.join(t["cwd"], t["file"]))
        time.sleep(0.6)
    top = n.screen().splitlines()[0]
    names = [os.path.basename(T[k]["file"]) for k in TARGETS]
    c.check(all(x in top for x in names), "bufferline lists all four files", top)
    seen = []
    for _ in range(len(TARGETS)):
        n.keys("L", settle=0.4)  # <S-l>: next buffer
        seen.append(os.path.basename(n.lua("return vim.api.nvim_buf_get_name(0)")))
    c.check(sorted(set(seen)) == sorted(names), "<S-l> cycles through every buffer", seen)
    c.shot("buffers")
    no_errors(c, n)


if __name__ == "__main__":
    runner.run_all(int(os.environ.get("REPEAT", "1")), [a for a in sys.argv[1:]] or None, out="results-bigfile.json")
