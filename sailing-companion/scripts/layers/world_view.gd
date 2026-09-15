extends Node2D
## 콕핏 뷰의 "세계" 묶음(하늘·바다·섬). 카메라가 배 위에 있으므로 배 대신 세계가 반대로 기울고 움직인다.
## 수평선 중앙을 축으로 -(롤+힐) 회전, 상하 -bob, 조타 heading 패럴랙스.

@export var boat_path: NodePath = ^"../Boat"
@export var parallax_px: float = 40.0
## 화면 상하 이동 배율(배의 bob 대비).
@export var bob_scale: float = 1.0

var _boat: Node2D
var _pivot: Vector2 = Vector2(225, 106)


func _ready() -> void:
	_boat = get_node_or_null(boat_path) as Node2D
	_pivot = Vector2(225.0, SceneLayout.to_screen(Vector2(0, SceneLayout.number("horizon_y", 212.0))).y)


func _process(_delta: float) -> void:
	var roll := 0.0
	var bob := 0.0
	if _boat != null:
		if "view_roll_deg" in _boat:
			roll = _boat.view_roll_deg
		if "bob_px" in _boat:
			bob = _boat.bob_px
	var heading := SailingMain.instance.heading if SailingMain.instance else 0.0
	rotation = deg_to_rad(-roll)
	# 회전축이 _pivot 이 되도록 위치 보정 + 상하/좌우 이동
	position = _pivot - _pivot.rotated(rotation) + Vector2(-heading * parallax_px, -bob * bob_scale)
