class_name SailingSim
extends RefCounted
## 간이 세일링 시뮬레이션. 씬과 무관한 순수 계산 클래스(헤드리스 테스트 가능).
## - 구간(마리나→마리나, 웨이포인트 경유)을 따라 항해
## - 진풍각(TWA)별 속도 계수(간이 폴라), 돛 각도·펼침에 따른 효율과 힐
## - 항법(오토파일럿 목표): 웨이포인트 방위가 불가 구역이면 자동 태킹
## - 압축 시간: 구간이 약 TARGET_LEG_HOURS 실시간에 끝나도록 time_scale 을 계산
##
## 목표값(target_*)은 "선장 또는 플레이어가 실행해야 할 값"이다. 실제 rudder/sail_* 은
## 실행자가 바꿔야 움직인다. auto_execute_enabled 가 true 면 즉시 실행자를 내장 사용(테스트/초기 단계).

const NO_GO_ANGLE := 40.0
const TACK_ANGLE := 45.0
const NO_GO_MARGIN := 5.0
const TACK_EXIT_HYSTERESIS := 10.0
const TARGET_LEG_HOURS := 1.0
const AVG_SPEED_KN := 6.0
const ARRIVAL_RADIUS_NM := 0.3
const WAYPOINT_RADIUS_NM := 0.5
const MAX_XTE_NM := 2.0
## 시뮬레이션 시간 기준 선회율(도/초).
const TURN_RATE_DEG_PER_S := 2.0
## 속도 관성 시간 상수(시뮬레이션 초).
const SPEED_TAU_S := 20.0
const HEEL_TAU_S := 5.0

const SAIL_ANGLE_MIN := 5.0
const SAIL_ANGLE_MAX := 90.0
const SAIL_FURL_MIN := 0.4
const SAIL_FURL_MAX := 1.0

var wind: WindModel

# ---- 구간
var leg_index: int = 0
var leg_reversed: bool = false
var points: Array = []          # [[lat, lon], ...] 진행 순서
var waypoint_index: int = 1
var leg_distance_nm: float = 0.0
var time_scale: float = 1.0
var start_id: String = ""
var end_id: String = ""

# ---- 배 상태
var lat: float = 0.0
var lon: float = 0.0
var heading: float = 0.0        # 0 = 북, 시계방향(도)
var speed_kn: float = 0.0
var rudder: float = 0.0         # -1(좌) ~ 1(우)
var sail_angle: float = 45.0    # 붐이 중심선에서 벌어진 각(도)
var sail_furl: float = 1.0      # 펼침 0.4~1.0
var heel: float = 0.0           # 도, 양수 = 우현으로 기움
var arrived: bool = false
var sim_time_hours: float = 0.0
var tack_side: int = 0          # 0 = 태킹 아님, ±1 = 바람 기준 방향

# ---- 항법 목표(실행자가 따라야 할 값)
var target_heading: float = 0.0
var target_sail_angle: float = 45.0
var target_sail_furl: float = 1.0
var tacking: bool = false

## true 면 목표를 즉시 실행하는 내장 실행자를 사용.
var auto_execute_enabled: bool = true

var _origin_lat: float = 0.0
var _origin_lon: float = 0.0
var _cos_lat: float = 1.0


func _init(wind_model: WindModel = null) -> void:
	wind = wind_model if wind_model != null else WindModel.new()


# ================================================================ 구간 설정

func start_leg(index: int, reversed: bool) -> void:
	leg_index = index
	leg_reversed = reversed
	points = Marinas.leg_points(index, reversed)
	start_id = Marinas.leg_start_id(index, reversed)
	end_id = Marinas.leg_end_id(index, reversed)
	_origin_lat = points[0][0]
	_origin_lon = points[0][1]
	_cos_lat = cos(deg_to_rad(_origin_lat))
	leg_distance_nm = Marinas.leg_distance_nm(index)
	time_scale = maxf(1.0, leg_distance_nm / (AVG_SPEED_KN * TARGET_LEG_HOURS))
	waypoint_index = 1
	lat = points[0][0]
	lon = points[0][1]
	heading = _bearing(_local(lat, lon), _local(points[1][0], points[1][1]))
	speed_kn = 0.0
	rudder = 0.0
	heel = 0.0
	arrived = false
	tack_side = 0
	sim_time_hours = 0.0
	_update_navigation()
	sail_angle = target_sail_angle
	sail_furl = target_sail_furl


