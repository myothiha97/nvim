#!/usr/bin/env python3
"""Measuring tools for this config's syntax palette.

    python3 scripts/palette/palette.py scorecard
    python3 scripts/palette/palette.py scorecard --build solarized-osaka-custom-v3
    python3 scripts/palette/palette.py screenshot ~/Pictures/shot.png
    python3 scripts/palette/palette.py screenshot shot.png --near '#be6421'

One self-contained file, standard library only, so it still runs in two years
without a pip install and without an import path to get wrong.

The third tool is `census.lua` next door -- it needs to run inside nvim to reach
treesitter, so it cannot live here.

Read notes/syntax-palette-decisions.md before changing a colour. These tools tell
you what a value IS; that file records what was already tried and why it lost.

WHY THIS EXISTS. Colour judgement on a near-black background fails in one
specific, repeatable way: the eye reads CHROMA as brightness. That mistake was
made three times in one session (2026-08-11) and each time the axis named in the
complaint was not the axis that had changed. Measure which axis first.

THE TWO PIPELINES THAT MATTER

  authored   the hex written in lua/colorschemes/solarized-osaka/palette.lua
  emitted    what the panel actually shows

They are not the same. Ghostty runs `window-colorspace = display-p3`, so it tags
these sRGB-authored numbers as Display P3 and every accent is drawn roughly
20 C* more saturated than authored. Quote the emitted figure when arguing about
loudness. On an sRGB external monitor the opposite happens: out-of-gamut values
are CLIPPED, and a channel falling to 00 is a category change (earthy red -> flat
orange) that a small dE badly understates.

INTERPRETING dE2000, on small text glyphs against this background:
    < 10   confusable
   10-20   distinguishable but tiring
    > 20   unambiguous

PERCEPTUAL FLOORS -- moves smaller than these return no signal, so a ladder built
inside them is wasted work:
   lightness   ~5 L*
   chroma      ~5 C*   (olive 67.0 and yellow 67.4 read as the same colour)

WHAT THIS CANNOT TELL YOU: whether a colour is comfortable for six hours. Every
candidate rejected on 2026-08-11 measured well and lost on looks. Use the numbers
to ELIMINATE, then judge the survivors on real files.
"""

import argparse
import collections
import json
import math
import struct
import subprocess
import sys
import tempfile
from itertools import combinations
from pathlib import Path


# -------------------------------------------------------------------------- colour maths

BACKGROUND = "#031219"
"""Ghostty's background, NOT nvim's #001419.

`transparent = true` leaves Normal bg = NONE, so the terminal's colour is what
shows through. Measuring against #001419 gives contrast figures the eye never
sees.
"""

ERROR_RED = "#ff3b30"
"""Set in solarized-osaka.lua as DiagnosticVirtualTextError.

The punctuation role must stay clear of this so brackets never read as
diagnostics. Chroma does that work, not hue -- every warm value in the palette
sits within a few degrees of this red's hue 36.
"""

# ---------------------------------------------------------------- conversions

_D65 = (0.95047, 1.0, 1.08883)

_SRGB_TO_XYZ = (
    (0.4124564, 0.3575761, 0.1804375),
    (0.2126729, 0.7151522, 0.0721750),
    (0.0193339, 0.1191920, 0.9503041),
)
_XYZ_TO_SRGB = (
    (3.2404542, -1.5371385, -0.4985314),
    (-0.9692660, 1.8760108, 0.0415560),
    (0.0556434, -0.2040259, 1.0572252),
)
_P3_TO_XYZ = (
    (0.4865709, 0.2656677, 0.1982173),
    (0.2289746, 0.6917385, 0.0792869),
    (0.0000000, 0.0451134, 1.0439444),
)


def _linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def _encode(c):
    return 12.92 * c if c <= 0.0031308 else 1.055 * (c ** (1 / 2.4)) - 0.055


def _mul(m, v):
    return [sum(m[i][j] * v[j] for j in range(3)) for i in range(3)]


def hex_to_linear(h):
    h = h.lstrip("#")
    return [_linear(int(h[i : i + 2], 16) / 255) for i in (0, 2, 4)]


def _xyz_to_lab(x, y, z):
    def f(t):
        return t ** (1 / 3) if t > 0.008856 else (7.787 * t + 16 / 116)

    fx, fy, fz = f(x / _D65[0]), f(y / _D65[1]), f(z / _D65[2])
    return 116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)


