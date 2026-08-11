# Solarized Osaka Upstream Update

## Status

Deferred to the 2026-10-20 config checkpoint. Do not update during the freeze unless
the current theme is broken.

Recorded 2026-08-11 after upstream advertised a large update ending at `0df74ef`.
The current known-good lock is `f675d9a5c58f3b0d6158d665a623f81a62e7bdaf`.

## Why It Is Deferred

The upstream batch refactors palette construction, adds palette tiers, removes color
helpers, and adds a vivid style. The local theme is not a simple option override. It
uses upstream internals while building four local variants:

- `require("solarized-osaka")._load()`
- `require("solarized-osaka.config").options`
- `require("solarized-osaka.colors").setup(...)`
- Upstream highlight and palette names consumed by local syntax overrides

The update may be compatible, but it has a larger-than-normal chance of changing
colors or breaking variant loading. There is no current bug or workflow need that
justifies taking that risk during the freeze.

## Checkpoint Procedure

1. Create a dedicated branch. Never test the update on `main`.
2. Read the upstream diff from the pinned commit before updating, especially changes
   to `_load`, config options, color construction, and highlight names.
3. Start one unlocked session with `NVIM_LAZY_UNLOCK=1 nvim` and update only
   solarized-osaka.nvim.
4. Run the Lua parse check, clean boot, and `git diff --check`.
5. Load and inspect all four entry points:
   - `solarized-osaka-custom-v1`
   - `solarized-osaka-custom-v2`
   - `solarized-osaka-custom-v3`
   - `solarized-osaka-original`
6. Confirm custom-v1 still has the selected violet keyword, copper punctuation,
   neutral delimiters and symbolic operators, and the intended Type color.
7. Confirm diagnostics, git signs, lualine, CodeCompanion, LSP doc floats, and Trouble
   colors did not inherit syntax-palette changes.
8. Inspect real TSX, Go, and Lua files in Ghostty. Compare against the pinned build.
9. Keep the update only if behavior and appearance are proven equivalent or an
   intentional upstream improvement is explicitly accepted.

If compatibility work becomes large or visual results regress, keep the current pin
and revisit at a later scheduled checkpoint.
