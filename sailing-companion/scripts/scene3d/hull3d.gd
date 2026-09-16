extends Node3D
## 콕핏 뷰의 3D 툰 저폴리 선체. 프리미티브(상자·원통·판)만 써서 코드로 만든다.
## 카메라는 콕핏 뒤 눈높이에 있고, 배는 카메라 앞으로 뻗어 있다(선수 방향 = -Z).
## 크기는 미터 기준: 전장 약 9m, 선폭 2.9m.

@export var length_m: float = 9.0
@export var beam_m: float = 2.9
@export var deck_y: float = -1.62          # 카메라(눈높이) 기준 갑판 높이
@export var freeboard: float = 0.42        # 갑판에서 선체 바닥까지(현측 높이)
@export var hull_color: Color = Color(0.93, 0.92, 0.9)
@export var deck_color: Color = Color(0.71, 0.64, 0.55)
@export var deck_dark: Color = Color(0.64, 0.54, 0.43)
@export var cabin_color: Color = Color(0.94, 0.92, 0.89)
@export var trim_color: Color = Color(0.52, 0.36, 0.24)
@export var metal_color: Color = Color(0.82, 0.84, 0.88)

var _vp: Cockpit3D


func setup(vp: Cockpit3D) -> void:
	_vp = vp
	var mat_hull := vp.make_toon_material(hull_color, 0.012)
	var mat_deck := vp.make_toon_material(deck_color, 0.0)
	var mat_plank := vp.make_toon_material(deck_dark, 0.0)
	var mat_cabin := vp.make_toon_material(cabin_color, 0.012)
	var mat_trim := vp.make_toon_material(trim_color, 0.01)
	var mat_metal := vp.make_toon_material(metal_color, 0.008)

	var L := length_m
	var B := beam_m
	# ---- 갑판(선수로 갈수록 좁아지는 다각형 판)
	_add_deck(mat_deck, mat_plank)
	# ---- 현측(양쪽 벽) + 선수 쐐기
	_add_sides(mat_hull)
	# ---- 콕핏: 바닥, 양쪽 벤치, 뒤쪽 코밍
	_add_cockpit(mat_deck, mat_trim, mat_cabin)
	# ---- 선실(캐빈 탑) + 해치
	var cabin := _box(Vector3(B * 0.62, 0.34, L * 0.3), Vector3(0.0, deck_y + 0.17, -L * 0.33), mat_cabin)
	cabin.rotation_degrees = Vector3(-2.0, 0, 0)
	_box(Vector3(B * 0.4, 0.05, L * 0.1), Vector3(0.0, deck_y + 0.36, -L * 0.25), mat_trim)
	# ---- 페데스탈(휠 기둥)
	_cyl(0.09, 0.62, Vector3(0.0, deck_y + 0.31 - 0.18, -1.15), mat_metal)
	_box(Vector3(0.26, 0.16, 0.2), Vector3(0.0, deck_y + 0.52, -1.15), mat_metal)
	# ---- 난간(펄핏·스탠션·라이프라인)
	_add_rails(mat_metal)
	# ---- 윈치 2개(선장이 줄을 당기는 자리 표시)
	for sx in [-1.0, 1.0]:
		_cyl(0.075, 0.13, Vector3(sx * B * 0.34, deck_y + 0.3, -0.35), mat_metal)
	return


