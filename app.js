const status = document.querySelector("#status");
const placeList = document.querySelector("#places");

function createLink(label, href) {
  const link = document.createElement("a");
  link.href = href;
  link.textContent = label;
  link.target = "_blank";
  link.rel = "noopener noreferrer";
  return link;
}

function createPlaceCard(place) {
  const item = document.createElement("li");
  item.className = "place-card";

  const meta = document.createElement("div");
  meta.className = "place-meta";
  const category = document.createElement("span");
  category.textContent = place.category;
  const distance = document.createElement("span");
  distance.textContent = `직선 ${Math.round(place.distance_m)}m`;
  meta.append(category, distance);

  const name = document.createElement("h3");
  name.className = "place-name";
  name.textContent = place.name;

  const story = document.createElement("p");
  story.className = "place-story";
  story.textContent = place.story;

  const address = document.createElement("p");
  address.className = "place-address";
  address.textContent = place.address;

  const links = document.createElement("div");
  links.className = "place-links";
  const mapQuery = new URLSearchParams({ q: `${place.name} ${place.address}` });
  links.append(
    createLink("지도 보기", `https://map.kakao.com/?${mapQuery}`),
    createLink("정보 출처", place.source_url),
  );
  item.append(meta, name, story, address, links);
  return item;
}

async function loadPlaces() {
  const response = await fetch("/api/places", { cache: "no-store" });
  if (!response.ok) {
    throw new Error(`추천 장소를 불러오지 못했습니다 (${response.status}).`);
  }

  const places = await response.json();
  if (!Array.isArray(places) || places.length !== 10) {
    throw new Error("추천 장소 데이터가 정확히 10개가 아닙니다.");
  }

  placeList.replaceChildren(...places.map(createPlaceCard));
  status.textContent = `성심당 본점 주변 추천 ${places.length}곳`;
}

loadPlaces().catch((error) => {
  status.textContent = "추천 장소를 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.";
  console.error(error);
});
