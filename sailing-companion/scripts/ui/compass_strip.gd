extends Control
## 상단 나침반 띠. 현재 방위(COG)를 중앙에, 10° 눈금과 30° 라벨을 좌우로 보여준다.

@export var degrees_visible: float = 120.0
@export var text_color: Color = Color(1, 1, 1, 0.9)
@export var bg_color: Color = Color(0.2, 0.12, 0.06, 0.55)

var _heading: float = 0.0
var _shown: float = -1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	var sim: SailingSim = Voyage.sim
	if sim == null:
		return
	_heading = _lerp_angle_deg(_heading, sim.heading, minf(1.0, delta * 3.0))
	if absf(wrapf(_heading - _shown, -180.0, 180.0)) > 0.2:
		_shown = _heading
		queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(0, 0, w, h), bg_color)
	var font := get_theme_default_font()
	var px_per_deg := w / degrees_visible
	var start := _heading - degrees_visible * 0.5
	var first := int(floor(start / 10.0)) * 10
	for d in range(first, first + int(degrees_visible) + 20, 10):
		var x := (d - start) * px_per_deg
		if x < 0.0 or x > w:
			continue
		var deg := wrapi(d, 0, 360)
		var major := deg % 30 == 0
		draw_line(Vector2(x, h), Vector2(x, h - (5.0 if major else 2.5)), text_color, 1.0)
		if major:
			var label := _label_for(deg)
			var size_px := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, 8)
			draw_string(font, Vector2(x - size_px.x * 0.5, h - 6.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, text_color)
	# 중앙 마커
	var cx := w * 0.5
	draw_colored_polygon(PackedVector2Array([Vector2(cx - 4, 0), Vector2(cx + 4, 0), Vector2(cx, 5)]), Color(1.0, 0.85, 0.4))


static func _label_for(deg: int) -> String:
	match deg:
		0: return "N"
		90: return "E"
		180: return "S"
		270: return "W"
	return str(deg)


static func _lerp_angle_deg(from: float, to: float, weight: float) -> float:
	return wrapf(from + wrapf(to - from, -180.0, 180.0) * weight, 0.0, 360.0)
