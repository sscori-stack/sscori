extends Control
## 접이식 해도. 현재 구간의 항로선·웨이포인트·현재 위치·항적(태킹 궤적)·진풍 화살표·북쪽·축척을 그린다.
## chart_bg.png 가 있으면 배경으로, 없으면 양피지 톤 패널.

@export var texture_path: String = "res://assets/art/chart_bg.png"
@export var margin: float = 14.0
@export var paper_color: Color = Color(0.93, 0.88, 0.76, 0.94)
@export var border_color: Color = Color(0.45, 0.3, 0.16)
@export var route_color: Color = Color(0.35, 0.3, 0.25, 0.8)
@export var trail_color: Color = Color(0.85, 0.35, 0.25, 0.9)
@export var boat_color: Color = Color(0.15, 0.25, 0.5)
@export var text_color: Color = Color(0.3, 0.2, 0.1)
## 항적 샘플 간격(해리).
@export var trail_step_nm: float = 0.15
@export var trail_max_points: int = 400

var _bg: Texture2D
var _trail := PackedVector2Array()
var _leg_key: String = ""
var _redraw_timer: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP   # 우클릭 창 드래그가 해도 위에서 시작되지 않게
	if texture_path != "" and ResourceLoader.exists(texture_path, "Texture2D"):
		_bg = load(texture_path)
	Voyage.leg_started.connect(func(_sim: SailingSim) -> void: _trail.clear(); queue_redraw())


func _process(delta: float) -> void:
	var sim: SailingSim = Voyage.sim
	if sim == null:
		return
	var key := "%d:%s" % [sim.leg_index, sim.leg_reversed]
	if key != _leg_key:
		_leg_key = key
		_trail.clear()
	var pos := sim.local_position()
	if _trail.is_empty() or _trail[_trail.size() - 1].distance_to(pos) >= trail_step_nm:
		_trail.append(pos)
		if _trail.size() > trail_max_points:
			_trail.remove_at(0)
	if not visible:
		return
	_redraw_timer -= delta
	if _redraw_timer <= 0.0:
		_redraw_timer = 0.5
		queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if _bg != null:
		draw_texture_rect(_bg, rect, false)
	else:
		draw_rect(rect, paper_color)
		draw_rect(rect, border_color, false, 2.0)
	var sim: SailingSim = Voyage.sim
	if sim == null or sim.points.size() < 2:
		return

	# 항로 전체가 들어가는 변환(북쪽 위, 등비 축척)
	var pts: Array[Vector2] = []
	for i in sim.points.size():
		pts.append(sim.local_point(i))
	var minp := pts[0]
	var maxp := pts[0]
	for p in pts:
		minp = minp.min(p)
		maxp = maxp.max(p)
	for p in _trail:
		minp = minp.min(p)
		maxp = maxp.max(p)
	var span := (maxp - minp).max(Vector2(0.5, 0.5))
	var inner := size - Vector2(margin * 2.0, margin * 2.0)
	var scale_px := minf(inner.x / span.x, inner.y / span.y)
	var center_nm := (minp + maxp) * 0.5
	var center_px := size * 0.5

	var to_px := func(p: Vector2) -> Vector2:
		var d := (p - center_nm) * scale_px
		return center_px + Vector2(d.x, -d.y)

	# 항로선 + 웨이포인트
	for i in range(1, pts.size()):
		draw_dashed_line(to_px.call(pts[i - 1]), to_px.call(pts[i]), route_color, 1.0, 4.0)
	for i in pts.size():
		var c: Vector2 = to_px.call(pts[i])
		if i == 0 or i == pts.size() - 1:
			draw_circle(c, 3.0, border_color)
		else:
			draw_arc(c, 2.5, 0.0, TAU, 12, route_color, 1.0)
	# 항적
	if _trail.size() >= 2:
		var tp := PackedVector2Array()
		for p in _trail:
			tp.append(to_px.call(p))
		draw_polyline(tp, trail_color, 1.5)
	# 배
	var bp: Vector2 = to_px.call(sim.local_position())
	var h := deg_to_rad(sim.heading)
	var dir := Vector2(sin(h), -cos(h))
	var n := Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([bp + dir * 6.0, bp - dir * 4.0 + n * 3.5, bp - dir * 4.0 - n * 3.5]), boat_color)

	# 이름
	var font := get_theme_default_font()
	var ko := UiTheme.korean_font_available
	var a: Dictionary = Marinas.get_marina(sim.start_id)
	var b: Dictionary = Marinas.get_marina(sim.end_id)
	_label(font, to_px.call(pts[0]) + Vector2(5, -4), a.get("name_ko" if ko else "name", "").get_slice(",", 0))
	_label(font, to_px.call(pts[pts.size() - 1]) + Vector2(5, -4), b.get("name_ko" if ko else "name", "").get_slice(",", 0))

	# 북쪽 + 진풍 화살표(우상단)
	var corner := Vector2(size.x - 14.0, 14.0)
	_label(font, corner + Vector2(-3, -6), "N")
	draw_line(corner + Vector2(0, 8), corner + Vector2(0, -2), text_color, 1.0)
	var wd := deg_to_rad(Voyage.wind.dir)
	var wdir := Vector2(sin(wd), -cos(wd))   # 바람이 불어오는 쪽
	var wc := corner + Vector2(-16, 4)
	draw_line(wc + wdir * 7.0, wc - wdir * 7.0, trail_color, 1.5)
	var tipv := wc - wdir * 7.0
	var wn := Vector2(-wdir.y, wdir.x)
	draw_colored_polygon(PackedVector2Array([tipv, tipv + wdir * 4.0 + wn * 2.5, tipv + wdir * 4.0 - wn * 2.5]), trail_color)

	# 축척(좌하단): 1/2/5/10/20/50 nm 중 40px 이상 되는 최소값
	var nm := 1.0
	for cand in [1.0, 2.0, 5.0, 10.0, 20.0, 50.0, 100.0]:
		nm = cand
		if cand * scale_px >= 40.0:
			break
	var sb := Vector2(8.0, size.y - 8.0)
	draw_line(sb, sb + Vector2(nm * scale_px, 0), text_color, 1.5)
	_label(font, sb + Vector2(0, -3), "%d nm" % int(nm))
	# 진행률(우하단)
	var prog := "%d%%  %.1f nm" % [int(sim.progress() * 100.0), sim.distance_to_go_nm()]
	var sz := font.get_string_size(prog, HORIZONTAL_ALIGNMENT_LEFT, -1, 8)
	_label(font, Vector2(size.x - sz.x - 8.0, size.y - 4.0), prog)


func _label(font: Font, at: Vector2, text: String) -> void:
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, text_color)
