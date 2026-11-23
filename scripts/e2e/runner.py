"""Tiny scenario runner: soft checks, screenshots, repeat runs, JSON results."""
import json, os, sys, time, traceback

from render import render

RESULTS = []
TESTS = []
SHOTS = os.path.join(os.path.dirname(__file__), "shots")
os.makedirs(SHOTS, exist_ok=True)


class Ctx:
    def __init__(self, name, run):
        self.name, self.run = name, run
        self.checks = []
        self.notes = []
        self.n = None

    def check(self, cond, msg, detail=None):
        self.checks.append({"ok": bool(cond), "msg": msg, "detail": None if cond else (str(detail)[:1500] if detail is not None else None)})
        return bool(cond)

    def note(self, msg):
        self.notes.append(msg)

    def shot(self, label, n=None):
        n = n or self.n
        if not n:
            return
        base = f"{self.name}__{label}".replace(" ", "_").replace("/", "_")
        ans = n.screen(ansi=True)
        p = os.path.join(SHOTS, base + ".ans")
        open(p, "w").write(ans)
        try:
            render(ans, os.path.join(SHOTS, base + ".png"), n.cols, n.rows)
        except Exception as e:  # noqa
            self.note(f"render failed: {e}")


def test(name):
    def deco(fn):
        TESTS.append((name, fn))
        return fn
    return deco


def run_all(repeat=1, only=None, out="results.json"):
    for r in range(1, repeat + 1):
        for name, fn in TESTS:
            if only and not any(o in name for o in only):
                continue
            c = Ctx(name, r)
            t0 = time.time()
            err = None
            try:
                fn(c)
            except Exception as e:  # noqa
                err = "".join(traceback.format_exception(e))[-3000:]
                try:
                    c.shot("ERROR")
                except Exception:
                    pass
            finally:
                if c.n:
                    try:
                        c.n.close()
                    except Exception:
                        pass
            ok = err is None and all(x["ok"] for x in c.checks)
            res = {"name": name, "run": r, "ok": ok, "secs": round(time.time() - t0, 1), "checks": c.checks, "notes": c.notes, "error": err}
            RESULTS.append(res)
            mark = "PASS" if ok else "FAIL"
            print(f"[{mark}] {name} (run {r}, {res['secs']}s)", flush=True)
            for x in c.checks:
                if not x["ok"]:
                    print(f"     ✗ {x['msg']}  {x['detail'] or ''}"[:600], flush=True)
            if err:
                print("     ERROR:", err.splitlines()[-1][:300], flush=True)
                print("\n".join("        " + l for l in err.splitlines()[-25:]), flush=True)
            for nt in c.notes:
                print("     note:", nt[:300], flush=True)
    json.dump(RESULTS, open(os.path.join(os.path.dirname(__file__), out), "w"), indent=1)
    total = len(RESULTS)
    passed = sum(1 for r in RESULTS if r["ok"])
    print(f"\n{passed}/{total} passed")
