extends Control
## 풍향·풍속 위젯. 배를 위쪽으로 두고 겉보기 풍향 화살표(바람이 불어오는 쪽에서 중심으로)를 그리고,
## 아래에 진풍속(노트)을 쓴다. 거스트 중엔 테두리가 따뜻한 색으로 맥동한다.

@export var text_color: Color = Color(1, 1, 1, 0.9)
@export var ring_color: Color = Color(1, 1, 1, 0.55)
@export var gust_color: Color = Color(1.0, 0.75, 0.35)
@export var arrow_color: Color = Color(0.6, 0.85, 1.0)

var _awa: float = 0.0
var _speed: float = 0.0
var _gust: float = 0.0
var _t: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	var sim: SailingSim = Voyage.sim
	if sim == null:
		return
	var aw: Array = sim.apparent_wind()
	_awa = lerp_angle(_awa, deg_to_rad(aw[0]), minf(1.0, delta * 3.0))
	_speed = lerpf(_speed, Voyage.wind.speed, minf(1.0, delta * 2.0))
	_gust = Voyage.wind.gust_intensity
	queue_redraw()


func _draw() -> void:
	var r := minf(size.x, size.y - 12.0) * 0.5 - 1.0
	var c := Vector2(size.x * 0.5, r + 1.0)
	var ring := ring_color.lerp(gust_color, _gust * (0.6 + 0.4 * sin(_t * 6.0)))
	draw_arc(c, r, 0.0, TAU, 40, ring, 1.5)
	# 배(위쪽을 향한 작은 삼각형)
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -5), c + Vector2(-3.5, 4), c + Vector2(3.5, 4)]), Color(1, 1, 1, 0.75))
	# 바람 화살표: 림의 AWA 지점에서 중심 쪽으로
	var from := c + Vector2.from_angle(_awa - PI * 0.5) * (r - 1.0)
	var to := c + Vector2.from_angle(_awa - PI * 0.5) * 7.0
	draw_line(from, to, arrow_color, 2.0)
	var d := (to - from).normalized()
	var n := Vector2(-d.y, d.x)
	draw_colored_polygon(PackedVector2Array([to + d * 2.0, to - d * 4.0 + n * 3.0, to - d * 4.0 - n * 3.0]), arrow_color)
	# 풍속
	var font := get_theme_default_font()
	var label := "%d kn" % int(round(_speed))
	var sz := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, 9)
	draw_string(font, Vector2(size.x * 0.5 - sz.x * 0.5, size.y - 2.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, text_color.lerp(gust_color, _gust))
