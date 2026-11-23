"""E2E harness: real Neovim TUI inside tmux, real keystrokes, RPC side channel for assertions.

- Keys go through the terminal (tmux send-keys), so mappings, timeouts and the
  VeryLazy/keymaps.lua path behave as in a real session.
- Mouse events are sent as SGR mouse escape sequences into the pty (the same
  bytes a terminal emits for a click), not via nvim_input_mouse.
- Assertions read state over the --listen socket with a watchdog timeout.
- Waits poll a condition; no fixed sleeps except tiny settle delays.
"""
import os, re, subprocess, threading, time, json, uuid

import pynvim

TMUX = ["tmux", "-L", "e2e"]


def sh(args, **kw):
    return subprocess.run(args, capture_output=True, text=True, **kw)


SPECIAL = {
    "<CR>": "Enter", "<Esc>": "Escape", "<Tab>": "Tab", "<BS>": "BSpace", "<Space>": "Space",
    "<Up>": "Up", "<Down>": "Down", "<Left>": "Left", "<Right>": "Right",
    "<F5>": "F5", "<F9>": "F9", "<F10>": "F10", "<F11>": "F11", "<F12>": "F12",
    "<S-F5>": "S-F5", "<S-F11>": "S-F11", "<C-c>": "C-c", "<C-w>": "C-w", "<C-o>": "C-o",
    "<C-h>": "C-h", "<C-j>": "C-j", "<C-k>": "C-k", "<C-l>": "C-l", "<C-n>": "C-n", "<C-p>": "C-p",
    "<C-d>": "C-d", "<C-u>": "C-u", "<C-\\>": "C-\\", "<C-y>": "C-y", "<C-e>": "C-e",
}
TOKEN = re.compile(r"(<[^<>]+>)")


class Timeout(Exception):
    pass


