extends Node2D
## 돛 조작 입력(2D 히트 영역). 돛 위에서 좌우 드래그 = 각도, 마우스 휠 = 펼침. 그리기는 3D 가 담당.

@export var drag_deg_per_px: float = 0.6
@export var furl_step: float = 0.05
## 히트 영역(화면 좌표). layout 의 sail bbox 에서 채운다.
var hit_rect: Rect2 = Rect2(0, 0, 180, 150)
var _dragging: bool = false
var _last_x: float = 0.0


func _ready() -> void:
	if SceneLayout.has_layer("sail"):
		var b: Array = SceneLayout.layer("sail")["bbox"]
		hit_rect = Rect2(Vector2(float(b[0]), maxf(0.0, float(b[1]))) * 0.5, Vector2(float(b[2] - b[0]), float(b[3] - maxf(0.0, float(b[1])))) * 0.5)


func _unhandled_input(event: InputEvent) -> void:
	var sim: SailingSim = Voyage.sim
	if sim == null:
		return
	if event is InputEventMouseButton and event.pressed and hit_rect.has_point(get_global_mouse_position()):
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = true
			_last_x = get_global_mouse_position().x
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var dir := 1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0
			sim.sail_furl = clampf(sim.sail_furl + dir * furl_step, SailingSim.SAIL_FURL_MIN, SailingSim.SAIL_FURL_MAX)
			_note()
			get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if not _dragging:
		return
	var sim: SailingSim = Voyage.sim
	if event is InputEventMouseMotion and sim != null:
		var x := get_global_mouse_position().x
		var side := -1.0 if sim.true_wind_angle() > 0.0 else 1.0   # 붐이 있는 쪽으로 끌면 시트를 푼다
		sim.sail_angle = clampf(sim.sail_angle + (x - _last_x) * side * drag_deg_per_px, SailingSim.SAIL_ANGLE_MIN, SailingSim.SAIL_ANGLE_MAX)
		_last_x = x
		_note()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_dragging = false


func _note() -> void:
	if SailingMain.instance != null:
		SailingMain.instance.note_player_sail()
