import unittest
from unittest import mock

from tools import build_dashboard


class FetchTests(unittest.TestCase):
    def test_empty_list_is_not_an_error_and_paths_are_summed(self):
        def fake_api(path, params=None, empty_on_404=False):
            if path == "stats/hits":
                return {"hits": [{"path": "/fight/quick/bibi", "path_id": 1, "count": 4,
                                  "stats": []},
                                 {"path": "session/start/touch", "path_id": 2, "count": 9,
                                  "stats": [{"day": "2026-10-09", "daily": 9}]}], "more": False}
            return {}  # systems, browsers, ... have no rows: the real API answers 404

        with mock.patch.object(build_dashboard, "api", fake_api):
            data = build_dashboard.fetch(7)
        self.assertEqual(data["counts"], {"fight/quick/bibi": 4, "session/start/touch": 9})
        self.assertEqual(data["daily"], [("2026-10-09", 9)])
        self.assertEqual(data["systems"], [])

    def test_missing_page_is_treated_as_end_of_list(self):
        with mock.patch.object(build_dashboard, "api", lambda *a, **k: {}):
            data = build_dashboard.fetch(7)
        self.assertEqual(data["counts"], {})


if __name__ == "__main__":
    unittest.main()
