extends Line2D
## 슈라우드에 매단 리본(텔테일). 겉보기 바람 방향으로 흐르며 세기에 따라 펄럭인다.

@export var segments: int = 6
@export var segment_length: float = 4.0
@export var color: Color = Color(0.95, 0.3, 0.3)

var _t: float = 0.0


func _ready() -> void:
	width = 1.5
	default_color = color
	joint_mode = Line2D.LINE_JOINT_ROUND
	end_cap_mode = Line2D.LINE_CAP_ROUND
	_rebuild(0.0, 0.0, 0.0)


func _process(delta: float) -> void:
	_t += delta
	var sim: SailingSim = Voyage.sim
	if sim == null:
		return
	var aw: Array = sim.apparent_wind()
	var awa: float = deg_to_rad(aw[0])
	var strength: float = clampf(aw[1] / 20.0, 0.15, 1.0)
	_rebuild(awa, strength, Voyage.wind.gust_intensity)


func _rebuild(awa: float, strength: float, gust: float) -> void:
	# 바람이 우현(양수)에서 오면 리본은 좌현(-x)으로 흐른다. 앞/뒤에서 오면 아래로 처진다.
	var lateral := -sin(awa)
	var dir := Vector2(lateral * strength, 0.25 + (1.0 - absf(lateral)) * 0.5 + (1.0 - strength) * 0.4).normalized()
	var perp := Vector2(-dir.y, dir.x)
	var pts := PackedVector2Array()
	var p := Vector2.ZERO
	pts.append(p)
	for i in segments:
		var phase := _t * (5.0 + 6.0 * strength + 4.0 * gust) - i * 0.9
		var amp := (0.6 + 2.0 * strength + 1.5 * gust) * (float(i + 1) / segments)
		p += dir * segment_length
		pts.append(p + perp * sin(phase) * amp)
	points = pts
