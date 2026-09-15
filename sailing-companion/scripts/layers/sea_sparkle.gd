extends Node2D
## 노을 반사 길의 물비늘. 사다리꼴 영역 안의 점들이 반짝이며 천천히 다가온다(화면 좌표).

@export var count: int = 26
@export var top_y: float = 156.0
@export var bottom_y: float = 238.0
@export var top_half_width: float = 22.0
@export var bottom_half_width: float = 110.0
@export var center_x: float = 232.0
@export var color: Color = Color(1.0, 0.95, 0.8)

var _t: float = 0.0
var _pts: Array = []   # [v(0~1), side(-1~1), phase, speed]
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 7
	for i in count:
		_pts.append([_rng.randf(), _rng.randf_range(-1.0, 1.0), _rng.randf_range(0.0, TAU), _rng.randf_range(1.5, 4.0)])


func _process(delta: float) -> void:
	_t += delta
	var sog := 0.0
	if Voyage.sim != null:
		sog = Voyage.sim.speed_kn
	var drift := (0.02 + 0.012 * sog) * delta
	for p in _pts:
		p[0] += drift
		if p[0] > 1.0:
			p[0] -= 1.0
			p[1] = _rng.randf_range(-1.0, 1.0)
			p[2] = _rng.randf_range(0.0, TAU)
	queue_redraw()


func _draw() -> void:
	var heading := SailingMain.instance.heading if SailingMain.instance else 0.0
	for p in _pts:
		var v: float = p[0]
		var half := lerpf(top_half_width, bottom_half_width, v)
		var pos := Vector2(center_x - heading * 40.0 * v + p[1] * half, lerpf(top_y, bottom_y, v))
		var tw := pow(maxf(0.0, sin(_t * p[3] + p[2])), 4.0)
		if tw < 0.05:
			continue
		var size := 0.8 + 1.6 * v
		var c := Color(color.r, color.g, color.b, 0.35 + 0.65 * tw)
		draw_line(pos + Vector2(-size, 0), pos + Vector2(size, 0), c, 1.0)
		draw_line(pos + Vector2(0, -size * 0.6), pos + Vector2(0, size * 0.6), c, 1.0)
