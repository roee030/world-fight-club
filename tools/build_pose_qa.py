"""Build a contact sheet for one or more fighters' twelve normalized frames."""

from pathlib import Path
import sys

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
SPRITES = ROOT / "assets" / "characters" / "sprites"
OUTPUT = ROOT / "output"


def build(fighter_id: str) -> Path:
    cell = 256
    label_height = 28
    canvas = Image.new("RGBA", (cell * 4, (cell + label_height) * 3), "#17212c")
    draw = ImageDraw.Draw(canvas)
    for index in range(12):
        frame = Image.open(SPRITES / f"{fighter_id}-{index}.png").convert("RGBA")
        frame.thumbnail((cell, cell), Image.Resampling.LANCZOS)
        x = index % 4 * cell
        y = index // 4 * (cell + label_height)
        canvas.alpha_composite(frame, (x, y))
        draw.text((x + 8, y + cell + 5), f"{index}", fill="#f6f1e7")
    path = OUTPUT / f"pose-qa-{fighter_id}.png"
    canvas.save(path)
    return path


if __name__ == "__main__":
    for fighter in sys.argv[1:] or ["bibi", "mansour_abbas"]:
        print(build(fighter))
