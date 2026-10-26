"""Drive the real config in a raw pty with exact byte timing; compare ttimeoutlen 10 vs 50."""
import os, pty, sys, time, threading, subprocess, json, fcntl, termios, struct

W = os.path.dirname(os.path.abspath(__file__))
FILE = W + "/t.txt"
BIG = W + "/paste_src.txt"


def run(ttm, steps, setup="", wait=2.5):
    sock = f"./s{time.time_ns() % 10**8}.sock"
    with open(FILE, "w") as f:
        f.write("\n".join(f"line{i:02d}" for i in range(1, 61)) + "\n")
    args = ["nvim", "-n", "--listen", sock]
    if ttm is not None:
        args += ["-c", f"set ttimeoutlen={ttm}"]
    args += [FILE]
    pid, fd = pty.fork()
    if pid == 0:
        os.chdir(W)
        os.environ["TERM"] = "xterm-256color"
        os.execvp("nvim", args)
    fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", 30, 100, 0, 0))
    stop = threading.Event()

    def drain():
        while not stop.is_set():
            try:
                os.read(fd, 65536)
            except OSError:
                break

    threading.Thread(target=drain, daemon=True).start()
    time.sleep(wait)
    if setup:
        rexpr(sock, f'execute("{setup}")')
        time.sleep(0.2)
    for b, gap in steps:
        mv = memoryview(b)
        while mv:
            n = os.write(fd, mv)
            mv = mv[n:]
        if gap:
            time.sleep(gap / 1000)
    time.sleep(0.5)
    st = rexpr(sock, "json_encode([mode(), line('.'), col('.'), getline(1,'$'), &ttimeoutlen, line('w0')])")
    try:
        rexpr(sock, 'execute("qa!")')
    except Exception:
        pass
    time.sleep(0.3)
    stop.set()
    try:
        os.kill(pid, 9)
        os.waitpid(pid, 0)
    except Exception:
        pass
    try:
        os.close(fd)
    except Exception:
        pass
    return json.loads(st) if st else None


def rexpr(sock, expr):
    try:
        r = subprocess.run(["nvim", "--clean", "--headless", "--server", sock, "--remote-expr", expr],
                           capture_output=True, text=True, timeout=4, cwd=W)
    except subprocess.TimeoutExpired:
        return ""
    return r.stdout.strip()


ESC = b"\x1b"


def esc_then(key, gap):
    # i (insert), type X, then <Esc> and key with an exact gap (0 = same write)
    if gap == 0:
        return [(b"ggiX", 30), (ESC + key, 0)]
    return [(b"ggiX", 30), (ESC, gap), (key, 0)]


def report(name, res, ok):
    if res is None:
        print(f"{name:44s} FAIL   nvim blocked (stuck on a prompt)", flush=True)
        return
    print(f"{name:44s} {'PASS' if ok(res) else 'FAIL'}   mode={res[0]!r} line={res[1]} col={res[2]} l1={res[3][0]!r} l2={res[3][1]!r} w0={res[5]} ttm={res[4]}", flush=True)


CASES = []
for g in [0, 5, 8, 15, 30, 45]:
    # Esc then j: after Esc the cursor should be on line 2 in normal mode (works), or still insert (merged to <M-j> Nop)
    CASES.append((f"Esc then j, gap {g:2d} ms", esc_then(b"j", g), lambda r: r[0] == "n" and r[1] == 2))
for g in [15, 30]:
    # Esc then O: opens a line above line 1, in insert mode
    CASES.append((f"Esc then O, gap {g:2d} ms", esc_then(b"O", g), lambda r: r[0] == "i" and r[3][0] == "" and r[3][1] == "Xline01"))
CASES += [
    ("Cmd+J (\\x1bj one write) stays in insert", [(b"ggiX", 30), (b"\x1bj", 0)], lambda r: r[0] == "i" and r[1] == 1),
    ("Cmd+H (\\x1bh one write) stays in insert", [(b"ggiX", 30), (b"\x1bh", 0)], lambda r: r[0] == "i" and r[1] == 1),
    ("Left arrow in insert (one write)", [(b"ggAab", 30), (b"\x1b[D", 30), (b"Z", 0)], lambda r: r[3][0] == "line01aZb"),
    ("Left arrow, SS3 form (one write)", [(b"ggAab", 30), (b"\x1bOD", 30), (b"Z", 0)], lambda r: r[3][0] == "line01aZb"),
    ("Mouse wheel down x3 (SGR, one write)", [(b"\x1b[<65;10;10M" * 3, 0)], lambda r: r[5] > 1),
    ("Focus out/in events (one write)", [(b"\x1b[O", 30), (b"\x1b[I", 0)], lambda r: r[0] == "n" and r[3][0] == "line01"),
    # Over a slow link the arrow sequence can arrive split; this shows what 10 ms gives up
    ("SLOW LINK: Left arrow split by 20 ms", [(b"ggAab", 30), (b"\x1b", 20), (b"[D", 30), (b"Z", 0)], lambda r: r[3][0] == "line01aZb"),
]


def paste_case():
    lines = []
    for i in range(4000):
        lines.append(f"\tconst v{i} = obj?.[\"k{i}\"] ?? `t${{x}}` // café → {i} [] {{}} <> ~ ^ $")
    src = "\n".join(lines)
    with open(BIG, "w") as f:
        f.write(src + "\n")
    data = b"\x1b[200~" + src.encode() + b"\x1b[201~"
    return [(b"Go", 50), (data, 0)], lines


if __name__ == "__main__":
    for ttm in [None, 50]:
        print(f"\n=== {'real config (ttimeoutlen from options.lua)' if ttm is None else 'control: ttimeoutlen=50'}", flush=True)
        for name, steps, ok in CASES:
            report(name, run(ttm, steps), ok)
        steps, lines = paste_case()
        r = run(ttm, steps, wait=2.5)
        got = r[3][60:]
        ok = got == lines and r[0] == "i"
        print(f"{'Bracketed paste, 4000 lines / ~330 KB':44s} {'PASS' if ok else 'FAIL'}   mode={r[0]!r} pasted_lines={len(got)} exact={got == lines}", flush=True)
