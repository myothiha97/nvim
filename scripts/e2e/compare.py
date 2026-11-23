"""Compare configs (or one-feature-off variants) with perf.py, interleaved, with statistics.

A "config" is LABEL=SPEC, where SPEC is
  app:<NVIM_APPNAME>   another config side by side (e.g. an older version of this one, see README)
  ab:<variant>         this config with one perf.AB_VARIANTS entry applied ("ab:" alone = as is)
Runs are interleaved: every round runs each config once, in a shuffled order, so drift in the
machine (thermal, background load, a server's cache warming) spreads over all configs instead of
landing on whichever ran last. The load average is recorded before every run.

  python3 compare.py --configs now=ab: jun=app:nvim-jun --ref now --targets go-mid py-mid --reps 5
  python3 compare.py --configs a=ab: b=ab: --ref a --targets go --reps 5          # A/A: noise floor
  python3 compare.py --configs off=ab: d5=ab:selftest-5ms --ref off --targets go   # calibration

Statistics: per config, the median of the per-run values with min-max; against --ref a
two-sided Mann-Whitney U test on the per-run values (5 vs 5 runs: the smallest possible p is
0.008). A difference is called real only when p < 0.05 AND it is larger than the noise floor
an A/A run measured. Writes compare-<name>.json; --table re-prints a saved file. Every run is
also appended to compare-<name>.jsonl as it finishes; the same command resumes a killed batch.
"""
import argparse, json, os, random, statistics, sys, time

import perf

METRICS = [("cpu_per_key", "CPU ms/key"), ("median", "latency median ms"), ("p95", "latency p95 ms"), ("stall_max", "longest stall ms")]


def mannwhitney(a, b):
    try:
        from scipy.stats import mannwhitneyu
        return float(mannwhitneyu(a, b, alternative="two-sided").pvalue)
    except Exception:  # scipy missing or all values equal
        return None


def run_all(configs, targets, reps, actions, seed, log):
    """Each finished run is appended to `log` (JSON lines); rerunning the same command skips the
    runs already there, so a killed batch resumes where it stopped."""
    rng = random.Random(seed)
    T = perf.load_targets()
    perf.ACTIONS[:] = actions
    out = [json.loads(l) for l in open(log)] if os.path.exists(log) else []
    done = {(r["run"], r["target"], r["label"]) for r in out}
    for rep in range(1, reps + 1):
        for tk in targets:
            order = list(configs)
            rng.shuffle(order)
            for label in order:
                if (rep, tk, label) in done:
                    continue
                kind, _, val = configs[label].partition(":")
                os.environ.pop("NVIM_APPNAME", None)
                perf.AB = ""
                if kind == "app":
                    os.environ["NVIM_APPNAME"] = val
                elif val:
                    perf.AB = val
                load = os.getloadavg()[0]
                t0 = time.time()
                print(f"== round {rep}/{reps} {tk} {label} (load {load:.2f})", flush=True)
                try:
                    o = perf.one_run(T[tk], "config")
                except Exception as e:  # noqa  one failed run must not kill an hour of runs
                    print(f"   FAILED: {str(e)[:300]}", flush=True)
                    o = {"error": str(e)[:1000], "actions": {}}
                o.update({"label": label, "target": tk, "run": rep, "load_before": round(load, 2), "secs": round(time.time() - t0, 1)})
                out.append(o)
                with open(log, "a") as f:
                    f.write(json.dumps(o) + "\n")
    return out


def table(rows, ref, configs=None):
    labels = configs or sorted({r["label"] for r in rows}, key=lambda x: (x != ref, x))
    targets = list(dict.fromkeys(r["target"] for r in rows))
    lines = []
    for tk in targets:
        acts = list(dict.fromkeys(a for r in rows if r["target"] == tk for a in r.get("actions", {})))
        lines.append(f"\n#### {tk}\n")
        lines.append("| action | metric | " + " | ".join(labels) + " |")
        lines.append("|---|---|" + "---|" * len(labels))
        for a in acts:
            for m, mname in METRICS:
                vals = {lb: [r["actions"][a][m] for r in rows if r["target"] == tk and r["label"] == lb and a in r.get("actions", {}) and r["actions"][a].get(m) is not None] for lb in labels}
                cells = []
                for lb in labels:
                    v = vals[lb]
                    if not v:
                        cells.append("–")
                        continue
                    c = f"{statistics.median(v):.1f} [{min(v):.1f}–{max(v):.1f}]"
                    if lb != ref and vals.get(ref):
                        p = mannwhitney(v, vals[ref])
                        if p is not None:
                            c += f" p={p:.3f}" + (" *" if p < 0.05 else "")
                    cells.append(c)
                lines.append(f"| {a} | {mname} | " + " | ".join(cells) + " |")
    loads = [r["load_before"] for r in rows]
    fails = [f"{r['label']}/{r['target']}#{r['run']}" for r in rows if r.get("error")]
    lines.append(f"\nRuns: {len(rows)}, failed: {len(fails)} {fails if fails else ''}; load before runs: median {statistics.median(loads):.2f}, max {max(loads):.2f}. "
                 "Cells: median of runs [min–max], p = Mann-Whitney U vs " + ref + ", * = p < 0.05.")
    return "\n".join(lines)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--configs", nargs="+", default=[])
    ap.add_argument("--ref")
    ap.add_argument("--targets", nargs="+", default=[])
    ap.add_argument("--reps", type=int, default=5)
    ap.add_argument("--actions", default="scroll_j,half_page,wheel,word_motion,jumps,typing")
    ap.add_argument("--name", default="run")
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--table", help="re-print the table of a saved compare-*.json")
    a = ap.parse_args()
    if a.table:
        d = json.load(open(a.table))
        print(table(d["rows"], d["ref"], d["labels"]))
        return
    configs = dict(c.split("=", 1) for c in a.configs)
    ref = a.ref or next(iter(configs))
    log = os.path.join(perf.HERE, f"compare-{a.name}.jsonl")
    rows = run_all(configs, a.targets, a.reps, a.actions.split(","), a.seed, log)
    path = os.path.join(perf.HERE, f"compare-{a.name}.json")
    json.dump({"ref": ref, "labels": list(configs), "configs": configs, "rows": rows}, open(path, "w"), indent=1)
    print(table(rows, ref, list(configs)))


if __name__ == "__main__":
    main()
