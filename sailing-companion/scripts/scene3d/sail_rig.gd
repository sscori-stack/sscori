extends Node3D
## 마스트 + 붐 + 돛(3D, 미터 단위). 선체가 알려준 마스트 밑동에 선다.
## 돛은 시뮬레이션의 돛 각도만큼 마스트를 축으로 실제 회전하고(택에 따라 좌/우),
## 펼침·트림 효율·거스트에 따라 부풀고 펄럭인다.

@export var grid_u: int = 10
@export var grid_v: int = 12
@export var mast_height: float = 9.5
@export var boom_height: float = 2.05      # 갑판에서 붐까지(눈높이 살짝 위 → 돛 아랫부분이 화면에 들어온다)
@export var boom_length: float = 3.2
@export var belly_ratio: float = 0.2       # 최대 부풀기 / 붐 길이
@export var sail_color: Color = Color(0.98, 0.97, 0.94)
@export var wood_color: Color = Color(0.82, 0.68, 0.5)
@export var shape_lerp_speed: float = 1.5

var _vp: Cockpit3D
var _boom_pivot: Node3D
var _sail: MeshInstance3D
var _mesh := ArrayMesh.new()
var _t: float = 0.0
var _vis_angle: float = 0.6
var _vis_side: float = -1.0
var _vis_furl: float = 1.0
var _vis_fill: float = 1.0
var _vis_luff: float = 0.0


## base: 마스트 밑동(갑판 위) 위치.
func setup(vp: Cockpit3D, base: Vector3) -> void:
	_vp = vp
	position = base

	var mast := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.038
	cm.bottom_radius = 0.06
	cm.height = mast_height
	cm.radial_segments = 8
	mast.mesh = cm
	mast.position = Vector3(0, mast_height * 0.5, 0)
	mast.material_override = vp.make_toon_material(wood_color, 0.012)
	add_child(mast)

	_boom_pivot = Node3D.new()
	_boom_pivot.position = Vector3(0, boom_height, 0)
	add_child(_boom_pivot)

	var boom := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.03
	bm.bottom_radius = 0.03
	bm.height = boom_length
	bm.radial_segments = 6
	boom.mesh = bm
	boom.rotation_degrees = Vector3(90, 0, 0)
	boom.position = Vector3(0, 0, boom_length * 0.5)
	boom.material_override = vp.make_toon_material(wood_color, 0.01)
	_boom_pivot.add_child(boom)

	_sail = MeshInstance3D.new()
	_sail.mesh = _mesh
	var sh := Shader.new()
	sh.code = vp.toon_shader.code.replace("cull_back", "cull_disabled")
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("albedo", sail_color)
	mat.set_shader_parameter("shadow_tint", Color(0.78, 0.7, 0.8))
	mat.set_shader_parameter("shade_1", 0.55)
	mat.set_shader_parameter("shade_2", 0.2)
	var outline := ShaderMaterial.new()
	outline.shader = vp.outline_shader
	outline.set_shader_parameter("thickness", 0.03)
	mat.next_pass = outline
	_sail.material_override = mat
	_boom_pivot.add_child(_sail)
	_rebuild()


func sail_top() -> Vector3:
	return global_position + Vector3(0, mast_height, 0)


func _process(delta: float) -> void:
	if _vp == null:
		return
	_t += delta
	var k := minf(1.0, delta * shape_lerp_speed)
	var sim: SailingSim = Voyage.sim
	if sim != null:
		var twa := sim.true_wind_angle()
		# 바람이 우현(TWA>0)에서 오면 붐은 좌현(-x)으로 나간다
		_vis_side = lerpf(_vis_side, -1.0 if twa > 0.0 else 1.0, k)
		_vis_angle = lerpf(_vis_angle, deg_to_rad(clampf(sim.sail_angle, 5.0, 90.0)), k)
		_vis_furl = lerpf(_vis_furl, sim.sail_furl, k)
		var eff := SailingSim.trim_efficiency(absf(twa), sim.sail_angle)
		_vis_fill = lerpf(_vis_fill, eff * clampf(Voyage.wind.speed / 12.0, 0.35, 1.3), k)
		_vis_luff = lerpf(_vis_luff, (1.0 - eff) * 1.4 + Voyage.wind.gust_intensity * 0.8, minf(1.0, delta * 3.0))
	_boom_pivot.rotation.y = _vis_side * _vis_angle
	_rebuild()


func _rebuild() -> void:
	var h := (mast_height - boom_height) * (0.55 + 0.45 * _vis_furl)
	var L := boom_length * (0.72 + 0.28 * _vis_furl)
	var belly := L * belly_ratio * _vis_fill
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for j in grid_v + 1:
		var v := float(j) / grid_v
		var len_v := L * (1.0 - 0.88 * v)
		for i in grid_u + 1:
			var u := float(i) / grid_u
			var bulge := belly * sin(u * PI) * pow(1.0 - v, 0.55)
			var flutter := L * 0.06 * (0.08 + _vis_luff * 0.55) * u * u * sin(_t * 9.0 + v * 7.0)
			var sway := L * 0.02 * sin(_t * 0.9 + v * 2.0) * u
			verts.append(Vector3(_vis_side * (bulge + flutter + sway), v * h, u * len_v))
			uvs.append(Vector2(u, 1.0 - v))
	for j in grid_v:
		for i in grid_u:
			var a := j * (grid_u + 1) + i
			idx.append_array(PackedInt32Array([a, a + grid_u + 1, a + 1, a + 1, a + grid_u + 1, a + grid_u + 2]))
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	for n in normals.size():
		normals[n] = Vector3.ZERO
	var t := 0
	while t < idx.size():
		var nrm := (verts[idx[t + 1]] - verts[idx[t]]).cross(verts[idx[t + 2]] - verts[idx[t]])
		normals[idx[t]] += nrm
		normals[idx[t + 1]] += nrm
		normals[idx[t + 2]] += nrm
		t += 3
	for n in normals.size():
		normals[n] = normals[n].normalized() if normals[n].length() > 0.0001 else Vector3(_vis_side, 0, 0)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	_mesh.clear_surfaces()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
