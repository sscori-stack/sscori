class_name IconButton
extends Button
## 아이콘 버튼. texture_path 의 PNG 가 있으면 그것을 아이콘으로 쓰고, 없으면 _draw 로 벡터 아이콘을 그린다.

enum Kind { GEAR, SHARE, TRIANGLE_DOWN, TRIANGLE_UP }

@export var kind: Kind = Kind.GEAR:
	set(value):
		kind = value
		queue_redraw()
@export var texture_path: String = ""
@export var icon_color: Color = Color(0.97, 0.92, 0.82)


func _ready() -> void:
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(30, 30)
	focus_mode = Control.FOCUS_NONE
	if texture_path != "" and ResourceLoader.exists(texture_path, "Texture2D"):
		icon = load(texture_path) as Texture2D
		expand_icon = true
		icon_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _draw() -> void:
	if icon != null:
		return
	var c := size * 0.5
	match kind:
		Kind.GEAR:
			draw_arc(c, 5.0, 0.0, TAU, 24, icon_color, 2.5)
			for i in 8:
				var dir := Vector2.from_angle(TAU * i / 8.0)
				draw_line(c + dir * 6.5, c + dir * 9.5, icon_color, 2.5)
		Kind.SHARE:
			draw_line(c + Vector2(-6, 6), c + Vector2(6, -6), icon_color, 2.0)
			draw_line(c + Vector2(6, -6), c + Vector2(0, -6), icon_color, 2.0)
			draw_line(c + Vector2(6, -6), c + Vector2(6, 0), icon_color, 2.0)
			draw_line(c + Vector2(-6, -2), c + Vector2(-6, 6), icon_color, 2.0)
			draw_line(c + Vector2(-6, 6), c + Vector2(2, 6), icon_color, 2.0)
		Kind.TRIANGLE_DOWN:
			draw_colored_polygon(PackedVector2Array([c + Vector2(-5, -3), c + Vector2(5, -3), c + Vector2(0, 4)]), icon_color)
		Kind.TRIANGLE_UP:
			draw_colored_polygon(PackedVector2Array([c + Vector2(-5, 3), c + Vector2(5, 3), c + Vector2(0, -4)]), icon_color)
