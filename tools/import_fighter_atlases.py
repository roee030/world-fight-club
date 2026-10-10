"""Slice the 3x2 chroma-green combat atlases into consistent transparent frames."""

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
ATLAS_DIR = ROOT / "output" / "imagegen"
SPRITE_DIR = ROOT / "assets" / "characters" / "sprites"
CELL_W = 512
CELL_H = 512
FRAME_SIZE = (320, 420)
STANDING_HEIGHT = 366


def remove_green(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            red, green, blue, _ = pixels[x, y]
            dominance = green - max(red, blue)
            if dominance > 28 and green > 75:
                alpha = max(0, min(255, 255 - int((dominance - 24) * 4.5)))
                if alpha == 0:
                    pixels[x, y] = (0, 0, 0, 0)
                else:
                    # Remove the green-screen contribution from antialiased edge pixels.
                    spill = (255 - alpha) / 255.0
                    corrected_green = max(0, min(255, int((green - 255 * spill) / (alpha / 255.0))))
                    pixels[x, y] = (red, corrected_green, blue, alpha)
    return rgba


def make_frames(character_id: str, atlas_file: str) -> None:
    atlas_path = ATLAS_DIR / atlas_file
    if not atlas_path.exists():
        raise FileNotFoundError(f"Missing generated atlas: {atlas_path}")
    atlas = Image.open(atlas_path).convert("RGB")
    if atlas.width != CELL_W * 3 or atlas.height != CELL_H * 2:
        raise ValueError(f"Expected a 3x2 {CELL_W}x{CELL_H} atlas, got {atlas.size}")
    SPRITE_DIR.mkdir(parents=True, exist_ok=True)
    scale = STANDING_HEIGHT / 450.0
    for index in range(6):
        col, row = index % 3, index // 3
        # The image model occasionally lets a head from row two intrude a few
        # pixels into row one. Row-one poses end above y=470; trim that spill.
        cell_bottom = 460 if row == 0 else CELL_H
        cell = atlas.crop((col * CELL_W, row * CELL_H, (col + 1) * CELL_W, row * CELL_H + cell_bottom))
        cutout = remove_green(cell)
        bounds = cutout.getchannel("A").getbbox()
        if bounds is None:
            raise ValueError(f"No character found in atlas cell {index}")
        character = cutout.crop(bounds)
        frame_scale = min(scale, (FRAME_SIZE[0] - 24) / character.width)
        resized = character.resize((round(character.width * frame_scale), round(character.height * frame_scale)), Image.Resampling.LANCZOS)
        frame = Image.new("RGBA", FRAME_SIZE, (0, 0, 0, 0))
        x = (FRAME_SIZE[0] - resized.width) // 2
        y = FRAME_SIZE[1] - 26 - resized.height
        frame.alpha_composite(resized, (x, y))
        frame.save(SPRITE_DIR / f"{character_id}-{index}.png", optimize=True)


if __name__ == "__main__":
    make_frames("bibi", "bibi-combat-atlas.png")
    make_frames("yair_golan", "yair-golan-combat-atlas.png")
