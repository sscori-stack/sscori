class_name Cockpit3D
extends SubViewport
## 2.5D 하이브리드의 3D 부분. 2D 그림(하늘·바다·섬·선체 판) 위에 투명 배경으로 합성된다.
## 카메라는 원점에서 -Z 를 보며, 물체는 "화면 픽셀 + 깊이" 로 배치한다(layout.json 좌표를 그대로 씀).
## 담는 것: 마스트+붐+돛(바람 각도로 실제 회전), 휠, 선장(툰 셰이딩 3D).

const FRAME := Vector2(900.0, 560.0)

@export var fov_deg: float = 40.0
## 각 물체의 깊이(m). 그림의 원근에 맞춰 조정.
@export var mast_depth: float = 11.0
@export var wheel_depth: float = 3.2
@export var helm_depth: float = 2.6
@export var winch_depth: float = 9.0

var camera: Camera3D
var sun: DirectionalLight3D
var toon_shader: Shader
var outline_shader: Shader


func _ready() -> void:
	transparent_bg = true
	size = Vector2i(FRAME)
	msaa_3d = Viewport.MSAA_2X
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	toon_shader = load("res://shaders/toon.gdshader")
	outline_shader = load("res://shaders/outline.gdshader")

	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = fov_deg
	camera.near = 0.1
	camera.far = 200.0
	camera.position = Vector3.ZERO
	add_child(camera)

	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(1.0, 0.85, 0.7)
	sun.light_energy = 1.1
	sun.rotation_degrees = Vector3(-25.0, 35.0, 0.0)   # 앞쪽 왼쪽 위 노을
	add_child(sun)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.85, 0.7, 0.8)
	e.ambient_light_energy = 0.45
	env.environment = e
	add_child(env)


## 프레임 픽셀(900x560 기준) 과 깊이 → 카메라 공간 3D 점(카메라는 원점, -Z 를 봄).
func pixel_to_world(px: Vector2, depth: float) -> Vector3:
	var f := (FRAME.y * 0.5) / tan(deg_to_rad(fov_deg) * 0.5)
	var x := (px.x - FRAME.x * 0.5) / f * depth
	var y := -(px.y - FRAME.y * 0.5) / f * depth
	return Vector3(x, y, -depth)


## 어떤 깊이에서 픽셀 길이가 몇 m 인가.
func pixels_to_meters(px: float, depth: float) -> float:
	var f := (FRAME.y * 0.5) / tan(deg_to_rad(fov_deg) * 0.5)
	return px / f * depth


func make_toon_material(color: Color, outline: float = 0.012, tex: Texture2D = null) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = toon_shader
	m.set_shader_parameter("albedo", color)
	if tex != null:
		m.set_shader_parameter("albedo_tex", tex)
		m.set_shader_parameter("use_texture", 1.0)
	if outline > 0.0:
		var o := ShaderMaterial.new()
		o.shader = outline_shader
		o.set_shader_parameter("thickness", outline)
		m.next_pass = o
	return m
