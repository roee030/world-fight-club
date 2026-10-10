from pathlib import Path
from tempfile import TemporaryDirectory
import unittest

from tools.patch_web_export import DISCLAIMER_VERSION, analytics_script, load_site_config, patch


SHELL = """<html><head></head><body><canvas id="canvas"></canvas>
<div id="status"><progress id="status-progress"></progress><div id="status-notice"></div></div>
<script src="index.js"></script></body></html>"""


def _patched(config: dict) -> str:
    with TemporaryDirectory() as folder:
        html = Path(folder) / "index.html"
        html.write_text(SHELL, encoding="utf-8")
        patch(html, config)
        return html.read_text(encoding="utf-8")


class LegalGateTests(unittest.TestCase):
    def test_disclaimer_blocks_entry_until_checked(self):
        page = _patched({"goatcounter_code": "", "linkedin_url": ""})
        self.assertIn('id="worldFightDisclaimer"', page)
        self.assertIn('role="dialog"', page)
        self.assertIn('id="worldFightDisclaimerCheck" type="checkbox"', page)
        self.assertIn('id="worldFightDisclaimerAccept" type="button" disabled', page)
        self.assertIn("accept.disabled = !check.checked", page)
        self.assertIn(DISCLAIMER_VERSION, page)
        # Hebrew first, with the key protections spelled out.
        # The owner's exact lead sentence, then the supporting points.
        self.assertIn("המשחק הוא סאטירה בלבד, כל קשר בין הדמויות למציאות הוא מקרי בהחלט, ואין בו שום קריאה או עידוד לאלימות בעולם האמיתי.", page)
        for phrase in ("קריקטורות פרודיות", "אינו קשור", "בחינם לחלוטין", "ללא מטרת רווח", "אנונימיים"):
            self.assertIn(phrase, page)
        self.assertIn("not affiliated", page)
        self.assertIn("purely coincidental", page)
        self.assertIn(".wf-legal-open #worldFightFullscreenGate{display:none!important}", page)
        self.assertIn("if (!root.classList.contains('wf-legal-open')) root.classList.add('wf-legal-open');", page)
        # Settings > LEGAL reopens the notice with the box unticked again.
        self.assertIn("window.worldFightShowDisclaimer = open;", page)
        self.assertIn("window.addEventListener(name, guard, { capture: true, passive: false })", page)
        self.assertIn("canvas.setAttribute('inert', '')", page)
        # Keyboard users can Tab into the notice, with a visible focus ring.
        self.assertIn("event.key === 'Tab'", page)
        self.assertIn("#worldFightDisclaimer :focus-visible{outline:3px solid #f2c35a", page)
        self.assertIn("setInterval(lock, 300)", page)
        self.assertIn("check.checked = false;", page)
        # The in-game FULL button reopens the iPhone Home Screen guide.
        self.assertIn("window.worldFightShowIosInstall = () => {", page)
        # The gate is parsed before the engine loader starts.
        self.assertLess(page.index('id="worldFightDisclaimer"'), page.index('<script src="index.js">'))


class AnalyticsTests(unittest.TestCase):
    def test_no_code_means_no_third_party_script(self):
        page = _patched({"goatcounter_code": "", "linkedin_url": ""})
        self.assertIn("window.worldFightTrack = ", page)
        self.assertIn("const code = ''", page)

    def test_code_enables_goatcounter_and_is_sanitized(self):
        script = analytics_script("World-Fight\"><script>")
        self.assertIn("const code = 'world-fightscript'", script)
        page = _patched({"goatcounter_code": "worldfight", "linkedin_url": ""})
        self.assertIn("const code = 'worldfight'", page)
        self.assertIn("https://gc.zgo.at/count.js", page)
        # Readable per-dimension paths, an early-event queue and play-time milestones.
        self.assertIn("(props && props.path) || ('event/' + name)", page)
        self.assertIn("queue.push(entry)", page)
        self.assertIn("tag.addEventListener('load'", page)
        self.assertIn("'playtime/'", page)
        self.assertIn("document.visibilityState !== 'visible'", page)
        self.assertIn("path: 'disclaimer/accepted'", page)
        # Exit point: reported once when the page is hidden or closed.
        self.assertIn("'leave/' + where()", page)
        self.assertIn("addEventListener('pagehide'", page)
        self.assertIn("worldFightPauseRequest?.(hidden ? 'hidden' : 'visible')", page)

    def test_site_config_enables_owner_analytics_and_profile(self):
        config = load_site_config()
        self.assertEqual(set(config), {"goatcounter_code", "linkedin_url", "site_url"})
        self.assertEqual(config["goatcounter_code"], "roeeangel")
        self.assertTrue(config["linkedin_url"].startswith("https://www.linkedin.com/in/"))


if __name__ == "__main__":
    unittest.main()
