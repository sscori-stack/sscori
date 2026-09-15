extends Node2D
## 마스트 꼭대기 풍향 화살표(윈덱스). 겉보기 풍향(AWA)을 가리킨다: 화살촉이 바람이 불어오는 쪽.
## windex.png 가 있으면 스프라이트(위쪽이 화살촉), 없으면 _draw 로 그린다.

@export var texture_path: String = "res://assets/art/windex.png"
@export var art_scale: float = 0.5
@export var length: float = 14.0
@export var color: Color = Color(0.95, 0.35, 0.25)
@export var turn_speed: float = 2.5

var _sprite: Sprite2D
var _angle: float = 0.0


func _ready() -> void:
	if texture_path != "" and ResourceLoader.exists(texture_path, "Texture2D"):
		_sprite = Sprite2D.new()
		_sprite.texture = load(texture_path)
		_sprite.scale = Vector2.ONE * art_scale
		add_child(_sprite)


func _process(delta: float) -> void:
	var sim: SailingSim = Voyage.sim
	if sim == null:
		return
	var awa: float = sim.apparent_wind()[0]
	_angle = lerp_angle(_angle, deg_to_rad(awa), minf(1.0, delta * turn_speed))
	rotation = _angle
	if _sprite == null:
		queue_redraw()


func _draw() -> void:
	if _sprite != null:
		return
	# 위(-y) = 뱃머리. 회전은 AWA 만큼: 양수(우현)면 시계방향.
	var tip := Vector2(0, -length)
	draw_line(Vector2(0, length * 0.5), tip, color, 2.0)
	draw_line(tip, tip + Vector2(-3.5, 4.5), color, 2.0)
	draw_line(tip, tip + Vector2(3.5, 4.5), color, 2.0)
	draw_circle(Vector2.ZERO, 1.8, color.darkened(0.3))
