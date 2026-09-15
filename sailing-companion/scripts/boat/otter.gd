extends "res://scripts/boat/breather.gd"
## 해달. 호흡에 더해 otter_<n>.png 프레임이 있으면 느린 프레임 애니메이션(귀 씰룩, 몸 뒤척임).

@export var fps: float = 1.6

var _frames: Array = []
var _frame_t: float = 0.0
var _frame_i: int = 0


func _ready() -> void:
	super()
	var base_dir := texture_path.get_base_dir()
	for i in 8:
		var path := "%s/otter_%d.png" % [base_dir, i]
		if ResourceLoader.exists(path, "Texture2D"):
			_frames.append(load(path))
	if not _frames.is_empty():
		texture = _frames[0]
		offset = -texture.get_size() * pivot_normalized


func _process(delta: float) -> void:
	super(delta)
	if _frames.size() < 2:
		return
	_frame_t += delta
	if _frame_t >= 1.0 / fps:
		_frame_t = 0.0
		_frame_i = (_frame_i + 1) % _frames.size()
		texture = _frames[_frame_i]
