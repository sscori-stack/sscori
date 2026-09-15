extends "res://scripts/scene3d/cockpit3d.gd"
## 씬에 배치되는 3D 루트: 돛 리그·휠·선장을 만들어 붙인다.

const SailRig := preload("res://scripts/scene3d/sail_rig.gd")
const Wheel3D := preload("res://scripts/scene3d/wheel3d.gd")
const Captain3D := preload("res://scripts/scene3d/captain3d.gd")

var sail_rig: Node3D
var wheel3d: Node3D
var captain3d: Node3D


func _ready() -> void:
	super()
	sail_rig = SailRig.new()
	sail_rig.name = "SailRig"
	add_child(sail_rig)
	sail_rig.setup(self)
	wheel3d = Wheel3D.new()
	wheel3d.name = "Wheel3D"
	add_child(wheel3d)
	wheel3d.setup(self)
	captain3d = Captain3D.new()
	captain3d.name = "Captain3D"
	add_child(captain3d)
	captain3d.setup(self)
