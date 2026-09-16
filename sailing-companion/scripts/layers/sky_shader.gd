extends ColorRect
## 절차적 셀셰이딩 하늘(shaders/sky2d.gdshader). 구름 스크롤·풍속·태양 위치·시간대를 넘긴다.
## 시간대: 실제 시각으로 낮/노을/밤을 부드럽게 보간(설정에서 고정 가능).

@export var sun_screen_x: float = 0.5
## 수평선 기준 태양 높이(0~1, 이 Rect 안에서).
@export var sun_screen_y: float = 0.9
## true 면 실제 시각에 따라 낮/노을/밤이 바뀐다. false 면 항상 노을.
@export var follow_real_time: bool = false
@export var cloud_scroll_speed: float = 0.012

var _t: float = 0.0
var _scroll: float = 0.0
var _mat: ShaderMaterial
var _night: float = 0.0
var _day: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/sky2d.gdshader")
	material = _mat
	var w := _targets()
	_night = w[0]
	_day = w[1]


func _process(delta: float) -> void:
	_t += delta
	if _mat == null:
		return
	var wind_speed := 10.0
	if Voyage.wind != null:
		wind_speed = Voyage.wind.speed
	var wind_norm := clampf((wind_speed - 5.0) / 20.0, 0.0, 1.0)
	# 구름 스크롤: 풍속과 조타(heading)에 따라
	var heading := SailingMain.instance.heading if SailingMain.instance else 0.0
	_scroll += delta * cloud_scroll_speed * (0.5 + wind_norm * 1.5) + heading * delta * 0.05
	var targets := _targets()
	_night = lerpf(_night, targets[0], minf(1.0, delta * 0.05))
	_day = lerpf(_day, targets[1], minf(1.0, delta * 0.05))
	_mat.set_shader_parameter("time", _t)
	_mat.set_shader_parameter("wind_norm", wind_norm)
	_mat.set_shader_parameter("scroll", _scroll)
	_mat.set_shader_parameter("sun_x", sun_screen_x)
	_mat.set_shader_parameter("sun_y", sun_screen_y)
	_mat.set_shader_parameter("night", _night)
	_mat.set_shader_parameter("day", _day)


## [night, day] 가중치. 06~09 새벽→낮, 09~16 낮, 16~20 노을, 20~06 밤.
func _targets() -> Array:
	if not follow_real_time:
		return [0.0, 0.0]
	var t: Dictionary = Time.get_datetime_dict_from_system()
	var h := float(t["hour"]) + float(t["minute"]) / 60.0
	if h >= 9.0 and h < 16.0:
		return [0.0, 1.0]
	if h >= 16.0 and h < 18.5:
		return [0.0, clampf((18.5 - h) / 2.5, 0.0, 1.0)]
	if h >= 18.5 and h < 20.5:
		return [clampf((h - 18.5) / 2.0, 0.0, 1.0), 0.0]
	if h >= 20.5 or h < 5.0:
		return [1.0, 0.0]
	if h >= 5.0 and h < 7.0:
		return [clampf((7.0 - h) / 2.0, 0.0, 1.0), 0.0]
	return [0.0, clampf((h - 7.0) / 2.0, 0.0, 1.0)]


## 밤 가중치(별 표시 등 외부에서 참조).
func night_weight() -> float:
	return _night
