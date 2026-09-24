# Freeze-override trace — 2026-09-24 string green

Required by rule 10 in [`discipline-stop-rules.md`](../process/discipline-stop-rules.md).

**The change (one line):** strings move from the theme cyan `#29a298` to the
green `#96bc67`, and object keys follow member access instead of strings, so key,
member and string stop being one colour in TS/JS.

**Why it did not wait for the 2026-10-20 checkpoint:** it could have. The gate
fired, the four-point answer was given (optional, not blocking, not serving the
current priorities), the todo was written
([`string-member-separation.md`](../theme/string-member-separation.md)), and it
was overridden by choice: "by pass the gate, lets settled it now".

**Scope held to the todo's plan:** one hex from a measured candidate set, one
link change. **One second round did happen:** `#8eaa67` read dull in Go, and
screenshots confirmed it (strings are 49% of Go's coloured ink at the lowest
chroma on screen). Replaced by `#96bc67`, which is the measured ceiling: nothing
brighter stays under body lightness and out of the kelly greens. No third round.

**Then the scope changed, not the value:** by request, the green now applies only
in the languages that paint members cyan (JS/TS/TSX/Lua/Python/Terraform/HCL);
Go and the rest went back to cyan strings. That pass also found a real bug, not
a preference: the Lua key query captured table VALUES as keys, which the key
link change had made visible (`desc = "Open file"` rendered in the key colour).

**Last pass, same day:** the language scoping was measured and dropped (cyan
lost on legibility in every language, 6.19:1 vs 8.93:1), so strings are green
everywhere. Two neighbouring roles moved with it, because the green sat only
16.4 from the yellow they wore: `@string.escape` to the literal orange (39.6)
and `@keyword.import` to the keyword violet (63.6). No new hue was added.

**Consequence:** the freeze was extended from 2026-10-20 to 2026-12-31
(`rules.md`), for the same reason as the 2026-08-11 extension: time spent
inside a freeze buys more freeze.

**After the extension, one more by choice:** body text moved from `tinted` to
`brighter` ("lets go with brighter"). The measured reason: the green strings
rose to body level, and `tinted` then read dimmer than strings and types. The
step is dE 4.1. Offered as a todo for the checkpoint first; declined.
File and folder names followed it (`base0` -> `tinted` in snacks and oil), so
the approved step below body stayed dE 4.1.
Then two more by choice: string interpolation (`@punctuation.special`) joined
the escapes on the orange, and the accent yellow went to `vivid` as a trial,
against the measured recommendation (it reads brighter than body text).
The `vivid` trial was dropped after the side-by-side screenshots: dE 3.7 on
screen, and it read brighter than body text. The yellow stays `brighter`.
Reversed once more, by preference: the user found `vivid` better on real files,
so it stays (dE 3.7, no separation loss). The yellow is settled.
Also fixed a regression from the string change: doc code blocks in hovers and
:help had turned green through the `@markup.raw` -> `String` link; pinned back.

**End of day: parked, not settled.** No pair was chosen with confidence, so live
`custom-latest` went back to cyan strings and the `brighter` yellow (this
morning's look), keeping only the `brighter` body and `tinted` file names. The
day's work is saved, not discarded: `custom-v4` (the day's final custom-latest)
and `custom-swap` .. `custom-swap-6`, verified byte-identical to how they stood.
One piece went live again the same evening, by choice: violet imports
(`import = keyword.warm_violet` in custom-latest).
