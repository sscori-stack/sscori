extends Node
## 헤드리스 스모크 테스트. 메인 씬을 띄우고 입력을 시뮬레이션해 핵심 동작을 검사한다.
## 실행: godot --headless --path sailing-companion res://tests/smoke_test.tscn
## 종료 코드 0 = 전부 통과, 1 = 실패 있음.

var _frames := 0
var _main: Node
var _report := []


func _ready() -> void:
	# 이전 실행이 남긴 항해 저장 상태(정박 등)가 검사에 섞이지 않도록 초기화
	get_node("/root/Voyage").reset_voyage()
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
		var sky: ColorRect = _main.get_node("World/Sky")
		var sea: ColorRect = _main.get_node("World/Sea")
		var vp := _main.get_node("Scene3D")
		_check("Sky rect oversized past window", sky.size.x > 450.0 and sky.size.y > 100.0)
		_check("Sea rect starts at the 3D horizon", absf(sea.position.y - vp.horizon_screen_y()) < 0.5)
		_check("Sky and Sea use shaders", sky.material is ShaderMaterial and sea.material is ShaderMaterial)
		_check("Scene3D has hull, sail rig, wheel", _main.get_node("Scene3D/Hull") != null
			and _main.get_node("Scene3D/SailRig") != null and _main.get_node("Scene3D/Wheel3D") != null)
		_check("View3D shows the 3D viewport", _main.get_node("View3D").texture != null)
		_check("Pomodoro text", "25:00" in _main.get_node("UI/UIBar/HBox/Pomodoro/TimeButton").text)
		var bar: Control = _main.get_node("UI/UIBar")
		_check("UIBar height == 40", bar.size.y == 40.0)
		print("  horizon screen y=%.1f  sea rect=%s" % [vp.horizon_screen_y(), sea.position])
		print("  Music label: ", _main.get_node("UI/UIBar/HBox/MusicWidget/TrackLabel").text.replace("\n", " | "))

	if _frames == 30:
		var boat := _main.get_node("Boat")
		_check("Boat bobbing", boat.bob_px != 0.0)
		_check("World tilts opposite the roll", absf(_main.get_node("World").rotation) > 0.00001)
		print("  bob_px=%.2f view_roll=%.3f world rot=%.4f" % [boat.bob_px, boat.view_roll_deg, _main.get_node("World").rotation])
		# 휠 드래그 시뮬레이션: 휠 중심 우측에서 눌러 아래로 이동 (시계방향 회전)
		var wheel := _main.get_node("Boat/Wheel")
		_send_mouse_button(wheel.global_position + Vector2(20, 0), MOUSE_BUTTON_LEFT, true)

	if _frames == 32:
		var wheel := _main.get_node("Boat/Wheel")
		_check("Wheel dragging", wheel.is_dragging)
		_send_mouse_motion(wheel.global_position + Vector2(0, 20))

	if _frames == 36:
		var wheel := _main.get_node("Boat/Wheel")
		print("  wheel rot=%.3f heading=%.3f" % [wheel.rotation, _main.heading])
		_check("Wheel rotated >= 60deg", rad_to_deg(wheel.rotation) >= 60.0)
		_check("Heading >= 0.65", _main.heading >= 0.65)
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
		var pom := _main.get_node("UI/UIBar/HBox/Pomodoro/TimeButton")
		pom.button_down.emit()
		pom.button_up.emit()

	if _frames == 160:
		var pom := _main.get_node("UI/UIBar/HBox/Pomodoro")
		_check("Pomodoro counting", pom.is_running() and pom.remaining_seconds() < 1500.0)
		var popup := _main.get_node("UI/UIBar/SettingsPopup")
		popup.popup_centered(Vector2i(230, 262))

	if _frames == 165:
		var popup := _main.get_node("UI/UIBar/SettingsPopup")
		_check("Popup visible", popup.visible)
		popup.get_node("VBox/AmbientSlider").value = 0.3
		popup.hide()

	if _frames == 170:
		_check("Ambient volume applied", is_equal_approx(Settings.ambient_volume, 0.3))
		_main.get_node("UI/UIBar/HBox/MusicWidget/ToggleButton").pressed.emit()
		_check("BGM toggled off", Settings.bgm_enabled == false)
		_main.idle_seconds = 30.0

	if _frames == 200:
		var voyage := get_node("/root/Voyage")
		_check("Sim auto-executes without a crew", voyage.sim.auto_execute_enabled)
		voyage.sim.sail_angle = clampf(voyage.sim.target_sail_angle + 40.0, 5.0, 90.0)

	if _frames == 420:
		var voyage := get_node("/root/Voyage")
		_check("Sim trims the sail back toward target", absf(voyage.sim.sail_angle - voyage.sim.target_sail_angle) < 25.0)
		var chart := _main.get_node("UI/ChartInset")
		_check("Chart hidden by default", not chart.visible)
		_main.get_node("UI/UIBar/HBox/ChartButton").pressed.emit()
		_check("Chart toggled visible", chart.visible)
		var popup := _main.get_node("UI/UIBar/SettingsPopup")
		_check("Route options filled", popup.get_node("VBox/RouteRow/RouteOption").item_count == Marinas.LEGS.size() * 2)

	if _frames == 460:
		var voyage := get_node("/root/Voyage")
		_check("Voyage sim running", voyage.sim != null and voyage.sim.sim_time_hours > 0.0)
		_check("Voyage progress > 0", voyage.sim.progress() > 0.0)
		_check("Voyage label shows the leg", "→" in _main.get_node("UI/Hud/VoyageLabel").text)
		_check("World shifted by heading", absf(_main.get_node("World").position.x) > 0.5)
		_check("Wheel follows rudder target", is_finite(_main.get_node("Boat/Wheel").external_target))
		var rig := _main.get_node("Scene3D/SailRig")
		_check("Sail boom rotates with the sail angle", is_finite(rig._boom_pivot.rotation.y) and absf(rig._boom_pivot.rotation.y) > 0.001)
		var hull := _main.get_node("Scene3D/Hull")
		_check("Hull built from meshes", hull.get_child_count() > 10)
		var sea_mat: ShaderMaterial = _main.get_node("World/Sea").material
		_check("Sea shader receives wind", sea_mat.get_shader_parameter("wind_norm") != null)
		_check("Autopilot active", _main.autopilot_active)
		print("  boom yaw=%.2f  hull children=%d  fps cap=%d" % [rig._boom_pivot.rotation.y, hull.get_child_count(), Engine.max_fps])
		print("  ", voyage.summary_text().replace("\n", " | "))
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
