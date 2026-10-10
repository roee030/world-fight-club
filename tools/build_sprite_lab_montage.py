from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
FILES = sorted((ROOT / "output").glob("sprite-lab-*.png"))
THUMB = (384, 216)
COLS = 4
ROWS = (len(FILES) + COLS - 1) // COLS

canvas = Image.new("RGB", (COLS * THUMB[0], ROWS * (THUMB[1] + 28)), "#08131b")
draw = ImageDraw.Draw(canvas)

for index, path in enumerate(FILES):
    image = Image.open(path).convert("RGB")
    image.thumbnail(THUMB, Image.Resampling.LANCZOS)
    x = (index % COLS) * THUMB[0]
    y = (index // COLS) * (THUMB[1] + 28)
    canvas.paste(image, (x, y))
    draw.text((x + 8, y + THUMB[1] + 5), path.stem.removeprefix("sprite-lab-"), fill="#f5f0e8")

output = ROOT / "output" / "sprite-lab-montage.png"
canvas.save(output)
print(output)
