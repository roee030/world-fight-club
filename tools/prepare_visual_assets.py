from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageOps


ROOT = Path(__file__).resolve().parents[1]
ASSET_CHARS = ROOT / "assets" / "characters"
STAGES = ROOT / "assets" / "stages"
ATLASES = ROOT / "output" / "imagegen"
def fit_cover(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    return ImageOps.fit(image.convert("RGB"), size, method=Image.Resampling.LANCZOS)


def prepare_stage_background(source: Path) -> None:
    image = Image.open(source).convert("RGB")
    canvas_size = (1920, 1080)
    background = fit_cover(image, canvas_size).filter(ImageFilter.GaussianBlur(30))
    background = Image.blend(background, Image.new("RGB", canvas_size, (5, 9, 18)), 0.45)
    foreground = ImageOps.contain(image, canvas_size, method=Image.Resampling.LANCZOS)
    x = (canvas_size[0] - foreground.width) // 2
    y = (canvas_size[1] - foreground.height) // 2
    background.paste(foreground, (x, y))
    background.save(STAGES / f"{source.stem}-arena.png", optimize=True)


def cut_green(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            r, g, b, a = pixels[x, y]
            dominance = g - max(r, b)
            if g > 115 and dominance > 42:
                pixels[x, y] = (r, g, b, 0)
            elif dominance > 12 and g > 95:
                alpha = int(255 * max(0.0, min(1.0, (dominance - 12) / 30.0)))
                pixels[x, y] = (r, min(g, max(r, b) + 10), b, min(a, alpha))
    alpha = rgba.getchannel("A").filter(ImageFilter.GaussianBlur(0.7))
    rgba.putalpha(alpha)
    return rgba


def make_character_art(character: str, palette: tuple[tuple[int, int, int], tuple[int, int, int]]) -> None:
    atlas = Image.open(ATLASES / f"{character}-combat-atlas.png").convert("RGB")
    # The first row's feet finish before y=470; cropping there excludes the
    # next row, whose heads slightly overlap the nominal 512px cell boundary.
    source_pose = atlas.crop((0, 0, atlas.width // 3, 470))
    pose = cut_green(source_pose)
    bbox = pose.getchannel("A").getbbox()
    pose = pose.crop(bbox)

    canvas = Image.new("RGB", (768, 720), (8, 13, 22))
    px = canvas.load()
    top, bottom = palette
    for y in range(canvas.height):
        for x in range(canvas.width):
            glow = max(0.0, 1.0 - (((x - 505) / 470) ** 2 + ((y - 330) / 510) ** 2) ** 0.5)
            vignette = 0.52 + 0.48 * (1.0 - x / canvas.width)
            px[x, y] = tuple(int(min(255, max(0, (top[i] * (1 - y / 720) + bottom[i] * y / 720) * vignette + glow * top[i] * 0.56))) for i in range(3))

    draw = ImageDraw.Draw(canvas, "RGBA")
    draw.polygon([(360, 0), (570, 0), (300, 720), (100, 720)], fill=(255, 255, 255, 9))
    draw.line((24, 24, 744, 24), fill=(*bottom, 190), width=2)
    draw.line((24, 696, 744, 696), fill=(*bottom, 190), width=2)
    draw.ellipse((245, 72, 790, 617), outline=(*top, 105), width=3)

    target_h = 680
    target_w = round(pose.width * target_h / pose.height)
    pose = pose.resize((target_w, target_h), Image.Resampling.LANCZOS)
    x = 768 - target_w + 20
    canvas_rgba = canvas.convert("RGBA")
    shadow_piece = Image.new("RGBA", pose.size, (0, 0, 0, 155))
    shadow_piece.putalpha(pose.getchannel("A").filter(ImageFilter.GaussianBlur(15)).point(lambda value: int(value * 0.52)))
    canvas_rgba.alpha_composite(shadow_piece, (x + 5, 720 - target_h + 4))
    canvas_rgba.alpha_composite(pose, (x, 720 - target_h))
    canvas_rgba.convert("RGB").save(ASSET_CHARS / f"{character}-hero.png", optimize=True)

    # A separate bust crop is used in roster tiles; the large menu art must not
    # be squeezed into a tiny tile, where its full-body fighter becomes a speck.
    upper = cut_green(source_pose)
    upper_box = upper.getchannel("A").getbbox()
    upper = upper.crop(upper_box)
    upper = upper.crop((0, 0, upper.width, int(upper.height * 0.62)))
    upper_box = upper.getchannel("A").getbbox()
    upper = upper.crop(upper_box)
    upper.thumbnail((238, 238), Image.Resampling.LANCZOS)
    thumb = Image.new("RGBA", (256, 256), (*top, 255))
    thumb_draw = ImageDraw.Draw(thumb, "RGBA")
    thumb_draw.ellipse((7, 7, 249, 249), fill=(*bottom, 95), outline=(*bottom, 245), width=3)
    thumb.alpha_composite(upper, ((256 - upper.width) // 2, 256 - upper.height + 4))
    thumb.save(ASSET_CHARS / f"{character}-thumb.png", optimize=True)


for stage in STAGES.iterdir():
    if stage.suffix.lower() in {".png", ".jpg", ".jpeg"} and not stage.stem.endswith("-arena"):
        prepare_stage_background(stage)

make_character_art("bibi", ((24, 51, 93), (40, 160, 206)))
make_character_art("yair-golan", ((39, 57, 42), (200, 142, 56)))
