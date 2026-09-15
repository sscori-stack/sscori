extends "res://scripts/boat/breather.gd"
## 고양이 선장 스프라이트. 호흡(Breather)에 더해 포즈를 표현한다.
## assets/art/captain_<pose>.png 가 있으면 텍스처를 바꾸고, 없으면 플레이스홀더 색을 살짝 바꾼다.
## 포즈: idle(헬름에 앉아 바다 보기), walk, pull(줄 당기기), steer(휠 잡기), pet(해달 쓰다듬기), stretch(기지개)

const POSES := ["idle", "walk", "pull", "steer", "pet", "stretch"]

var pose: String = "idle"

var _pose_textures: Dictionary = {}
var _base_color: Color


func _ready() -> void:
	super()
	_base_color = modulate
	var base_dir := texture_path.get_base_dir()
	for p in POSES:
		var path := "%s/captain_%s.png" % [base_dir, p]
		if ResourceLoader.exists(path, "Texture2D"):
			_pose_textures[p] = load(path)
	if uses_real_texture and not _pose_textures.has("idle"):
		_pose_textures["idle"] = texture


func set_pose(new_pose: String) -> void:
	if new_pose == pose:
		return
	pose = new_pose
	if _pose_textures.has(pose):
		texture = _pose_textures[pose]
		offset = -texture.get_size() * pivot_normalized
	elif uses_real_texture and _pose_textures.has("idle"):
		texture = _pose_textures["idle"]
		offset = -texture.get_size() * pivot_normalized
	if not uses_real_texture:
		# 플레이스홀더: 포즈별로 색을 조금 바꿔 상태를 알 수 있게
		match pose:
			"walk": modulate = _base_color.lightened(0.12)
			"pull": modulate = _base_color.darkened(0.15)
			"steer": modulate = _base_color.lerp(Color(1.0, 0.8, 0.5), 0.3)
			"pet": modulate = _base_color.lerp(Color(1.0, 0.75, 0.8), 0.3)
			"stretch": modulate = _base_color.lightened(0.2)
			_: modulate = _base_color
