extends PlaceholderSprite
## 캐릭터 호흡. 바닥 피벗 기준으로 scale.y 를 1.00 → 1.0+breath_amount 왕복.
## 들숨(짧게) / 날숨(길게) 비대칭 ease_in_out 곡선.

@export var breath_amount: float = 0.015
@export var breath_period: float = 4.5
## 들숨이 차지하는 비율(0~1). 나머지가 날숨.
@export_range(0.1, 0.9) var inhale_ratio: float = 0.4
## 캐릭터마다 다르게 주어 위상을 어긋나게 한다(초).
@export var phase_offset: float = 0.0

var _base_scale: Vector2
var _t: float = 0.0


func _ready() -> void:
	super()
	_base_scale = scale
	_t = phase_offset


func _process(delta: float) -> void:
	_t += delta
	var u := fmod(_t, breath_period) / breath_period
	var b: float
	if u < inhale_ratio:
		b = _ease_in_out(u / inhale_ratio)
	else:
		b = 1.0 - _ease_in_out((u - inhale_ratio) / (1.0 - inhale_ratio))
	scale = _base_scale * Vector2(1.0, 1.0 + breath_amount * b)


static func _ease_in_out(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)
