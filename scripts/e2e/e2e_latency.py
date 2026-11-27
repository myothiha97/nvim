"""Independent check of perf.py's in-process latency probe: end-to-end latency seen by a terminal.

Neovim runs in a raw pty (no tmux). A key is written to the pty master; the latency is the time
until the TUI writes its screen update back ("first byte", and "done" = last byte before 25 ms
of silence). This path includes everything a terminal sees: input parsing, the server's work,
the redraw, the server -> TUI RPC and the TUI's output. Only the terminal's own paint is missing.

In the same run perf.py's probe is installed, so each key has both numbers: if the probe is
right, end-to-end = probe + a small constant, and an injected delay moves both by the same amount.

  python3 e2e_latency.py go-mid                 # config as is
  AB=selftest-5ms python3 e2e_latency.py go-mid # +5 ms injected: both columns must move ~5 ms
  NVIM_APPNAME=nvim-jun python3 e2e_latency.py go-mid
"""
import fcntl, json, os, pty, select, statistics, struct, sys, termios, threading, time

import pynvim

import perf
from nvh import reset_fixture

COLS, ROWS = 200, 50


class PtyNvim:
    def __init__(self, cwd, args, env_extra=None):
        self.sock = f"/tmp/e2epty-{os.getpid()}.sock"
        if os.path.exists(self.sock):
            os.remove(self.sock)
        pid, fd = pty.fork()
        if pid == 0:
            os.chdir(cwd)
            env = dict(os.environ, TERM="xterm-256color", COLORTERM="truecolor", **(env_extra or {}))
            os.execvpe("nvim", ["nvim", "--listen", self.sock] + args, env)
        self.pid, self.fd = pid, fd
        fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", ROWS, COLS, 0, 0))
        self.chunks = []  # (t, nbytes)
        self.alive = True
        self.reader = threading.Thread(target=self._read, daemon=True)
        self.reader.start()
        t0 = time.time()
        while not os.path.exists(self.sock):
            if time.time() - t0 > 20:
                raise RuntimeError("no socket")
            time.sleep(0.05)
        self.nv = pynvim.attach("socket", path=self.sock)

    def _read(self):
        while self.alive:
            r, _, _ = select.select([self.fd], [], [], 0.1)
            if r:
                try:
                    data = os.read(self.fd, 65536)
                except OSError:
                    return
                if not data:
                    return
                # answer terminal queries so the TUI does not wait on them
                if b"\x1b[6n" in data:
                    os.write(self.fd, b"\x1b[1;1R")
                self.chunks.append((time.perf_counter(), len(data)))

    def lua(self, code, *args):
        return self.nv.exec_lua(code, *args)

    def key(self, b):
        t = time.perf_counter()
        os.write(self.fd, b)
        return t

    def close(self):
        try:
            self.nv.command("qa!")
        except Exception:
            pass
        self.alive = False
        time.sleep(0.3)
        try:
            os.kill(self.pid, 9)
        except Exception:
            pass


def measure(n, keys, gap):
    """Write each key at `gap` s; return per-key (first_byte_ms, done_ms)."""
    res = []
    for k in keys:
        i0 = len(n.chunks)
        t0 = n.key(k)
        end = t0 + gap
        while time.perf_counter() < end:
            time.sleep(0.0005)
        after = [c for c in n.chunks[i0:] if c[0] >= t0]
        if not after:
            res.append((None, None))
            continue
        first = after[0][0]
        done = first
        for c in after[1:]:
            if c[0] - done > 0.025:
                break
            done = c[0]
        res.append(((first - t0) * 1000, (done - t0) * 1000))
    return res


def main():
    tk = sys.argv[1] if len(sys.argv) > 1 else "go-mid"
    t = perf.load_targets()[tk]
    reset_fixture(t["cwd"], t["file"])
    env = {"NVIM_APPNAME": os.environ["NVIM_APPNAME"]} if os.environ.get("NVIM_APPNAME") else {}
    n = PtyNvim(t["cwd"], [t["file"]], env)
    t0 = time.time()
    while time.time() - t0 < 40:
        try:
            if n.lua("local c=require('lazy.core.config').plugins['which-key.nvim']; return c and c._.loaded ~= nil"):
                break
        except Exception:
            pass
        time.sleep(0.2)
    time.sleep(4)
    ab = perf.AB_VARIANTS.get(os.environ.get("AB", ""), {})
    if ab.get("lua"):
        n.lua(ab["lua"])
    n.lua(perf.PROBE)
    out = {}
    for name, keys, gap in [("scroll_j", [b"j"] * 120, 0.06), ("word_motion", [b"w"] * 100, 0.06)]:
        n.lua("vim.fn.cursor(1, 1); local a = ...; vim.fn.search(a, 'W')", t["anchor"])
        time.sleep(0.5)
        n.lua("_G.__perf.start()")
        e2e = measure(n, keys, gap)
        probe = n.lua("return _G.__perf.stop()")
        first = [a for a, _ in e2e if a is not None]
        done = [b for _, b in e2e if b is not None]
        lat = probe["lat"]
        pairs = [(e2e[i][1] - lat[i]) for i in range(min(len(e2e), len(lat))) if e2e[i][1] is not None]
        out[name] = {
            "e2e_first_median": round(statistics.median(first), 2), "e2e_done_median": round(statistics.median(done), 2),
            "e2e_done_p95": round(sorted(done)[int(0.95 * (len(done) - 1))], 2),
            "probe_median": round(statistics.median(lat), 2), "probe_p95": round(sorted(lat)[int(0.95 * (len(lat) - 1))], 2),
            "e2e_minus_probe_median": round(statistics.median(pairs), 2) if pairs else None,
            "keys_without_output": sum(1 for a, _ in e2e if a is None), "probe_keys": len(lat),
        }
    n.close()
    print(json.dumps({"target": tk, "app": os.environ.get("NVIM_APPNAME", "nvim"), "ab": os.environ.get("AB", ""), **out}))


if __name__ == "__main__":
    main()
