import json
import re
import unittest
from pathlib import Path

from main import CONFIG, PLACE_COUNT, get_recommendations


ROOT = Path(__file__).resolve().parent


class RecommendationPageTests(unittest.TestCase):
    def test_returns_exactly_ten_unique_source_places(self):
        places = json.loads((ROOT / "places.json").read_text(encoding="utf-8"))
        recommendations = get_recommendations()

        self.assertEqual(len(places), PLACE_COUNT)
        self.assertEqual(len(recommendations), PLACE_COUNT)
        self.assertEqual(len({place["id"] for place in recommendations}), PLACE_COUNT)
        self.assertTrue(all(place["source_url"].startswith("http") for place in recommendations))
        self.assertTrue(all(place["distance_m"] <= CONFIG["service_radius_m"] for place in recommendations))

    def test_page_title_and_heading_are_exact(self):
        page = (ROOT / "index.html").read_text(encoding="utf-8")

        self.assertRegex(page, r"<title>안녕하세요 장승운</title>")
        self.assertRegex(page, r"<h1>안녕하세요 장승운</h1>")


if __name__ == "__main__":
    unittest.main()
