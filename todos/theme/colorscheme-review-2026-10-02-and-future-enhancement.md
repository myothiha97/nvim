# solarized-osaka custom-latest: review and roadmap

Review date: 2026-10-02. Values below were sampled from real screenshots (Go, TS, TSX, picker, oil, grug-far, hover docs, completion menu) on the live `custom-latest` build, background `#131312`.

**Verdict:** the palette is good and safe for daily professional work. There is one real defect (TS keys and strings share one colour), two smaller overlaps, and some housekeeping. Everything else is a deliberate trade-off and should stay as it is.

---

## 1. Live palette snapshot

| Role | Hex | L* | WCAG | APCA Lc | Notes |
|---|---|---|---|---|---|
| background | `#131312` | 5.9 | | | neutral, about Material's `#121212` |
| body (`body.tinted`) | `#a0b6b8` | 72.5 | 8.74:1 | 59.9 | brightest syntax role, as it should be |
| Go field / TS param / JSX tag | `#baac0d` | 69.5 | 7.96:1 | 55.6 | most saturated colour (C\* 71) |
| literal / boolean / null / Go param | `#ed8e55` | 68.0 | 7.61:1 | 53.6 | |
| type | `#05aac7` | 64.1 | 6.71:1 | 48.4 | chosen 2026-10-02 |
| function / JSX attribute | `#359ee9` | 62.6 | 6.39:1 | 46.1 | |
| string / object key / member | `#29a298` | 60.4 | 5.95:1 | 43.2 | see Issue 1 |
| delimiter / operator / bracket | `#7f9195` | 58.9 | 5.65:1 | 40.8 | |
| keyword | `#a17bcc` | 58.1 | 5.51:1 | 39.9 | dimmest accent |
| comment | `#5f767d` | 48.1 | 3.87:1 | 27.7 | dimmed on purpose |
| gutter | `#3d555b` | 34.5 | 2.35:1 | | chrome |

The background change from `#001014` to `#131312` moved every text role by 0.3 Lc or less, so earlier body, comment and gutter decisions still hold.

---

## 2. Where it stands

The same metrics were measured for 9 popular dark themes, using each theme's published default dark palette. Overall is the equal-weight average of the three ranks.

| Overall | Theme | Readability | Eye comfort | Clarity |
|---|---|---|---|---|
| 1 | Catppuccin Mocha | 1 | 2 | 4 |
| 2 | Kanagawa | 6 | 1 | 2 |
| 3 | VS Code Dark+ | 4 | 3 | 6 |
| 4 | Dracula | 3 | 10 | 1 |
| 5 | Tokyo Night | 7 | 5 | 3 |
| 6 | GitHub Dark | 2 | 7 | 8 |
| **7** | **custom-latest** | **8** | **4** | **7** |
| 8 | One Dark | 9 | 6 | 5 |
| 9 | Gruvbox | 5 | 9 | 9 |
| 10 | Solarized Dark | 10 | 8 | 10 |

The axes mean the following:

- **Readability:** APCA contrast of body text and accents.
- **Eye comfort:** glare, saturation and background darkness.
- **Clarity:** the closest pair among the core roles (body, keyword, function, string, type, number), plus overlaps found in real code.

**Strengths:**

- The darkest neutral background in the group.
- No accent is brighter than body text.
- Moderate saturation.
- A core-palette closest pair of 14.4 (type vs string), which is 5th of 10 on the core roles alone.
- Semantic fixes most themes do not make: neutral operators and delimiters, builtins on the function colour, decorators and imports moved off the error red, and one consistent colour for Go fields.

**Weaknesses:**

- Body text at Lc 60 is the softest of the group except One Dark and Solarized. This is a comfort choice (see section 5).
- The overlaps in section 3.

---

## 3. Issues (priority order)

### Issue 1: TS object keys, member access and strings are identical (HIGH)

