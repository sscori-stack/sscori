extends Node2D
## 하늘 효과: 별 반짝임 + 달 광채 맥동. 텍스처 없이 _draw 로 그린다(화면 좌표).

@export var star_count: int = 16
@export var star_region: Rect2 = Rect2(230, 6, 210, 95)
@export var moon_pos: Vector2 = Vector2(366, 44)
@export var moon_radius: float = 13.0
@export var star_color: Color = Color(1.0, 0.98, 0.85)
@export var glow_color: Color = Color(1.0, 0.93, 0.75)

var _t: float = 0.0
var _stars: Array = []   # [pos, phase, speed, size]


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20240915
	for i in star_count:
		_stars.append([
			Vector2(rng.randf_range(star_region.position.x, star_region.end.x), rng.randf_range(star_region.position.y, star_region.end.y)),
			rng.randf_range(0.0, TAU), rng.randf_range(0.6, 1.6), rng.randf_range(0.8, 1.6),
		])


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	for s in _stars:
		var tw := pow(maxf(0.0, sin(_t * s[2] + s[1])), 3.0)
		var a := 0.15 + 0.85 * tw
		var c := Color(star_color.r, star_color.g, star_color.b, a)
		draw_circle(s[0], s[3], c)
		if tw > 0.7:
			draw_line(s[0] + Vector2(-3, 0), s[0] + Vector2(3, 0), Color(c, a * 0.5), 1.0)
			draw_line(s[0] + Vector2(0, -3), s[0] + Vector2(0, 3), Color(c, a * 0.5), 1.0)
	var pulse := 0.5 + 0.5 * sin(_t * 0.6)
	for i in 3:
		var r := moon_radius * (1.3 + i * 0.55 + pulse * 0.15)
		var a := (0.10 - i * 0.03) * (0.8 + 0.4 * pulse)
		draw_circle(moon_pos, r, Color(glow_color.r, glow_color.g, glow_color.b, a))
