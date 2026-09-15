# Sailing Companion (Godot 4 MVP)

바탕화면 한구석에 띄워두는 방치형 힐링 세일링 컴패니언. 노을 바다 위에서 고양이 선장과 해달이 항해합니다.

- 엔진: **Godot 4.3** (GL Compatibility 렌더러), GDScript
- 창: 450×280, 보더리스, 항상 위, 크기 고정, 첫 실행 시 주 모니터 우측 하단(16px 여백)
- 설정 저장: `user://settings.cfg` (Windows: `%APPDATA%\Godot\app_userdata\Sailing Companion\`)

## 실행

1. Godot 4.3 에디터에서 이 폴더(`project.godot`)를 가져오기(Import) → 열기.
2. F5(메인 씬 실행). 에셋이 없어도 색상 도형 플레이스홀더로 동작합니다.

## 조작

| 입력 | 동작 |
|---|---|
| 배경 **우클릭 드래그** | 창 이동 (위치 자동 저장) |
| 조타 휠 **좌클릭 드래그** | 조타(±90°). 손 떼면 2~3초에 걸쳐 복귀 |
| ⚙ 버튼 | 설정 팝업(파도/음악 볼륨, BGM on/off, **종료**) |
| 뽀모도로 클릭 / 길게 누름 | 시작·일시정지 / 리셋. 종료 시 종소리 + 반짝임 |
| ▼ 버튼 | BGM on/off |
| 20초 무입력 | 오토파일럿: 등대 방향 유지 + 등대가 아주 천천히 커짐(전진 연출) |

## 에셋 교체 (코드 수정 없음)

`assets/art/` 에 아래 이름의 **투명 배경 PNG**(창 2배 해상도, 900×560 캔버스 기준)를 넣으면 다음 실행부터 자동 교체됩니다.
에디터가 열려 있으면 파일 시스템 독에서 자동 임포트되며, 임포트 기본값(mipmaps off, filter linear)이 프로젝트 설정에 맞춰져 있습니다.

| 파일 | 내용 | 기준점(pivot) |
|---|---|---|
| `sky.png` | 노을 하늘(불투명, 900×560) | 좌상단 |
| `clouds_far.png`, `clouds_near.png` | 구름 띠, 좌우 타일링(양끝 연결) | 좌상단 |
| `horizon.png` | 먼 섬 + 등대 실루엣(폭 900 이상, 높이 ~120) | 하단 중앙 (수평선 y=152) |
| `sea.png` | 바다(폭 1000 이상) | 상단 중앙 (수평선 y=150) |
| `sail.png` | 돛 + 마스트 | 하단 중앙 (마스트 밑동) |
| `deck.png` | 갑판 + 로프 + 나침반 | 하단 중앙 |
| `otter.png` | 잠든 해달 | 하단 중앙 (호흡 피벗) |
| `captain.png` | 앉은 고양이 선장 | 하단 중앙 (호흡 피벗) |
| `wheel.png` | 조타 휠(정중앙이 회전축) | 중앙 |
| `cockpit.png` | 하단 난간/콕핏 프레임 | 하단 중앙 |
| `ui_btn_settings.png`, `ui_btn_share.png` | 하단 바 버튼 아이콘 | – |

각 노드의 위치/크기/색은 `scenes/main.tscn` 인스펙터에서 조정할 수 있습니다(`texture_path`, `pivot_normalized`, `placeholder_*`).

오디오: `assets/audio/waves_loop.ogg`, `bgm_lofi.ogg`, `bell.ogg` (없으면 조용히 건너뜀).
폰트: `assets/fonts/` 에 한글 지원 폰트(.ttf/.otf) 1개를 넣으면 UI 기본 폰트로 사용됩니다. 없으면 Godot 기본 폰트(한글 미표시, 영문 라벨로 대체).

## Windows 실행 파일 빌드

1. 에디터 메뉴 **Editor → Manage Export Templates** 에서 4.3 템플릿 다운로드(최초 1회).
2. **Project → Export…** → 프리셋 `Windows Desktop`(이미 `export_presets.cfg` 에 정의됨) 선택.
3. **Export Project** → `build/SailingCompanion.exe` 생성(PCK 임베드, 단일 exe).

명령줄(에디터 없이):

```
godot --headless --path sailing-companion --export-release "Windows Desktop" build/SailingCompanion.exe
```

## 구조

```
scenes/main.tscn            루트 씬(레이어 → Boat → UI CanvasLayer)
scripts/main.gd             창 관리, 우클릭 드래그, FPS(30/15), heading/오토파일럿
scripts/autoload/           Settings(설정 파일), AudioManager(버스/루프/변조)
scripts/layers/             PlaceholderSprite(에셋 or 도형), 구름 스크롤, 바다, 수평선
scripts/boat/               Boat 흔들림, 호흡, 돛 펄럭임, 조타 휠
scripts/ui/                 테마, 아이콘 버튼, 시계, 뽀모도로, 음악 위젯, 설정 팝업
```

## 저사양 동작

- `OS.low_processor_usage_mode = true`, 포커스/마우스오버 시 30 FPS, 그 외 15 FPS
- 모든 모션은 경과 시간 기반 sin/cos 합성(파티클·셰이더 없음)
