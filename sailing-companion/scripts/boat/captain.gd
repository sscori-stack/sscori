extends "res://scripts/boat/breather.gd"
## 고양이 선장 스프라이트. 호흡(Breather)에 더해 포즈를 표현한다.
## assets/art/captain_<pose>.png 가 있으면 텍스처를 바꾸고, 없으면 플레이스홀더 색을 살짝 바꾼다.
## 포즈: idle(헬름에 앉아 바다 보기), walk, pull(줄 당기기), steer(휠 잡기), pet(해달 쓰다듬기), stretch(기지개)

const POSES := ["idle", "walk", "pull", "steer", "pet", "stretch"]

## 포즈별 프레임 속도.
const POSE_FPS := {"idle": 2.0, "walk": 6.0, "pull": 4.0, "steer": 2.0, "pet": 3.0, "stretch": 3.0}

var pose: String = "idle"

var _pose_textures: Dictionary = {}     # pose → 단일 텍스처
var _pose_frames: Dictionary = {}       # pose → [Texture2D, ...] (captain_<pose>_<n>.png)
var _base_color: Color
var _frame_t: float = 0.0
var _frame_i: int = 0


func _ready() -> void:
	super()
	_base_color = modulate
	var base_dir := texture_path.get_base_dir()
	for p in POSES:
		var path := "%s/captain_%s.png" % [base_dir, p]
		if ResourceLoader.exists(path, "Texture2D"):
			_pose_textures[p] = load(path)
		var frames: Array = []
		for i in 8:
			var fpath := "%s/captain_%s_%d.png" % [base_dir, p, i]
			if ResourceLoader.exists(fpath, "Texture2D"):
				frames.append(load(fpath))
		if frames.size() >= 2:
			_pose_frames[p] = frames
	if uses_real_texture and not _pose_textures.has("idle"):
		_pose_textures["idle"] = texture
	_apply_pose_texture()


func _process(delta: float) -> void:
	super(delta)
	if not _pose_frames.has(pose):
		return
	var frames: Array = _pose_frames[pose]
	_frame_t += delta
	if _frame_t >= 1.0 / float(POSE_FPS.get(pose, 3.0)):
		_frame_t = 0.0
		_frame_i = (_frame_i + 1) % frames.size()
		texture = frames[_frame_i]
		offset = -texture.get_size() * pivot_normalized


func _apply_pose_texture() -> void:
	_frame_i = 0
	_frame_t = 0.0
	if _pose_frames.has(pose):
		texture = _pose_frames[pose][0]
	elif _pose_textures.has(pose):
		texture = _pose_textures[pose]
	elif uses_real_texture and _pose_textures.has("idle"):
		texture = _pose_textures["idle"]
	else:
		return
	offset = -texture.get_size() * pivot_normalized


func set_pose(new_pose: String) -> void:
	if new_pose == pose:
		return
	pose = new_pose
	_apply_pose_texture()
	if not uses_real_texture:
		# 플레이스홀더: 포즈별로 색을 조금 바꿔 상태를 알 수 있게
		match pose:
			"walk": modulate = _base_color.lightened(0.12)
			"pull": modulate = _base_color.darkened(0.15)
			"steer": modulate = _base_color.lerp(Color(1.0, 0.8, 0.5), 0.3)
			"pet": modulate = _base_color.lerp(Color(1.0, 0.75, 0.8), 0.3)
			"stretch": modulate = _base_color.lightened(0.2)
			_: modulate = _base_color
