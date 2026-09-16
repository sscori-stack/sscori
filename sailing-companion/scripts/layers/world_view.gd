extends Node2D
## 콕핏 뷰의 "세계": 절차적 하늘과 바다를 코드로 만들어 배치하고, 파도에 따라 기울인다.
## 카메라가 배 위에 있으므로 배가 아니라 세계가 반대로 기울고 상하로 움직인다.
## 수평선 위치는 Scene3D(카메라 파라미터)가 단일 기준이라 3D 선체와 어긋나지 않는다.
## 사각형은 화면보다 넉넉히 그려서 기울어도 여백이 생기지 않는다.

const WINDOW := Vector2(450.0, 280.0)

@export var scene3d_path: NodePath = ^"../Scene3D"
@export var boat_path: NodePath = ^"../Boat"
## 화면 밖으로 넉넉히 그릴 여백(px).
@export var margin: float = 210.0
## heading = ±1 일 때 좌우 패럴랙스(px).
@export var parallax_px: float = 26.0
## 상하 이동 배율(배의 bob 대비).
@export var bob_scale: float = 1.0
## 태양의 화면 가로 위치(0~1).
@export var sun_x: float = 0.24

var sky: ColorRect
var sea: ColorRect

var _boat: Node2D
var _pivot: Vector2 = Vector2(225.0, 150.0)


func _ready() -> void:
	_boat = get_node_or_null(boat_path) as Node2D
	var vp := get_node_or_null(scene3d_path)
	var horizon: float = 150.0
	if vp != null and vp.has_method("horizon_screen_y"):
		horizon = vp.horizon_screen_y()
	_pivot = Vector2(WINDOW.x * 0.5, horizon)

	# 하늘: 위쪽 여백 ~ 수평선
	sky = ColorRect.new()
	sky.name = "Sky"
	sky.set_script(load("res://scripts/layers/sky_shader.gd"))
	sky.position = Vector2(-margin, -margin)
	sky.size = Vector2(WINDOW.x + margin * 2.0, horizon + margin)
	sky.sun_screen_x = (sun_x * WINDOW.x + margin) / sky.size.x
	# 태양은 수평선 살짝 위
	sky.sun_screen_y = (horizon + margin - 14.0) / sky.size.y
	add_child(sky)

	# 바다: 수평선 ~ 아래쪽 여백
	sea = ColorRect.new()
	sea.name = "Sea"
	sea.set_script(load("res://scripts/layers/sea_shader.gd"))
	sea.position = Vector2(-margin, horizon)
	sea.size = Vector2(WINDOW.x + margin * 2.0, WINDOW.y - horizon + margin)
	sea.sun_screen_x = (sun_x * WINDOW.x + margin) / sea.size.x
	add_child(sea)


func _process(delta: float) -> void:
	var roll := 0.0
	var bob := 0.0
	if _boat != null:
		if "view_roll_deg" in _boat:
			roll = _boat.view_roll_deg
		if "bob_px" in _boat:
			bob = _boat.bob_px
	var heading := SailingMain.instance.heading if SailingMain.instance else 0.0
	rotation = deg_to_rad(-roll)
	position = _pivot - _pivot.rotated(rotation) + Vector2(-heading * parallax_px, -bob * bob_scale)


## 밤 가중치(0~1). 별·달 표시 등에 쓴다.
func night_weight() -> float:
	return sky.night_weight() if sky != null and sky.has_method("night_weight") else 0.0
