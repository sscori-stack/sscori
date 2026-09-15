extends WarpSprite
## 돛(격자 메시). 시뮬레이션의 돛 각도·펼침·트림 효율·거스트를 형상과 정점 변위로 표현한다.
## - 붐 쪽(바람 반대쪽)으로 좌우 반전, 시트를 당기면 폭이 좁아지고 펼침이 줄면 높이가 줄어든다
## - 바람을 받으면 돛 가운데가 부풀고(정점 x 변위), 트림 불량·거스트에는 빠르게 펄럭인다
## 플레이어 조작: 돛 위에서 좌우 드래그 = 각도, 마우스 휠 = 펼침.

@export var shape_lerp_speed: float = 1.5
@export var belly_px: float = 14.0
@export var flutter_px: float = 5.0
@export var drag_deg_per_px: float = 0.6
@export var furl_step: float = 0.05

var _base_scale: Vector2
var _vis_side: float = -1.0
var _vis_width: float = 1.0
var _vis_furl: float = 1.0
var _vis_luff: float = 0.0
var _vis_fill: float = 1.0
var _dragging: bool = false
var _last_mouse_x: float = 0.0


func _ready() -> void:
	grid_x = 8
	grid_y = 10
	super()
	_base_scale = scale


func _process(delta: float) -> void:
	super(delta)
	var k := minf(1.0, delta * shape_lerp_speed)
	var sim: SailingSim = Voyage.sim
	if sim != null:
		var twa := sim.true_wind_angle()
		var side_target := -1.0 if twa > 0.0 else 1.0
		_vis_side = lerpf(_vis_side, side_target, k)
		_vis_width = lerpf(_vis_width, 0.35 + 0.65 * sin(deg_to_rad(clampf(sim.sail_angle, 0.0, 90.0))), k)
		_vis_furl = lerpf(_vis_furl, sim.sail_furl, k)
		var eff := SailingSim.trim_efficiency(absf(twa), sim.sail_angle)
		_vis_fill = lerpf(_vis_fill, eff * clampf(Voyage.wind.speed / 12.0, 0.4, 1.3), k)
		var luff_target := (1.0 - eff) * 1.5 + Voyage.wind.gust_intensity * 0.8
		_vis_luff = lerpf(_vis_luff, luff_target, minf(1.0, delta * 3.0))
	var width := _vis_width * (0.6 + 0.4 * _vis_furl)
	var height := 0.55 + 0.45 * _vis_furl
	scale = _base_scale * Vector2(_vis_side * width, height)


func displacement(u: float, v: float, t_now: float) -> Vector2:
	# 마스트(u=0)와 아래 끝은 고정, 돛 가운데가 바람 쪽으로 부푼다. 펄럭임은 뒤쪽(u→1) 가장자리에서 크다.
	var edge := sin(u * PI) * (1.0 - v * 0.3)
	var belly := belly_px * _vis_fill * edge * (1.0 + 0.08 * sin(t_now * 1.7))
	var flutter := flutter_px * (0.15 + _vis_luff) * u * u * sin(t_now * 9.0 + v * 7.0)
	var sway := 1.5 * sin(t_now * 0.9 + v * 2.0) * u
	return Vector2(belly + flutter + sway, flutter * 0.3)


# ---------------------------------------------------------------- 플레이어 조작

func _is_mouse_over() -> bool:
	var local := to_local(get_global_mouse_position())
	return Rect2(-tex_size * pivot_normalized, tex_size).has_point(local)


func _unhandled_input(event: InputEvent) -> void:
	var sim: SailingSim = Voyage.sim
	if sim == null:
		return
	if event is InputEventMouseButton and event.pressed and _is_mouse_over():
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = true
			_last_mouse_x = get_global_mouse_position().x
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var dir := 1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0
			sim.sail_furl = clampf(sim.sail_furl + dir * furl_step, SailingSim.SAIL_FURL_MIN, SailingSim.SAIL_FURL_MAX)
			_note_player()
			get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if not _dragging:
		return
	var sim: SailingSim = Voyage.sim
	if event is InputEventMouseMotion and sim != null:
		var x := get_global_mouse_position().x
		var dx := (x - _last_mouse_x) * _vis_side
		_last_mouse_x = x
		sim.sail_angle = clampf(sim.sail_angle + dx * drag_deg_per_px, SailingSim.SAIL_ANGLE_MIN, SailingSim.SAIL_ANGLE_MAX)
		_note_player()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_dragging = false


func _note_player() -> void:
	if SailingMain.instance != null:
		SailingMain.instance.note_player_sail()