`classPricingGroupId:`, `.classPricingGroupId` and `'guest'` are all `#29a298` (ΔE 0.0). In `type: 'guest'` the key and the value cannot be told apart by colour. Keys are the highest-dose role in TS/TSX after body text. This single overlap moves the clarity rank from 5th to 7th.

**Fix:** give `member` its own colour. The guard in `init.lua` already exists:

```lua
-- init.lua (already present)
if palette.member then
  hl["@variable.member"] = { fg = palette.member }
end
```

```lua
-- palette.lua, variants.member
green = "#7db46d", -- keys + member access, 2026-10-02. L*68 C*44 h136, 7.63:1, Lc 53.5.
                   -- Nearest role: string cyan at dE00 20.7.
```

```lua
-- variants.lua, custom-latest (replaces `member = false`)
member = palette.variants.member.green,
```

Notes:

- Object keys follow automatically, because `@variable.member.key` links to `@variable.member`.
- Go is untouched, because `@variable.member.go` resolves first.
- Check that the base value of `member` in `palette.lua` is `false`. Otherwise `custom-v1` to `custom-v3`, which do not name `member`, pick up a colour too.
- Dose check: open an object-heavy TSX file and confirm keys do not flood the page. That is how the 2026-09-08 salmon attempt failed.
- **Colour-vision note:** under red-green colour vision deficiency, green keys vs orange numbers drop to ΔE 5.2 (protan) and 7.8 (deutan). That is the same level as the existing known weak pair (booleans, 5.4 deutan). It is acceptable unless you regularly share screens with colleagues who have red-green CVD.
- **If green strings ever come back** (parked in `custom-v4`), keys and strings collide again. Revisit this role at that point.

Alternatives that were considered:

| Option | Hex | Nearest role | Why not first choice |
|---|---|---|---|
| rose | `#f1859a` | keyword, 24.5 | pink was turned down twice on high-dose roles |
| Ghostty cyan | `#7bb6ae` | string, 10.1 | too close to strings |

### Issue 2: JSX attributes are identical to function calls (MEDIUM)

`isOpen=`, `onChange=` and `className=` render in `#359ee9`, the same colour as `handleAttendeeChange(...)`. This is the "OPEN FOLLOW-UP, non-Go `@property`" already noted in `init.lua`. `@tag.attribute` links to `@property`, which sits at the theme default and duplicates `Function`. The same group carries YAML/TOML keys (a YAML manifest is about 59% function blue) and dict keys in other languages.

**Fix:** give `@property` its own role. Recommended value: **body text**. This is the VS Code Dark+ approach: attributes read as quiet names, and calls keep the blue to themselves. Because `@property` is a very high-dose group in JSX and YAML, it needs the quietest possible value, and body text adds no new hue and no colour-vision risk.

```lua
-- palette.lua return block: add the role with an explicit `false`
-- (M.load iterates with `pairs`, so nil would silently do nothing)
property = false,
```

```lua
-- variants.lua, custom-latest
property = palette.variants.body.tinted,
```

```lua
-- init.lua, replacing the OPEN FOLLOW-UP note
-- Non-Go `@property` (JSX attributes via @tag.attribute, YAML/TOML/HCL keys,
-- dict keys). Was the theme default, identical to Function. Go is untouched:
-- `@property.go` is set in the Go field block and resolves first.
if palette.property then
  hl["@property"] = { fg = palette.property }
end
```

Known cost: in `isOpen={isOpen}`, the name and the value are both body text. The `={...}` structure separates them, as it does in VS Code. Do **not** use the member value here, as the existing `init.lua` warning says. Attributes and members land on the same line constantly (`key={currentAttendeeInfo?.cUserId}`).

### Issue 3: Go parameters match literals, and parameters differ across languages (LOW)

In Go, parameters and receivers are `#ed8e55`, identical to numbers and `nil`. In TS, parameters are yellow `#baac0d`. This was a deliberate choice (the comment in `init.lua` says orange reads better in Go), so leave it unless it causes real confusion.

Small code cleanup: in the Go field loop in `init.lua`, `hl["@variable.parameter.go"] = { fg = palette.field }` runs on every pass. Move it below the loop so it runs once. Behaviour is unchanged.

