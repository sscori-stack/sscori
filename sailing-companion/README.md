# Sailing Companion (Godot 4 MVP)

바탕화면 한구석에 띄워두는 방치형 힐링 세일링 컴패니언. **실제 지중해 마리나 사이를 실제 바람을 타고** 항해합니다.
화면은 요트 콕핏에서 앞을 보는 시점이며, 하늘·바다·선체·돛·휠을 모두 코드로 그립니다(그림 파일 없음).

- 엔진: **Godot 4.3 이상** (4.3 / 4.7 에서 검증, GL Compatibility 렌더러), GDScript
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
| 조타 휠 **좌클릭 드래그** | 직접 조타(±90°). 손을 떼면 휠이 중립으로 돌아가고 오토파일럿이 이어받는다 |
| 돛 위 **좌우 드래그** / **마우스 휠** | 돛 각도(시트) / 펼침(0.4~1.0) |
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

## 화면 구성 (전부 절차적, 그림 파일 없음)

콕핏 뷰 한 장면입니다. 섬·등대·캐릭터는 없고 망망대해만 있습니다.

- **하늘** (`shaders/sky2d.gdshader`): 노을 그라디언트를 단계적으로 끊고, 값 노이즈 fbm 으로 뭉게구름을 두 겹(먼 구름·가까운 구름) 2~3단 색으로 그립니다. 태양 원반과 글로우 포함. 구름은 풍속에 따라 흐릅니다.
- **바다** (`shaders/sea2d.gdshader`): 사인파 3개를 합성한 높이장을 4단 색으로 끊어 만화 물결처럼 보이게 하고, 능선에 흰 거품 선을 얹습니다. 태양 아래 세로 띠에 반사 길과 반짝임을 그립니다. 풍속·거스트·풍향·선속이 셰이더 파라미터로 실시간 반영됩니다.
- **선체** (`scripts/scene3d/hull3d.gd`): 상자·원통만 써서 코드로 만든 3D 저폴리 요트입니다. 갑판·티크 판자·현측·선수 쐐기·콕핏 바닥·양쪽 벤치·코밍·선실·해치·페데스탈·스탠션·라이프라인·펄핏·윈치를 포함합니다.
- **돛·마스트·붐** (`sail_rig.gd`): 돛은 시뮬레이션의 돛 각도만큼 마스트를 축으로 실제 회전하고(택에 따라 좌/우 전환), 펼침·트림 효율·거스트에 따라 부풀고 펄럭입니다.
- **조타 휠** (`wheel3d.gd`): 토러스·스포크·허브 3D. 입력은 2D `Boat/Wheel` 노드가 받고 3D 가 그립니다. 시작 시 3D 허브의 화면 위치·반경을 2D 노드에 알려줍니다.
- **셀셰이딩**: `shaders/toon.gdshader`(빛을 3단으로 끊고 림 라이트) + `shaders/outline.gdshader`(뒤집힌 껍질 외곽선). 3D 인데 2D 일러스트처럼 보이게 하는 부분입니다.

### 흔들림과 수평선

카메라가 배 위에 있으므로 배가 아니라 **세계(하늘·바다)가 반대로 기울고 상하로 움직입니다**(`world_view.gd`). 사각형을 화면보다 210px 넉넉히 그려서 기울어도 여백이 생기지 않습니다.

화면 수평선 위치의 **단일 기준은 3D 카메라**입니다. `Scene3D` 의 `horizon_screen_y()` 가 화각·하향각에서 수평선을 계산하고, 하늘·바다 사각형이 그 값에 맞춰 배치되므로 2D 와 3D 가 어긋나지 않습니다.

### 구도 조정용 값

| 위치 | 값 | 뜻 |
|---|---|---|
| `Scene3D` | `fov_deg` 58 | 수직 화각 |
| `Scene3D` | `pitch_deg` 9 | 카메라 하향각(크면 갑판이 더 보이고 수평선이 올라감) |
| `Scene3D` | `eye_offset`, `yaw_deg` | 눈 위치(우현 치우침)와 좌우 시선 |
| `Scene3D` | `hull_offset_z`, `mast_z`, `wheel_z` | 선체·마스트·휠의 전후 위치(m) |
| `Hull` | `deck_y` −1.62 | 눈높이에서 갑판까지(작으면 갑판이 화면을 덜 차지) |
| `SailRig` | `mast_height`, `boom_height`, `boom_length` | 돛 크기와 붐 높이(붐이 낮으면 돛이 더 보이지만 시야를 가림) |
| `World` | `sun_x`, `margin`, `parallax_px` | 태양 가로 위치, 회전 여백, 조타 패럴랙스 |
| `World/Sky` | `follow_real_time` | 켜면 실제 시각에 따라 낮·노을·밤으로 바뀜(기본 꺼짐 = 항상 노을) |

## 남은 그림 파일

`assets/art/` 에는 UI 버튼 3개(`ui_btn_settings/share/chart.png`)와 해도 배경(`chart_bg.png`)만 남았습니다. 나머지는 전부 코드가 그립니다. 이 4개는 `scripts/generate_assets.py` 로 다시 만들 수 있습니다(`GEMINI_API_KEY` 필요, 없으면 벡터 아이콘으로 대체됩니다).

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
