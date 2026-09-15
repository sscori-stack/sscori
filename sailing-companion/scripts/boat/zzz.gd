extends Node2D
## 잠든 해달 위로 "z" 가 떠오르며 사라진다. 정박이든 항해든 늘 자는 중.

@export var interval: float = 2.4
@export var rise_px: float = 26.0
@export var life: float = 2.6
@export var color: Color = Color(1.0, 1.0, 1.0, 0.9)

var _t: float = 0.0
var _next: float = 1.0
var _zs: Array = []   # [age, x_wobble_phase]


func _process(delta: float) -> void:
	_t += delta
	_next -= delta
	if _next <= 0.0:
		_next = interval
		_zs.append([0.0, randf() * TAU])
	for z in _zs:
		z[0] += delta
	_zs = _zs.filter(func(z: Array) -> bool: return z[0] < life)
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	for z in _zs:
		var u: float = z[0] / life
		var pos := Vector2(4.0 + sin(u * 4.0 + z[1]) * 4.0 + u * 8.0, -u * rise_px)
		var size := int(8 + u * 6)
		var c := Color(color.r, color.g, color.b, color.a * (1.0 - u) * minf(1.0, u * 5.0))
		draw_string(font, pos, "z", HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)
