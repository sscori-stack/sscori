extends Area2D
## 조타 휠. 휠 위에서 좌클릭 드래그하면 마우스 각도 변화만큼 회전(±max_angle_deg).
## 손을 떼면 return_time 에 걸쳐 0 으로 복귀. heading(-1~1)을 시그널로 알린다.

signal heading_changed(heading: float)

@export var max_angle_deg: float = 90.0
## 복귀에 걸리는 대략적인 시간(초).
@export var return_time: float = 2.5

var is_dragging: bool = false

var _angle: float = 0.0
var _last_mouse_angle: float = 0.0
var _last_emitted: float = INF


func _ready() -> void:
	add_to_group("wheel")
	input_pickable = true
	input_event.connect(_on_input_event)


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		is_dragging = true
		_last_mouse_angle = _mouse_angle()
		get_viewport().set_input_as_handled()


## 드래그 중의 이동/놓음은 휠 영역 밖에서도 처리해야 하므로 _input 에서 받는다.
func _input(event: InputEvent) -> void:
	if not is_dragging:
		return
	if event is InputEventMouseMotion:
		var now := _mouse_angle()
		_angle = clampf(_angle + wrapf(now - _last_mouse_angle, -PI, PI), -deg_to_rad(max_angle_deg), deg_to_rad(max_angle_deg))
		_last_mouse_angle = now
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		is_dragging = false


## 전역 좌표 기준 각도. 차이만 쓰므로 배/휠의 회전과 무관하다.
func _mouse_angle() -> float:
	return (get_global_mouse_position() - global_position).angle()


func _process(delta: float) -> void:
	if not is_dragging and _angle != 0.0:
		# return_time 안에 사실상 0 에 수렴하는 지수 감쇠 lerp
		_angle = lerpf(_angle, 0.0, minf(1.0, delta * 4.0 / maxf(return_time, 0.01)))
		if absf(_angle) < 0.0005:
			_angle = 0.0
	rotation = _angle
	var heading := _angle / deg_to_rad(max_angle_deg)
	if heading != _last_emitted:
		_last_emitted = heading
		heading_changed.emit(heading)