def lab(hex_colour):
    """CIELAB of a hex read as plain sRGB (the authored value)."""
    return _xyz_to_lab(*_mul(_SRGB_TO_XYZ, hex_to_linear(hex_colour)))


def lch(hex_colour):
    """(L*, C*, hue) of the authored value. Hue in degrees, 0-360."""
    lightness, a, b = lab(hex_colour)
    return lightness, math.hypot(a, b), math.degrees(math.atan2(b, a)) % 360


def p3_emitted(hex_colour):
    """(L*, C*, hue) as the panel actually draws it under Ghostty's display-p3.

    This is the number to quote when arguing about loudness. Accents land
    roughly 20 C* above their authored chroma.
    """
    lightness, a, b = _xyz_to_lab(*_mul(_P3_TO_XYZ, hex_to_linear(hex_colour)))
    return lightness, math.hypot(a, b), math.degrees(math.atan2(b, a)) % 360


def on_srgb_display(hex_colour):
    """What an sRGB-gamut external monitor shows, as a hex.

    macOS must convert the P3-tagged colour into the monitor's gamut, and
    anything outside it is CLIPPED. Read the channels, not just the dE: a
    channel going to 0 is a category change (earthy red -> flat orange) that a
    dE score understates badly. Verified against real screenshots to within
    1/255.
    """
    rgb = _mul(_XYZ_TO_SRGB, _mul(_P3_TO_XYZ, hex_to_linear(hex_colour)))
    rgb = [min(1.0, max(0.0, c)) for c in rgb]
    return "#%02x%02x%02x" % tuple(round(_encode(c) * 255) for c in rgb)


def clips_on_srgb(hex_colour):
    """True if an sRGB monitor cannot reproduce this and will clip it."""
    rgb = _mul(_XYZ_TO_SRGB, _mul(_P3_TO_XYZ, hex_to_linear(hex_colour)))
    return any(c < -1e-6 or c > 1 + 1e-6 for c in rgb)


# ------------------------------------------------------------------- metrics


def relative_luminance(hex_colour):
    r, g, b = hex_to_linear(hex_colour)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(fg, bg=BACKGROUND):
    """WCAG contrast ratio. The AA floor for body text is 4.5:1.

    Punctuation and brackets are structure rather than prose, so sitting under
    AA there is a defensible trade -- but know that you are making it.
    """
    a, b = relative_luminance(fg), relative_luminance(bg)
    a, b = max(a, b), min(a, b)
    return (a + 0.05) / (b + 0.05)


def delta_e(hex1, hex2):
    """CIEDE2000. See the module docstring for how to read the number."""
    l1, a1, b1 = lab(hex1)
    l2, a2, b2 = lab(hex2)
    c1, c2 = math.hypot(a1, b1), math.hypot(a2, b2)
    c_bar = (c1 + c2) / 2
    g = 0.5 * (1 - math.sqrt(c_bar**7 / (c_bar**7 + 25**7))) if c_bar > 0 else 0
    a1p, a2p = (1 + g) * a1, (1 + g) * a2
    c1p, c2p = math.hypot(a1p, b1), math.hypot(a2p, b2)
    h1p = math.degrees(math.atan2(b1, a1p)) % 360
    h2p = math.degrees(math.atan2(b2, a2p)) % 360
    dlp, dcp = l2 - l1, c2p - c1p
    d = h2p - h1p
    dhp = 0 if c1p * c2p == 0 else (d - 360 if d > 180 else d + 360 if d < -180 else d)
    dHp = 2 * math.sqrt(c1p * c2p) * math.sin(math.radians(dhp) / 2)
    lbp, cbp = (l1 + l2) / 2, (c1p + c2p) / 2
    if c1p * c2p == 0:
        hbp = h1p + h2p
    elif abs(h1p - h2p) <= 180:
        hbp = (h1p + h2p) / 2
    elif h1p + h2p < 360:
        hbp = (h1p + h2p + 360) / 2
    else:
        hbp = (h1p + h2p - 360) / 2
    t = (
        1
        - 0.17 * math.cos(math.radians(hbp - 30))
        + 0.24 * math.cos(math.radians(2 * hbp))
        + 0.32 * math.cos(math.radians(3 * hbp + 6))
        - 0.20 * math.cos(math.radians(4 * hbp - 63))
    )
    dtheta = 30 * math.exp(-(((hbp - 275) / 25) ** 2))
    rc = 2 * math.sqrt(cbp**7 / (cbp**7 + 25**7)) if cbp > 0 else 0
    sl = 1 + (0.015 * (lbp - 50) ** 2) / math.sqrt(20 + (lbp - 50) ** 2)
    sc, sh = 1 + 0.045 * cbp, 1 + 0.015 * cbp * t
    rt = -math.sin(math.radians(2 * dtheta)) * rc
    return math.sqrt(
        (dlp / sl) ** 2 + (dcp / sc) ** 2 + (dHp / sh) ** 2 + rt * (dcp / sc) * (dHp / sh)
    )


