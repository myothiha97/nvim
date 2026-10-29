-- Shared UI colour values, read once at colorscheme-load time (never a hot path).
--
-- TO CHANGE THE BACKGROUND: point `bg` at another `candidates` key. Nothing else
-- needs touching -- the colorscheme's `on_colors` fans it out to bg/bg_float/
-- bg_sidebar, and the runtime-derived groups (oil's invisible border, the
-- explorer's blank/border groups) follow.
--
-- WHAT IS LIVE RIGHT NOW: `candidates.teal_light` (#001014). Confirmed
-- 2026-09-19 as the value to keep. Verify with
-- `nvim_get_hl(0, {name = "Normal"}).bg`.
--
-- This block previously said `reference.ghostty_background` (#031219) was live,
-- and stayed that way after `bg` moved to the ladder -- so anything quoting
-- #031219 as the background is stale by definition. `ghostty_background` is
-- kept below as the reference value it is named for, not as the live one.
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
--   8.5x on every rung. Five groups sit under 4.5:1 (LineNr worst: 1.78:1 then, 2.44:1 since its 2026-09-23 raise) and
--   Delimiter over 12:1 where it can glow on near-black; no rung moves any of them
--   across a threshold. Fix those groups instead.

-- Everything tried, so an experiment is one word and nothing gets re-measured.
-- L*/C* are CIELAB lightness/chroma; "teal" is C* as a share of #031116's.
local candidates = {
  -- R=0 family -- teal preserved. Green and blue move together, red stays out.
  teal_lightest = "#001116", -- L* 4.14  C* 6.01  113% teal  untried; more teal than the "too teal" mark
  teal_light = "#001014", ----- L* 3.80  C* 5.28   99% teal  LIVE (bg below); the full original teal, one rung lighter
  teal = "#000f13", ---------- L* 3.51  C* 4.91   92% teal  tried; 0.81 L* below the start, just under a JND
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
  -- NOT LIVE since the move to `candidates.teal_light`. Kept as the reference
  -- for what the terminal itself uses, which is what this key is named for.
  ghostty_background = "#031219",

  -- The completion menu's panel (`bg_popup`/base04), deliberately NOT the shared
  -- background so the menu keeps its own. L* 5.15, C* 7.30 -- the "too teal" value
  -- that caps the list above.
  completion_menu = "#001419",
  black_matte_color = {

    -- #191918  L* 8.7  Claude desktop editor bg (sampled)
    -- #171716  L* 7.7  -1 step
    -- #151514  L* 6.7  -2 steps
    -- #131312  L* 5.7  -3 steps
    -- #10100f  L* 4.7  -4 steps
    -- #0e0e0d  L* 3.8  approx, same lightness as current nvim bg

    claude_desktop = "#191918",
    medium_dark = "#171716",
    darker = "#151514",
    second_darkest = "#131312",
    darkest = "#10100f",
  },
  -- Checkpoint candidates, not live. Findings: todos/theme/background-16181d-candidate.md
  one_dark_pro_vscode = {
    darker = "#23272e", -- theme's own editor bg; reads brighter than VS Code shows it
    darker_custom = "#16181d", -- VS Code colorCustomizations override of One Dark Pro Darker
  },
}
local status_line = {
  light_matte = "#222221",
  dark_matte = "#1e1e1d",
  darker_matte = "#171716",
}

local M = {
  -- bg = reference.black_matte_color.darkest,
  bg = reference.black_matte_color.second_darkest, -- start trialling from 1st Oct 2026
  -- bg = candidates.teal, -- current live color,
  status_line = status_line,
  candidates = candidates,
  reference = reference,
}

-- Mixes `hex` toward white by `amount` (0..1), so the result keeps its tint.
local function lift(hex, amount)
  local function channel(i)
    local value = tonumber(hex:sub(i, i + 1), 16)
    return math.floor(value + (255 - value) * amount + 0.5)
  end
  return string.format("#%02x%02x%02x", channel(2), channel(4), channel(6))
end

-- Neutral UI surfaces derived from `bg`, so they move with it. They replace the
-- theme's teal base04/base03/base02 ramp, which was tuned for the retired teal
-- background (#001014) and showed as teal bands on the black matte one.
M.surface = {
  panel = lift(M.bg, 0.03), -- base04: popup panels (Pmenu)
  raised = lift(M.bg, 0.09), -- base03: native StatusLine, Pmenu scrollbar
  selection = lift(M.bg, 0.12), -- base02: borders, separators, ColorColumn
  -- Explorer active-file band. Warm taupe against the cool `list_cursor`: warm
  -- means "open file", cool means "cursor here". dE00 9.0 from bg and 11.5 from
  -- the slate, 6 L* below it so the cursor row stays the stronger mark. #37332b
  -- (C* 5.7) read too heavy; a lighter plain grey drifted toward the slate. 2026-10-29.
  active_file = "#312f2b",
  -- The one "selected row" colour: picker, explorer, outline, completion menu,
  -- Pmenu and Oil. A muted slate, not bg-derived: a little hue makes the row
  -- easier to find than plain grey (dE00 15.6 vs 13.2 on #131312) without the
  -- old violet's loss of text contrast. Measured 2026-10-29.
  list_cursor = "#383c4a",
  -- Softer step down, if the slate still feels heavy after a few days of use:
  -- dE00 14.3 from bg (catppuccin's PmenuSel level), 10.7 from the active-file
  -- band, body text 6.09:1. Still easy to find in a list.
  -- list_cursor = "#353845",
  guide = lift(M.bg, 0.19), -- explorer tree lines and indent guides
}

return M