---

## 4. Housekeeping

- [ ] **Restart stale Neovim instances.** tmux window 1 (customer-portal-js) still shows types as `#37b4ce`. The Go windows show the chosen `#05aac7`.
- [ ] **Record the type value** in `palette.lua` under `variants.type`, with its measurements: L\* 64.1, 6.71:1, Lc 48.4, nearest string at 14.4 and function at 14.5.
- [ ] **Close the 2026-10-01 trials by a fixed date** (suggested 2026-10-08). Keep or revert each one, then delete the "start trialling" comment:
  - editor background `reference.black_matte_color.second_darkest` (see section 5)
  - statusline band `ui_color.status_line.dark_matte`
  - `FloatBorder` on `cyan900` (rejected on 2026-09-22 as too faint, but that was against the teal background; judge it on the neutral one in normal use)
  - `BlinkCmpMenu` / `BlinkCmpMenuBorder` on `second_darkest`
- [ ] **Update stale comments:**
  - The `on_colors` and `WinBar` notes say the statusline keeps its base03 band. It is now a deliberate neutral band.
  - Many measurements name `#001014` as the background. The numbers still hold to within about 0.3 Lc, so only the background name needs updating.
  - The `variants.lua` comment on `member` says "UNUSED"; update it when Issue 1 lands.
- [ ] **Fix `lua/config/ui.lua`:**
  - `-- bg = reference.teal` is broken. The `reference` table has no `teal` key, so uncommenting it would set the background to `nil`. The previous live value was `candidates.teal_light`:
    ```lua
    -- bg = candidates.teal_light, -- previous live (#001014), fallback
    ```
  - The header still says "WHAT IS LIVE RIGHT NOW: `candidates.teal_light`". Change it to `reference.black_matte_color.second_darkest` once the trial is confirmed.
  - The `black_matte_color` ladder comment lists `#131312` as L\* 5.7. The actual hex measures L\* 5.9 (5.7 was the target the ladder was built from). Correct the comment so it matches the colour.

---

## 5. Background decision

**Keep `reference.black_matte_color.second_darkest` (`#131312`).** Confirm it when the trial ends (2026-10-08). The fallback is `candidates.teal_light` (`#001014`).

| Background | L\* | Tint | Body Lc | Keyword Lc | Comment Lc |
|---|---|---|---|---|---|
| `candidates.teal_light` (previous) | 3.8 | teal, C\* 5.3 | 60.2 | 40.2 | 28.0 |
| `black_matte_color.darkest` | 4.7 | neutral | 60.1 | 40.2 | 27.9 |
| **`black_matte_color.second_darkest` (live)** | 5.9 | neutral | 59.9 | 39.9 | 27.7 |
| `black_matte_color.darker` | 6.7 | neutral | 59.7 | 39.8 | 27.6 |
| `black_matte_color.claude_desktop` | 8.7 | neutral | 59.3 | 39.4 | 27.2 |

**The background is not a readability lever.** Across the whole curated list, text contrast varies by less than 1 Lc. The `ui.lua` header already records this. The choice is about feel and fit.

Why `#131312` is the best fit:

- **Right lightness among the neutral rungs.** It is essentially Material Design's recommended dark surface (`#121212`). `darkest` gains no readability and starts reading as plain black. The lighter rungs give up a little contrast and make the whole screen look greyer.
- **Matches the direction already taken.** The statusline band, completion menu and Ghostty `background` are all neutral now. Ghostty's `background = #131312` matches exactly, so there is no seam around Neovim.
- **Highlight bands stand out more.** Selection (violet) and the explorer and oil bands (teal) sit further from a neutral background than from the teal one. For the selection that is ΔE 22.9 vs 19.7.

What teal did better: cohesion. The text greys (body, comment, delimiter, gutter) are all slightly cool teal-blue (hue 207–225, C\* 7–10), because they were designed on the teal background. There they sat in one colour family. On neutral they read as cool greys on a neutral surface, which is a normal look (VS Code Dark+ works the same way), just a different one.

