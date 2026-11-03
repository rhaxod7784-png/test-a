# 안녕하세요 장승운

성심당 본점 주변의 실제 장소 10곳을 보여주는 작은 모바일 대응 웹 페이지입니다.

## 실행

Python 표준 라이브러리만 사용합니다.

```powershell
python main.py
```

브라우저에서 `http://localhost:8000`을 엽니다. Azure App Service 같은 기존 Python 호스트에서는 `PORT` 환경 변수를 사용합니다.

## 출처와 범위

- 원본 저장소: <https://github.com/rhaxod7784-png/sungsim>
- 읽기 전용 원본 스냅샷: `codex/theme2-connected-20261102` 브랜치, 커밋 [`abffc925533e8ee70e9235e3c628c3f10ffae111`](https://github.com/rhaxod7784-png/sungsim/tree/abffc925533e8ee70e9235e3c628c3f10ffae111)
- 추천 규칙 모듈: [`daejeon-mvp/app/recommend.py`](https://github.com/rhaxod7784-png/sungsim/blob/abffc925533e8ee70e9235e3c628c3f10ffae111/daejeon-mvp/app/recommend.py), 현재 스냅샷에서 재사용
- 장소 데이터: `daejeon-mvp/static/worker-data/places.json`에서 활성·비프랜차이즈 항목 10개를 골라 `places.json`에 필요한 공개 필드와 출처 URL만 복사했습니다.
- 원본 ID: `1325`, `1324`, `1154`, `1771`, `1847`, `441`, `77`, `95`, `413`, `2`
- `places.json`의 각 항목에는 원본 데이터의 `story_source` 중 첫 URL을 `source_url`로 보존했습니다. 설명과 좌표는 선택된 원본 데이터에서 그대로 가져왔습니다.
- 추천은 원본의 500m 시작 반경과 장소 활성·프랜차이즈 판정 규칙을 사용합니다. 표기 거리는 성심당 본점 좌표 기준 직선거리이며 도보 경로가 아닙니다.

원본 저장소는 읽기만 했으며 변경하지 않았습니다.

배포 대상 URL: <https://test-a-jangseungun-20261103.azurewebsites.net>

## Azure App Service 무료 배포

`deploy-azure.ps1`은 리소스 그룹 `rg-test-a-20261103`의 Korea Central Linux F1 플랜 `test-a-free-20261103`과 Python 3.12 웹 앱 `test-a-jangseungun-20261103`을 만들거나, 동일한 설정으로 이미 존재하는 리소스를 재사용합니다. 플랜과 앱은 리소스 목록 대신 ARM `2023-12-01` 리소스 GET으로 확인합니다. 플랜은 `sku.name=F1`, `sku.tier=Free`, `properties.reserved=true`, Linux `kind`를 검증하며, 지역명은 공백과 대소문자를 정규화해 비교합니다. 플랜이 무료 F1/Linux가 아니면 즉시 중단하며 유료 SKU로 전환하지 않습니다. 앱의 시작 명령은 `python main.py`, `PORT`는 `8000`입니다.

Azure CLI 로그인이 완료된 PowerShell에서 실행합니다.

```powershell
& .\deploy-azure.ps1
```

CLI 실행 파일 경로를 바꾸려면 전체 경로를 전달합니다.

```powershell
& .\deploy-azure.ps1 -AzCliPath 'C:\path\to\az.cmd'
```

스크립트는 `main.py`, `recommend.py`, `places.json`, `index.html`, `app.js`, `styles.css`만 ZIP에 넣어 배포하고, 배포 후 HTTPS 페이지의 정확한 제목·큰 문구와 `/api/places`의 10개 항목을 확인합니다. F1 할당량이나 정책이 배포를 막으면 오류로 중단하며 유료 플랜을 생성하지 않습니다.
