from pathlib import Path
from tempfile import TemporaryDirectory
import json
import unittest

from tools.patch_web_export import patch


ROOT = Path(__file__).resolve().parents[1]
GODOT_SHELL = """<html><head><title>World Fight</title></head><body><canvas id="canvas"></canvas>
<div id="status"><progress id="status-progress"></progress><div id="status-notice"></div></div>
<script src="index.js"></script></body></html>"""


class WebCachePolicyTests(unittest.TestCase):
    def test_pages_build_does_not_pin_old_game_package(self):
        preset = (ROOT / "export_presets.cfg").read_text(encoding="utf-8")
        self.assertIn("variant/extensions_support=false", preset)
        self.assertIn("progressive_web_app/enabled=false", preset)
        # Full bleed: the canvas covers the notch side too (no black strip);
        # Godot insets its interactive UI by the published safe area instead.
        self.assertIn("viewport-fit=cover", preset)
        patcher = (ROOT / "tools" / "patch_web_export.py").read_text(encoding="utf-8")
        workflow = (ROOT / ".github" / "workflows" / "deploy-pages.yml").read_text(encoding="utf-8")
        self.assertIn("getRegistrations()", patcher)
        self.assertIn("caches.keys()", patcher)
        self.assertIn("python tools/patch_web_export.py", workflow)

    def test_textures_download_as_lossy_webp(self):
        # Lossless images made a 65 MB package that gzip cannot shrink. Lossy
        # WebP decodes to the same GPU textures, so runtime cost is unchanged.
        project = (ROOT / "project.godot").read_text(encoding="utf-8")
        self.assertIn("[importer_defaults]", project)
        self.assertIn('"compress/mode": 1', project)

    def test_finisher_art_ships_with_main_package(self):
        preset = (ROOT / "export_presets.cfg").read_text(encoding="utf-8")
        workflow = (ROOT / ".github" / "workflows" / "deploy-pages.yml").read_text(encoding="utf-8")
        core = preset.split("[preset.1]")[0]
        self.assertNotIn("assets/finishers/*", core)
        self.assertNotIn('name="Web Finishers Pack"', preset)
        self.assertNotIn("finishers.pck", workflow)
        self.assertFalse((ROOT / "scripts" / "web_pack_loader.gd").exists())

    def test_web_export_omits_editor_only_source_assets(self):
        preset = (ROOT / "export_presets.cfg").read_text(encoding="utf-8")
        for pattern in (
            "export/*",
            "assets/animations/*",
            "assets/characters/rigged/*",
            "assets/characters/references/*",
            "assets/characters/sprite-sheets/*",
            "tests/*",
            "tools/*",
            "assets/ui/rotate-device-ensemble.webp",
        ):
            self.assertIn(pattern, preset)

    def test_retired_worker_never_reloads_the_page(self):
        with TemporaryDirectory() as folder:
            root = Path(folder)
            html = root / "index.html"
            html.write_text(GODOT_SHELL, encoding="utf-8")
            patch(html)
            worker = (root / "index.service.worker.js").read_text(encoding="utf-8")
            self.assertIn("self.registration.unregister()", worker)
            self.assertIn("caches.keys()", worker)
            self.assertIn("self.clients.claim()", worker)
            # navigate() reloaded open tabs and downloaded the game twice.
            self.assertNotIn(".navigate(", worker)

    def test_shell_fills_screen_and_gates_fullscreen(self):
        with TemporaryDirectory() as folder:
            root = Path(folder)
            html = root / "index.html"
            html.write_text(GODOT_SHELL, encoding="utf-8")
            patch(html)
            patched = html.read_text(encoding="utf-8")
            self.assertIn("width:100%!important;height:100%!important", patched)
            self.assertNotIn("--wf-canvas-width", patched, "the 16:9 letterbox box is gone")
            self.assertIn("worldFightRotateGate", patched)
            self.assertIn("worldFightFullscreenGate", patched)
            self.assertIn("TAP TO FIGHT", patched)
            self.assertIn("fullscreenchange", patched)
            self.assertIn("worldFightPauseRequest", patched)
            self.assertIn("screen.orientation?.lock?.('landscape')", patched)
            self.assertIn("worldFightSetReady", patched)
            self.assertIn("rotate-device-ensemble.webp", patched)
            self.assertTrue((root / "rotate-device-ensemble.webp").is_file())
            # Branded loading screen mirrors Godot's progress and offers retry.
            self.assertIn("#status{display:none!important}", patched)
            self.assertIn("status-progress", patched)
            self.assertIn("wf-retry", patched)
            self.assertIn("חיבור איטי", patched)
            self.assertIn("params.has('diag')", patched)
            self.assertIn("worldFightSafeArea", patched)
            self.assertIn("safe-area-inset-left", patched)
            self.assertIn("worldFightHeartbeat", patched)
            self.assertIn("webglcontextlost", patched)
            self.assertIn("worldFightGraphicsReset", patched)
            # The loading bomb keeps its native 1712:1232 canvas inside a
            # full-bleed, blurred cover background.  Do not stretch the
            # foreground artwork to the viewport: that would turn its circular
            # percentage gauge into an oval on phones and ultrawide displays.
            self.assertIn("#world-fight-startup::before", patched)
            self.assertIn("center/cover no-repeat", patched)
            self.assertIn("aspect-ratio:1712/1232", patched)
            self.assertIn("center/100% 100% no-repeat", patched)
            # The diagnostics GPU probe must run once and release its context.
            self.assertEqual(patched.count("getContext('webgl2')"), 1)
            self.assertIn("loseContext()", patched)
            self.assertNotIn('data-action="quick"', patched)
            self.assertLess(
                patched.index('<div id="world-fight-startup"'),
                patched.index('<script src="index.js">'),
                "startup shell must parse before the blocking engine loader",
            )
            self.assertLess(
                patched.index("window.initializeWorldFightShell()</script>"),
                patched.index('<script src="index.js">'),
            )

    def test_ios_home_screen_web_app_metadata_is_emitted(self):
        with TemporaryDirectory() as folder:
            root = Path(folder)
            html = root / "index.html"
            html.write_text(GODOT_SHELL, encoding="utf-8")
            patch(html)

            patched = html.read_text(encoding="utf-8")
            manifest_path = root / "manifest.webmanifest"
            self.assertIn('<link rel="manifest" href="manifest.webmanifest">', patched)
            self.assertIn('<link rel="apple-touch-icon" href="index.apple-touch-icon.png">', patched)
            self.assertTrue(manifest_path.is_file())

            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            self.assertEqual(manifest["display"], "fullscreen")
            self.assertEqual(manifest["display_override"], ["fullscreen", "standalone"])
            self.assertEqual(manifest["orientation"], "landscape")
            self.assertEqual(manifest["start_url"], "./")
            self.assertEqual(manifest["scope"], "./")

    def test_ios_safari_gets_home_screen_guidance_without_changing_android_flow(self):
        with TemporaryDirectory() as folder:
            root = Path(folder)
            html = root / "index.html"
            html.write_text(GODOT_SHELL, encoding="utf-8")
            patch(html)

            patched = html.read_text(encoding="utf-8")
            self.assertIn("worldFightIosInstallHint", patched)
            self.assertIn("navigator.standalone", patched)
            self.assertIn("params.get('qa') === 'ios-install'", patched)
            self.assertIn("Add to Home Screen", patched)
            self.assertIn("נעילת סיבוב", patched)
            self.assertIn("fullscreenSupported()", patched)
            self.assertIn("screen.orientation?.lock?.('landscape')", patched)

    def test_ios_safari_landscape_gets_install_gate(self):
        # iPhone Safari has no element-fullscreen API, so the TAP TO FIGHT gate
        # never shows there. Landscape players must still learn the Home Screen
        # route, and one tap must always let them play in the Safari tab.
        with TemporaryDirectory() as folder:
            root = Path(folder)
            html = root / "index.html"
            html.write_text(GODOT_SHELL, encoding="utf-8")
            patch(html)

            patched = html.read_text(encoding="utf-8")
            self.assertIn('id="worldFightIosGate"', patched)
            self.assertIn(".wf-needs-ios-install #worldFightIosGate{display:flex}", patched)
            self.assertIn(".wf-legal-open #worldFightIosGate{display:none!important}", patched)
            self.assertIn("wf-needs-ios-install", patched)
            self.assertIn("!fullscreenSupported()", patched)
            self.assertIn("worldFightIosPlayButton", patched)
            self.assertIn("הוספה למסך הבית", patched)
            self.assertIn("sessionStorage", patched)
            self.assertLess(
                patched.index('id="worldFightIosGate"'),
                patched.index('<script src="index.js">'),
            )

    def test_patching_replaces_old_and_repeated_shells(self):
        with TemporaryDirectory() as folder:
            root = Path(folder)
            html = root / "index.html"
            legacy = GODOT_SHELL.replace(
                "</head>",
                '<script id="world-fight-responsive-script">window.oldShell=1</script></head>',
            ).replace(
                "<body>",
                '<body><div id="world-fight-startup"><div class="wf-loading">LOADING GAME…</div></div><script>window.initializeWorldFightShell()</script>',
            )
            html.write_text(legacy, encoding="utf-8")
            patch(html)
            patch(html)
            patched = html.read_text(encoding="utf-8")
            self.assertNotIn("window.oldShell", patched)
            self.assertEqual(patched.count('id="world-fight-responsive-script"'), 1)
            self.assertEqual(patched.count('id="world-fight-startup"'), 1)
            self.assertEqual(patched.count("window.initializeWorldFightShell()</script>"), 1)
            self.assertIn("window.initializeWorldFightShell = ", patched)


if __name__ == "__main__":
    unittest.main()
