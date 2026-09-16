extends Node2D
## 돛 조작 입력(2D 히트 영역). 돛 위에서 좌우 드래그 = 각도, 마우스 휠 = 펼침. 그리기는 3D 가 담당.

@export var drag_deg_per_px: float = 0.6
@export var furl_step: float = 0.05
@export var scene3d_path: NodePath = ^"../../Scene3D"
## 히트 영역(화면 좌표). 3D 돛 리그의 투영에서 계산한다.
var hit_rect: Rect2 = Rect2(60, 0, 180, 150)
var _dragging: bool = false
var _last_x: float = 0.0


func _ready() -> void:
	_compute_hit_rect.call_deferred()


func _compute_hit_rect() -> void:
	var vp := get_node_or_null(scene3d_path)
	if vp == null or not vp.has_method("project_screen"):
		return
	var rig: Node3D = vp.get("sail_rig")
	if rig == null:
		return
	var pts: Array = []
	var base: Vector3 = rig.global_position
	var h: float = float(rig.mast_height)
	var l: float = float(rig.boom_length)
	for p in [base, base + Vector3(0, h, 0), base + Vector3(-l * 0.8, h * 0.5, l * 0.5),
			base + Vector3(l * 0.8, h * 0.5, l * 0.5), base + Vector3(0, float(rig.boom_height), l)]:
		pts.append(vp.project_screen(p))
	var minp: Vector2 = pts[0]
	var maxp: Vector2 = pts[0]
	for p in pts:
		minp = minp.min(p)
		maxp = maxp.max(p)
	minp.y = maxf(minp.y, 0.0)
	hit_rect = Rect2(minp, maxp - minp)


func _unhandled_input(event: InputEvent) -> void:
	var sim: SailingSim = Voyage.sim
	if sim == null:
		return
	if event is InputEventMouseButton and event.pressed and _hits(get_global_mouse_position()):
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


## 돛 영역이면서 휠 원 밖일 때만 돛 조작으로 본다.
func _hits(p: Vector2) -> bool:
	if not hit_rect.has_point(p):
		return false
	for w in get_tree().get_nodes_in_group("wheel"):
		if w is Node2D and "hit_radius" in w:
			if p.distance_to((w as Node2D).global_position) <= float(w.hit_radius) + 4.0:
				return false
	return true


func _note() -> void:
	if SailingMain.instance != null:
		SailingMain.instance.note_player_sail()
