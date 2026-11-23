# basedpyright: `standard` instead of the default `recommended` mode (F20)

Found 2026-11-23 (runtime perf E2E, `docs/advance-features/testing/e2e-perf-report-2026-11-23.md`).

- basedpyright's default mode reported **2,379 warnings + 117 errors** on django's
  `query.py` (3.1k lines, mostly `reportUnknown*` / `reportAny` on untyped code).
- Every one is a diagnostic extmark and a sign. bufferline, Snacks statuscolumn and core
  `vim.diagnostic` all scale with that count (the three causes `notes/large-file-performance.md`
  already names), so Python is 3× costlier per key than Go/TS.
- `typeCheckingMode = "standard"` (one line in the basedpyright block of `lua/plugins/lsp.lua`):
  diagnostics 2,496 → 134, `j` 26.5 → 9.1 ms CPU/key, typing 39.4 → 23.7, worst typing key
  129 → 79 ms (sandbox numbers, 3 runs each).
- Trade-off: far fewer warnings, closer to PyCharm/Pylance defaults. Decide whether the strict
  warnings are worth it in your real Python projects (count them there first).
