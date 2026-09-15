extends Node3D
## 3D 고양이 선장. assets/models/captain.glb 가 있으면 그 모델(툰 셰이딩 적용)과 애니메이션을 쓰고,
## 없으면 프리미티브로 만든 임시 고양이를 쓴다. 2D CaptainAnchor(컨트롤러가 움직이는 자리)를 따라간다:
## 화면 픽셀 → 헬름/윈치 사이 진행도에 따른 깊이 → 3D 위치. 포즈 이름은 애니메이션에 매핑한다.

const MODEL_PATH := "res://assets/models/captain.glb"
## 포즈 → 후보 애니메이션 이름(앞에서부터 있는 것을 씀).
const ANIM_CANDIDATES := {
	"idle": ["idle", "sit", "Idle", "Sit", "sitting", "seated"],
	"steer": ["steer", "sit", "idle", "Idle"],
	"walk": ["walk", "Walk", "walking", "run"],
	"pull": ["pull", "Pull", "work", "action"],
	"stretch": ["stretch", "Stretch", "yawn", "idle2"],
	"pet": ["pet", "idle"],
}

@export var anchor_path: NodePath = ^"../../Boat/Captain"
@export var fur_color: Color = Color(0.9, 0.62, 0.36)
@export var sweater_color: Color = Color(0.74, 0.4, 0.28)
@export var hat_color: Color = Color(0.2, 0.25, 0.45)

var _vp: Cockpit3D
var _anchor: Node2D
var _model: Node3D
var _anim: AnimationPlayer
var _has_model: bool = false
var _pose: String = ""
var _t: float = 0.0
var _height_m: float = 1.0
var _model_base_scale: float = 1.0
var _helm_px: Vector2
var _winch_px: Vector2


func setup(vp: Cockpit3D) -> void:
	_vp = vp
	_anchor = get_node_or_null(anchor_path) as Node2D
	var bbox: Array = SceneLayout.layer("captain").get("bbox", [529, 224, 782, 594]) if SceneLayout.has_layer("captain") else [529, 224, 782, 594]
	_height_m = vp.pixels_to_meters(float(bbox[3] - bbox[1]) * 0.85, vp.helm_depth)
	_helm_px = SceneLayout.point("helm_spot", Vector2(655, 594))
	_winch_px = SceneLayout.point("winch_spot", Vector2(381, 437))
	if ResourceLoader.exists(MODEL_PATH):
		_load_model(vp)
	if not _has_model:
		_build_placeholder(vp)


func _load_model(vp: Cockpit3D) -> void:
	var packed := load(MODEL_PATH) as PackedScene
	if packed == null:
		return
	_model = packed.instantiate() as Node3D
	if _model == null:
		return
	add_child(_model)
	_anim = _find_anim(_model)
	# 툰 셰이딩: 기존 머티리얼의 알베도 텍스처/색을 툰 머티리얼로 옮긴다
	for mi in _find_meshes(_model):
		if mi.mesh == null:
			continue
		for si in mi.mesh.get_surface_count():
			var src: Material = mi.get_active_material(si)
			var color := Color.WHITE
			var tex: Texture2D = null
			if src is BaseMaterial3D:
				color = (src as BaseMaterial3D).albedo_color
				tex = (src as BaseMaterial3D).albedo_texture
			mi.set_surface_override_material(si, vp.make_toon_material(color, 0.006, tex))
	# 키를 목표 높이에 맞춘다
	var aabb := _combined_aabb(_model)
	if aabb.size.y > 0.001:
		_model_base_scale = _height_m / aabb.size.y
		_model.scale = Vector3.ONE * _model_base_scale
		_model.position.y = -aabb.position.y * _model_base_scale
	_has_model = true