def lch_to_hex(lightness, chroma, hue):
    """Build a hex from LCh, or None when it falls outside the sRGB gamut.

    Use this to walk one axis at a time. Holding two of the three fixed is the
    only way to know which axis a complaint is actually about.
    """
    a = chroma * math.cos(math.radians(hue))
    b = chroma * math.sin(math.radians(hue))
    fy = (lightness + 16) / 116
    fx, fz = fy + a / 500, fy - b / 200

    def inv(t):
        return t**3 if t**3 > 0.008856 else (t - 16 / 116) / 7.787

    xyz = [inv(fx) * _D65[0], inv(fy) * _D65[1], inv(fz) * _D65[2]]
    rgb = _mul(_XYZ_TO_SRGB, xyz)
    if any(c < 0 or c > 1 for c in rgb):
        return None
    return "#%02x%02x%02x" % tuple(max(0, min(255, round(_encode(c) * 255))) for c in rgb)


SOLARIZED = {
    "yellow": "#b58900",
    "orange": "#cb4b16",
    "red": "#dc322f",
    "magenta": "#d33682",
    "violet": "#6c71c4",
    "blue": "#268bd2",
    "cyan": "#2aa198",
    "green": "#859900",
    "base03": "#002b36",
    "base02": "#073642",
    "base01": "#586e75",
    "base00": "#657b83",
    "base0": "#839496",
    "base1": "#93a1a1",
    "base2": "#eee8d5",
    "base3": "#fdf6e3",
}
"""Canonical Solarized, for answering "is this still Solarized?".

Measure each role against its nearest entry. Under ~13 means the role is a
lighter or quieter reading of a Solarized hue; over ~20 means it is an import
from another theme.
"""


def nearest_solarized(hex_colour):
    name, value = min(SOLARIZED.items(), key=lambda kv: delta_e(hex_colour, kv[1]))
    return name, value, delta_e(hex_colour, value)


# ---------------------------------------------------------------------- scorecard command

# The groups that actually carry ink, in the order they matter.
ROLES = [
    ("keyword", "Keyword"),
    ("punctuation", "Special"),
    # Split off `punctuation` on 2026-09-05 so a build could move parameters
    # without moving brackets and tags. No SHIPPING build separates them today,
    # so this row is expected to duplicate the one above -- that is the point: if
    # the two ever drift apart unintentionally, this row is what shows it.
    ("parameter", "@variable.parameter"),
    # Split off `punctuation` on 2026-09-05 along with `parameter`. `bracket` and
    # `delimiter` are NEUTRAL by design in the default build, so they are
    # expected to score close to each other and far from every accent -- that is
    # the "punctuation is chrome" shape, not a collision.
    ("bracket", "@punctuation.bracket"),
    ("delimiter", "@punctuation.delimiter"),
    ("function", "Function"),
    ("type", "Type"),
    ("string", "@string"),
    ("body", "Normal"),
    ("comment", "Comment"),
]

DUMP = """
local out = {{}}
local ok = pcall(vim.cmd.colorscheme, "{build}")
if not ok then io.write('{{"__error":"unknown colorscheme"}}') return end
for _, pair in ipairs({{ {pairs} }}) do
  local hl = vim.api.nvim_get_hl(0, {{ name = pair[2], link = false }})
  if hl and hl.fg then out[pair[1]] = string.format("#%06x", hl.fg) end
end
io.write("PALETTE_JSON" .. vim.json.encode(out))
"""