class Nvim:
    def __init__(self, cwd, args=(), cols=200, rows=50, name=None, env=None):
        self.name = name or "nv" + uuid.uuid4().hex[:6]
        self.sock = f"/tmp/{self.name}.sock"
        self.cols, self.rows = cols, rows
        if os.path.exists(self.sock):
            os.remove(self.sock)
        envs = " ".join(f"{k}={v}" for k, v in (env or {}).items())
        cmd = f"env TERM=tmux-256color COLORTERM=truecolor {envs} nvim --listen {self.sock} " + " ".join(args)
        sh(TMUX + ["kill-session", "-t", self.name])
        r = sh(TMUX + ["new-session", "-d", "-s", self.name, "-x", str(cols), "-y", str(rows), "-c", cwd, cmd])
        assert r.returncode == 0, r.stderr
        sh(TMUX + ["set", "-g", "escape-time", "0"])
        sh(TMUX + ["set", "-g", "extended-keys", "on"])
        sh(TMUX + ["set", "-g", "focus-events", "on"])
        sh(TMUX + ["set", "-g", "default-terminal", "tmux-256color"])
        sh(TMUX + ["set", "-ga", "terminal-overrides", ",*:RGB"])
        t0 = time.time()
        while not os.path.exists(self.sock):
            if time.time() - t0 > 20:
                raise Timeout("nvim socket never appeared:\n" + self.screen())
            time.sleep(0.05)
        self.nv = pynvim.attach("socket", path=self.sock)
        self.lock = threading.Lock()

    # ---------- RPC with watchdog ----------
    def _rpc(self, fn, timeout=10):
        res, err = [None], [None]

        def run():
            try:
                with self.lock:
                    res[0] = fn()
            except Exception as e:  # noqa
                err[0] = e

        th = threading.Thread(target=run, daemon=True)
        th.start()
        th.join(timeout)
        if th.is_alive():
            raise Timeout("RPC hung (nvim blocked?)\n" + self.screen())
        if err[0]:
            raise err[0]
        return res[0]

    def lua(self, code, *args, timeout=10):
        return self._rpc(lambda: self.nv.exec_lua(code, *args), timeout)

    def ex(self, cmd, timeout=10):
        return self._rpc(lambda: self.nv.command_output(cmd), timeout)

    def expr(self, e, timeout=10):
        return self._rpc(lambda: self.nv.eval(e), timeout)

    # ---------- input ----------
    def keys(self, s, settle=0.05):
        """Vim-ish notation: '<leader>dc', '<F10>', 'iHello<Esc>'. <leader> is Space.
        Aliases like <BP> (resolved from the config's keymap descriptions) keep the suites
        independent of which key a feature is bound to."""
        for alias, lhs in getattr(self, "aliases", {}).items():
            s = s.replace(alias, lhs)
        s = s.replace("<leader>", " ")
        for part in TOKEN.split(s):
            if not part:
                continue
            if part in SPECIAL:
                sh(TMUX + ["send-keys", "-t", self.name, SPECIAL[part]])
                # human-ish gaps: two Esc in one write parse as <M-Esc>; keys sent <50 ms
                # after a :cmd<CR> can be lost (measured: 50 ms lost, >=120 ms fine).
                time.sleep(0.15 if part == "<CR>" else 0.04)
            elif part.startswith("<") and part.endswith(">") and len(part) > 2:
                raise ValueError("unknown key " + part)
            else:
                sh(TMUX + ["send-keys", "-t", self.name, "-l", tmux_literal(part)])
        time.sleep(settle)

    def mouse(self, row, col, button="left", action="click", mods=0, settle=0.15):
        """1-based screen row/col. SGR 1006 encoding, written into the pty like a terminal would."""
        b = {"left": 0, "middle": 1, "right": 2, "wheelup": 64, "wheeldown": 65, "move": 35}[button] + mods
        seqs = []
        if button.startswith("wheel") or button == "move":
            seqs.append(f"\x1b[<{b};{col};{row}M")
        else:
            seqs.append(f"\x1b[<{b};{col};{row}M")
            seqs.append(f"\x1b[<{b};{col};{row}m")
            if action == "double":
                seqs += seqs[:]
        for sq in seqs:
            sh(TMUX + ["send-keys", "-t", self.name, "-H"] + [f"{ord(c):02x}" for c in sq])
            time.sleep(0.03)
        time.sleep(settle)

    # ---------- observation ----------
    def screen(self, ansi=False):
        # -e keeps Nerd-Font private-use glyphs that plain capture drops
        out = sh(TMUX + ["capture-pane", "-p", "-e", "-t", self.name]).stdout
        return out if ansi else re.sub(r"\x1b\[[0-9;:]*m", "", out)

    def wait(self, cond_lua, timeout=15, desc=None, interval=0.1):
        """cond_lua: Lua expression body returning truthy; returns its value."""
        t0 = time.time()
        last_err = None
        while time.time() - t0 < timeout:
            try:
                v = self.lua("return (function() " + cond_lua + " end)()", timeout=5)
                if v:
                    return v
            except Timeout:
                raise
            except Exception as e:  # noqa
                last_err = e
            time.sleep(interval)
        raise Timeout(f"wait failed: {desc or cond_lua} ({last_err})\n" + self.screen())

    def wait_screen(self, pattern, timeout=15, desc=None):
        t0 = time.time()
        rx = re.compile(pattern)
        while time.time() - t0 < timeout:
            s = self.screen()
            if rx.search(s):
                return s
            time.sleep(0.1)
        raise Timeout(f"screen never matched {desc or pattern}\n" + self.screen())

    def find(self, text):
        """(row, col) 1-based of first occurrence of text on screen."""
        for i, line in enumerate(self.screen().splitlines()):
            j = line.find(text)
            if j >= 0:
                # account for wide chars before j (rough: count display cells)
                return i + 1, _cells(line[:j]) + 1
        return None

    def messages(self):
        return self.ex("messages")

    def close(self):
        # Quit cleanly so no stale swap files trigger the ATTENTION prompt next time.
        pid = None
        try:
            pid = self._rpc(lambda: self.nv.call("getpid"), timeout=3)
        except Exception:
            pass
        try:
            self._rpc(lambda: self.nv.command("qa!"), timeout=3)
        except Exception:
            pass  # the connection drops as nvim exits
        t0 = time.time()
        while time.time() - t0 < 3 and sh(TMUX + ["has-session", "-t", self.name]).returncode == 0:
            time.sleep(0.1)
        try:
            self.nv.close()
        except Exception:
            pass
        sh(TMUX + ["kill-session", "-t", self.name])
        # nvim's server process (--embed) and the LSP/DAP children it spawned must not outlive
        # the test: leftovers piled up to load 35 on 2 CPUs and caused timeouts. Only this
        # nvim's own process tree is killed, never other editors' servers.
        if pid:
            # whole process tree (go test -> pkg.test, dlv -> __debug_bin, node -> vitest workers)
            tree = sh(["bash", "-c", f"ps -eo pid=,ppid="]).stdout.split()
            kids, pairs = {pid}, list(zip(tree[0::2], tree[1::2]))
            changed = True
            while changed:
                changed = False
                for p_, pp in pairs:
                    if int(pp) in kids and int(p_) not in kids:
                        kids.add(int(p_)); changed = True
            sh(["bash", "-c", "kill -9 " + " ".join(map(str, kids)) + " 2>/dev/null; true"])
        sh(["bash", "-c", f"pkill -9 -f 'listen {self.sock}'"])


def reset_fixture(cwd, file):
    """Undo leftovers of an aborted run on a fixture file: its swap file (else the next start
    stops at the E325 ATTENTION prompt) and uncommitted edits. Only that one file is touched."""
    path = os.path.realpath(os.path.join(cwd, file))
    swap = os.path.expanduser("~/.local/state/nvim/swap/") + path.replace("/", "%")
    for ext in (".swp", ".swo", ".swn"):
        if os.path.exists(swap + ext):
            os.remove(swap + ext)
    sh(["git", "-C", cwd, "checkout", "--", file])


def tmux_literal(s):
    """tmux ends a command at an argument ending in an unescaped `;`, so `send-keys -l ';'` sent
    nothing (the `;` of a typed statement was silently dropped). Escape it."""
    return s[:-1] + "\\;" if s.endswith(";") else s


def _cells(s):
    import unicodedata
    n = 0
    for ch in s:
        n += 2 if unicodedata.east_asian_width(ch) in ("W", "F") else 1
    return n


def attach(name, cols=200, rows=50):
    """Re-attach to a running session (for step-by-step exploration)."""
    n = Nvim.__new__(Nvim)
    n.name, n.sock, n.cols, n.rows = name, f"/tmp/{name}.sock", cols, rows
    n.nv = pynvim.attach("socket", path=n.sock)
    n.lock = threading.Lock()
    return n