func _build_placeholder(vp: Cockpit3D) -> void:
	_model = Node3D.new()
	add_child(_model)
	var h := _height_m
	var fur := vp.make_toon_material(fur_color, 0.01)
	var sweater := vp.make_toon_material(sweater_color, 0.01)
	var hat := vp.make_toon_material(hat_color, 0.008)
	var cream := vp.make_toon_material(Color(0.98, 0.95, 0.9), 0.006)

	var body := _sphere(h * 0.36, Vector3(0, h * 0.34, 0), sweater)
	body.scale = Vector3(1.0, 0.95, 1.05)
	var lower := _sphere(h * 0.3, Vector3(0, h * 0.2, h * 0.05), fur)
	lower.scale = Vector3(1.1, 0.7, 1.15)
	var head := _sphere(h * 0.22, Vector3(0, h * 0.72, h * 0.04), fur)
	var scarf := _sphere(h * 0.2, Vector3(0, h * 0.56, h * 0.06), cream)
	scarf.scale = Vector3(1.0, 0.35, 1.0)
	for sgn in [-1.0, 1.0]:
		var ear := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = h * 0.06
		cm.height = h * 0.12
		ear.mesh = cm
		ear.position = Vector3(sgn * h * 0.13, h * 0.9, 0)
		ear.rotation_degrees = Vector3(0, 0, -sgn * 20.0)
		ear.material_override = fur
		_model.add_child(ear)
	var brim := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = h * 0.24
	bm.bottom_radius = h * 0.24
	bm.height = h * 0.02
	brim.mesh = bm
	brim.position = Vector3(0, h * 0.88, h * 0.03)
	brim.material_override = hat
	_model.add_child(brim)
	var crown := MeshInstance3D.new()
	var km := CylinderMesh.new()
	km.top_radius = h * 0.19
	km.bottom_radius = h * 0.2
	km.height = h * 0.09
	crown.mesh = km
	crown.position = Vector3(0, h * 0.93, h * 0.03)
	crown.material_override = hat
	_model.add_child(crown)
	var tail := MeshInstance3D.new()
	var tm := CapsuleMesh.new()
	tm.radius = h * 0.04
	tm.height = h * 0.36
	tail.mesh = tm
	tail.position = Vector3(h * 0.22, h * 0.14, h * 0.14)
	tail.rotation_degrees = Vector3(20, 0, -70)
	tail.material_override = fur
	_model.add_child(tail)


func _sphere(r: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	mi.mesh = sm
	mi.position = pos
	mi.material_override = mat
	_model.add_child(mi)
	return mi


func _process(delta: float) -> void:
	if _vp == null or _anchor == null or _model == null:
		return
	_t += delta
	# 2D 앵커 → 프레임 픽셀 → 깊이(헬름↔윈치 진행도) → 3D
	var px := _anchor.position * 2.0
	var span := _helm_px.y - _winch_px.y
	var t := 0.0
	if absf(span) > 1.0:
		t = clampf((_helm_px.y - px.y) / span, 0.0, 1.0)
	var depth := lerpf(_vp.helm_depth, _vp.winch_depth, t)
	position = _vp.pixel_to_world(px, depth)
	# 원근은 깊이로 자동. 2D 앵커의 depth_scale 은 쓰지 않는다.
	var facing := 1.0
	if "facing" in _anchor:
		facing = float(_anchor.facing)
	# 뒷모습 기준: 헬름에서는 앞(-Z)을 본다. 걸을 때는 진행 방향(좌/우)으로 몸을 튼다.
	var pose := str(_anchor.pose) if "pose" in _anchor else "idle"
	var target_yaw := 0.0
	if pose == "walk":
		target_yaw = -facing * PI * 0.5
	_model.rotation.y = lerp_angle(_model.rotation.y, target_yaw, minf(1.0, delta * 6.0))
	if pose != _pose:
		_pose = pose
		_play_pose(pose)
	if not _has_model:
		_placeholder_motion(pose, delta)
	else:
		var skew := float(_anchor.pose_skew) if "pose_skew" in _anchor else 0.0
		_model.rotation.x = lerpf(_model.rotation.x, -skew * 0.6, minf(1.0, delta * 6.0))


func _play_pose(pose: String) -> void:
	if _anim == null:
		return
	for cand in ANIM_CANDIDATES.get(pose, [pose]):
		if _anim.has_animation(cand):
			_anim.get_animation(cand).loop_mode = Animation.LOOP_LINEAR
			_anim.play(cand, 0.25)
			return
	if _anim.has_animation("idle"):
		_anim.play("idle", 0.25)


func _placeholder_motion(pose: String, delta: float) -> void:
	var breath := 1.0 + 0.02 * sin(_t * 1.4)
	var s := Vector3(1.0, breath, 1.0)
	var rot_x := 0.0
	var bob := 0.0
	match pose:
		"walk":
			bob = absf(sin(_t * 7.0)) * _height_m * 0.03
			rot_x = sin(_t * 7.0) * 0.06
		"pull":
			var skew := float(_anchor.pose_skew) if "pose_skew" in _anchor else 0.0
			rot_x = -skew * 0.8
		"stretch":
			s = Vector3(1.0, breath + 0.08 * maxf(0.0, sin(_t * 1.2)), 1.0)
	_model.scale = s
	_model.position.y = bob
	_model.rotation.x = lerpf(_model.rotation.x, rot_x, minf(1.0, delta * 8.0))


static func _find_anim(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var f := _find_anim(c)
		if f != null:
			return f
	return null


static func _find_meshes(n: Node) -> Array:
	var out: Array = []
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		out.append_array(_find_meshes(c))
	return out


static func _combined_aabb(n: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for mi in _find_meshes(n):
		var box: AABB = mi.get_aabb()
		box = mi.global_transform * box if mi.is_inside_tree() else mi.transform * box
		if first:
			result = box
			first = false
		else:
			result = result.merge(box)
	return result
