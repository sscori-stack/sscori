class_name Cockpit3D
extends SubViewport
## 2.5D 하이브리드의 3D 부분. 절차적 하늘·바다(2D 셰이더) 위에 투명 배경으로 합성된다.
## 담는 것: 선체(툰 저폴리), 마스트·붐·돛, 조타 휠. 카메라는 콕핏에 앉은 눈높이에 고정된다.
## 3D 수평선과 2D 수평선이 어긋나지 않도록, 화면 수평선 위치는 여기(카메라 파라미터)가 단일 기준이다.

const FRAME := Vector2(900.0, 560.0)   # 창(450x280)의 2배
const SCREEN_SCALE := 0.5

## 수직 화각(도). 콕핏에서 갑판과 수평선을 함께 보려면 넓어야 한다.
@export var fov_deg: float = 58.0
## 카메라 하향각(도). 갑판이 얼마나 보이는지 결정한다.
@export var pitch_deg: float = 9.0
## 카메라 위치(원점 기준, m). 우현 헬름 쪽으로 약간 치우친다.
@export var eye_offset: Vector3 = Vector3(0.28, 0.0, 0.0)
## 좌우 시선(도). 음수 = 왼쪽(뱃머리 좌현)을 본다.
@export var yaw_deg: float = -1.5

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
	camera.near = 0.05
	camera.far = 400.0
	camera.position = eye_offset
	camera.rotation_degrees = Vector3(-pitch_deg, yaw_deg, 0.0)
	add_child(camera)

	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(1.0, 0.86, 0.72)
	sun.light_energy = 1.15
	# 노을 태양이 뱃머리 왼쪽 앞 낮은 곳에 있다고 가정
	sun.rotation_degrees = Vector3(-14.0, -28.0, 0.0)
	add_child(sun)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.78, 0.68, 0.78)
	e.ambient_light_energy = 0.5
	env.environment = e
	add_child(env)


## 초점거리(프레임 픽셀).
func focal_px() -> float:
	return (FRAME.y * 0.5) / tan(deg_to_rad(fov_deg) * 0.5)


## 3D 점 → 프레임 픽셀(900x560 기준). 카메라 앞이 아니면 y 에 매우 큰 값.
func project_frame(p: Vector3) -> Vector2:
	var basis := Basis.from_euler(Vector3(deg_to_rad(-pitch_deg), deg_to_rad(yaw_deg), 0.0))
	var local: Vector3 = basis.transposed() * (p - eye_offset)
	if local.z >= -0.001:
		return Vector2(FRAME.x * 0.5, 99999.0)
	var f := focal_px()
	return Vector2(FRAME.x * 0.5 + local.x / -local.z * f, FRAME.y * 0.5 - local.y / -local.z * f)


## 3D 점 → 화면 픽셀(450x280 기준).
func project_screen(p: Vector3) -> Vector2:
	return project_frame(p) * SCREEN_SCALE


## 무한 원방(수평선)의 프레임 y. 카메라가 아래를 보면(pitch_deg > 0) 수평선은 위로 올라간다.
func horizon_frame_y() -> float:
	return FRAME.y * 0.5 - tan(deg_to_rad(pitch_deg)) * focal_px()


func horizon_screen_y() -> float:
	return horizon_frame_y() * SCREEN_SCALE


## 깊이 depth 에서 프레임 픽셀 길이 → 미터.
func pixels_to_meters(px: float, depth: float) -> float:
	return px / focal_px() * depth


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
