class_name SceneLayout
extends RefCounted
## assets/art/layout.json (generate_scene.py 가 생성) 로더.
## 레이어별 파일·프레임 기준 바운딩 박스·피벗을 제공한다. 프레임은 900x560(창 2배), 화면 좌표는 ×0.5.

const PATH := "res://assets/art/layout.json"
const ART_DIR := "res://assets/art/"

static var _data: Dictionary = {}
static var _loaded: bool = false


static func data() -> Dictionary:
	if not _loaded:
		_loaded = true
		if ResourceLoader.exists(PATH) or FileAccess.file_exists(PATH):
			var f := FileAccess.open(PATH, FileAccess.READ)
			if f != null:
				var parsed: Variant = JSON.parse_string(f.get_as_text())
				if parsed is Dictionary:
					_data = parsed
	return _data


static func available() -> bool:
	return not data().is_empty()


static func has_layer(key: String) -> bool:
	return data().get("layers", {}).has(key)


static func layer(key: String) -> Dictionary:
	return data().get("layers", {}).get(key, {})


static func layer_texture_path(key: String) -> String:
	var l := layer(key)
	return ART_DIR + str(l.get("file", "")) if not l.is_empty() else ""


## 프레임 좌표의 피벗(픽셀).
static func pivot(key: String) -> Vector2:
	var l := layer(key)
	var p: Array = l.get("pivot", [0, 0])
	return Vector2(float(p[0]), float(p[1]))


## 프레임 좌표의 바운딩 박스 원점.
static func origin(key: String) -> Vector2:
	var l := layer(key)
	var b: Array = l.get("bbox", [0, 0, 0, 0])
	return Vector2(float(b[0]), float(b[1]))


static func point(key: String, default: Vector2) -> Vector2:
	var v: Variant = data().get(key, null)
	if v is Array and v.size() >= 2:
		return Vector2(float(v[0]), float(v[1]))
	return default


static func number(key: String, default: float) -> float:
	var v: Variant = data().get(key, null)
	return float(v) if v != null else default


## 프레임(2배) 좌표 → 화면 좌표.
static func to_screen(p: Vector2) -> Vector2:
	return p * 0.5
