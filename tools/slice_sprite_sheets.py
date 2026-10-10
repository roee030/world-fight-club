"""Normalize 4x3 fighter sheets into deterministic Godot sprite frames."""

from pathlib import Path
from PIL import Image, ImageDraw
import numpy as np
from scipy import ndimage


ROOT = Path(__file__).resolve().parents[1]
SHEETS = ROOT / "assets" / "characters" / "sprite-sheets" / "new-roster"
FRAMES = ROOT / "assets" / "characters" / "sprites"
CARDS = ROOT / "assets" / "characters"
CANVAS = 512
MARGIN = 22


def alpha_bbox(image: Image.Image):
    return image.getchannel("A").getbbox()


def isolate_primary_figure(cell: Image.Image) -> Image.Image:
    """Remove pieces of neighbouring poses that spill across a sheet cell.

    Generated sheets do not always respect the mathematical 4x3 grid.  A boot,
    glove or coat from the next pose can cross the crop line.  Those fragments
    are disconnected from the fighter in this cell, so keep the dominant alpha
    component and nearby accessory components only.
    """
    rgba = np.asarray(cell.convert("RGBA")).copy()
    alpha = rgba[:, :, 3]
    mask = alpha > 12
    labels, count = ndimage.label(mask, structure=np.ones((3, 3), dtype=np.uint8))
    if count == 0:
        raise ValueError("empty sprite cell")
    sizes = np.bincount(labels.ravel())
    sizes[0] = 0
    primary = int(sizes.argmax())
    primary_mask = labels == primary
    primary_area = int(sizes[primary])
    ys, xs = np.nonzero(primary_mask)
    primary_box = (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)
    keep = primary_mask.copy()

    # Hair highlights, a loose coat tip or a small prop may be separated by a
    # handful of transparent pixels. Keep only sizeable components very close
    # to the main silhouette; remote neighbour-pose fragments are discarded.
    proximity = 14
    for component in range(1, count + 1):
        if component == primary:
            continue
        area = int(sizes[component])
        if area < max(18, round(primary_area * 0.0015)):
            continue
        cy, cx = np.nonzero(labels == component)
        box = (cx.min(), cy.min(), cx.max() + 1, cy.max() + 1)
        horizontal_gap = max(primary_box[0] - box[2], box[0] - primary_box[2], 0)
        vertical_gap = max(primary_box[1] - box[3], box[1] - primary_box[3], 0)
        if horizontal_gap <= proximity and vertical_gap <= proximity:
            keep |= labels == component

    rgba[~keep, 3] = 0
    return Image.fromarray(rgba, "RGBA")


def extract_pose_cells(sheet: Image.Image) -> list[Image.Image]:
    """Assign complete alpha components to the 4x3 pose they mostly occupy.

    A rigid grid crop can cut an extended hand or boot and paste that fragment
    into the neighbouring pose. Component ownership keeps the whole connected
    fighter with the cell containing most of it, while detached accessories
    that genuinely sit inside a cell remain with that pose.
    """
    sheet = sheet.convert("RGBA")
    rgba = np.asarray(sheet).copy()
    mask = rgba[:, :, 3] > 12
    labels, count = ndimage.label(mask, structure=np.ones((3, 3), dtype=np.uint8))
    x_edges = [round(i * sheet.width / 4) for i in range(5)]
    y_edges = [round(i * sheet.height / 3) for i in range(4)]
    owned: list[list[int]] = [[] for _ in range(12)]

    for component in range(1, count + 1):
        component_mask = labels == component
        area = int(component_mask.sum())
        if area < 12:
            continue
        overlaps = []
        for row in range(3):
            for col in range(4):
                overlaps.append(int(component_mask[y_edges[row]:y_edges[row + 1], x_edges[col]:x_edges[col + 1]].sum()))
        owner = int(np.argmax(overlaps))
        if overlaps[owner] > 0:
            owned[owner].append(component)

    cells: list[Image.Image] = []
    for pose_index, components in enumerate(owned):
        if not components:
            raise ValueError(f"empty sprite cell {pose_index}")
        pose_mask = np.isin(labels, components)
        ys, xs = np.nonzero(pose_mask)
        left, top, right, bottom = xs.min(), ys.min(), xs.max() + 1, ys.max() + 1
        crop = rgba[top:bottom, left:right].copy()
        crop_mask = pose_mask[top:bottom, left:right]
        crop[~crop_mask, 3] = 0
        cells.append(Image.fromarray(crop, "RGBA"))
    return cells