def live_colours(build):
    """Ask a real nvim what it paints.

    Uses `-c 'lua ...'` and NOT `nvim -l`: the `-l` form skips the user config
    entirely, so lazy.nvim never runs, no colorscheme loads, and every group
    silently reports nvim's built-in defaults. That produced a completely
    plausible-looking but wrong scorecard on 2026-08-11 -- if these numbers ever
    look strange, check that first.
    """
    pairs = ", ".join('{"%s","%s"}' % (r, g) for r, g in ROLES)
    script = DUMP.format(build=build, pairs=pairs)
    result = subprocess.run(
        ["nvim", "--headless", "-c", "lua " + script.replace("\n", " "), "-c", "qa!"],
        capture_output=True,
        text=True,
        cwd=str(Path(__file__).resolve().parents[2]),
    )
    blob = (result.stdout or "") + (result.stderr or "")
    marker = blob.find("PALETTE_JSON")
    if marker < 0:
        sys.exit("could not read colours from nvim:\n" + blob[-800:])
    data = json.loads(blob[marker + len("PALETTE_JSON") :].strip())
    if "__error" in data:
        sys.exit(f"unknown colorscheme: {build}")
    if not data:
        sys.exit("nvim returned no colours -- is the theme loading?")
    return data


def cmd_scorecard(args):
    c = live_colours(args.build)
    print(f"\n{args.build}   against Ghostty's {BACKGROUND}\n")

    print("ROLES                              authored              emitted (P3)")
    print(f"  {'role':<12} {'hex':<9} {'L*':>5} {'C*':>5} {'hue':>4}   {'L*':>5} {'C*':>5}   {'contrast':>9}")
    for role, _ in ROLES:
        if role not in c:
            continue
        h = c[role]
        al, ac, ah = lch(h)
        el, ec, _ = p3_emitted(h)
        print(f"  {role:<12} {h:<9} {al:5.1f} {ac:5.1f} {ah:4.0f}   {el:5.1f} {ec:5.1f}   {contrast(h):8.2f}:1")

    print("\nSEPARATION  (dE2000, worst first)")
    pairs = sorted(
        ((delta_e(c[a], c[b]), a, b) for a, b in combinations([r for r, _ in ROLES if r in c], 2))
    )
    for d, a, b in pairs[:8]:
        flag = "  CONFUSABLE" if d < 10 else ("  tiring" if d < 20 else "")
        print(f"  {a:<12} vs {b:<12} {d:6.1f}{flag}")

    print("\n  vs the error red (brackets must not read as diagnostics)")
    for role in ("punctuation", "keyword"):
        if role in c:
            print(f"  {role:<12} vs {'error red':<12} {delta_e(c[role], ERROR_RED):6.1f}")

    if "keyword" in c and "punctuation" in c:
        kc, pc = p3_emitted(c["keyword"])[1], p3_emitted(c["punctuation"])[1]
        gap = abs(kc - pc)
        verdict = "balanced" if gap < 10 else ("drifting" if gap < 25 else "one drowns the other")
        print(f"\nPAIRING     keyword C* {kc:.1f}  vs  punctuation C* {pc:.1f}   gap {gap:.1f}  -- {verdict}")

    print("\nDISPLAYS    what an sRGB external monitor receives")
    for role, _ in ROLES:
        if role not in c:
            continue
        h = c[role]
        shown = on_srgb_display(h)
        note = "CLIPPED" if clips_on_srgb(h) else "in gamut"
        zero = [n for n, v in zip("rgb", (shown[1:3], shown[3:5], shown[5:7])) if v == "00"]
        if zero:
            note += f", {'/'.join(zero)} channel to 00"
        print(f"  {role:<12} {h} -> {shown}   {note}")

    print("\nSOLARIZED   distance to the nearest canonical Solarized colour")
    for role, _ in ROLES:
        if role not in c:
            continue
        name, _, d = nearest_solarized(c[role])
        verdict = "identical" if d < 3 else ("same family" if d < 15 else "IMPORTED")
        print(f"  {role:<12} ~{name:<8} {d:5.1f}  {verdict}")
    print()


# -------------------------------------------------------------------- screenshot command

