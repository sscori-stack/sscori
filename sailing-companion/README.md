# Sailing Companion (Godot 4 MVP)

바탕화면 한구석에 띄워두는 방치형 힐링 세일링 컴패니언. 고양이 선장과 해달이 **실제 지중해 마리나 사이를 실제 바람을 타고** 항해합니다.
오토파일럿의 실체는 고양이 선장입니다. 선장이 헬름과 윈치를 느긋하게 오가며 휠을 돌리고 줄을 당겨야 배가 움직입니다.

- 엔진: **Godot 4.3** (GL Compatibility 렌더러), GDScript
- 창: 450×280, 보더리스, 항상 위, 크기 고정, 첫 실행 시 주 모니터 우측 하단(16px 여백)
- 저장: `user://settings.cfg`(창 위치·볼륨·설정), `user://voyage.cfg`(항해 진행 상태, 30초마다)
  (Windows: `%APPDATA%\Godot\app_userdata\Sailing Companion\`)

## 실행

1. Godot 4.3 에디터에서 이 폴더(`project.godot`)를 가져오기(Import) → 열기.
2. F5(메인 씬 실행). 에셋이 없어도 색상 도형 플레이스홀더로 동작합니다.

## 조작

| 입력 | 동작 |
|---|---|
| 배경 **우클릭 드래그** | 창 이동 (위치 자동 저장) |
| 조타 휠 **좌클릭 드래그** | 직접 조타(±90°). 잡고 있는 동안 선장은 윈치에서 돛만 맡는다. 손을 떼면 휠이 중립으로 돌아가고 10초 뒤 선장이 헬름을 되찾는다 |
| 돛 위 **좌우 드래그** / **마우스 휠** | 돛 각도(시트) / 펼침(0.4~1.0). 만지는 동안 선장은 헬름에서 조타만 맡는다 |
| 해도 버튼(바 왼쪽 세 번째) | 접이식 해도: 항로·현재 위치·항적·바람·축척·진행률 |
| ⚙ 버튼 | 설정: 파도/음악 볼륨, BGM, 실제 바람(온라인), 구간 선택 → 출항, 종료 |
| 뽀모도로 클릭 / 길게 누름 | 시작·일시정지 / 리셋. 종료 시 종소리 + 반짝임 |
| ▼ 버튼 | BGM on/off |

## 항해 시스템

- **마리나·구간**: 서지중해 8곳(모나코·앙티브·생트로페·포르토피노·칼비·마르세유·팔마·이비사). 육지를 피하도록 미리 정의한 구간 9개(양방향)와 웨이포인트. 도착하면 5분 정박 후 연결된 다음 구간으로 자동 출항. `scripts/voyage/marinas.gd`
- **압축 시간**: 구간이 실시간 약 1시간에 끝나도록 `time_scale = 거리(nm) ÷ 6`. 바람은 실시간, 배 이동만 압축.
- **바람**: 켜져 있으면 [Open-Meteo](https://open-meteo.com)에서 현재 배 위치의 풍향·풍속·거스트를 30분마다 받습니다(무료, 키 불필요). 실패하거나 끄면 해역별 월별 계절풍 표로 대체. 풍속은 **5~25노트로 보정**해 무풍에도 배가 움직입니다. 2~5분마다 20~40초 거스트(풍속 +30~60%, 풍향 ±15°).
- **세일링 모델** (`sailing_sim.gd`): 진풍각별 속도 계수(맞바람 40° 이내 불가), 돛 각도·펼침에 따른 효율과 힐, 자동 태킹(횡이탈 상한, 히스테리시스), 서브스텝으로 저FPS 안정화.
- **선장 AI** (`captain_controller.gd`): 돛이 목표에서 10° 이상 어긋나면 윈치로 걸어가 세 번에 나눠 줄을 당기고, 헬름에서는 목표 방위로 천천히 휠을 잡습니다. 45~120초마다 바다 보기·해달 쓰다듬기·기지개. 정박 중엔 돛을 접습니다.
- **바람 표현**: 마스트 윈덱스, 슈라우드 리본, 돛 형상(각도→폭, 펼침→높이, 붐 방향 반전, 트림 불량·거스트 펄럭임), 힐, 파도 진폭, 구름 속도·방향, 바다 색, 파도 소리. HUD: 항해 라벨, 나침반 띠, 풍향/풍속 위젯(거스트 맥동).

Windows 방화벽이 최초 네트워크 접근을 물어볼 수 있습니다. 거부해도 계절풍 폴백으로 동작합니다.

## 에셋 교체 (코드 수정 없음)

`assets/art/` 에 아래 이름의 **투명 배경 PNG**(창 2배 해상도, 900×560 캔버스 기준)를 넣으면 다음 실행부터 자동 교체됩니다.
에디터가 열려 있으면 파일 시스템 독에서 자동 임포트되며, 임포트 기본값(mipmaps off, filter linear)이 프로젝트 설정에 맞춰져 있습니다.

| 파일 | 내용 | 기준점(pivot) |
|---|---|---|
| `sky.png` | 노을 하늘(불투명, 900×560) | 좌상단 |
| `clouds_far.png`, `clouds_near.png` | 구름 띠, 좌우 타일링(양끝 연결) | 좌상단 |
| `horizon.png` | 먼 섬 + 등대 실루엣(폭 900 이상, 높이 ~120) | 하단 중앙 (수평선 y=152) |
| `sea.png` | 바다(폭 1000 이상) | 상단 중앙 (수평선 y=150) |
| `sail.png` | 돛 + 마스트(부풀어 있는 상태, 붐은 오른쪽으로) | 하단 중앙 (마스트 밑동). 코드가 각도·펼침에 따라 폭/높이/좌우를 바꿈 |
| `deck.png` | 갑판 + 로프 + 나침반 | 하단 중앙 |
| `winch.png` | 윈치/시트 클리트(선장이 줄을 당기는 자리) | 하단 중앙 |
| `otter.png` | 잠든 해달 | 하단 중앙 (호흡 피벗) |
| `captain.png` | 앉아서 바다를 보는 고양이 선장(기본/idle) | 하단 중앙 (호흡 피벗) |
| `captain_walk.png`, `captain_pull.png`, `captain_steer.png`, `captain_pet.png`, `captain_stretch.png` | 포즈별(선택). 없으면 idle 을 그대로 씀 | 하단 중앙 |
| `wheel.png` | 조타 휠(정중앙이 회전축) | 중앙 |
| `windex.png` | 마스트 꼭대기 풍향 화살표(위쪽이 화살촉) | 중앙 |
| `cockpit.png` | 하단 난간/콕핏 프레임 | 하단 중앙 |
| `chart_bg.png` | 해도 인셋 배경(400×260, 양피지 느낌) | – |
| `ui_btn_settings.png`, `ui_btn_share.png`, `ui_btn_chart.png` | 하단 바 버튼 아이콘 | – |

각 노드의 위치/크기/색은 `scenes/main.tscn` 인스펙터에서 조정할 수 있습니다(`texture_path`, `pivot_normalized`, `placeholder_*`).
선장의 자리(헬름/윈치/해달)는 `Boat/Crew` 노드의 `helm_spot`, `winch_spot`, `otter_spot` 으로 조정합니다.

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

## 헤드리스 테스트 / 스크린샷

```
# 세일링 시뮬레이션·항법·바람·저장 (50개 검사)
godot --headless --path sailing-companion res://tests/sim_test.tscn
# 씬 전체 스모크: 흔들림·조타·창 드래그·UI·선장 행동·해도 (41개 검사)
godot --headless --path sailing-companion res://tests/smoke_test.tscn
# 화면 캡처(리눅스, Xvfb): 지정 프레임의 화면을 PNG 로
xvfb-run -a godot --path sailing-companion --rendering-driver opengl3 res://tests/screenshot.tscn -- out=/tmp/shot.png frames=300 chart=1
```

## 구조

```
scenes/main.tscn            루트 씬(레이어 → Boat(돛·윈덱스·리본·선장·해달·휠·Crew) → UI(HUD·해도·바))
scripts/main.gd             창 관리, 우클릭 드래그, FPS(30/15), 플레이어 개입 플래그, 휠↔타각 연결
scripts/autoload/           Settings, AudioManager, Voyage(항해 상태·정박·저장), WindService(Open-Meteo)
scripts/voyage/             Marinas(데이터), WindModel(거스트·보정), SailingSim(폴라·항법·태킹)
scripts/layers/             PlaceholderSprite(에셋 or 도형), 구름 스크롤, 바다, 수평선
scripts/boat/               Boat 흔들림·힐, 호흡, 돛, 윈덱스, 텔테일, 조타 휠, 선장 스프라이트, CaptainController
scripts/ui/                 테마, 아이콘 버튼, 시계, 뽀모도로, 음악 위젯, 설정 팝업, HUD 위젯, 해도 인셋
tests/                      sim_test, smoke_test, screenshot
```

## 저사양 동작

- `OS.low_processor_usage_mode = true`, 포커스/마우스오버 시 30 FPS, 그 외 15 FPS
- 모든 모션은 경과 시간 기반 sin/cos 합성(파티클·셰이더·물리 서버 없음)
- 네트워크 요청은 30분에 한 번(실패 시 5분 후 재시도)
