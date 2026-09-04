-- Shared UI colour values, read once at colorscheme-load time (never a hot path).
--
-- TO CHANGE THE BACKGROUND: point `bg` at another `candidates` key. Nothing else
-- needs touching -- the colorscheme's `on_colors` fans it out to bg/bg_float/
-- bg_sidebar, and the runtime-derived groups (oil's invisible border, the
-- explorer's blank/border groups) follow.
--
-- Need the background AT RUNTIME? Read `Normal`'s bg, not this module: that
-- follows what the colorscheme actually applied, and is correctly nil under
-- transparency. `nvim_get_hl(0, { name = "Normal" }).bg`
--
-- MEASURED 2026-09-04/05, so a new pick starts from data:
--
-- * RED IS THE LEVER. At this lightness red is near-pure grey -- it costs chroma
--   without buying visible lightness. R 3 -> 0 darkens AND saturates at once, so
--   the R=0 family wins on both axes. Tune red before green/blue.
-- * "NOT NEAR BLACK" MEANS SATURATION, not brightness. Chroma carries more of the
--   distance from black than lightness does (#000f13: 81% vs 58%). A grey at
--   L* 3.5 reads black, a teal at L* 3.5 reads dark teal -- so "darker" and "not
--   black" do not conflict. #030e12 is 0.10 L* darker than #000f13 (10% of a JND,
--   unseeable) yet 28% less teal and 17% closer to black.
-- * SUM THE STEPS, don't compare neighbours. Every rung is under the ~1 L*
--   just-noticeable difference, but they accumulate: #031116 -> #000e12 was
--   1.09 L* and was called "very dark" immediately.
-- * HARD FLOOR ~L* 3.1. The sRGB gamut narrows to a point at black, so max chroma
--   falls with lightness. Below that line C* 4.5 is unreachable at this hue and
--   darker MUST mean less teal. Geometry, not taste -- don't go hunting.
-- * NOT THE READABILITY LEVER. Every text contrast ratio scales by the same ~2%
--   across the whole ladder, so the theme's dimmest-to-brightest spread stays
--   8.5x on every rung. Five groups sit under 4.5:1 (LineNr worst, 1.78:1) and
--   Delimiter over 12:1 where it can glow on near-black; no rung moves any of them
--   across a threshold. Fix those groups instead.

-- Everything tried, so an experiment is one word and nothing gets re-measured.
-- L*/C* are CIELAB lightness/chroma; "teal" is C* as a share of #031116's.
local candidates = {
  -- R=0 family -- teal preserved. Green and blue move together, red stays out.
  teal_lightest = "#001116", -- L* 4.14  C* 6.01  113% teal  untried; more teal than the "too teal" mark
  teal_light = "#001014", ----- L* 3.80  C* 5.28   99% teal  untried; the full original teal, one rung lighter
  teal = "#000f13", ---------- L* 3.51  C* 4.91   92% teal  CURRENT; 0.81 L* below the start, just under a JND
  teal_dark = "#000e12", ----- L* 3.23  C* 4.55   85% teal  tried; 1.09 L* below the start, read as "very dark"
  teal_darker = "#000d11", --- L* 2.97  C* 4.21   79% teal  untried; below the floor, so teal starts dropping
  teal_darkest = "#000c10", -- L* 2.71  C* 3.89   73% teal  untried; below the floor, and no more teal than greyed_dark

  -- R=3 family -- the red greys the teal out. Reference only; prefer R=0.
  greyed_light = "#031116", -- L* 4.32  C* 5.32  100% teal  the start: first opaque value, "a little biased to teal"
  greyed_mid = "#031014", ---- L* 3.98  C* 4.56   86% teal  tried; midpoint of the two below it, teal fine but wanted darker
  greyed = "#030f13", -------- L* 3.69  C* 4.19   79% teal  untried; teal_light is darker AND more teal, so skip it
  greyed_dark = "#030e12", --- L* 3.41  C* 3.84   72% teal  tried; darker than teal by 0.10 L* (unseeable) at 28% less teal
}

-- Fixed points the list was judged against -- NOT selectable backgrounds.
local reference = {
  -- Ghostty's `background` at `background-opacity = 0.9` composites to #031116
  -- over a dark desktop (measured: flat #031116 across 600/600 px). The first
  -- opaque value matched that, confirmed by transparent rendering #031116 against
  -- opaque #031216 -- one unit apart, so going opaque changed nothing visible.
  ghostty_background = "#031219",

  -- The completion menu's panel (`bg_popup`/base04), deliberately NOT the shared
  -- background so the menu keeps its own. L* 5.15, C* 7.30 -- the "too teal" value
  -- that caps the list above.
  completion_menu = "#001419",
}

return {
  bg = candidates.teal,
  candidates = candidates,
  reference = reference,
}
