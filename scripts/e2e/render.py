"""Render a tmux ANSI capture (capture-pane -e) to PNG for visual review."""
import sys
import pyte
from PIL import Image, ImageDraw, ImageFont

FONT = "/usr/share/fonts/truetype/jetbrains-mono/JetBrainsMono-Regular.ttf"
BOLD = "/usr/share/fonts/truetype/jetbrains-mono/JetBrainsMono-Bold.ttf"
FALLBACK = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"
SIZE = 15

_f = ImageFont.truetype(FONT, SIZE)
_fb = ImageFont.truetype(BOLD, SIZE)
_ff = ImageFont.truetype(FALLBACK, SIZE)
CW = int(_f.getlength("M"))
CH = SIZE + 5


def _has(font, ch):
    try:
        return font.getmask(ch).getbbox() is not None or ch == " "
    except Exception:
        return False


def _color(c, default):
    if c == "default":
        return default
    if isinstance(c, str) and len(c) == 6:
        return "#" + c
    names = {"black": "#000000", "red": "#cd3131", "green": "#0dbc79", "brown": "#e5e510", "blue": "#2472c8",
             "magenta": "#bc3fbc", "cyan": "#11a8cd", "white": "#e5e5e5"}
    return names.get(c, default)


def render(ansi_text, out, cols=200, rows=50, bg="#002b36", fg="#93a1a1"):
    screen = pyte.Screen(cols, rows)
    stream = pyte.Stream(screen)
    import re
    t = re.sub(r"\x1b\[4:[0-5]m", "\x1b[4m", ansi_text)          # curly/dotted underline -> underline
    t = re.sub(r"\x1b\[58;2;\d+;\d+;\d+m|\x1b\[59m", "", t)    # underline colour (pyte can't)
    for i, line in enumerate(t.split("\n")[:rows]):
        stream.feed(f"\x1b[{i + 1};1H\x1b[0m" + line)
    img = Image.new("RGB", (cols * CW, rows * CH), bg)
    d = ImageDraw.Draw(img)
    for y in range(rows):
        line = screen.buffer[y]
        for x in range(cols):
            c = line[x]
            f, b = _color(c.fg, fg), _color(c.bg, bg)
            if c.reverse:
                f, b = b, f
            if b != bg:
                d.rectangle([x * CW, y * CH, (x + 1) * CW, (y + 1) * CH], fill=b)
            ch = c.data
            if ch and ch != " ":
                font = _fb if c.bold else _f
                if not _has(font, ch):
                    font = _ff if _has(_ff, ch) else None
                if font:
                    d.text((x * CW, y * CH + 2), ch, fill=f, font=font)
                elif ord(ch) >= 0xE000:  # Nerd Font icon not available: small marker
                    d.rectangle([x * CW + 3, y * CH + 6, x * CW + CW - 3, y * CH + CH - 6], outline=f)
    img.save(out)


if __name__ == "__main__":
    render(open(sys.argv[1]).read(), sys.argv[2])
