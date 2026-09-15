extends PlaceholderSprite
## 돛. 시뮬레이션의 돛 각도·펼침·트림 효율·거스트를 형상으로 표현한다.
## - 붐이 있는 쪽(바람 반대쪽)으로 scale.x 부호가 바뀐다(태킹 때 마스트를 지나 넘어감)
## - 시트를 당기면(각도 작음) 폭이 좁아지고, 풀면 넓어진다
## - 펼침(furl)이 줄면 높이·폭이 줄어든다
## - 트림이 나쁘거나 거스트면 펄럭임(skew)이 커진다

@export var flutter_skew_deg: float = 0.6
@export var flutter_period: float = 3.7
@export var flutter_scale_x: float = 0.004
## 형상 전환 속도(초당 비율).
@export var shape_lerp_speed: float = 1.5

var _base_scale: Vector2
var _t: float = 0.0
var _vis_side: float = -1.0
var _vis_width: float = 1.0
var _vis_furl: float = 1.0
var _vis_luff: float = 0.0


func _ready() -> void:
	super()
	_base_scale = scale


func _process(delta: float) -> void:
	_t += delta
	var k := minf(1.0, delta * shape_lerp_speed)
	var sim: SailingSim = Voyage.sim
	if sim != null:
		var twa := sim.true_wind_angle()
		var side_target := -1.0 if twa > 0.0 else 1.0
		_vis_side = lerpf(_vis_side, side_target, k)
		_vis_width = lerpf(_vis_width, 0.35 + 0.65 * sin(deg_to_rad(clampf(sim.sail_angle, 0.0, 90.0))), k)
		_vis_furl = lerpf(_vis_furl, sim.sail_furl, k)
		var eff := SailingSim.trim_efficiency(absf(twa), sim.sail_angle)
		var luff_target := (1.0 - eff) * 1.5 + Voyage.wind.gust_intensity * 0.8
		_vis_luff = lerpf(_vis_luff, luff_target, minf(1.0, delta * 3.0))

	var a := sin(TAU * _t / flutter_period)
	var b := sin(TAU * _t / (flutter_period * 0.53) + 0.9)
	var fast := sin(TAU * _t / 0.45) * _vis_luff   # 펄럭임: 빠른 떨림
	skew = deg_to_rad(flutter_skew_deg) * (a * 0.7 + b * 0.3) * (1.0 + 3.0 * _vis_luff) + deg_to_rad(1.2) * fast
	var width := _vis_width * (0.6 + 0.4 * _vis_furl) * (1.0 + flutter_scale_x * b)
	var height := 0.55 + 0.45 * _vis_furl
	scale = _base_scale * Vector2(_vis_side * width, height)
