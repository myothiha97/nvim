# Separate object keys and members from strings

## Status

**IN PROGRESS, parked the evening of 2026-09-24** (was briefly marked done).
No colour pair was settled; live `custom-latest` is back on cyan strings and the
`brighter` yellow. The work is saved as `custom-v4` and `custom-swap` ..
`custom-swap-6`; resume from `notes/string-and-member-colours.md`.

Earlier status, kept for the record: **done 2026-09-24, by freeze override** (trace:
[`freeze-override-2026-09-24.md`](../freeze/freeze-override-2026-09-24.md)).
Built on branch `theme/string-green`. The LAST theme item: the theme is done, no
new theme todos, only bugs.

What shipped: strings on `string.vivid` `#96bc67` (replaced `tokyodark` `#8eaa67`
the same day) in every language; escapes moved to the literal orange and
`import`/`package` to the keyword violet, both 16.4 from the green on the
yellow. Also fixed a Lua query that captured table VALUES as keys. Object keys
linked to
`@variable.member` (still the theme cyan `#29a298`). Checked with a treesitter
probe on a real TS object, which reported all five positions as one cyan before
the change, so it can see the broken state. The checkpoint plan below was
skipped by choice; the same-app `tokyonight-night` test is still available.

## The gap

In TS/JS the object key, the member access and the string are one colour,
`#29a298`, dE2000 0.0:

```ts
url: 'appt-recurring/validate', // key + string
apptId: values.apptId,          // key + member access
```

Three captures land there:

- `@string`, the theme default
- `@variable.member` (member access), because `member = false` in
  `custom-latest`, so it falls back to the theme's `#29a298`
- `@variable.member.key` (bare keys), which `init.lua` links to `@string` on
  purpose (see `notes/palette-reference.md`, "Object keys were two colours")

Go is not affected: its fields already have their own colour.

## Reference: TokyoDark Islands (WebStorm)

Values read from the plugin's own file,
`theme-jetbrains-tokyodark-2.2.0.jar` -> `themes/TokyoDarkIslands.xml`, and
confirmed pixel-exact against a native 1080p screenshot converted to sRGB.

| role | TokyoDark | on its bg `#1a1b26` |
| --- | --- | --- |
| string | `#9ece6a` | L\* 77.6 C\* 55.0 h126 |
| key + member | `#65beb0` | L\* 71.4 C\* 30.2 h182 |
| string vs member | | **dE 22.8** |

## Why its values do not transplant

Measured on our bg `#001014`:

- **Member teal alone** is dE 9.3 from our string cyan. Under 10 they read as
  one colour. It only works in Tokyo because strings moved to green.
- **Green strings** would be L\* 77.6, above body text (72.5), on the most
  common accent in Go and Python. In Ghostty (P3) chroma rises 55 -> 65 at
  h128, the edge of the kelly-green range rejected in July.
- **`keyword.kanagawa` `#957fb8` as member** (tried uncommitted 2026-09-24,
  dropped): dE 5.1 from keyword `#a17bcc`, so members read as keywords. The
  whole purple family now collides with keyword since keyword moved to violet.
- Already rejected earlier: `#73daca`, 5 degrees from string cyan.

So this is a two-role redesign (string + member together), not one hex.

## The wider readability question (2026-09-24)

WebStorm with TokyoDark felt clearer to read overall. The numbers back that up,
and the reason is bigger than string vs member:

| | ours in Ghostty (P3) | TokyoDark in WebStorm (sRGB) |
| --- | --- | --- |
| mean accent contrast | 7.34:1 | **8.51:1** |
| peak chroma | **C\* 92.5** (yellow `#baac0d`) | C\* 55.0 |
| background | L\* 3.8 | L\* 10.1 |

High chroma on near-black is what reads as glare (see the user-colour memory),
and our peak is the punctuation/parameter yellow, one of the most frequent
colours.

A cross-app comparison cannot separate palette from colour management (sRGB vs
P3) and font rendering. The fair test is the same app.

## Checkpoint plan

1. **Same-app test, no config edit.** `:colorscheme tokyonight-night` in
   Ghostty for one real work day. `tokyonight.nvim` is already installed
   (`lazy = true`). Its palette is close to TokyoDark, not identical: fg
   `#c0caf5` vs `#a8b1d6`, functions blue `#7aa2f7` instead of gold. Do not tune
   anything during the test.
2. **Decide once, one of two:**
   - switch the base theme to tokyonight (the member/string split comes free), or
   - keep solarized-osaka and redesign string + member together.
3. **Stop rule** for the redesign path: string vs member dE >= 15, each dE >= 10
   from every other role, member at or below body L\* (72.5). The first pair
   that meets all three ships. One session, no second round.
