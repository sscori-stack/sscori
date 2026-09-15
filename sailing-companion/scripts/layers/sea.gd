extends PlaceholderSprite
## 바다 레이어. Boat 의 상하 위상과 반대 방향으로 1~2px 움직여 상대 운동감을 주고,
## 조타에 따라 좌우 패럴랙스.

@export var boat_path: NodePath = ^"../Boat"
var boat: Node2D
## Boat 반대 방향 상하 진폭(px).
@export var counter_amplitude: float = 1.5
## heading = ±1 일 때 좌우 최대 픽셀.
@export var parallax_px: float = 60.0

## 강풍일 때 섞을 색(채도 낮고 살짝 어두운 바다).
@export var strong_wind_tint: Color = Color(0.8, 0.84, 0.92)

var _base_position: Vector2


func _ready() -> void:
	super()
	_base_position = position
	boat = get_node_or_null(boat_path) as Node2D


func _process(_delta: float) -> void:
	var bob := 0.0
	if boat != null and "bob_normalized" in boat:
		bob = boat.bob_normalized
	var heading := SailingMain.instance.heading if SailingMain.instance else 0.0
	position = _base_position + Vector2(-heading * parallax_px, -bob * counter_amplitude)
	if Voyage.wind != null:
		var wind_norm := clampf((Voyage.wind.speed - 5.0) / 20.0, 0.0, 1.0)
		modulate = modulate.lerp(Color.WHITE.lerp(strong_wind_tint, wind_norm * 0.6), minf(1.0, _delta * 0.5))
