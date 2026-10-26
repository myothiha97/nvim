"""Drive a real Neovim in tmux and measure insert-mode keystroke cost.

Usage: python3 driver.py <workdir> <plan>   (plan: all | smoke)
Results append to <workdir>/results.txt via measure.lua.
"""
import subprocess, sys, time, os

W = sys.argv[1]
PLAN = sys.argv[2] if len(sys.argv) > 2 else "all"
P = W + "/proj"
OUT = W + "/results.txt"
SESSION = "insmeas"

TEXT = {
    "go": 'func Sum(values []int) int {\ntotal := 0\nfor _, v := range values {\ntotal += v\n}\nreturn total\n}\nfmt.Println(strings.Repeat("ab", 3), Sum([]int{1, 2, 3}))\nu.Display()',
    "ts": 'export function sum(values: number[]): number {\nlet total = 0;\nfor (const v of values) {\ntotal += v;\n}\nreturn total;\n}\nconst u = newUser(2, "bo", "bo@example.com");\nconsole.log(display(u), u.name.toUpperCase(), sum([1, 2, 3]));',
    "py": 'def total(values: list[int]) -> int:\nresult = 0\nfor v in values:\nresult += v\nreturn result\nuser = new_user(2, "bo", "bo@example.com")\nprint(user.display(), user.name.upper(), total([1, 2, 3]))',
    "rs": 'fn sum(values: &[i32]) -> i32 {\nvalues.iter().sum()\n}\nlet total = sum(&[1, 2, 3]);\nprintln!("{} {}", total, u.name.to_uppercase());\nlet names: Vec<String> = vec![u.name.clone()];',
    "sh": 'backup() {\nlocal src="$1"\ncp -r "$src" "$TARGET_DIR/backup-$(date +%s)"\nlog "backup of $src done"\n}\nfor f in "$TARGET_DIR"/*.log; do\necho "$f"\ndone',
    "cpp": 'int sum(const std::vector<int> &values) {\nint total = 0;\nfor (int v : values) total += v;\nreturn total;\n}\nstd::cout << sum({1, 2, 3}) << std::endl;\nstd::string label = users.front().name;',
    "cs": 'public static int Sum(List<int> values)\n{\nvar total = 0;\nforeach (var v in values) total += v;\nreturn total;\n}\nConsole.WriteLine(Sum(new List<int> { 1, 2, 3 }));',
    "md": '## Section two\nSome *italic* and **bold** text with a [link](https://example.com).\n- item three\n- item four\n| c | d |\n| - | - |\n| 3 | 4 |\nA closing paragraph with `inline code` and more words to type.',
    "sql": "SELECT u.id, u.name, count(o.id) AS orders\nFROM users u\nLEFT JOIN orders o ON o.user_id = u.id\nWHERE u.created_at > now() - interval '7 days'\nGROUP BY u.id, u.name\nORDER BY orders DESC;",
}
PREFIX = {
    "go": ["fmt.Pr", "strings.To", "u.Di"], "ts": ["console.lo", "u.na", "Math.ma"],
    "py": ["user.di", "user.na", "print"], "rs": ["u.na", "String::fr", "vec"],
    "sh": ["ech", "TARGET", "log"], "cpp": ["std::co", "users.pu", "display"],
    "cs": ["Console.Wr", "users.Ad", "Displ"], "md": ["Sect", "item", "link"], "sql": ["SEL", "coun", "ORD"],
}
FILE = {"go": "go/main.go", "ts": "ts/src/app.ts", "py": "py/app.py", "rs": "rs/src/main.rs", "sh": "sh/deploy.sh",
        "cpp": "cpp/main.cpp", "cs": "cs/Program.cs", "md": "md/notes.md", "sql": "sql/query.sql"}
BIG = {"go": "go/big.go", "ts": "ts/src/big.ts", "py": "py/big.py", "md": "md/big.md"}


def tmux(*args):
    subprocess.run(["tmux", *args], check=False)


def send_literal(s):
    tmux("send-keys", "-t", SESSION, "-l", s)


def send_key(k):
    tmux("send-keys", "-t", SESSION, k)


def type_text(text, delay):
    """Type like a person: one key per send, Enter for newlines. Returns seconds spent."""
    t = time.time()
    for ch in text:
        if ch == "\n":
            send_key("Enter")
        else:
            send_literal(ch)
        time.sleep(delay)
    return time.time() - t


def cmd(s):
    send_key("Escape")
    time.sleep(0.15)
    send_literal(":" + s)
    send_key("Enter")
    time.sleep(0.3)


