extends Node2D
## 등대 불빛. Horizon 스프라이트의 자식으로 두고(스프라이트 로컬 좌표) 주기적으로 번쩍인다.

@export var period: float = 4.0
@export var radius: float = 9.0
@export var color: Color = Color(1.0, 0.92, 0.6)

var _t: float = 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var phase := fmod(_t, period) / period
	var flash := pow(maxf(0.0, sin(phase * PI)), 10.0)   # 짧고 부드러운 번쩍임
	if flash < 0.02:
		draw_circle(Vector2.ZERO, radius * 0.25, Color(color.r, color.g, color.b, 0.35))
		return
	draw_circle(Vector2.ZERO, radius * (1.0 + flash * 1.5), Color(color.r, color.g, color.b, 0.12 * flash))
	draw_circle(Vector2.ZERO, radius * 0.6, Color(color.r, color.g, color.b, 0.5 * flash))
	draw_circle(Vector2.ZERO, radius * 0.25, Color(1.0, 1.0, 0.9, 0.9 * flash))
