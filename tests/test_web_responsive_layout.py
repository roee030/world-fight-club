import unittest

from tools.patch_web_export import fit_viewport


class ResponsiveViewportTests(unittest.TestCase):
    def test_landscape_matrix_fills_the_whole_screen(self):
        # The game uses Godot's "expand" aspect: every landscape phone gets the
        # full width and height, no letterbox bars.
        for width, height in [
            (568, 320),
            (667, 375),
            (740, 360),
            (844, 390),
            (915, 412),
            (1024, 600),
            (1280, 720),
            (2400 / 2.625, 1080 / 2.625),
        ]:
            with self.subTest(viewport=(width, height)):
                result = fit_viewport(width, height)
                self.assertFalse(result["portrait"])
                self.assertEqual(result["left"], 0)
                self.assertEqual(result["top"], 0)
                self.assertAlmostEqual(result["width"], width)
                self.assertAlmostEqual(result["height"], height)

    def test_safe_area_is_respected(self):
        result = fit_viewport(844, 390, {"left": 47, "right": 34, "top": 0, "bottom": 21})
        self.assertFalse(result["portrait"])
        self.assertEqual(result["left"], 47)
        self.assertAlmostEqual(result["left"] + result["width"], 844 - 34)
        self.assertAlmostEqual(result["top"] + result["height"], 390 - 21)

    def test_portrait_uses_rotate_gate_instead_of_tiny_canvas(self):
        for width, height in [(320, 568), (390, 844), (412, 915)]:
            with self.subTest(viewport=(width, height)):
                result = fit_viewport(width, height)
                self.assertTrue(result["portrait"])
                self.assertEqual(result["width"], 0)
                self.assertEqual(result["height"], 0)

    def test_project_expands_instead_of_letterboxing(self):
        from pathlib import Path

        project = (Path(__file__).resolve().parents[1] / "project.godot").read_text(encoding="utf-8")
        self.assertIn('window/stretch/mode="canvas_items"', project)
        self.assertIn('window/stretch/aspect="expand"', project)


if __name__ == "__main__":
    unittest.main()
