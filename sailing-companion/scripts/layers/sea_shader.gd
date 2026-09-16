extends ColorRect
## 절차적 셀셰이딩 바다(shaders/sea2d.gdshader). 풍속·풍향·거스트·선속·태양 위치를 셰이더에 넘긴다.
## 화면보다 넉넉하게 그려서 World 가 기울어도 여백이 생기지 않는다.

@export var sun_screen_x: float = 0.5
## 파도 흐름 방향을 결정할 때 진풍각을 쓰는 세기.
@export var lateral_gain: float = 1.0

var _t: float = 0.0
var _mat: ShaderMaterial
var _wind_norm: float = 0.3
var _lateral: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/sea2d.gdshader")
	material = _mat


func _process(delta: float) -> void:
	_t += delta
	if _mat == null:
		return
	var wind_speed := 10.0
	var gust := 0.0
	var twa := 0.0
	var sog := 0.0
	if Voyage.wind != null:
		wind_speed = Voyage.wind.speed
		gust = Voyage.wind.gust_intensity
	if Voyage.sim != null:
		twa = Voyage.sim.true_wind_angle()
		sog = Voyage.sim.speed_kn
	var target_norm := clampf((wind_speed - 5.0) / 20.0, 0.0, 1.0)
	_wind_norm = lerpf(_wind_norm, target_norm, minf(1.0, delta * 0.5))
	# 바람이 우현(TWA>0)에서 오면 파도는 좌현 쪽으로 흐른다
	var target_lat := clampf(-sin(deg_to_rad(twa)) * lateral_gain, -1.0, 1.0)
	_lateral = lerpf(_lateral, target_lat, minf(1.0, delta * 0.4))
	_mat.set_shader_parameter("time", _t)
	_mat.set_shader_parameter("wind_norm", _wind_norm)
	_mat.set_shader_parameter("wind_dir_x", _lateral)
	_mat.set_shader_parameter("gust", gust)
	_mat.set_shader_parameter("speed_norm", clampf(sog / 6.0, 0.0, 2.0))
	_mat.set_shader_parameter("sun_x", sun_screen_x)
