"""Markdown tables from perf.py output: medians across runs, config next to the clean baseline.
  python3 perf_table.py perf-config.json [perf-clean.json] [perf-config-<AB>.json ...]"""
import json, statistics, sys
from collections import defaultdict


def load(p):
    rows = defaultdict(list)
    for r in json.load(open(p)):
        rows[r["target"]].append(r)
    return rows


def med(xs):
    xs = [x for x in xs if x is not None]
    return round(statistics.median(xs), 1) if xs else None


def action_stats(runs, action, key):
    return med([r["actions"][action][key] for r in runs if action in r["actions"]])


def fmt(x):
    return "–" if x is None else (f"{x:g}" if isinstance(x, (int, float)) else str(x))


def main(paths):
    sets = [(p, load(p)) for p in paths]
    base, base_rows = sets[0]
    targets = list(base_rows)
    actions = list(base_rows[targets[0]][0]["actions"])
    for label, key in [("CPU ms per key (median of runs)", "cpu_per_key"), ("Latency median ms", "median"),
                       ("Latency p95 ms", "p95"), ("Longest stall ms", "stall_max")]:
        print(f"\n### {label}\n")
        cols = [f"{t} ({p.split('perf-')[-1].removesuffix('.json')})" for t in targets for p, _ in sets]
        print("| action | " + " | ".join(cols) + " |")
        print("|---|" + "---|" * len(cols))
        for a in actions:
            vals = [fmt(action_stats(rows.get(t, []), a, key)) for t in targets for _, rows in sets]
            print(f"| {a} | " + " | ".join(vals) + " |")
    print("\n### Open, LSP and memory (config, median of runs)\n")
    print("| file | lines | VeryLazy s | LSP attach s | LSP ready s | save ms | Nvim MB | LSP MB |")
    print("|---|---|---|---|---|---|---|---|")
    for t in targets:
        rs = base_rows[t]
        lsp = med([sum(v for k, v in r["memory"].items() if k != "nvim_mb" and v) for r in rs])
        print(f"| {rs[0]['file']} | {rs[0]['lines']} | {fmt(med([r['open'].get('verylazy_s') for r in rs]))} | "
              f"{fmt(med([r['open'].get('lsp_attach_s') for r in rs]))} | {fmt(med([r['open'].get('lsp_ready_s') for r in rs]))} | "
              f"{fmt(med([r.get('save_ms') for r in rs]))} | {fmt(med([r['memory'].get('nvim_mb') for r in rs]))} | {fmt(lsp)} |")
    if any("lsp_rt" in r for rs in base_rows.values() for r in rs):
        print("\n### LSP round trips, ms (median of all requests)\n")
        methods = ["hover", "definition", "references", "documentSymbol", "completion"]
        print("| file | " + " | ".join(methods) + " |")
        print("|---|" + "---|" * len(methods))
        for t in targets:
            rs = [r for r in base_rows[t] if "lsp_rt" in r]
            print(f"| {t} | " + " | ".join(fmt(med([x for r in rs for x in r["lsp_rt"][m]["ms"]])) for m in methods) + " |")


if __name__ == "__main__":
    main(sys.argv[1:])