## 도착 마리나에서 다음 구간(무작위, 방금 온 구간 제외)으로 출항.
func start_next_leg(rng: RandomNumberGenerator = null) -> void:
	var options := Marinas.next_legs_from(end_id, leg_index)
	var pick: Dictionary
	if rng != null:
		pick = options[rng.randi_range(0, options.size() - 1)]
	else:
		pick = options[randi() % options.size()]
	start_leg(pick["index"], pick["reversed"])


# ================================================================ 틱

## 시뮬레이션 서브스텝 상한(초). 낮은 FPS × 큰 time_scale 에서도 선회 제어가 안정되도록.
const MAX_SUBSTEP_S := 2.0


## dt_real: 실시간 초. 바람은 실시간으로, 배는 압축 시간으로 진행한다.
func step(dt_real: float) -> void:
	wind.step(dt_real)
	if arrived:
		return
	if auto_execute_enabled:
		_update_navigation()
		auto_execute(dt_real)
	var remaining := dt_real * time_scale
	while remaining > 0.0 and not arrived:
		var dt := minf(remaining, MAX_SUBSTEP_S)
		remaining -= dt
		_integrate(dt)


func _integrate(dt: float) -> void:
	sim_time_hours += dt / 3600.0
	_update_navigation()
	if auto_execute_enabled:
		var err := wrapf(target_heading - heading, -180.0, 180.0)
		rudder = clampf(err / 20.0, -1.0, 1.0)

	# 선회
	heading = wrapf(heading + rudder * TURN_RATE_DEG_PER_S * dt, 0.0, 360.0)

	# 속도
	var twa := true_wind_angle()
	var atwa := absf(twa)
	var target_speed := polar_coefficient(atwa) * base_speed(wind.speed) \
		* trim_efficiency(atwa, sail_angle) * furl_efficiency(wind.speed, sail_furl)
	speed_kn = lerpf(speed_kn, target_speed, minf(1.0, dt / SPEED_TAU_S))

	# 힐
	var heel_target := heel_magnitude(wind.speed, atwa, sail_furl)
	if twa > 0.0:
		heel_target = -heel_target   # 바람이 우현에서 오면 좌현으로 기운다
	heel = lerpf(heel, heel_target, minf(1.0, dt / HEEL_TAU_S))

	# 전진
	var pos := _local(lat, lon)
	var dir := Vector2(sin(deg_to_rad(heading)), cos(deg_to_rad(heading)))
	pos += dir * speed_kn * dt / 3600.0
	var ll := _from_local(pos)
	lat = ll[0]
	lon = ll[1]

	# 웨이포인트/도착
	var wp := _local(points[waypoint_index][0], points[waypoint_index][1])
	var radius := ARRIVAL_RADIUS_NM if waypoint_index == points.size() - 1 else WAYPOINT_RADIUS_NM
	if pos.distance_to(wp) <= radius:
		if waypoint_index >= points.size() - 1:
			arrived = true
			speed_kn = 0.0
		else:
			waypoint_index += 1
			tack_side = 0


## 내장 즉시 실행자: 돛을 목표로 움직인다(실시간 기준 속도). 타는 서브스텝마다 잡는다.
func auto_execute(dt_real: float) -> void:
	sail_angle = move_toward(sail_angle, target_sail_angle, 10.0 * dt_real)
	sail_furl = move_toward(sail_furl, target_sail_furl, 0.1 * dt_real)


# ================================================================ 항법

