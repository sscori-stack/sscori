extends "res://scripts/scene3d/cockpit3d.gd"
## 씬에 배치되는 3D 루트: 선체·돛 리그·휠을 만들어 붙인다(캐릭터 없음).

const Hull3D := preload("res://scripts/scene3d/hull3d.gd")
const SailRig := preload("res://scripts/scene3d/sail_rig.gd")
const Wheel3D := preload("res://scripts/scene3d/wheel3d.gd")

## 선체를 카메라 앞으로 얼마나 밀어낼지(m). 콕핏 뒤에서 보는 느낌을 조절한다.
@export var hull_offset_z: float = -1.6
## 마스트 밑동의 선체 기준 z(m, 음수 = 앞).
@export var mast_z: float = -3.1
## 휠 허브의 선체 기준 z(m).
@export var wheel_z: float = -0.85

var hull: Node3D
var sail_rig: Node3D
var wheel3d: Node3D


func _ready() -> void:
	super()
	hull = Hull3D.new()
	hull.name = "Hull"
	hull.position = Vector3(0, 0, hull_offset_z)
	add_child(hull)
	hull.setup(self)

	var deck_top: float = hull.deck_y + 0.3
	sail_rig = SailRig.new()
	sail_rig.name = "SailRig"
	add_child(sail_rig)
	sail_rig.setup(self, Vector3(0, deck_top, hull_offset_z + mast_z))

	wheel3d = Wheel3D.new()
	wheel3d.name = "Wheel3D"
	add_child(wheel3d)
	wheel3d.setup(self, Vector3(0, hull.deck_y + 0.62, hull_offset_z + wheel_z))