def _cropped_figure(cell: Image.Image) -> Image.Image:
    bbox = alpha_bbox(cell)
    if bbox is None:
        raise ValueError("empty sprite cell")
    return cell.crop(bbox)


def normalize(cell: Image.Image, scale: float | None = None) -> Image.Image:
    figure = _cropped_figure(cell)
    max_w = CANVAS - MARGIN * 2
    max_h = CANVAS - MARGIN * 2
    if scale is None:
        scale = min(max_w / figure.width, max_h / figure.height)
    size = (max(1, round(figure.width * scale)), max(1, round(figure.height * scale)))
    if size[0] > max_w or size[1] > max_h:
        raise ValueError("sprite scale exceeds the safe canvas padding")
    figure = figure.resize(size, Image.Resampling.LANCZOS)
    out = Image.new("RGBA", (CANVAS, CANVAS))
    out.alpha_composite(figure, ((CANVAS - size[0]) // 2, CANVAS - MARGIN - size[1]))
    return out


def normalize_cells(cells: list[Image.Image]) -> list[Image.Image]:
    """Normalize a sheet with one scale while keeping every pose on one floor line."""
    figures = [_cropped_figure(cell) for cell in cells]
    max_w = CANVAS - MARGIN * 2
    max_h = CANVAS - MARGIN * 2
    shared_scale = min(
        max_w / max(figure.width for figure in figures),
        max_h / max(figure.height for figure in figures),
    )
    return [normalize(cell, shared_scale) for cell in cells]


def make_card(id_: str, idle: Image.Image) -> None:
    width, height = 768, 1024
    card = Image.new("RGBA", (width, height), (8, 15, 24, 255))
    draw = ImageDraw.Draw(card)
    for y in range(height):
        mix = y / max(1, height - 1)
        draw.line((0, y, width, y), fill=(12 + int(18 * mix), 28 + int(17 * mix), 42 + int(22 * mix), 255))
    bbox = alpha_bbox(idle)
    figure = idle.crop(bbox)
    scale = min((width - 40) / figure.width, (height - 30) / figure.height)
    figure = figure.resize((round(figure.width * scale), round(figure.height * scale)), Image.Resampling.LANCZOS)
    card.alpha_composite(figure, ((width - figure.width) // 2, height - 15 - figure.height))
    card.save(CARDS / f"{id_.replace('_', '-')}-card.png")


def slice_sheet(path: Path) -> None:
    id_ = path.stem.removesuffix("-sheet").replace("-", "_")
    sheet = Image.open(path).convert("RGBA")
    cells = extract_pose_cells(sheet)
    normalized = normalize_cells(cells)
    for index, frame in enumerate(normalized):
        frame.save(FRAMES / f"{id_}-{index}.png")
    make_card(id_, normalized[0])
    print(f"{id_}: 12 frames + card")


def main() -> None:
    FRAMES.mkdir(parents=True, exist_ok=True)
    for sheet in sorted(SHEETS.glob("*-sheet.png")):
        slice_sheet(sheet)
    # Keep the launch and selection screens on the same in-game art pipeline.
    for id_ in ("bennet", "avigdor", "bibi", "yair_golan"):
        source = FRAMES / f"{id_}-0.png"
        if source.exists():
            make_card(id_, normalize(Image.open(source).convert("RGBA")))
            print(f"{id_}: refreshed card from playable sprite")


if __name__ == "__main__":
    main()
