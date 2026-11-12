-- Scrollbar on the right edge of each window, so the position in a long file is
-- visible at a glance. Plain position bar only: no marks.
--
-- Chosen 2026-11-12 over satellite.nvim (about 2x slower per refresh on real
-- files, 2.9 ms on a 19k-line file) and nvim-scrollbar (no mouse drag; its v2
-- breaks the config on 2026-11-16).
--
-- Defaults that already match what is wanted, so they are NOT repeated here:
--   * visibility = "overflow": the bar shows only when the file is longer than
--     the window. A file that fits shows nothing.
--   * floating_windows = false: popups (oil, pickers, LSP hovers) never get a bar.
--   * Mouse drag on the bar works on Neovim >= 0.11 through `vim.on_key`, not a
--     <LeftMouse> mapping, so it does not touch the gutter-click maps in
--     `lua/debugging/mouse.lua` or `lua/config/mouse-hover.lua`.
--
-- Cost: refreshes run async (two timer hops, and a pending one is dropped when
-- a newer one is queued) on WinScrolled / WinResized / TextChanged / BufWinEnter
-- and similar events. Each refresh must therefore be cheap, or a stream of
-- wheel events keeps dropping them and the bar trails the text.
--
-- Do NOT add a synchronous WinScrolled refresh (calling the internal
-- `refresh_impl`). Tried and measured 2026-11-12: no gain once `line_limit = 0`
-- made refreshes cheap. What still reads as lag on the mouse wheel is the bar
-- moving in whole rows (~9 lines of text per row in a 400-line file), which no
-- refresh timing can fix.
return {
  {
    "dstein64/nvim-scrollview",
    event = "LazyFile", -- the plugin initialises on a timer, so loading after startup is fine
    opts = {
      -- Off on purpose: the default sign groups (diagnostics, marks, search)
      -- add work to every refresh and clutter a position-only bar.
      signs_on_startup = {},
      -- Restricted mode for EVERY buffer (the default only kicks in above 20k
      -- lines): `simple` positioning and the whole sign pipeline skipped.
      -- Measured per refresh on 2026-11-12, full config: 1.6-2.0 ms -> 0.1-0.2 ms
      -- (AddBooking.tsx, keymaps.lua, a 19k-line file). Trade-off: the bar
      -- ignores closed folds and wrapped lines when sizing itself.
      line_limit = 0,
    },
  },
}