def profile_of(path):
    out = subprocess.run(
        ["sips", "-g", "profile", "-g", "pixelWidth", "-g", "pixelHeight", str(path)],
        capture_output=True,
        text=True,
    ).stdout
    fields = {}
    for line in out.splitlines():
        if ":" in line:
            k, _, v = line.strip().partition(":")
            fields[k.strip()] = v.strip()
    return fields


def to_bmp(path):
    tmp = Path(tempfile.mkdtemp()) / "shot.bmp"
    r = subprocess.run(
        ["sips", "-s", "format", "bmp", str(path), "--out", str(tmp)],
        capture_output=True,
        text=True,
    )
    if not tmp.exists():
        sys.exit("sips could not convert that file:\n" + r.stderr)
    return tmp


def read_bmp(path, skip_bottom=0.10):
    """Pixels as (r, g, b), dropping the bottom strip (status bar, tmux line)."""
    data = path.read_bytes()
    offset = struct.unpack_from("<I", data, 10)[0]
    width, height = struct.unpack_from("<ii", data, 18)
    bpp = struct.unpack_from("<H", data, 28)[0]
    row = ((bpp * width + 31) // 32) * 4
    flip, rows = height > 0, abs(height)
    step = bpp // 8
    out = []
    for y in range(int(rows * (1 - skip_bottom))):
        base = offset + (rows - 1 - y if flip else y) * row
        for x in range(width):
            i = base + x * step
            out.append((data[i + 2], data[i + 1], data[i]))
    return width, rows, out


def cmd_screenshot(args):
    src = Path(args.image).expanduser()
    if not src.exists():
        sys.exit(f"no such file: {src}")

    meta = profile_of(src)
    print(f"\n{src.name}")
    print(f"  profile {meta.get('profile', '?')}   {meta.get('pixelWidth', '?')}x{meta.get('pixelHeight', '?')}")
    if meta.get("profile") == "Display P3":
        print("  -> the laptop panel: colours arrive as authored, no clipping")
    else:
        print("  -> not Display P3, so most likely the external monitor:")
        print("     out-of-gamut accents are CLIPPED, watch for a channel at 00")

    width, height, pixels = read_bmp(to_bmp(src))
    counts = collections.Counter(pixels)

    background = counts.most_common(1)[0]
    print(f"\n  background (modal pixel)   #{background[0][0]:02x}{background[0][1]:02x}{background[0][2]:02x}   x{background[1]}")

    if args.near:
        target = tuple(int(args.near.lstrip("#")[i : i + 2], 16) for i in (0, 2, 4))
        hits = {p: n for p, n in counts.items() if sum((a - b) ** 2 for a, b in zip(p, target)) ** 0.5 < args.tolerance}
        total = sum(hits.values())
        print(f"\n  within {args.tolerance:.0f} of {args.near}: {total} pixels")
        for p, n in sorted(hits.items(), key=lambda kv: -kv[1])[:5]:
            print(f"    #{p[0]:02x}{p[1]:02x}{p[2]:02x}  x{n}")
        if not hits:
            print("    none -- the display is not showing that value. Run without")
            print("    --near to see what it IS showing, then compare.")
        return

    # No target given: show the strongest colours, which are the full-coverage
    # glyph pixels of each accent.
    print("\n  most common saturated pixels (full-coverage glyph centres):")
    saturated = {
        p: n
        for p, n in counts.items()
        if max(p) > 70 and (max(p) - min(p)) > 45
    }
    for p, n in sorted(saturated.items(), key=lambda kv: -kv[1])[:12]:
        zero = [c for c, v in zip("rgb", p) if v == 0]
        note = f"   {'/'.join(zero)} channel at 00 -- CLIPPED" if zero else ""
        print(f"    #{p[0]:02x}{p[1]:02x}{p[2]:02x}  x{n}{note}")
    print()



def main():
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    sub = ap.add_subparsers(dest="command", required=True)

    s = sub.add_parser("scorecard", help="score the live palette")
    s.add_argument("--build", default="solarized-osaka-custom-v1")
    s.set_defaults(func=cmd_scorecard)

    p = sub.add_parser("screenshot", help="decode what a display really emitted")
    p.add_argument("image")
    p.add_argument("--near", help="hex to search for, e.g. '#be6421'")
    p.add_argument("--tolerance", type=float, default=26.0)
    p.set_defaults(func=cmd_screenshot)

    args = ap.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
