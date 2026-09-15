extends Node2D
## 조타 휠. 휠 위에서 좌클릭 드래그하면 마우스 각도 변화만큼 회전(±max_angle_deg).
## 손을 떼면 return_time 에 걸쳐 0 으로 복귀. heading(-1~1)을 시그널로 알린다.
## 물리 픽킹 대신 반경 검사로 클릭을 판정한다(물리 서버 불필요, 저사양에 유리).

signal heading_changed(heading: float)

@export var max_angle_deg: float = 90.0
## 복귀에 걸리는 대략적인 시간(초).
@export var return_time: float = 2.5
## 클릭 판정 반경(픽셀, 화면 기준).
@export var hit_radius: float = 32.0
## layout.json 레이어 키. 있으면 허브 위치와 반경을 레이아웃에서 가져온다.
@export var layer_key: String = ""

var is_dragging: bool = false
## 손을 놓았을 때 파도에 따라 미세하게 흔들리는 폭(도).
@export var wobble_deg: float = 1.5
var _wobble_t: float = 0.0
## 드래그 중이 아닐 때 휠이 따라갈 목표 각(라디안). 선장/오토파일럿의 타각을 Main 이 넣어준다.
var external_target: float = 0.0

var _angle: float = 0.0
var _last_mouse_angle: float = 0.0
var _last_emitted: float = INF


func _ready() -> void:
	add_to_group("wheel")
	if layer_key != "" and SceneLayout.has_layer(layer_key):
		position = SceneLayout.to_screen(SceneLayout.pivot(layer_key))
		var l := SceneLayout.layer(layer_key)
		var b: Array = l.get("bbox", [0, 0, 0, 0])
		hit_radius = maxf(hit_radius, float(b[2] - b[0]) * 0.5 * 0.5 * 0.95)


## 좌클릭 "누름"은 UI 가 소비하지 않은 경우에만 도착한다.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed \
			and _is_mouse_over():
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


func _is_mouse_over() -> bool:
	return (get_global_mouse_position() - global_position).length() <= hit_radius


## 전역 좌표 기준 각도. 차이만 쓰므로 배/휠의 회전과 무관하다.
func _mouse_angle() -> float:
	return (get_global_mouse_position() - global_position).angle()


func _process(delta: float) -> void:
	if not is_dragging and _angle != external_target:
		# return_time 안에 사실상 목표에 수렴하는 지수 감쇠 lerp
		_angle = lerpf(_angle, external_target, minf(1.0, delta * 4.0 / maxf(return_time, 0.01)))
		if absf(_angle - external_target) < 0.0005:
			_angle = external_target
	_wobble_t += delta
	var wobble := 0.0 if is_dragging else deg_to_rad(wobble_deg) * sin(_wobble_t * 0.9) * sin(_wobble_t * 0.37 + 1.0)
	rotation = _angle + wobble
	var heading := _angle / deg_to_rad(max_angle_deg)
	if heading != _last_emitted:
		_last_emitted = heading
		heading_changed.emit(heading)
