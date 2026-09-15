extends PlaceholderSprite
## 돛. 바람에 아주 미세하게 펄럭이는 느낌(skew + scale.x 미세 변동).

@export var flutter_skew_deg: float = 0.6
@export var flutter_period: float = 3.7
@export var flutter_scale_x: float = 0.004

var _base_scale: Vector2
var _t: float = 0.0


func _ready() -> void:
	super()
	_base_scale = scale


func _process(delta: float) -> void:
	_t += delta
	var a := sin(TAU * _t / flutter_period)
	var b := sin(TAU * _t / (flutter_period * 0.53) + 0.9)
	skew = deg_to_rad(flutter_skew_deg) * (a * 0.7 + b * 0.3)
	scale = _base_scale * Vector2(1.0 + flutter_scale_x * b, 1.0)
