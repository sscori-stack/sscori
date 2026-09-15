extends PlaceholderSprite
## 먼 섬 + 등대. 패럴랙스가 가장 작고, 오토파일럿 중에는 몇 분에 걸쳐 아주 미세하게 확대(전진 연출).

## heading = ±1 일 때 좌우 최대 픽셀. 등대가 화면 밖으로 나가지 않는 상한 역할.
@export var parallax_px: float = 30.0
## 오토파일럿 확대 속도(배율/초). 0.0003 ≒ 1분에 1.8%.
@export var autopilot_zoom_per_second: float = 0.0003
## 확대 상한. 도달 후 리셋 없이 유지.
@export var autopilot_zoom_max: float = 1.12

var _base_position: Vector2
var _base_scale: Vector2
var _zoom: float = 1.0


func _ready() -> void:
	super()
	_base_position = position
	_base_scale = scale


func _process(delta: float) -> void:
	var main := SailingMain.instance
	var heading := 0.0
	if main != null:
		heading = main.heading
		if main.autopilot_active:
			_zoom = minf(_zoom + autopilot_zoom_per_second * delta, autopilot_zoom_max)
	position.x = _base_position.x - heading * parallax_px
	scale = _base_scale * _zoom