func _update_navigation() -> void:
	var pos := _local(lat, lon)
	var wp := _local(points[waypoint_index][0], points[waypoint_index][1])
	var d := pos.distance_to(wp)
	var bearing := _bearing(pos, wp)
	var wind_rel := wrapf(bearing - wind.dir, -180.0, 180.0)

	# 히스테리시스: 태킹 진입은 45° 미만, 해제는 55° 초과 (바람이 경계에서 흔들려도 모드가 떨리지 않게)
	var exit_angle := NO_GO_ANGLE + NO_GO_MARGIN + (TACK_EXIT_HYSTERESIS if tacking else 0.0)
	if absf(wind_rel) >= exit_angle:
		target_heading = bearing
		tack_side = 0
		tacking = false
	else:
		tacking = true
		var seg_start := _local(points[waypoint_index - 1][0], points[waypoint_index - 1][1])
		var xte := _cross_track(pos, seg_start, wp)   # 양수 = 항로선의 오른쪽
		if tack_side == 0:
			tack_side = 1 if wind_rel >= 0.0 else -1
		var candidate := wrapf(wind.dir + tack_side * TACK_ANGLE, 0.0, 360.0)
		# 이 택으로 가면 항로선 기준 어느 쪽으로 밀리는가
		var drift_sign := signf(wrapf(candidate - bearing, -180.0, 180.0))
		var limit := minf(MAX_XTE_NM, maxf(0.3, d * 0.35))
		if drift_sign != 0.0 and xte * drift_sign > limit:
			tack_side = -tack_side
			candidate = wrapf(wind.dir + tack_side * TACK_ANGLE, 0.0, 360.0)
		target_heading = candidate

	# 돛 목표: 현재 방위의 진풍각 기준 최적 트림, 풍속 기준 최적 펼침
	target_sail_angle = optimal_sail_angle(absf(true_wind_angle()))
	target_sail_furl = optimal_furl(wind.speed)


# ================================================================ 공식(정적)

## 진풍각(-180~180). 양수 = 바람이 우현에서 온다.
func true_wind_angle() -> float:
	return wrapf(wind.dir - heading, -180.0, 180.0)


## 겉보기 바람 [AWA(도, 부호 동일), AWS(노트)].
func apparent_wind() -> Array:
	var toward := deg_to_rad(wind.dir + 180.0)
	var wind_vel := Vector2(sin(toward), cos(toward)) * wind.speed
	var h := deg_to_rad(heading)
	var boat_vel := Vector2(sin(h), cos(h)) * speed_kn
	var apparent := wind_vel - boat_vel
	var aws := apparent.length()
	if aws < 0.001:
		return [0.0, 0.0]
	var from_dir := rad_to_deg(atan2(-apparent.x, -apparent.y))
	return [wrapf(from_dir - heading, -180.0, 180.0), aws]


static func polar_coefficient(atwa: float) -> float:
	var table := [[0.0, 0.0], [35.0, 0.0], [40.0, 0.2], [45.0, 0.6], [50.0, 0.7], [60.0, 0.8],
		[90.0, 1.0], [120.0, 1.05], [150.0, 0.85], [180.0, 0.7]]
	atwa = clampf(atwa, 0.0, 180.0)
	for i in range(1, table.size()):
		if atwa <= table[i][0]:
			var a: Array = table[i - 1]
			var b: Array = table[i]
			return lerpf(a[1], b[1], (atwa - a[0]) / (b[0] - a[0]))
	return 0.7


## 풍속(노트)에 대한 기준 선속(노트). 12노트 바람 ≈ 6노트.
static func base_speed(tws: float) -> float:
	return clampf(tws * 0.5, 0.0, 8.5)


static func optimal_sail_angle(atwa: float) -> float:
	return clampf(12.0 + (atwa - 40.0) / 140.0 * 73.0, 12.0, 85.0)


static func trim_efficiency(atwa: float, angle: float) -> float:
	var diff := absf(angle - optimal_sail_angle(atwa))
	return 1.0 - 0.7 * clampf(diff / 35.0, 0.0, 1.0)


static func optimal_furl(tws: float) -> float:
	if tws <= 16.0:
		return 1.0
	return clampf(lerpf(1.0, 0.6, (tws - 16.0) / 9.0), 0.6, 1.0)


