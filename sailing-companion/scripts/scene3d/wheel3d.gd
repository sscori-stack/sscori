extends Node3D
## 3D 조타 휠(토러스 + 스포크 + 허브). 회전각은 2D Wheel 노드(입력·복귀 로직)에서 가져온다.

@export var wheel_path: NodePath = ^"../../Boat/Wheel"
@export var tilt_deg: float = -18.0
@export var wood_color: Color = Color(0.6, 0.4, 0.25)
@export var brass_color: Color = Color(0.85, 0.7, 0.35)

var _wheel2d: Node2D
var _spin: Node3D


func setup(vp: Cockpit3D) -> void:
	var hub := SceneLayout.pivot("wheel") if SceneLayout.has_layer("wheel") else Vector2(412.0, 414.0)
	var bbox: Array = SceneLayout.layer("wheel").get("bbox", [277, 296, 547, 532]) if SceneLayout.has_layer("wheel") else [277, 296, 547, 532]
	var radius_px := float(bbox[2] - bbox[0]) * 0.5
	var r := vp.pixels_to_meters(radius_px, vp.wheel_depth)
	position = vp.pixel_to_world(hub, vp.wheel_depth)
	rotation_degrees = Vector3(tilt_deg, 0, 0)

	_spin = Node3D.new()
	add_child(_spin)
	var wood := vp.make_toon_material(wood_color, 0.008)
	var brass := vp.make_toon_material(brass_color, 0.006)

	var rim := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = r * 0.86
	tm.outer_radius = r
	tm.rings = 48
	tm.ring_segments = 12
	rim.mesh = tm
	rim.rotation_degrees = Vector3(90, 0, 0)     # 토러스는 XZ 평면 → XY 평면으로
	rim.material_override = wood
	_spin.add_child(rim)

	for i in 8:
		var spoke := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = r * 0.035
		cm.bottom_radius = r * 0.035
		cm.height = r * 1.22
		spoke.mesh = cm
		spoke.rotation_degrees = Vector3(0, 0, i * 45.0)
		spoke.material_override = wood
		_spin.add_child(spoke)
		var handle := MeshInstance3D.new()
		var hm := CapsuleMesh.new()
		hm.radius = r * 0.05
		hm.height = r * 0.2
		handle.mesh = hm
		var ang := deg_to_rad(i * 45.0)
		handle.position = Vector3(-sin(ang) * r * 1.1, cos(ang) * r * 1.1, 0)
		handle.rotation_degrees = Vector3(0, 0, i * 45.0)
		handle.material_override = wood
		_spin.add_child(handle)

	var hubm := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r * 0.12
	sm.height = r * 0.24
	hubm.mesh = sm
	hubm.material_override = brass
	_spin.add_child(hubm)
	_wheel2d = get_node_or_null(wheel_path) as Node2D


func _process(_delta: float) -> void:
	if _spin != null and _wheel2d != null:
		_spin.rotation.z = -_wheel2d.rotation
