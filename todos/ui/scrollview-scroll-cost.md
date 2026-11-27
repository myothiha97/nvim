# nvim-scrollview costs 3–5 ms CPU per `j` in TS/TSX/Python (F28)

Found 2026-11-24 (runtime perf E2E, history comparison §1a of
`docs/advance-features/testing/e2e-perf-report-2026-11-23.md`). Added 2026-11-12; the comment in
`lua/plugins/scrollview.lua` measured 0.1–0.2 ms per refresh, but the per-key cost while
scrolling is larger (its float is redrawn on every scroll step).

- Typical files, scrollbar off: `j` −3.0 (TS), −3.5 (TSX), −5.4 (Python) ms CPU, `<C-d>`
  −5.5 / −6.0 (TS / TSX); all significant at p < 0.05 over 5 interleaved runs. Go: −0.7 (noise).
- With indent-blankline (F22) it is most of the November slowdown.
- Options: keep (the position bar is the feature); try a slower/throttled refresh; drop it.
