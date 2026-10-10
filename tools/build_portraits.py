"""Build face-focused fighter-select portraits from the canonical character cards."""

from pathlib import Path
from PIL import Image, ImageEnhance


ROOT = Path(__file__).resolve().parents[1]
CARDS = ROOT / "assets" / "characters"
OUTPUT = CARDS / "portraits"
IDS = (
    "bennet", "avigdor", "bibi", "yair_golan", "aryeh_deri", "yair_lapid",
    "mansour_abbas", "benny_gantz", "itamar_ben_gvir", "bezalel_smotrich",
    "gadi_eisenkot", "trump", "joint_list",
)


def card_path(fighter_id: str) -> Path:
    return CARDS / f"{fighter_id.replace('_', '-')}-card.png"


def build_portrait(fighter_id: str) -> Path:
    image = Image.open(card_path(fighter_id)).convert("RGB")
    width, height = image.size
    # Character cards share a portrait composition. Keeping the upper 56% retains
    # hair, face, shoulders and signature headwear without squeezing full bodies
    # into a tiny roster tile. Joint List needs both heads, so it keeps more width.
    crop_width = width if fighter_id == "joint_list" else int(width * 0.78)
    center_x = width // 2
    left = max(0, center_x - crop_width // 2)
    right = min(width, left + crop_width)
    crop_height = min(height, int(height * 0.56))
    portrait = image.crop((left, 0, right, crop_height))
    portrait.thumbnail((480, 360), Image.Resampling.LANCZOS)
    canvas = Image.new("RGB", (480, 360), (8, 15, 24))
    x = (canvas.width - portrait.width) // 2
    y = (canvas.height - portrait.height) // 2
    canvas.paste(portrait, (x, y))
    canvas = ImageEnhance.Contrast(canvas).enhance(1.06)
    output = OUTPUT / f"{fighter_id}.png"
    output.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(output, optimize=True)
    return output


if __name__ == "__main__":
    for character_id in IDS:
        print(build_portrait(character_id))
