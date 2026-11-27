"""Startup time in the real TUI: --startuptime, open a file, wait for VeryLazy, quit. N runs, median.
  python3 startup.py 15        # fixtures goapp/main.go
  python3 startup.py 15 tsx    # a targets.json file (large-file fixtures)"""
import json, os, re, statistics, sys, time
from nvh import Nvim, sh, TMUX, reset_fixture

target = sys.argv[2] if len(sys.argv) > 2 else None
if target:
    t = json.load(open(os.environ.get("E2E_TARGETS", os.path.join(os.path.dirname(os.path.abspath(__file__)), "targets.json"))))[target]
    CWD, FILE = t["cwd"], t["file"]
else:
    CWD, FILE = os.environ.get("E2E_FX", "/tmp/nvim-e2e-fx") + "/goapp", "main.go"


def one(i):
    log = f"/tmp/st_{i}.log"
    if os.path.exists(log): os.remove(log)
    if target:
        reset_fixture(CWD, FILE)
    n = Nvim(CWD, ["--startuptime", log, FILE], name=f"st{i}")
    n.wait("local c=require('lazy.core.config').plugins['which-key.nvim']; return c and c._.loaded ~= nil", 30)
    lazy = n.lua("local s=require('lazy').stats(); return {s.startuptime, s.times.LazyDone or 0, s.times.UIEnter or 0}")
    n.close()
    total = None
    for line in open(log):
        m = re.match(r"\s*([\d.]+)\s+.*NVIM STARTED", line)
        if m: total = float(m.group(1))
    return total, lazy
runs = [one(i) for i in range(int(sys.argv[1]) if len(sys.argv) > 1 else 10)]
tot = [r[0] for r in runs if r[0]]
ls = [r[1][0] for r in runs]
print(f"{FILE}: NVIM STARTED (startuptime log) median {statistics.median(tot):.1f} ms  min {min(tot):.1f}  max {max(tot):.1f}  n={len(tot)}")
print(f"lazy.stats().startuptime median {statistics.median(ls):.1f} ms")
