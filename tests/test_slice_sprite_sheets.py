import unittest
from pathlib import Path

from PIL import Image, ImageDraw
import numpy as np
from scipy import ndimage

from tools.slice_sprite_sheets import CANVAS, MARGIN, extract_pose_cells, normalize_cells


def make_cell(size: tuple[int, int], figure_box: tuple[int, int, int, int]) -> Image.Image:
    image = Image.new("RGBA", size)
    ImageDraw.Draw(image).rectangle(figure_box, fill=(255, 255, 255, 255))
    return image


class SpriteSheetGeometryTests(unittest.TestCase):
    def test_jab_and_cross_have_materially_different_silhouettes(self) -> None:
        """A second punch must read as a new pose, not a near-duplicate jab."""
        root = Path(__file__).resolve().parents[1] / "assets" / "characters" / "sprites"
        fighter_ids = (
            "bennet", "avigdor", "bibi", "yair_golan", "aryeh_deri", "yair_lapid",
            "mansour_abbas", "benny_gantz", "itamar_ben_gvir", "bezalel_smotrich",
            "gadi_eisenkot", "trump", "joint_list",
        )
        for fighter_id in fighter_ids:
            jab = np.asarray(Image.open(root / f"{fighter_id}-4.png").getchannel("A")) > 12
            cross = np.asarray(Image.open(root / f"{fighter_id}-5.png").getchannel("A")) > 12
            union = np.logical_or(jab, cross).sum()
            overlap = np.logical_and(jab, cross).sum() / union
            self.assertLessEqual(
                overlap,
                0.80,
                f"{fighter_id} cross is still visually indistinguishable from the jab (IoU={overlap:.3f})",
            )

    def test_cross_keeps_the_same_visible_fighter_scale_as_jab(self) -> None:
        """Changing attacks must not make the fighter visibly shrink."""
        root = Path(__file__).resolve().parents[1] / "assets" / "characters" / "sprites"
        fighter_ids = (
            "bennet", "avigdor", "bibi", "yair_golan", "aryeh_deri", "yair_lapid",
            "mansour_abbas", "benny_gantz", "itamar_ben_gvir", "bezalel_smotrich",
            "gadi_eisenkot", "trump", "joint_list",
        )
        for fighter_id in fighter_ids:
            jab = np.asarray(Image.open(root / f"{fighter_id}-4.png").getchannel("A")) > 12
            cross = np.asarray(Image.open(root / f"{fighter_id}-5.png").getchannel("A")) > 12
            visible_area_ratio = int(cross.sum()) / int(jab.sum())
            self.assertGreaterEqual(
                visible_area_ratio,
                0.95,
                f"{fighter_id} visibly shrinks during CROSS (area ratio={visible_area_ratio:.3f})",
            )

    def test_lapid_signature_kick_keeps_fighter_scale(self) -> None:
        """The kick must not make Lapid's body read as a smaller fighter."""
        root = Path(__file__).resolve().parents[1] / "assets" / "characters" / "sprites"
        jab = np.asarray(Image.open(root / "yair_lapid-4.png").getchannel("A")) > 12
        kick = np.asarray(Image.open(root / "yair_lapid-6.png").getchannel("A")) > 12
        visible_area_ratio = int(kick.sum()) / int(jab.sum())
        self.assertGreaterEqual(
            visible_area_ratio,
            0.88,
            "yair_lapid visibly shrinks during KICK (area ratio=%.3f)" % visible_area_ratio,
        )
        jab_rows = np.where(jab.any(axis=1))[0]
        kick_rows = np.where(kick.any(axis=1))[0]
        self.assertEqual(kick_rows[-1], jab_rows[-1], "yair_lapid KICK must use the shared floor line")
        self.assertAlmostEqual(
            len(kick_rows),
            len(jab_rows),
            delta=1,
            msg="yair_lapid KICK must retain the JAB's head-to-floor height",
        )

    def test_repaired_bibi_and_mansour_frames_have_no_remote_pose_fragments(self) -> None:
        root = Path(__file__).resolve().parents[1] / "assets" / "characters" / "sprites"
        for fighter_id in ("bibi", "mansour_abbas"):
            for index in range(12):
                alpha = np.asarray(Image.open(root / f"{fighter_id}-{index}.png").getchannel("A")) > 12
                labels, count = ndimage.label(alpha, structure=np.ones((3, 3), dtype=np.uint8))
                sizes = np.bincount(labels.ravel())[1:]
                self.assertGreater(count, 0)
                self.assertGreaterEqual(
                    int(sizes.max()) / int(sizes.sum()),
                    0.999,
                    f"{fighter_id}-{index} still contains a detached neighbouring pose fragment",
                )

    def test_whole_sheet_components_keep_cross_cell_limbs_without_neighbor_spill(self) -> None:
        sheet = Image.new("RGBA", (400, 300))
        draw = ImageDraw.Draw(sheet)
        expected_areas: list[int] = []
        for row in range(3):
            for col in range(4):
                x = col * 100
                y = row * 100
                body = (x + 25, y + 15, x + 74, y + 94)
                draw.rectangle(body, fill=(255, 255, 255, 255))
                area = 50 * 80
                if col == 0:
                    # A connected arm crosses the nominal cell boundary. A rigid
                    # crop loses its hand and leaves that hand in the next pose.
                    draw.rectangle((x + 70, y + 40, x + 107, y + 49), fill=(255, 255, 255, 255))
                    area += 33 * 10
                expected_areas.append(area)

        poses = extract_pose_cells(sheet)

        self.assertEqual(len(poses), 12)
        for index, pose in enumerate(poses):
            alpha_area = sum(value > 0 for value in pose.getchannel("A").getdata())
            self.assertEqual(alpha_area, expected_areas[index], f"pose {index} contains clipped or foreign alpha")

    def test_detached_accessory_stays_with_the_pose_in_its_cell(self) -> None:
        sheet = Image.new("RGBA", (400, 300))
        draw = ImageDraw.Draw(sheet)
        for row in range(3):
            for col in range(4):
                x = col * 100
                y = row * 100
                draw.rectangle((x + 30, y + 25, x + 69, y + 94), fill=(255, 255, 255, 255))
        draw.rectangle((45, 8, 54, 17), fill=(255, 255, 255, 255))

        poses = extract_pose_cells(sheet)

        first_area = sum(value > 0 for value in poses[0].getchannel("A").getdata())
        self.assertEqual(first_area, 40 * 70 + 10 * 10)

    def test_frames_share_one_scale_and_keep_relative_pose_height(self) -> None:
        standing = make_cell((180, 240), (40, 20, 139, 219))
        crouching = make_cell((180, 240), (30, 120, 149, 219))

        standing_out, crouching_out = normalize_cells([standing, crouching])
        standing_box = standing_out.getchannel("A").getbbox()
        crouching_box = crouching_out.getchannel("A").getbbox()

        self.assertEqual(standing_box[3], CANVAS - MARGIN)
        self.assertEqual(crouching_box[3], CANVAS - MARGIN)
        self.assertAlmostEqual(
            (crouching_box[3] - crouching_box[1]) / (standing_box[3] - standing_box[1]),
            0.5,
            delta=0.02,
        )

    def test_normalized_alpha_stays_inside_safe_padding(self) -> None:
        wide = make_cell((240, 180), (5, 40, 234, 139))
        tall = make_cell((240, 180), (95, 5, 144, 174))

        for frame in normalize_cells([wide, tall]):
            left, top, right, bottom = frame.getchannel("A").getbbox()
            self.assertGreaterEqual(left, MARGIN)
            self.assertGreaterEqual(top, MARGIN)
            self.assertLessEqual(right, CANVAS - MARGIN)
            self.assertEqual(bottom, CANVAS - MARGIN)

    def test_empty_cell_is_rejected(self) -> None:
        with self.assertRaisesRegex(ValueError, "empty sprite cell"):
            normalize_cells([Image.new("RGBA", (64, 64))])


if __name__ == "__main__":
    unittest.main()
