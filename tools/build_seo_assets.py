"""Regenerate the committed favicon set and social-share image in web/static.

Run only when the icon design or hero art changes:
    python tools/build_seo_assets.py
"""

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "web" / "static"
HERO = ROOT / "assets" / "ui" / "main-hero-b-edited.jpg"

NAVY = (5, 8, 16)
PANEL = (16, 25, 35)
GOLD = (242, 195, 90)
TEAL = (38, 182, 182)
RED = (214, 72, 72)

# Geometry in a 128-unit box; icon.svg mirrors it exactly.
W_POINTS = [(24, 34), (45, 96), (64, 54), (83, 96), (104, 34)]
W_STROKE = 15


def draw_icon(size: int, maskable: bool = False) -> Image.Image:
    scale = 4
    s = size * scale
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    unit = s / 128
    if maskable:
        d.rectangle([0, 0, s, s], fill=PANEL)
        glyph = 0.78
    else:
        d.rounded_rectangle([0, 0, s - 1, s - 1], radius=24 * unit, fill=PANEL)
        d.rounded_rectangle([4 * unit, 4 * unit, s - 4 * unit, s - 4 * unit], radius=20 * unit, outline=TEAL, width=max(1, int(3 * unit)))
        glyph = 1.0
    cx = cy = 64

    def pt(p):
        return ((cx + (p[0] - cx) * glyph) * unit, (cy + (p[1] - cy) * glyph) * unit)

    pts = [pt(p) for p in W_POINTS]
    width = W_STROKE * unit * glyph
    d.line(pts, fill=GOLD, width=int(width), joint="curve")
    for x, y in pts:
        d.ellipse([x - width / 2, y - width / 2, x + width / 2, y + width / 2], fill=GOLD)
    sx, sy = pt((104, 94))
    r = 7 * unit * glyph
    d.ellipse([sx - r, sy - r, sx + r, sy + r], fill=RED)
    return img.resize((size, size), Image.LANCZOS)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    big = draw_icon(512)
    big.save(OUT / "icon-512.png")
    draw_icon(192).save(OUT / "icon-192.png")
    draw_icon(512, maskable=True).save(OUT / "icon-512-maskable.png")
    draw_icon(180).save(OUT / "apple-touch-icon.png")
    draw_icon(32).save(OUT / "favicon-32.png")
    draw_icon(256).save(OUT / "favicon.ico", sizes=[(16, 16), (32, 32), (48, 48), (64, 64)])
    hero = Image.open(HERO).convert("RGB")
    w, h = hero.size
    crop_h = round(w * 630 / 1200)
    og = hero.crop((0, 0, w, crop_h)).resize((1200, 630), Image.LANCZOS)
    og.save(OUT / "og-image.jpg", quality=86, optimize=True, progressive=True)


if __name__ == "__main__":
    main()
