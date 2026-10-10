"""Build a local-only test fighter from 12 green-screen pose images.

Usage:  python tools/build_private_fighter.py roee

Reads    private/<id>/frames/01-*.png ... 12-*.png  (pose order of docs/character-pipeline.md)
Writes   private/<id>/sprites/<id>-0..11.png, private/<id>/card.png, private/<id>/portrait.png
Then add the fighter to private/fighters.json (see scripts/private_roster.gd).

Everything under private/ is git-ignored: personal likenesses never reach the public repo.
"""

import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from slice_sprite_sheets import isolate_primary_figure, normalize_cells  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]


def key_green(image: Image.Image) -> Image.Image:
    """Chroma-key a flat green background into a soft alpha with despill."""
    rgb = np.asarray(image.convert("RGB")).astype(float)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    dominance = g - np.maximum(r, b)
    alpha = np.clip(1.0 - (dominance - 25.0) / 70.0, 0.0, 1.0)
    despilled = np.where(alpha < 1.0, np.minimum(g, np.maximum(r, b) + 8.0), g)
    out = np.dstack([r, despilled, b, alpha * 255.0]).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def build(fighter_id: str) -> None:
    base = ROOT / "private" / fighter_id
    sources = sorted((base / "frames").glob("[0-1][0-9]-*.png"))
    if len(sources) != 12:
        raise SystemExit(f"expected 12 pose images in {base / 'frames'}, found {len(sources)}")
    cells = [isolate_primary_figure(key_green(Image.open(path))) for path in sources]
    frames = normalize_cells(cells)
    out_dir = base / "sprites"
    out_dir.mkdir(parents=True, exist_ok=True)
    for index, frame in enumerate(frames):
        frame.save(out_dir / f"{fighter_id}-{index}.png")
    idle = frames[0]
    figure = idle.crop(idle.getchannel("A").getbbox())
    # Card: full figure on the dark console gradient used by the roster cards.
    card = Image.new("RGBA", (768, 1024), (10, 22, 34, 255))
    scale = min(728 / figure.width, 994 / figure.height)
    sized = figure.resize((round(figure.width * scale), round(figure.height * scale)), Image.Resampling.LANCZOS)
    card.alpha_composite(sized, ((768 - sized.width) // 2, 1024 - 15 - sized.height))
    card.save(base / "card.png")
    # Portrait: head-and-shoulders crop (top 30% of the idle figure), 480x360 like the roster.
    head = figure.crop((0, 0, figure.width, max(1, int(figure.height * 0.30))))
    portrait = Image.new("RGBA", (480, 360), (10, 22, 34, 255))
    scale = min(470 / head.width, 350 / head.height)
    head = head.resize((round(head.width * scale), round(head.height * scale)), Image.Resampling.LANCZOS)
    portrait.alpha_composite(head, ((480 - head.width) // 2, 360 - head.height))
    portrait.convert("RGB").save(base / "portrait.png")
    print(f"{fighter_id}: 12 frames, card and portrait in {base}")


if __name__ == "__main__":
    build(sys.argv[1] if len(sys.argv) > 1 else "roee")
