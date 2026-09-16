extends Node3D
## 3D 조타 휠(미터 단위). 회전각은 2D Wheel 노드(입력·복귀 로직)에서 가져오고,
## 시작할 때 자신의 화면 위치·반경을 그 2D 노드에 알려준다.

@export var wheel_path: NodePath = ^"../../Boat/Wheel"
@export var radius: float = 0.42
@export var tilt_deg: float = -12.0
@export var wood_color: Color = Color(0.7, 0.48, 0.28)
@export var brass_color: Color = Color(0.88, 0.74, 0.4)

var _wheel2d: Node2D
var _spin: Node3D


func setup(vp: Cockpit3D, hub: Vector3) -> void:
	position = hub
	rotation_degrees = Vector3(tilt_deg, 0, 0)
	_spin = Node3D.new()
	add_child(_spin)
	var wood := vp.make_toon_material(wood_color, 0.006)
	var brass := vp.make_toon_material(brass_color, 0.005)
	var r := radius

	var rim := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = r * 0.88
	tm.outer_radius = r
	tm.rings = 32
	tm.ring_segments = 8
	rim.mesh = tm
	rim.rotation_degrees = Vector3(90, 0, 0)
	rim.material_override = wood
	_spin.add_child(rim)

	for i in 6:
		var spoke := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = r * 0.035
		cm.bottom_radius = r * 0.035
		cm.height = r * 1.8
		cm.radial_segments = 6
		spoke.mesh = cm
		spoke.rotation_degrees = Vector3(0, 0, i * 30.0)
		spoke.material_override = wood
		_spin.add_child(spoke)

	var hubm := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r * 0.13
	sm.height = r * 0.26
	sm.radial_segments = 10
	sm.rings = 6
	hubm.mesh = sm
	hubm.material_override = brass
	_spin.add_child(hubm)

	_wheel2d = get_node_or_null(wheel_path) as Node2D
	if _wheel2d != null:
		_wheel2d.position = vp.project_screen(hub)
		var edge := vp.project_screen(hub + Vector3(radius, 0, 0))
		if "hit_radius" in _wheel2d:
			_wheel2d.hit_radius = maxf(18.0, absf(edge.x - _wheel2d.position.x) * 1.15)


func _process(_delta: float) -> void:
	if _spin != null and _wheel2d != null:
		_spin.rotation.z = -_wheel2d.rotation
