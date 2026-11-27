# indent-blankline costs 5–8 ms CPU per typed key and per `<C-d>` (F22)

Found 2026-11-23 (runtime perf E2E report). Enabled 2026-11-20 with the cost accepted, but the
comment in `lua/plugins/indent-blank-line.lua` only covers held `j`/`k` (true: −0.7 ms).

- ibl's "debounce" refreshes at once on the first event, then again 200 ms later, so typing
  repaints the guides several times a second.
- Go 3.7k lines, ibl off: typing 26.0 → 17.7 ms CPU/key, typing p95 33.7 → 15.6 ms,
  `<C-d>` 24.3 → 16.3. Python −3 to −9 ms.
- Options: accept and put these numbers in the comment; raise `debounce`; turn scope off.

Update 2026-11-24 (history comparison, typical-size files, 5 interleaved runs): ibl off saves
typing −6.1 (Go), −5.2 (TS), −7.7 (Python) ms CPU/key and `<C-d>` −6.5 (Go), −5.3 (TS); all
significant. It is the single largest cost added since October, in every language.