func _add_deck(mat: Material, plank: Material) -> void:
	var L := length_m
	var B := beam_m
	var st := SurfaceTool.new()
	# 좌우 대칭 다각형: 선미(+Z)에서 선수(-Z)로 가며 폭이 줄어든다
	var rows := [
		[0.60 * L, 0.46 * B], [0.30 * L, 0.50 * B], [0.0, 0.50 * B],
		[-0.25 * L, 0.47 * B], [-0.45 * L, 0.38 * B], [-0.52 * L, 0.06 * B],
	]
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(rows.size() - 1):
		var z0: float = rows[i][0]
		var w0: float = rows[i][1]
		var z1: float = rows[i + 1][0]
		var w1: float = rows[i + 1][1]
		var quad := [
			Vector3(-w0, 0, z0), Vector3(w0, 0, z0), Vector3(w1, 0, z1), Vector3(-w1, 0, z1),
		]
		for tri in [[0, 2, 1], [0, 3, 2]]:
			for k in tri:
				st.set_normal(Vector3.UP)
				st.set_uv(Vector2(quad[k].x / B + 0.5, quad[k].z / L + 0.5))
				st.add_vertex(quad[k])
	st.generate_tangents()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.position = Vector3(0, deck_y + 0.3, 0)
	mi.material_override = mat
	add_child(mi)
	# 티크 판자: 굵은 띠를 번갈아 얹어 멀리서도 읽히게
	var n := 6
	for i in n:
		var x := lerpf(-B * 0.36, B * 0.36, float(i) / (n - 1))
		var strip := _box(Vector3(B * 0.055, 0.004, L * 0.8), Vector3(x, deck_y + 0.303, -L * 0.05), plank)
		strip.name = "Plank%d" % i


func _add_sides(mat: Material) -> void:
	var L := length_m
	var B := beam_m
	for sx in [-1.0, 1.0]:
		var side := _box(Vector3(0.07, freeboard, L * 0.9), Vector3(sx * B * 0.48, deck_y + 0.3 - freeboard * 0.5, -L * 0.02), mat)
		side.rotation_degrees = Vector3(0, sx * 1.5, 0)
	# 선수 쐐기(두 판이 모이는 형태)
	for sx in [-1.0, 1.0]:
		var bow := _box(Vector3(0.07, freeboard, L * 0.22), Vector3(sx * B * 0.24, deck_y + 0.3 - freeboard * 0.5, -L * 0.47), mat)
		bow.rotation_degrees = Vector3(0, sx * 34.0, 0)
	# 선미 판
	_box(Vector3(B * 0.9, freeboard, 0.07), Vector3(0, deck_y + 0.3 - freeboard * 0.5, L * 0.44), mat)


func _add_cockpit(deck_mat: Material, trim: Material, cabin: Material) -> void:
	var L := length_m
	var B := beam_m
	# 콕핏 바닥(갑판보다 낮게)
	_box(Vector3(B * 0.52, 0.06, L * 0.24), Vector3(0, deck_y - 0.02, -0.1), deck_mat)
	# 양쪽 벤치
	for sx in [-1.0, 1.0]:
		_box(Vector3(B * 0.2, 0.08, L * 0.24), Vector3(sx * B * 0.29, deck_y + 0.16, -0.1), cabin)
		_box(Vector3(0.06, 0.2, L * 0.24), Vector3(sx * B * 0.42, deck_y + 0.28, -0.1), trim)
	# 뒤쪽 코밍(카메라 바로 앞의 낮은 벽)
	_box(Vector3(B * 0.72, 0.16, 0.07), Vector3(0, deck_y + 0.24, L * 0.14), trim)


func _add_rails(mat: Material) -> void:
	var L := length_m
	var B := beam_m
	var stations := [-0.44, -0.3, -0.12, 0.08, 0.28]
	for z in stations:
		for sx in [-1.0, 1.0]:
			_cyl(0.012, 0.58, Vector3(sx * B * 0.46, deck_y + 0.3 + 0.29, z * L), mat)
	# 라이프라인 2줄
	for h in [0.3, 0.55]:
		for sx in [-1.0, 1.0]:
			var line := _box(Vector3(0.012, 0.012, L * 0.74), Vector3(sx * B * 0.46, deck_y + 0.3 + h, -0.08 * L), mat)
			line.rotation_degrees = Vector3(0, sx * 1.0, 0)
	# 선수 펄핏(앞쪽 U 자 난간)
	for sx in [-1.0, 1.0]:
		var p := _box(Vector3(0.014, 0.014, L * 0.14), Vector3(sx * B * 0.2, deck_y + 0.86, -L * 0.47), mat)
		p.rotation_degrees = Vector3(0, sx * 30.0, 0)


# ---------------------------------------------------------------- 프리미티브 도우미

func _box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = mat
	add_child(mi)
	return mi


func _cyl(radius: float, height: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = 8
	mi.mesh = cm
	mi.position = pos
	mi.material_override = mat
	add_child(mi)
	return mi
