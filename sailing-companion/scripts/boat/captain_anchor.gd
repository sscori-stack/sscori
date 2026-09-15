extends Node2D
## 선장의 2D "자리" 노드. CaptainController 가 이 노드를 움직이고 포즈를 정하면 Captain3D 가 따라 그린다.
## (예전 Sprite2D 선장과 같은 인터페이스: set_pose, facing, pose_scale, pose_skew, depth_scale, uses_layout)

@export var layer_key: String = "captain"

var pose: String = "idle"
var facing: float = 1.0
var pose_scale: Vector2 = Vector2.ONE
var pose_skew: float = 0.0
var depth_scale: float = 1.0
var uses_layout: bool = false


func _ready() -> void:
	if layer_key != "" and SceneLayout.has_layer(layer_key):
		position = SceneLayout.to_screen(SceneLayout.pivot(layer_key))
		uses_layout = true


func set_pose(new_pose: String) -> void:
	pose = new_pose
