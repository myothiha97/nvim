# Theme Enhancements — solarized-osaka (custom)

- **Created:** 2026-10-06
- **Status:** Proposed — not applied
- **Baseline build:** `custom-latest`
- **Scope:** Readability for TSX, Go, Lua + font/spacing + background
- **Gate:** Check against `neovim-config-change-gate.md` before applying anything (config is on the `trial-config-before-01-Jan-2027` branch).

---

## 1. Baseline assessment (2026-10-06)

| Area                | Verdict                  | Notes                                                                                                                                  |
| ------------------- | ------------------------ | -------------------------------------------------------------------------------------------------------------------------------------- |
| Background          | Keep                     | Neutral near-black (`ui.reference.black_matte_color.second_darkest`), no blue cast. Foreground is off-white, not pure white — correct. |
| Go                  | Strongest                | Keywords, types, functions, strings, numbers, `nil`/`true` all distinct. No collisions.                                                |
| Lua                 | Good                     | Clean separation. Weak spot: todo-comments `WARN` blocks paint whole paragraphs orange.                                                |
| TSX                 | Weakest                  | Blue overloaded (props + function calls + types). Native tags and components share orange.                                             |
| Comments            | Weak in docs-heavy files | Dim gray + italic = double de-emphasis. Hurts long comment blocks (`variants.lua`, `snacks.lua`).                                      |
| Font size / spacing | Dense                    | ~60 rows × 190+ cols visible. Line height is tight.                                                                                    |
| Cursor row          | Invisible                | No visible CursorLine background; only the line number marks the row.                                                                  |

---

## 2. Enhancements (priority order)

### E1 — Line height + font size (terminal, not theme) (already fixed in 06 Oct 2026)

- **Problem:** Dense grid; tight vertical rhythm slows scanning on long sessions.
- **Change (Ghostty config):**
  ```
  font-size = <current + 1>
  adjust-cell-height = 10%
  ```
- **Verify:** Read a 300+ line TSX file for 10 minutes at both settings. Keep whichever causes less re-reading.
- **Risk:** Fewer visible lines. Line height matters more than size — if forced to choose, keep `adjust-cell-height` and revert size.

### E2 — TSX: break up the blue

- **Problem:** JSX props (`onChange=`), function calls (`setValues(`), and types (`FormikSetValues<…>`) are the same blue. Long prop lists read as one block.
- **Goal:** Three different hues for props / calls / types.
- **Recommended mapping:**
  | Role           | Group(s)                                                                | Proposal                                                                                                  |
  | -------------- | ----------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
  | Function calls | `@function.call`, `@function.method.call`                               | Keep blue                                                                                                 |
  | Types          | `@type`, `@lsp.type.type`, `@lsp.type.interface`, `@lsp.type.typeAlias` | Match the teal Go types already use → cross-language consistency                                          |
  | JSX props      | `@tag.attribute` (+ `.tsx` variant)                                     | New distinct hue — candidate: `palette.variants.member.theme_cyan` or a muted non-blue from `palette.lua` |
- **WARN:** LSP semantic tokens outrank treesitter. Override the `@lsp.type.*` groups too, or the treesitter change silently does nothing for types.
- **Verify:** `:Inspect` on a prop, a call, and a type in `RecurringCheckoutPage.tsx` — confirm which group actually wins.

### E3 — TSX: separate native tags from components

- **Problem:** `<div>` and `<RecurringCheckoutBookingSummary>` are both orange; structural info lost.
- **Change:**
  | Role             | Group          | Proposal                                                                                |
  | ---------------- | -------------- | --------------------------------------------------------------------------------------- |
  | Components       | `@tag`         | Keep orange                                                                             |
  | Native HTML tags | `@tag.builtin` | Dimmer/different — candidate: `palette.variants.punctuation.terracotta` or a muted gray |
- **Verify:** `:Inspect` on `div` — confirm the tsx parser captures it as `@tag.builtin`. If not, the parser version predates that capture; update treesitter parsers first.

### E4 — todo-comments: keyword only

- **Problem:** `WARN` paragraphs render fully orange → loud walls of color.
- **Change (todo-comments opts):**
  ```lua
  highlight = { after = "" }
  ```
- **Verify:** `snacks.lua` WARN blocks: keyword badge stays highlighted, body returns to comment color.

### E5 — Visible cursorline

- **Problem:** Cursor row not visible in a 60-line dense view.
- **Note:** LazyVim enables `cursorline` by default, so `CursorLine` bg likely equals `Normal` bg. Check `:set cursorline?` and `:hi CursorLine` first.
- **Change:** `CursorLine` bg = editor bg lightened ~3–5%. Subtle — must not compete with Visual selection.

### E6 — Comment readability

- **Problem:** Dim + italic on near-black. Fine for sparse code comments, poor for documentation-style comment blocks.
- **Options (pick one, not both at first):**
  1. Drop italic on comments (`styles.comments = { italic = false }` in build config).
  2. Raise comment lightness one step (`palette.variants.comment.*`).
- **Verify:** Read the header block of `variants.lua` and `mouse-hover.lua` at both settings.

---

## 3. Process

Follow the existing build rules in `variants.lua`:

1. Do **not** edit numbered builds.
2. Implement E2/E3/E5/E6 as a new trial build (e.g. `custom-v5`) on top of `custom-latest`.
3. A/B for at least one full work week across TSX (Rezerv), Go (LedgerFlow), Lua (nvim config).
4. If it wins: number the current `custom-latest` values first, then move the new values into `custom-latest`.
5. Remember `false` vs `nil` for role overrides (see existing WARN in `variants.lua`).
6. Log the decision and measurements in `notes/` like previous builds.

E1 and E4 are outside the colorscheme — apply and evaluate independently so results aren't confounded.

---

## 4. Verification checklist

- [ ] `:Inspect` confirms the intended group wins for: JSX prop, function call, TS type, native tag, component
- [ ] Go files unchanged (or improved via shared type color) — open `demo.go`
- [ ] Lua files unchanged apart from comment/todo changes — open `variants.lua`
- [ ] No contrast regressions in: Visual selection, search highlight, diagnostics undercurl, Snacks explorer, statusline
- [ ] One full work week of daily use before promoting to `custom-latest`

---

## 5. Out of scope

- Changing the background color
- Switching colorscheme family
- Font family change (revisit only if E1 doesn't resolve density)
