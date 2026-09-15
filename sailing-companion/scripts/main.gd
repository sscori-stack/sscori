class_name SailingMain
extends Node2D
## 루트 씬. 창(보더리스/최상단/우측 하단 배치/우클릭 드래그), FPS 제한,
## 전역 시간·조타(heading)·오토파일럿 상태를 소유한다.

const WINDOW_SIZE := Vector2i(450, 280)
const SCREEN_MARGIN := 16
const FPS_ACTIVE := 30
const FPS_IDLE := 15
const AUTOPILOT_IDLE_SECONDS := 20.0
## 오토파일럿 중 heading 이 0 으로 되돌아가는 속도(초당 비율).
const AUTOPILOT_RETURN_RATE := 0.15

## 다른 노드가 참조할 수 있는 단일 인스턴스 (씬은 하나뿐이다).
static var instance: SailingMain

## 조타 값 -1(좌) ~ 1(우). 레이어 패럴랙스가 읽는다.
var heading: float = 0.0
## 경과 시간(초). 모든 모션의 기준.
var time_elapsed: float = 0.0
## 마지막 입력 이후 경과 시간(초).
var idle_seconds: float = 0.0
## 입력 없이 AUTOPILOT_IDLE_SECONDS 이상 지나면 true.
var autopilot_active: bool = false

var _boat: Boat
var _wheel_heading: float = 0.0
var _wheel_dragging: bool = false

var _dragging_window := false
var _drag_offset := Vector2i.ZERO
var _app_focused := true
var _mouse_inside := false


func _ready() -> void:
	instance = self
	OS.low_processor_usage_mode = true
	_setup_window()
	_update_fps()
	_boat = get_tree().get_first_node_in_group("boat") as Boat
	for wheel in get_tree().get_nodes_in_group("wheel"):
		wheel.heading_changed.connect(_on_wheel_heading_changed.bind(wheel))


func _exit_tree() -> void:
	if instance == self:
		instance = null


# ---------------------------------------------------------------- 창 설정

func _setup_window() -> void:
	var win := get_window()
	win.borderless = true
	win.always_on_top = true
	win.unresizable = true
	win.size = WINDOW_SIZE
	win.position = _resolve_initial_position()
	win.mouse_entered.connect(_on_window_mouse_entered)
	win.mouse_exited.connect(_on_window_mouse_exited)


## 저장된 위치가 있고 어떤 모니터 안에 완전히 들어오면 그 위치, 아니면 주 모니터 우측 하단.
func _resolve_initial_position() -> Vector2i:
	var saved: Vector2i = Settings.window_position
	if saved != Vector2i(-1, -1) and _is_position_on_any_screen(saved):
		return saved
	return _default_position()


func _default_position() -> Vector2i:
	var usable := DisplayServer.screen_get_usable_rect(DisplayServer.SCREEN_PRIMARY)
	return usable.position + usable.size - WINDOW_SIZE - Vector2i(SCREEN_MARGIN, SCREEN_MARGIN)


func _is_position_on_any_screen(pos: Vector2i) -> bool:
	var rect := Rect2i(pos, WINDOW_SIZE)
	for i in DisplayServer.get_screen_count():
		if DisplayServer.screen_get_usable_rect(i).encloses(rect):
			return true
	return false


func _save_window_position() -> void:
	Settings.window_position = DisplayServer.window_get_position()
	Settings.save_settings()


# ---------------------------------------------------------------- 입력

## 우클릭 "누름"은 UI가 소비하지 않은 경우(배경)에만 도착한다.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_dragging_window = true
		_drag_offset = DisplayServer.mouse_get_position() - DisplayServer.window_get_position()
		get_viewport().set_input_as_handled()


## 이동/놓음은 UI 위에서 끝나도 놓치지 않도록 _input에서 처리한다.
func _input(event: InputEvent) -> void:
	if event is InputEventMouse or event is InputEventKey:
		idle_seconds = 0.0
	if not _dragging_window:
		return
	if event is InputEventMouseMotion:
		# 창이 움직이면 창 기준 좌표는 그대로이므로, 화면 절대 좌표에서 델타를 구한다.
		DisplayServer.window_set_position(DisplayServer.mouse_get_position() - _drag_offset)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
		_dragging_window = false
		_save_window_position()


# ---------------------------------------------------------------- 시뮬레이션 틱

func _process(delta: float) -> void:
	time_elapsed += delta
	idle_seconds += delta
	autopilot_active = idle_seconds >= AUTOPILOT_IDLE_SECONDS
	if autopilot_active and not _wheel_dragging:
		# 휠은 이미 스스로 복귀하지만, 오토파일럿은 등대 방향(0)을 아주 천천히 유지한다.
		heading = lerpf(heading, 0.0, minf(1.0, delta * AUTOPILOT_RETURN_RATE))
	else:
		heading = _wheel_heading
	if _boat != null:
		AudioManager.set_wave_phase(_boat.bob_normalized)


func _on_wheel_heading_changed(value: float, wheel: Node) -> void:
	_wheel_heading = value
	_wheel_dragging = wheel.is_dragging


# ---------------------------------------------------------------- FPS / 포커스

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_IN:
			_app_focused = true
			_update_fps()
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			_app_focused = false
			_dragging_window = false
			_update_fps()
		NOTIFICATION_WM_CLOSE_REQUEST:
			_save_window_position()
			get_tree().quit()


func _on_window_mouse_entered() -> void:
	_mouse_inside = true
	_update_fps()


func _on_window_mouse_exited() -> void:
	_mouse_inside = false
	_update_fps()


func _update_fps() -> void:
	Engine.max_fps = FPS_ACTIVE if (_app_focused or _mouse_inside) else FPS_IDLE


## 설정 메뉴의 "종료"가 호출한다.
func quit_app() -> void:
	_save_window_position()
	get_tree().quit()
