extends Node
## 헤드리스 스모크 테스트. 메인 씬을 띄우고 입력을 시뮬레이션해 핵심 동작을 검사한다.
## 실행: godot --headless --path sailing-companion res://tests/smoke_test.tscn
## 종료 코드 0 = 전부 통과, 1 = 실패 있음.

var _frames := 0
var _main: Node
var _report := []

func _ready() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	_main = packed.instantiate()
	add_child(_main)

func _process(_delta: float) -> void:
	_frames += 1
	if _frames == 5:
		_check("Main.instance set", SailingMain.instance == _main)
		_check("Boat found", _main.get_node("Boat") != null)
		_check("AudioManager bus Ambient", AudioServer.get_bus_index("Ambient") != -1)
		_check("AudioManager bus Music", AudioServer.get_bus_index("Music") != -1)
		var sky := _main.get_node("Sky")
		_check("Sky placeholder texture", sky.texture != null and sky.texture.get_size() == Vector2(450, 280))
		var cap := _main.get_node("Boat/Captain")
		_check("Captain placeholder", cap.texture != null)
		_check("Clouds region", _main.get_node("CloudsFar").region_enabled)
		_check("Pomodoro text", "25:00" in _main.get_node("UI/UIBar/HBox/Pomodoro/TimeButton").text)
		print("  Pomodoro text: ", _main.get_node("UI/UIBar/HBox/Pomodoro/Title").text, " ", _main.get_node("UI/UIBar/HBox/Pomodoro/TimeButton").text)
		var bar: Control = _main.get_node("UI/UIBar")
		print("  UIBar rect: ", bar.get_global_rect())
		_check("UIBar height == 40", bar.size.y == 40.0)
		print("  Music label: ", _main.get_node("UI/UIBar/HBox/MusicWidget/TrackLabel").text.replace("\n", " | "))
	if _frames == 30:
		var boat := _main.get_node("Boat")
		_check("Boat bobbing", boat.position.y != 280.0 or boat.rotation != 0.0)
		var cap := _main.get_node("Boat/Captain")
		_check("Captain breathing (scale.y != 1)", cap.scale.y != 1.0)
		print("  boat pos=%s rot=%.4f  captain scale=%s bob=%.3f" % [boat.position, boat.rotation, cap.scale, boat.bob_normalized])
		# 휠 드래그 시뮬레이션: 휠 중심 우측에서 눌러 아래로 이동 (시계방향 회전)
		var wheel := _main.get_node("Boat/Wheel")
		var center: Vector2 = wheel.global_position
		_send_mouse_button(center + Vector2(20, 0), MOUSE_BUTTON_LEFT, true)
	if _frames == 32:
		var wheel := _main.get_node("Boat/Wheel")
		var center: Vector2 = wheel.global_position
		_check("Wheel dragging", wheel.is_dragging)
		_send_mouse_motion(center + Vector2(0, 20))
	if _frames == 36:
		var wheel := _main.get_node("Boat/Wheel")
		print("  wheel rot=%.3f heading=%.3f" % [wheel.rotation, _main.heading])
		_check("Wheel rotated ~90deg", absf(rad_to_deg(wheel.rotation) - 90.0) < 2.0)
		_check("Heading ~1", absf(_main.heading - 1.0) < 0.05)
		var horizon := _main.get_node("Horizon")
		_check("Horizon shifted", absf(horizon.position.x - 225.0) > 20.0)
		_send_mouse_button(wheel.global_position + Vector2(0, 20), MOUSE_BUTTON_LEFT, false)
	if _frames == 38:
		_check("Wheel released", not _main.get_node("Boat/Wheel").is_dragging)
	if _frames == 130:
		var wheel := _main.get_node("Boat/Wheel")
		print("  after ~3s: wheel rot=%.3f heading=%.3f" % [wheel.rotation, _main.heading])
		_check("Wheel returning", absf(wheel.rotation) < 0.3)
		# 우클릭 드래그 (배경)
		_send_mouse_button(Vector2(100, 100), MOUSE_BUTTON_RIGHT, true)
		_send_mouse_motion(Vector2(110, 105))
		_send_mouse_button(Vector2(110, 105), MOUSE_BUTTON_RIGHT, false)
	if _frames == 132:
		_check("Settings saved position", Settings.window_position != Vector2i(-1, -1))
		print("  saved pos=", Settings.window_position, " settings file exists=", FileAccess.file_exists("user://settings.cfg"))
		# 뽀모도로 클릭
		var pom := _main.get_node("UI/UIBar/HBox/Pomodoro/TimeButton")
		pom.button_down.emit()
		pom.button_up.emit()
	if _frames == 160:
		var pom := _main.get_node("UI/UIBar/HBox/Pomodoro")
		print("  pomodoro after run: ", pom.get_node("TimeButton").text, " remaining=", pom.remaining_seconds())
		_check("Pomodoro counting", pom.is_running() and pom.remaining_seconds() < 1500.0)
		# 설정 팝업 열기/닫기
		var popup := _main.get_node("UI/UIBar/SettingsPopup")
		popup.popup_centered(Vector2i(220, 170))
	if _frames == 165:
		var popup := _main.get_node("UI/UIBar/SettingsPopup")
		_check("Popup visible", popup.visible)
		popup.get_node("VBox/AmbientSlider").value = 0.3
		popup.hide()
	if _frames == 170:
		_check("Ambient volume applied", is_equal_approx(Settings.ambient_volume, 0.3))
		_main.get_node("UI/UIBar/HBox/MusicWidget/ToggleButton").pressed.emit()
		_check("BGM toggled off", Settings.bgm_enabled == false)
		# 오토파일럿 강제
		_main.idle_seconds = 30.0
	if _frames == 200:
		var voyage := get_node("/root/Voyage")
		_check("Voyage sim running", voyage.sim != null and voyage.sim.sim_time_hours > 0.0)
		_check("Voyage progress > 0", voyage.sim.progress() > 0.0)
		_check("Debug label shows leg", "→" in _main.get_node("UI/DebugLabel").text)
		print("  ", voyage.summary_text().replace("\n", " | "))
		_check("Autopilot active", _main.autopilot_active)
		_check("Horizon zooming", _main.get_node("Horizon").scale.x > 1.0)
		print("  fps cap=", Engine.max_fps, " low_proc=", OS.low_processor_usage_mode)
		var fails := _report.filter(func(r): return not r[1])
		print("\n==== %d checks, %d failed ====" % [_report.size(), fails.size()])
		for f in fails:
			print("FAIL: ", f[0])
		get_tree().quit(1 if fails.size() > 0 else 0)

func _check(label: String, ok: bool) -> void:
	_report.append([label, ok])
	print(("PASS " if ok else "FAIL ") + label)

func _send_mouse_button(pos: Vector2, button: int, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.position = pos
	ev.global_position = pos
	ev.button_index = button
	ev.pressed = pressed
	Input.parse_input_event(ev)

func _send_mouse_motion(pos: Vector2) -> void:
	Input.warp_mouse(pos)
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	Input.parse_input_event(ev)
