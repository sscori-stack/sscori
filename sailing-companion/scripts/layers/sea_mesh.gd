extends WarpSprite
## 바다: 격자 메시로 파도가 굴러오게 하고(정점 상하 변위), 텍스처를 앞으로 흘려 전진감을 준다.
## Boat 의 상하 위상과 반대로 살짝 움직이고, 조타 패럴랙스와 풍속 색조도 유지한다.

@export var boat_path: NodePath = ^"../Boat"
var boat: Node2D
@export var counter_amplitude: float = 1.5
@export var parallax_px: float = 60.0
@export var strong_wind_tint: Color = Color(0.8, 0.84, 0.92)
## 파도 진폭(텍스처 픽셀, 수평선 0 → 아래쪽 최대).
@export var wave_amplitude: float = 7.0
## 파도 진행 속도(rad/s) 와 파장(격자 u 기준 파수).
@export var wave_speed: float = 1.1
@export var wave_count: float = 3.0
## 텍스처 흐름 속도(텍스처 픽셀/초) — 선속(노트)에 비례해 커진다.
@export var flow_px_per_knot: float = 5.0
@export var flow_min_px: float = 6.0

var _base_position: Vector2
var _flow: float = 0.0


func _ready() -> void:
	super()
	_base_position = position
	boat = get_node_or_null(boat_path) as Node2D
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED


func _process(delta: float) -> void:
	super(delta)
	var bob := 0.0
	if boat != null and "bob_normalized" in boat:
		bob = boat.bob_normalized
	var heading := SailingMain.instance.heading if SailingMain.instance else 0.0
	position = _base_position + Vector2(-heading * parallax_px, -bob * counter_amplitude)
	# 전진: 텍스처가 아래(관찰자 쪽)로 흐른다
	var sog := 0.0
	if Voyage.sim != null:
		sog = Voyage.sim.speed_kn
	_flow = fposmod(_flow + (flow_min_px + sog * flow_px_per_knot) * delta, tex_size.y)
	texture_offset = Vector2(0.0, -_flow)
	if Voyage.wind != null:
		var wind_norm := clampf((Voyage.wind.speed - 5.0) / 20.0, 0.0, 1.0)
		modulate = modulate.lerp(Color.WHITE.lerp(strong_wind_tint, wind_norm * 0.6), minf(1.0, delta * 0.5))


func displacement(u: float, v: float, t_now: float) -> Vector2:
	# 수평선(v=0)은 고정, 아래로 갈수록 크게. 두 파를 합성해 규칙적이지 않게.
	var amp := wave_amplitude * v * v
	var wind_mul := 1.0
	if Voyage.wind != null:
		wind_mul = 0.7 + 0.6 * clampf((Voyage.wind.speed - 5.0) / 20.0, 0.0, 1.0)
	var y := sin(TAU * (u * wave_count) - t_now * wave_speed) * amp \
		+ sin(TAU * (u * wave_count * 0.53 + v * 0.7) - t_now * wave_speed * 0.71 + 1.3) * amp * 0.5
	return Vector2(0.0, y * wind_mul)
