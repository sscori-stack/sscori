extends Node2D
## 선체 옆 물살(거품). 선속에 비례해 흰 줄이 뒤로 흘러간다. Boat 의 자식(로컬 좌표).

@export var count: int = 10
@export var hull_half_width: float = 150.0
@export var color: Color = Color(1.0, 1.0, 1.0, 0.7)

var _parts: Array = []   # [x, y, life, len, side]
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 11
	for i in count:
		_parts.append(_spawn(_rng.randf()))


func _spawn(life: float) -> Array:
	var side := -1.0 if _rng.randf() < 0.5 else 1.0
	return [side * _rng.randf_range(hull_half_width * 0.7, hull_half_width), _rng.randf_range(-6.0, 4.0), life, _rng.randf_range(6.0, 16.0), side]


func _process(delta: float) -> void:
	var sog := 0.0
	if Voyage.sim != null:
		sog = Voyage.sim.speed_kn
	var speed := 4.0 + sog * 5.0
	for i in _parts.size():
		var p: Array = _parts[i]
		p[2] += delta * (0.25 + sog * 0.08)
		p[0] += p[4] * speed * 0.35 * delta
		p[1] += speed * delta
		if p[2] >= 1.0:
			_parts[i] = _spawn(0.0)
	queue_redraw()


func _draw() -> void:
	var sog := 0.0
	if Voyage.sim != null:
		sog = Voyage.sim.speed_kn
	var strength := clampf(sog / 6.0, 0.15, 1.0)
	for p in _parts:
		var a := color.a * strength * sin(p[2] * PI)
		if a <= 0.02:
			continue
		var c := Color(color.r, color.g, color.b, a)
		draw_line(Vector2(p[0], p[1]), Vector2(p[0] + p[4] * p[3] * 0.4, p[1] + p[3] * 0.25), c, 1.5)