static func furl_efficiency(tws: float, furl: float) -> float:
	var opt := optimal_furl(tws)
	if furl > opt + 0.05:
		return 0.9   # 과다 펼침: 힐만 커지고 속도는 오히려 손해
	if furl < opt:
		return furl / opt
	return 1.0


static func heel_magnitude(tws: float, atwa: float, furl: float) -> float:
	var lateral := clampf(1.2 - atwa / 180.0, 0.3, 1.0)
	var mag := tws * furl * 0.9 * lateral
	if furl > optimal_furl(tws) + 0.05:
		mag += 5.0
	return clampf(mag, 0.0, 25.0)


# ================================================================ 진행률/정보

## 0~1. 항로선을 따라 지나온 거리 비율.
func progress() -> float:
	if arrived:
		return 1.0
	var done := 0.0
	for i in range(1, waypoint_index):
		done += _local(points[i - 1][0], points[i - 1][1]).distance_to(_local(points[i][0], points[i][1]))
	var seg_start := _local(points[waypoint_index - 1][0], points[waypoint_index - 1][1])
	var seg_end := _local(points[waypoint_index][0], points[waypoint_index][1])
	var seg := seg_end - seg_start
	var t := 0.0
	if seg.length_squared() > 0.0:
		t = clampf((_local(lat, lon) - seg_start).dot(seg) / seg.length_squared(), 0.0, 1.0)
	done += seg.length() * t
	return clampf(done / maxf(leg_distance_nm, 0.001), 0.0, 1.0)


func distance_to_go_nm() -> float:
	return leg_distance_nm * (1.0 - progress())


func to_dict() -> Dictionary:
	return {
		"leg_index": leg_index, "leg_reversed": leg_reversed, "waypoint_index": waypoint_index,
		"lat": lat, "lon": lon, "heading": heading, "speed_kn": speed_kn,
		"sail_angle": sail_angle, "sail_furl": sail_furl, "tack_side": tack_side,
		"sim_time_hours": sim_time_hours, "arrived": arrived,
	}


func from_dict(d: Dictionary) -> void:
	start_leg(int(d.get("leg_index", 0)), bool(d.get("leg_reversed", false)))
	waypoint_index = clampi(int(d.get("waypoint_index", 1)), 1, points.size() - 1)
	lat = float(d.get("lat", lat))
	lon = float(d.get("lon", lon))
	heading = float(d.get("heading", heading))
	speed_kn = float(d.get("speed_kn", 0.0))
	sail_angle = float(d.get("sail_angle", sail_angle))
	sail_furl = float(d.get("sail_furl", sail_furl))
	tack_side = int(d.get("tack_side", 0))
	sim_time_hours = float(d.get("sim_time_hours", 0.0))
	arrived = bool(d.get("arrived", false))
	_update_navigation()


# ================================================================ 좌표 유틸(구간 원점 기준 해리 평면)

func _local(p_lat: float, p_lon: float) -> Vector2:
	return Vector2((p_lon - _origin_lon) * 60.0 * _cos_lat, (p_lat - _origin_lat) * 60.0)


func _from_local(p: Vector2) -> Array:
	return [_origin_lat + p.y / 60.0, _origin_lon + p.x / (60.0 * _cos_lat)]


## 해도 인셋 등 외부에서 쓰는 공개 버전.
func local_position() -> Vector2:
	return _local(lat, lon)


func local_point(index: int) -> Vector2:
	return _local(points[index][0], points[index][1])


static func _bearing(from: Vector2, to: Vector2) -> float:
	var d := to - from
	return wrapf(rad_to_deg(atan2(d.x, d.y)), 0.0, 360.0)


## 항로선(a→b) 기준 점 p 의 부호 있는 횡이탈(해리). 양수 = 진행 방향의 오른쪽.
static func _cross_track(p: Vector2, a: Vector2, b: Vector2) -> float:
	var seg := b - a
	if seg.length_squared() <= 0.0:
		return 0.0
	var n := seg.normalized()
	var rel := p - a
	# 오른쪽 법선: 진행 방향(n) 을 시계방향 90° 회전 → (n.y, -n.x) (y=북 좌표계)
	return rel.dot(Vector2(n.y, -n.x))
