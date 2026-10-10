"""WWE-style "3 .. 2 .. 1 .. FIGHT" countdown intro rendered as PNG frames (PIL/numpy).

Dark arena (the game's own stage art), sweeping spotlights, a slam + flash on every
count and sparks on FIGHT. `cues` are the seconds at which 3, 2, 1 and FIGHT land.
"""
from __future__ import annotations

import math
import os
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

import overlays as ov

FPS = 60
STAGE_ART = Path(__file__).resolve().parents[2] / "assets" / "stages" / "knesset-chamber-arena.png"
LABELS = ["3", "2", "1", "קרב!"]
COLORS = [((255, 244, 214), (255, 190, 70)), ((255, 244, 214), (255, 160, 60)), ((255, 240, 210), (255, 120, 50)), ((255, 252, 230), (255, 70, 40))]


def beams(size, t, canvas_scale):
    """Two moving-head spotlight wedges, blurred, additive."""
    w, h = size
    layer = Image.new("RGBA", (w // 2, h // 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for k, (cx, phase, col) in enumerate([(0.18, 0.0, (110, 170, 255)), (0.82, 1.9, (255, 120, 90)), (0.5, 3.4, (255, 235, 190))]):
        ang = math.radians(-90 + 28 * math.sin(t * 1.6 + phase))
        ox, oy = cx * w / 2, -20
        length = h
        spread = math.radians(7)
        p = [(ox, oy), (ox + math.cos(ang - spread) * length, oy - math.sin(ang - spread) * -length),
             (ox + math.cos(ang + spread) * length, oy - math.sin(ang + spread) * -length)]
        # simple downward wedge using sin for horizontal sweep
        sweep = math.sin(t * 1.4 + phase) * 0.35 * w / 2
        d.polygon([(ox, oy), (ox + sweep - 0.16 * w / 2, h / 2), (ox + sweep + 0.16 * w / 2, h / 2)], fill=col + (70,))
    return layer.filter(ImageFilter.GaussianBlur(22)).resize(size, Image.BILINEAR)


def render(canvas: str, outdir: str, dur: float, cues: list[float]) -> int:
    os.makedirs(outdir, exist_ok=True)
    w, h = ov.CANVAS[canvas]
    hw, hh = w // 2, h // 2
    art = Image.open(STAGE_ART).convert("RGB")
    scale = max(hw / art.width, hh / art.height) * 1.25
    big = art.resize((int(art.width * scale), int(art.height * scale)), Image.BILINEAR)
    yy, xx = np.mgrid[0:hh, 0:hw]
    r = np.sqrt(((xx - hw / 2) / (hw / 2)) ** 2 + ((yy - hh / 2) / (hh / 2)) ** 2)
    vignette = np.clip(1.15 - r * 0.85, 0.05, 1.0)[..., None]
    tint = np.array([0.8, 0.9, 1.15], dtype=np.float32)
    n = int(round(dur * FPS))
    fonts = {}
    for i in range(n):
        t = i / FPS
        z = 1.0 + 0.10 * (t / dur)
        cw, ch = int(hw / z * 1.25), int(hh / z * 1.25)
        cx, cy = big.width // 2, int(big.height * 0.52)
        crop = big.crop((cx - cw // 2, cy - ch // 2, cx + cw // 2, cy + ch // 2)).resize((hw, hh), Image.BILINEAR)
        since = [t - c for c in cues if t >= c]
        s = since[-1] if since else 99.0
        base = 0.22 + 0.55 * math.exp(-s / 0.25)
        frame = np.clip(np.asarray(crop).astype(np.float32) / 255.0 * base * vignette * tint, 0, 1)
        img = Image.fromarray((frame * 255).astype(np.uint8)).convert("RGBA")
        img = Image.alpha_composite(img, beams((hw, hh), t, 1.0))
        img = img.resize((w, h), Image.BILINEAR)
        k = len([c for c in cues if t >= c]) - 1
        if k >= 0:
            kk = min(k, 3)
            if kk not in fonts:
                label = LABELS[kk]
                size = 760 if kk < 3 else 330
                fonts[kk] = ov.text_layer(label, ov.font(ov.IMPACT, size, label), None, stroke=14, gradient=COLORS[kk], glow=(255, 110, 40))
            art_t = fonts[kk]
            p = min(1.0, s / 0.18)
            sc = 1.0 + (2.4 if kk < 3 else 2.8) * (1 - ov.ease_out_back(p)) if p < 1 else 1.0
            sc = max(0.6, sc)
            max_w = w * (0.92 if kk == 3 else 0.7)
            if art_t.width * sc > max_w * (1.0 if p >= 1 else 2.6):
                sc = max_w * (1.0 if p >= 1 else 2.6) / art_t.width
            aw, ah = int(art_t.width * sc), int(art_t.height * sc)
            scaled = art_t.resize((max(1, aw), max(1, ah)), Image.BILINEAR)
            alpha = min(1.0, p * 2.0)
            if alpha < 1:
                scaled.putalpha(scaled.getchannel("A").point(lambda v, a=alpha: int(v * a)))
            shake = (math.sin(s * 120) * 18 * math.exp(-s / 0.12), math.cos(s * 95) * 12 * math.exp(-s / 0.12))
            img.alpha_composite(scaled, (int(w / 2 - aw / 2 + shake[0]), int(h * 0.46 - ah / 2 + shake[1])))
            if s < 0.12:
                img.alpha_composite(Image.new("RGBA", (w, h), (255, 255, 255, int(200 * (1 - s / 0.12)))))
            if kk == 3 and 0 <= s < 1.2:
                d = ImageDraw.Draw(img)
                for j in range(70):
                    a = j * 2.399963
                    spd = 400 + (j * 37) % 900
                    px, py = w / 2 + math.cos(a) * spd * s, h * 0.46 + math.sin(a) * spd * s + 500 * s * s
                    rad = max(1, int(5 * (1 - s / 1.2)))
                    d.ellipse([px - rad, py - rad, px + rad, py + rad], fill=(255, 190 + (j * 7) % 60, 80, int(255 * (1 - s / 1.2))))
        img.convert("RGB").save(os.path.join(outdir, f"{i:04d}.png"), compress_level=1)
    return n