def measure(label, body, est_seconds):
    ms = int((est_seconds + 2.0) * 1000)
    cmd(f"lua MEAS.start('{label}', {ms})")
    body()
    time.sleep(est_seconds + 2.5 - 0)  # let the auto-stop fire
    # body() already took its own time; sleep covers the tail only if body was async-free
    time.sleep(0.5)


def start(lang, path, wait):
    tmux("kill-session", "-t", SESSION)
    cwd = os.path.join(P, path.split("/")[0])
    tmux("new-session", "-d", "-s", SESSION, "-x", "160", "-y", "45", "-c", cwd,
         f"MEAS_OUT={OUT} nvim -n -c 'luafile {W}/measure.lua' {os.path.join(P, path)}")
    time.sleep(3)
    if lang == "rs":
        send_key("Enter")  # dismiss the rust-analyzer-missing prompt
    time.sleep(wait)


def stop():
    cmd("qa!")
    time.sleep(1)
    tmux("kill-session", "-t", SESSION)


def scen_type(lang, label, delay, line_cmd="G"):
    text = TEXT[lang]
    est = len(text) * delay * 1.15 + 1.0

    def body():
        send_literal(line_cmd)
        send_literal("o")
        type_text(text, delay)
        send_key("Escape")
    run_timed(label, body, est)


def run_timed(label, body, est):
    ms = int((est + 2.0) * 1000)
    cmd(f"lua MEAS.start('{label}', {ms})")
    t = time.time()
    body()
    left = (ms / 1000.0) - (time.time() - t) + 0.8
    if left > 0:
        time.sleep(left)
    else:
        print(f"WARN {label}: body overran the window by {-left:.1f}s", flush=True)


def scen_completion(lang, label):
    def body():
        send_literal("G")
        send_literal("o")
        for p in PREFIX[lang]:
            type_text(p, 0.07)
            time.sleep(0.9)
            for k in ["C-n", "C-n", "C-p"]:
                send_key(k)
                time.sleep(0.15)
            send_key("C-l")
            time.sleep(0.3)
            send_key("Enter")
            time.sleep(0.1)
        send_key("Escape")
    run_timed(label, body, 3 * (0.6 + 0.9 + 0.45 + 0.4) + 1.0)


def scen_modes(lang, label):
    def body():
        send_literal("G")
        for _ in range(15):
            send_literal("o")
            time.sleep(0.07)
            type_text("abc", 0.07)
            send_key("Escape")
            time.sleep(0.12)
    run_timed(label, body, 15 * (0.07 + 0.21 + 0.12) + 1.0)


LSP_WAIT = {"go": 10, "ts": 12, "py": 10, "rs": 3, "sh": 6, "cpp": 4, "cs": 4, "md": 5, "sql": 6}


def plan_all():
    for lang in ["go", "ts", "py", "rs", "sh", "cpp", "cs", "md", "sql"]:
        start(lang, FILE[lang], LSP_WAIT[lang])
        scen_type(lang, f"{lang} A type 70ms", 0.07)
        scen_type(lang, f"{lang} B burst 12ms", 0.012)
        scen_completion(lang, f"{lang} E completion")
        scen_modes(lang, f"{lang} F insert/esc x15")
        stop()
        print("done", lang, flush=True)
    for lang in ["go", "ts", "py", "md"]:
        start(lang, BIG[lang], LSP_WAIT[lang] + 6)
        mid = {"go": "3000G", "ts": "3000G", "py": "3300G", "md": "1650G"}[lang]
        scen_type(lang, f"{lang} D big-file mid", 0.07, line_cmd=mid)
        scen_type(lang, f"{lang} D big-file burst", 0.012, line_cmd=mid)
        stop()
        print("done big", lang, flush=True)
    for lang in ["go", "ts", "py"]:
        start(lang, FILE[lang], LSP_WAIT[lang])
        send_key("Escape")
        send_literal(" ad")  # <leader>ad: loads Copilot and turns it ON
        time.sleep(6)
        scen_type(lang, f"{lang} C copilot ON", 0.07)
        time.sleep(2)
        send_literal(" ad")  # loaded but OFF
        time.sleep(1)
        scen_type(lang, f"{lang} A1 copilot loaded-off", 0.07)
        stop()
        print("done copilot", lang, flush=True)


def plan_smoke():
    start("go", FILE["go"], LSP_WAIT["go"])
    scen_type("go", "go SMOKE", 0.07)
    stop()


{"all": plan_all, "smoke": plan_smoke}[PLAN]()
print("FINISHED", flush=True)
