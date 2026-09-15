class_name WindModel
extends RefCounted
## 진풍(true wind) 모델. 기준값(온라인 관측 또는 계절풍 폴백)에 느린 흔들림과 거스트를 더하고,
## "최소한의 움직임" 보정을 위해 풍속을 클램프한다. 모든 단위: 풍향 = 바람이 불어오는 방향(도), 풍속 = 노트.

const MIN_SPEED_KN := 5.0
const MAX_SPEED_KN := 25.0
const MAX_GUST_KN := 28.0
## 새 기준값으로 바뀌는 데 걸리는 시간(초).
const BASE_BLEND_SECONDS := 90.0

## 외부(관측/폴백)에서 받은 기준 풍향·풍속·거스트 풍속.
var base_dir: float = 315.0
var base_speed: float = 10.0
var base_gust: float = 14.0
## 현재 출력값(거스트·흔들림 반영).
var dir: float = 315.0
var speed: float = 10.0
## 0~1, 거스트 진행 세기(연출용: 돛 펄럭임·소리).
var gust_intensity: float = 0.0
var source: String = "climatology"

var _blend_dir: float = 315.0
var _blend_speed: float = 10.0
var _t: float = 0.0
var _gust_timer: float = 150.0
var _gust_elapsed: float = -1.0
var _gust_duration: float = 30.0
var _gust_factor: float = 1.4
var _gust_dir_shift: float = 10.0
var _rng := RandomNumberGenerator.new()


func _init(seed_value: int = 0) -> void:
	if seed_value != 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()
	_gust_timer = _rng.randf_range(120.0, 300.0)


## 기준값 설정. 즉시 적용하지 않고 BASE_BLEND_SECONDS 에 걸쳐 섞인다.
func set_base(direction_deg: float, speed_kn: float, gust_kn: float = -1.0, from_source: String = "api", immediate: bool = false) -> void:
	base_dir = wrapf(direction_deg, 0.0, 360.0)
	base_speed = clampf(speed_kn, MIN_SPEED_KN, MAX_SPEED_KN)
	base_gust = clampf(gust_kn if gust_kn > 0.0 else base_speed * 1.4, base_speed, MAX_GUST_KN)
	source = from_source
	if immediate:
		_blend_dir = base_dir
		_blend_speed = base_speed
		dir = base_dir
		speed = base_speed


## 계절풍 폴백으로 기준값 설정.
func set_base_from_climatology(region: String, month: int, immediate: bool = false) -> void:
	var c := Marinas.climatology(region, month)
	set_base(c[0], c[1], -1.0, "climatology", immediate)


func step(dt: float) -> void:
	_t += dt
	# 기준값으로 천천히 수렴
	var k := minf(1.0, dt / BASE_BLEND_SECONDS)
	_blend_dir = _lerp_angle_deg(_blend_dir, base_dir, k)
	_blend_speed = lerpf(_blend_speed, base_speed, k)

	# 느린 흔들림(수 분 주기)
	var meander_dir := 8.0 * sin(_t / 610.0) + 4.0 * sin(_t / 173.0 + 1.0)
	var meander_speed := 1.0 + 0.10 * sin(_t / 240.0) + 0.05 * sin(_t / 77.0 + 2.0)

	# 거스트
	_gust_timer -= dt
	if _gust_elapsed < 0.0 and _gust_timer <= 0.0:
		_start_gust()
	var gust_speed_mul := 1.0
	var gust_dir := 0.0
	if _gust_elapsed >= 0.0:
		_gust_elapsed += dt
		var u := _gust_elapsed / _gust_duration
		if u >= 1.0:
			_gust_elapsed = -1.0
			_gust_timer = _rng.randf_range(120.0, 300.0)
			gust_intensity = 0.0
		else:
			# 부드러운 상승(30%) → 유지 → 하강(40%)
			var env: float
			if u < 0.3:
				env = smoothstep(0.0, 1.0, u / 0.3)
			elif u < 0.6:
				env = 1.0
			else:
				env = 1.0 - smoothstep(0.0, 1.0, (u - 0.6) / 0.4)
			gust_intensity = env
			gust_speed_mul = 1.0 + (_gust_factor - 1.0) * env
			gust_dir = _gust_dir_shift * env

	dir = wrapf(_blend_dir + meander_dir + gust_dir, 0.0, 360.0)
	speed = clampf(_blend_speed * meander_speed * gust_speed_mul, MIN_SPEED_KN, MAX_GUST_KN)


func is_gusting() -> bool:
	return _gust_elapsed >= 0.0


## 테스트/연출용: 즉시 거스트 시작.
func trigger_gust() -> void:
	_start_gust()


func _start_gust() -> void:
	_gust_elapsed = 0.0
	_gust_duration = _rng.randf_range(20.0, 40.0)
	# 관측 거스트가 있으면 그 비율을, 없으면 1.3~1.6배
	var ratio := base_gust / maxf(base_speed, 1.0)
	_gust_factor = clampf(ratio, 1.3, 1.6)
	_gust_dir_shift = _rng.randf_range(-15.0, 15.0)


static func _lerp_angle_deg(from: float, to: float, weight: float) -> float:
	return wrapf(from + wrapf(to - from, -180.0, 180.0) * weight, 0.0, 360.0)
