extends Control
## 실시간 아날로그 시계. 초가 바뀔 때만 다시 그린다.

@export var face_color: Color = Color(0.96, 0.93, 0.86)
@export var rim_color: Color = Color(0.33, 0.2, 0.11)
@export var hand_color: Color = Color(0.25, 0.15, 0.08)
@export var second_hand_color: Color = Color(0.8, 0.25, 0.2)

var _last_second: int = -1


func _ready() -> void:
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(30, 30)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	var second: int = Time.get_time_dict_from_system()["second"]
	if second != _last_second:
		_last_second = second
		queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var r := minf(c.x, c.y) - 1.0
	draw_circle(c, r, face_color)
	draw_arc(c, r, 0.0, TAU, 40, rim_color, 1.5)
	for i in 12:
		var dir := Vector2.from_angle(TAU * i / 12.0)
		draw_line(c + dir * (r - 2.5), c + dir * (r - 1.0), rim_color, 1.0)

	var t := Time.get_time_dict_from_system()
	var hour: float = float(t["hour"] % 12) + float(t["minute"]) / 60.0
	var minute: float = float(t["minute"]) + float(t["second"]) / 60.0
	var second: float = float(t["second"])

	draw_line(c, c + Vector2.from_angle(hour / 12.0 * TAU - PI * 0.5) * r * 0.5, hand_color, 2.0)
	draw_line(c, c + Vector2.from_angle(minute / 60.0 * TAU - PI * 0.5) * r * 0.75, hand_color, 1.5)
	draw_line(c, c + Vector2.from_angle(second / 60.0 * TAU - PI * 0.5) * r * 0.8, second_hand_color, 1.0)
	draw_circle(c, 1.5, hand_color)
