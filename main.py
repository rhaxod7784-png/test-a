import json
import os
import random
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit

from recommend import RecommendationService


ROOT = Path(__file__).resolve().parent
PLACE_COUNT = 10
CONFIG = {
    "anchor_lat": 36.327744,
    "anchor_lon": 127.427246,
    "service_radius_m": 500,
    "initial_search_radius_m": 500,
    "max_search_radius_m": 500,
    "search_step_m": 500,
}
CATEGORY_LABELS = {1: "맛집", 2: "카페", 3: "산책·문화", 4: "체험"}
STATIC_FILES = {
    "/": ("index.html", "text/html; charset=utf-8"),
    "/index.html": ("index.html", "text/html; charset=utf-8"),
    "/styles.css": ("styles.css", "text/css; charset=utf-8"),
    "/app.js": ("app.js", "text/javascript; charset=utf-8"),
}


def get_recommendations():
    places = json.loads((ROOT / "places.json").read_text(encoding="utf-8"))
    selected = RecommendationService.recommend(
        places,
        CONFIG,
        CONFIG["anchor_lat"],
        CONFIG["anchor_lon"],
        band=0,
        rng=random.Random(42),
    )
    if len(selected) != PLACE_COUNT or len({place["place_id"] for place in selected}) != PLACE_COUNT:
        raise ValueError(f"Expected {PLACE_COUNT} unique recommendations, got {len(selected)}")

    return [
        {
            "id": place["place_id"],
            "name": place["place_name"],
            "category": CATEGORY_LABELS.get(place["category_id"], "장소"),
            "address": place["address"],
            "story": place["one_line_story"],
            "distance_m": place["distance_m"],
            "source_url": place["source_url"],
        }
        for place in selected
    ]


class RequestHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        path = urlsplit(self.path).path
        if path == "/api/places":
            try:
                body = json.dumps(get_recommendations(), ensure_ascii=False).encode("utf-8")
            except (OSError, ValueError, KeyError) as error:
                self.log_error("Could not build recommendations: %s", error)
                self.send_error(500, "추천 장소 데이터를 불러오지 못했습니다.")
                return
            self.respond(body, "application/json; charset=utf-8")
            return

        static_file = STATIC_FILES.get(path)
        if static_file is None:
            self.send_error(404)
            return
        filename, content_type = static_file
        self.respond((ROOT / filename).read_bytes(), content_type)

    def respond(self, body, content_type):
        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("X-Content-Type-Options", "nosniff")
        self.end_headers()
        self.wfile.write(body)


if __name__ == "__main__":
    port = int(os.environ.get("PORT", "8000"))
    server = ThreadingHTTPServer(("0.0.0.0", port), RequestHandler)
    print(f"Serving on http://127.0.0.1:{port}")
    server.serve_forever()
