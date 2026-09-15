extends Node3D
## 마스트 + 붐 + 돛(3D). 돛은 시뮬레이션의 돛 각도만큼 마스트를 축으로 실제 회전하고(택에 따라 좌/우),
## 펼침·트림 효율·거스트에 따라 부풀고 펄럭인다. 정점은 매 프레임 CPU 로 갱신(격자 10x12, 저비용).

@export var grid_u: int = 10
@export var grid_v: int = 12
@export var boom_ratio: float = 0.62      # 붐 길이 / 마스트 높이
@export var belly_ratio: float = 0.22     # 최대 부풀기 / 붐 길이
## 카메라가 배 중심선에 있어 돛이 얇게 보이므로 시각적으로 더 벌려 보이는 각도(도).
@export var visual_angle_offset_deg: float = 18.0
@export var sail_color: Color = Color(0.97, 0.95, 0.9)
@export var wood_color: Color = Color(0.62, 0.4, 0.22)
@export var shape_lerp_speed: float = 1.5

var _vp: Cockpit3D
var _pivot: Node3D           # 마스트 밑동(회전축)
var _boom_pivot: Node3D      # 돛 각도만큼 Y 회전
var _boom: MeshInstance3D
var _sail: MeshInstance3D
var _mesh := ArrayMesh.new()
var _mast_h: float = 6.0
var _boom_len: float = 3.5
var _t: float = 0.0
var _vis_angle: float = 0.5
var _vis_side: float = -1.0
var _vis_furl: float = 1.0
var _vis_fill: float = 1.0
var _vis_luff: float = 0.0


func setup(vp: Cockpit3D) -> void:
	_vp = vp
	var mast_x := SceneLayout.number("mast_x", 363.0)
	var foot_y := SceneLayout.pivot("sail").y if SceneLayout.has_layer("sail") else 308.0
	var base := vp.pixel_to_world(Vector2(mast_x, foot_y), vp.mast_depth)
	_mast_h = vp.pixels_to_meters(foot_y + 140.0, vp.mast_depth)   # 꼭대기는 프레임 위로 나간다
	_boom_len = _mast_h * boom_ratio

	_pivot = Node3D.new()
	_pivot.position = base
	add_child(_pivot)

	var mast := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = vp.pixels_to_meters(5.0, vp.mast_depth)
	cm.bottom_radius = vp.pixels_to_meters(7.0, vp.mast_depth)
	cm.height = _mast_h
	mast.mesh = cm
	mast.position = Vector3(0, _mast_h * 0.5, 0)
	mast.material_override = vp.make_toon_material(wood_color, 0.01)
	_pivot.add_child(mast)

	_boom_pivot = Node3D.new()
	_pivot.add_child(_boom_pivot)

	_boom = MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = cm.top_radius * 0.9
	bm.bottom_radius = cm.top_radius * 0.9
	bm.height = _boom_len
	_boom.mesh = bm
	_boom.rotation_degrees = Vector3(90, 0, 0)     # +Z 방향으로 눕힘
	_boom.position = Vector3(0, _mast_h * 0.02, _boom_len * 0.5)
	_boom.material_override = vp.make_toon_material(wood_color, 0.01)
	_boom_pivot.add_child(_boom)

	_sail = MeshInstance3D.new()
	_sail.mesh = _mesh
	var sh := Shader.new()
	sh.code = (vp.toon_shader as Shader).code.replace("cull_back", "cull_disabled")
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("albedo", sail_color)
	mat.set_shader_parameter("shadow_tint", Color(0.8, 0.72, 0.8))
	var outline := ShaderMaterial.new()
	outline.shader = vp.outline_shader
	outline.set_shader_parameter("thickness", 0.02)
	mat.next_pass = outline
	_sail.material_override = mat
	_boom_pivot.add_child(_sail)
	_rebuild()


func _process(delta: float) -> void:
	if _vp == null:
		return
	_t += delta
	var k := minf(1.0, delta * shape_lerp_speed)
	var sim: SailingSim = Voyage.sim
	if sim != null:
		var twa := sim.true_wind_angle()
		var side_target := -1.0 if twa > 0.0 else 1.0     # 바람이 우현이면 붐은 좌현(-x)
		_vis_side = lerpf(_vis_side, side_target, k)
		_vis_angle = lerpf(_vis_angle, deg_to_rad(clampf(sim.sail_angle + visual_angle_offset_deg, 0.0, 95.0)), k)
		_vis_furl = lerpf(_vis_furl, sim.sail_furl, k)
		var eff := SailingSim.trim_efficiency(absf(twa), sim.sail_angle)
		_vis_fill = lerpf(_vis_fill, eff * clampf(Voyage.wind.speed / 12.0, 0.4, 1.3), k)
		_vis_luff = lerpf(_vis_luff, (1.0 - eff) * 1.5 + Voyage.wind.gust_intensity * 0.8, minf(1.0, delta * 3.0))
	# 붐 회전: (0,0,+1) 을 Y 축으로 side*angle 만큼 → (side*sin a, 0, cos a)
	_boom_pivot.rotation.y = _vis_side * _vis_angle
	_rebuild()


func _rebuild() -> void:
	var h := _mast_h * (0.55 + 0.45 * _vis_furl)
	var L := _boom_len * (0.7 + 0.3 * _vis_furl)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var belly := L * belly_ratio * _vis_fill
	for j in grid_v + 1:
		var v := float(j) / grid_v
		var len_v := L * (1.0 - 0.9 * v)
		for i in grid_u + 1:
			var u := float(i) / grid_u
			var bulge := belly * sin(u * PI) * pow(1.0 - v, 0.6)
			var flutter := (0.05 + _vis_luff * 0.5) * L * 0.08 * u * u * sin(_t * 9.0 + v * 7.0)
			var sway := 0.015 * L * sin(_t * 0.9 + v * 2.0) * u
			var x := _vis_side * (bulge + flutter + sway)
			verts.append(Vector3(x, v * h, u * len_v))
			uvs.append(Vector2(u, 1.0 - v))
			normals.append(Vector3(_vis_side, 0, 0))
	for j in grid_v:
		for i in grid_u:
			var a := j * (grid_u + 1) + i
			var b := a + 1
			var c := a + grid_u + 1
			var d := c + 1
			idx.append_array(PackedInt32Array([a, c, b, b, c, d]))
	# 법선 재계산(간단히 면 법선 평균)
	var acc := PackedVector3Array()
	acc.resize(verts.size())
	for n in acc.size():
		acc[n] = Vector3.ZERO
	var t := 0
	while t < idx.size():
		var p0 := verts[idx[t]]
		var p1 := verts[idx[t + 1]]
		var p2 := verts[idx[t + 2]]
		var nrm := (p1 - p0).cross(p2 - p0)
		acc[idx[t]] += nrm
		acc[idx[t + 1]] += nrm
		acc[idx[t + 2]] += nrm
		t += 3
	for n in acc.size():
		normals[n] = acc[n].normalized() if acc[n].length() > 0.0001 else Vector3(1, 0, 0)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	_mesh.clear_surfaces()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
