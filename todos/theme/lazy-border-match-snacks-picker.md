# Lazy Popup Border: Match the Snacks Picker Ring

## Status

Open. Filed 2026-09-19, inside the freeze window that runs to 2026-10-20. Nothing
was applied to the config. Deferred by the change gate as aesthetic polish, which
is the category `rules.md` names first.

## What Is Wrong

The `:Lazy` float draws an orange ring. Every other framed panel in this config
wears the snacks picker's ring, so the Lazy window is the one surface that does
not belong to the set.

## Why It Does Not Match Today

lazy.nvim sets only `Normal:LazyNormal` on its window
(`~/.local/share/nvim/lazy/lazy.nvim/lua/lazy/view/float.lua:185`, v11.17.5). It
never remaps `FloatBorder`, so the border falls through to the global
`FloatBorder`, which the colorscheme paints orange.

`ui.border = "rounded"` in `lua/config/lazy.lua:42` selects the border SHAPE only.
It has no say in the color. Changing it does nothing for this.

## The Shared Ring

`SnacksPickerBorder`. `lua/plugins/oil.lua:619-624` links `OilStartupBorder` to it,
as a link rather than a copied hex so it tracks the picker.

CRITICAL DETAIL, already paid for once on 2026-09-19 and recorded in
`lua/plugins/oil.lua:607-613`: link the WHOLE group, never lift the fg alone.
`SnacksPickerBorder`'s fg is `#063540`, which against `NormalFloat` (`#001014`) is
too dark to see. What makes the picker's frame legible is its BACKGROUND sitting
darker than the surround, not the colored line. Take fg only and the ring vanishes.

## Candidate Change, Not Applied

An autocmd on `FileType lazy` that rewrites that window's `winhighlight`, keeping
lazy's own mapping and appending the border:

```lua
vim.api.nvim_create_autocmd("FileType", {
  pattern = "lazy",
  callback = function(ev)
    local win = vim.fn.bufwinid(ev.buf)
    if win ~= -1 then
      vim.wo[win].winhighlight = "Normal:LazyNormal,FloatBorder:SnacksPickerBorder"
    end
  end,
})
```

Roughly six lines. Open questions to settle before writing it for real:

1. ORDERING. lazy sets `winhighlight` at window creation (`float.lua:185`). Confirm
   `FileType` fires after that, or the override is silently overwritten.
2. RE-RENDER. `View:update()` reuses the same window across mode switches (Home,
   Install, Log, and so on). Confirm the override survives, and that `FileType`
   does not need to be `WinEnter` or a `User LazyRender` hook instead.
3. WHERE IT LIVES. `lua/config/ui.lua` already owns runtime-derived groups, so it
   may belong there rather than beside the lazy spec.

## Verification At The Checkpoint

- Open `:Lazy` next to the oil startup float and a snacks picker. The three rings
  must read as one ring.
- Walk every mode: Home, Install, Update, Sync, Clean, Check, Log, Restore,
  Profile, Debug, Help. The ring must not revert on any of them.
- Confirm `LazyBackdrop` still dims behind the float.
- Fire `:colorscheme` again and confirm the ring survives. oil re-runs its
  highlights on `ColorScheme`; this needs the same treatment or a link that
  tracks on its own.
- Test the first-call case where snacks has not defined its groups yet, and give
  it a role-based fallback the way `oil.lua:621-624` falls back to `delimiter`.

## Related

Seen on the same window the same evening, and not filed: an `E5108` crash from a
nil `render.locations` when a key is pressed in a Lazy float that never rendered
(`lazy/view/render.lua:108`). Separate bug, separate fix, no upstream release to
pull. Worth triaging together only because both touch this window.
