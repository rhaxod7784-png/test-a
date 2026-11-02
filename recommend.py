"""Pure recommendation rules. Distances are WGS84 great-circle metres."""
import math
import random


class RecommendationService:
    """거리 계산, 추천 대상 판정, 추첨, 위치 격자를 관리한다."""

    CATEGORY_NAMES = {1: "음식점", 2: "카페", 3: "산책길", 4: "액티비티"}

    @staticmethod
    def distance(lat1, lon1, lat2, lon2):
        a, b = math.radians(lat1), math.radians(lat2)
        h = (math.sin((b - a) / 2) ** 2
             + math.cos(a) * math.cos(b) * math.sin(math.radians(lon2 - lon1) / 2) ** 2)
        return 6371000 * 2 * math.asin(min(1, math.sqrt(h)))

    @staticmethod
    def eligible(place, config):
        """폐업은 제외하되 오늘 영업 종료 시간은 필터로 쓰지 않는다."""
        if not place["is_active"]:
            return False
        if config.get("exclude_franchises", True) and place.get("is_franchise", False):
            if not (config.get("allow_local_franchises", True) and place.get("is_local_franchise", False)):
                return False
        return RecommendationService.distance(
            config["anchor_lat"],
            config["anchor_lon"],
            place["latitude"],
            place["longitude"],
        ) <= (config.get("service_radius_m") or math.inf)

    @staticmethod
    def category_name(category_id, fallback=None):
        return RecommendationService.CATEGORY_NAMES.get(category_id, fallback)

    @staticmethod
    def search_bounds(config, band):
        step = config["search_step_m"]
        max_radius = config.get("max_search_radius_m") or config.get("service_radius_m") or math.inf
        initial_radius = min(config.get("initial_search_radius_m", step), max_radius)
        if band == 0:
            return 0, initial_radius
        lower = initial_radius + (band - 1) * step
        return lower, min(lower + step, max_radius)

    @staticmethod
    def recommend(places, config, lat, lon, band, rng=None, category_id=None):
        rng = rng or random.SystemRandom()
        low, high = RecommendationService.search_bounds(config, band)
        candidates = []
        for place in places:
            if not RecommendationService.eligible(place, config):
                continue
            distance_m = RecommendationService.distance(
                lat, lon, place["latitude"], place["longitude"]
            )
            if (distance_m >= 0 if low == 0 else distance_m > low) and distance_m <= high:
                candidates.append({
                    **place,
                    "category_name": RecommendationService.category_name(
                        place["category_id"], place.get("category_name")
                    ),
                    "distance_m": round(distance_m, 1),
                })
        if category_id is not None:
            group = [place for place in candidates if place["category_id"] == category_id]
            return rng.sample(group, min(10, len(group)))

        selected = []
        for category, count in ((1, 3), (2, 3), (3, 4)):
            group = [place for place in candidates if place["category_id"] == category]
            selected.extend(rng.sample(group, min(count, len(group))))
        selected_ids = {place["place_id"] for place in selected}
        remaining = [place for place in candidates if place["place_id"] not in selected_ids]
        selected.extend(rng.sample(remaining, min(10 - len(selected), len(remaining))))
        rng.shuffle(selected)
        return selected

    @staticmethod
    def grid_cell(lat, lon, config):
        """100m local grid anchored on theme centre; raw GPS is never persisted."""
        north = math.radians(lat - config["anchor_lat"]) * 6371000
        east = (math.radians(lon - config["anchor_lon"]) * 6371000
                * math.cos(math.radians(config["anchor_lat"])))
        size = config.get("grid_size_m", 100)
        return f"{math.floor(east / size)}:{math.floor(north / size)}"


distance = RecommendationService.distance
eligible = RecommendationService.eligible
recommend = RecommendationService.recommend
grid_cell = RecommendationService.grid_cell