**If the trial is reverted to teal,** revert these together, or the editor will show neutral panels on a teal page:

- [ ] `ui.lua`: `bg = candidates.teal_light`
- [ ] Ghostty: `background` back to the teal value
- [ ] statusline band (`c.bg_statusline`) back to its pre-trial value
- [ ] `BlinkCmpMenu` / `BlinkCmpMenuBorder` back to `c.bg_popup`

**Once confirmed,** move the teal candidates in `ui.lua` under a "history" comment so the live choice is unambiguous, and close this topic.

---

## 6. Decided: keep as is

These came up in the review and are settled. Do not reopen them without a concrete symptom.

| Item | Decision | Reopen only if |
|---|---|---|
| Background `#131312` | keep, confirm 2026-10-08 (section 5) | never on numbers alone |
| Body `body.tinted` | keep | squinting, leaning in, or tired eyes over several days of normal work. Then use `brighter` (`#b1bebf`, Lc 65), which is already in the palette |
| Type `#05aac7` | keep | types and strings blur in real struct or interface code |
| Go field yellow `#baac0d` | keep | it feels loud after a week. Then use `#b5ad49` (same lightness, C\* 52, nearest role 16.6) |
| Keyword violet `#a17bcc` | keep | you decide to raise readability. This is the first role to lift, before body: `#a680d1` (Lc 42) or `#ac85d7` (Lc 45, nearest role 16.9) |

---

## 7. Path to 4th–5th

| Step | Readability | Comfort | Clarity | Overall |
|---|---|---|---|---|
| Now | 8 | 4 | 7 | 7th |
| + Issue 1 (member green) | 8 | 4 | 5 | about 6th, tied with GitHub Dark |
| + Issue 2 (`@property`) | 8 | 4 | 5 | 6th, with no zero-difference overlaps left |

To reach a numeric 5th, clarity would need to move above Tokyo Night (closest pair 15.1). Raising type to L\* 68 (`#18b5d2`) would lift the closest pair from 14.4 to 15.2 and tie Tokyo Night for 5th overall. That change is **not recommended**. A 0.8 ΔE gain is below what you would notice, so it would change the rank and not the experience. Clarity ranks 3 to 6 are all within about 1 ΔE of each other, which is a practical tie.

A real 4th place would need readability near Tokyo Night's level (body around Lc 74). That means body text brighter than `body.brightest`, which directly conflicts with the comfort you chose.

**The realistic target is the second tier.** After Issues 1 and 2, the palette sits in the same tier as VS Code Dark+, Dracula, Tokyo Night and GitHub Dark: no ambiguous overlaps, a clean brightness order, and the calmest background of the group. That is what "very solid for professional development" means in practice. The exact rank number within the tier is noise.

---

## 8. Professional-grade verification

Run this once after Issues 1 and 2 land, in normal work rather than side-by-side screenshots.

- [ ] Languages: Go, TS, TSX, Lua, Python, bash, YAML, JSON, Markdown.
- [ ] Surfaces: diff and git signs (DiffAdd, DiffDelete, DiffChange were tuned for the teal background), diagnostics and virtual text, `/` search and IncSearch, LSP reference highlight, inlay hints, completion menu, hover docs, picker, oil, grug-far.
- [ ] Environment: one session in a bright room or daylight. Soft palettes fail there first.
- [ ] Duration: one full working day. Eye comfort shows up late in the day, not in the first ten minutes.

---

## 9. Change protocol

- One change at a time.
- Each change runs for at least 5 working days before it is judged.
- Judge in real work. Comparison screenshots exaggerate small differences.
- Revert only on a concrete symptom, written down in one line.
- Before `custom-latest` changes, freeze its current values as the next numbered build (existing rule in `variants.lua`).
- When the items in sections 3 to 5 are done, the palette is finished. New ideas go into `todos/` and wait for the next scheduled review, not into the config.
