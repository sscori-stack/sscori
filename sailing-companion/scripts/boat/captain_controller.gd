class_name CaptainController
extends Node
## 고양이 선장 = 오토파일럿. 헬름 자리와 윈치(시트) 자리를 느긋하게 오가며 휠을 돌리고 줄을 당긴다.
## 시뮬레이션은 목표값(target_heading / target_sail_*)만 계산하고, 실제 rudder/sail 값은
## 이 컨트롤러(또는 플레이어)가 바꿔야만 움직인다.
##
## 역할 교대: 플레이어가 휠을 잡으면 선장은 돛만 담당(윈치 자리), 플레이어가 돛을 만지면 헬름만 담당.
## 힐링 톤: 서두르지 않는다. 걷기 느림, 줄은 세 번에 나눠 당김, 사이사이 바다 보기·해달 쓰다듬기·기지개.

enum State { IDLE_HELM, STEERING, WALKING, PULLING, IDLE_WINCH, PETTING, STRETCHING, GAZING }

## 손으로 쓴 tscn 에서도 확실히 풀리도록 NodePath 로 받는다.
@export var captain_path: NodePath = ^"../Captain"
@export var otter_path: NodePath = ^"../Otter"
@export var wheel_path: NodePath = ^"../Wheel"

var captain: Node2D
var otter: Node2D
var wheel: Node2D
## 자리(Boat 로컬 좌표).
@export var helm_spot: Vector2 = Vector2(95, -60)
@export var winch_spot: Vector2 = Vector2(18, -56)
@export var otter_spot: Vector2 = Vector2(128, -58)
@export var walk_speed: float = 22.0
## 돛 트림이 이만큼 어긋나야 움직인다(도 / 펼침 비율).
@export var sail_deadband_deg: float = 10.0
@export var furl_deadband: float = 0.1
## 줄 당기기: 횟수, 한 번 당기는 시간, 사이 쉬는 시간.
@export var tug_count: int = 3
@export var tug_duration: float = 0.7
@export var tug_rest: float = 0.9
## 조타 반응(목표 오차 20° 에 타 최대).
@export var steer_gain_deg: float = 20.0
## 손을 놓은 타가 중립으로 돌아가는 시간 상수(초).
@export var rudder_release_tau: float = 6.0
## 여유 행동 간격(초) 범위.
@export var vignette_interval_min: float = 45.0
@export var vignette_interval_max: float = 120.0

var state: State = State.IDLE_HELM
## 현재 선장이 맡은 역할: "both", "sails", "helm"
var role: String = "both"
var at_spot: String = "helm"

var _sim: SailingSim
var _walk_target: Vector2
var _walk_target_name: String = ""
var _after_walk: Callable
var _timer: float = 0.0
var _think_timer: float = 0.0
var _vignette_timer: float = 60.0
var _tug_index: int = 0
var _tug_phase: float = 0.0
var _tug_from_angle: float = 0.0
var _tug_to_angle: float = 0.0
var _tug_from_furl: float = 0.0
var _tug_to_furl: float = 0.0
var _pull_wait: float = 0.0
var _walk_t: float = 0.0
var _rng := RandomNumberGenerator.new()
var _spot_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	_rng.randomize()
	_vignette_timer = _rng.randf_range(vignette_interval_min, vignette_interval_max)
	captain = get_node_or_null(captain_path) as Node2D
	otter = get_node_or_null(otter_path) as Node2D
	wheel = get_node_or_null(wheel_path) as Node2D
	if captain != null:
		captain.position = helm_spot
		_spot_offset = Vector2.ZERO


func _process(delta: float) -> void:
	_sim = Voyage.sim
	if _sim == null or captain == null:
		return
	_sim.auto_execute_enabled = false
	_update_role()
	_think(delta)
	_act(delta)
	_apply_rudder(delta)


# ---------------------------------------------------------------- 역할

func _update_role() -> void:
	var main := SailingMain.instance
	var new_role := "both"
	if main != null:
		if main.player_helm_active():
			new_role = "sails"
		elif main.player_sail_active():
			new_role = "helm"
	if new_role != role:
		role = new_role
		# 역할이 바뀌면 진행 중인 여유 행동은 접고 자기 자리로
		if state in [State.PETTING, State.STRETCHING, State.GAZING]:
			_go_home()


func _home_spot_name() -> String:
	return "winch" if role == "sails" else "helm"


# ---------------------------------------------------------------- 판단(1초에 한 번)

func _think(delta: float) -> void:
	_think_timer -= delta
	_vignette_timer -= delta
	if _think_timer > 0.0:
		return
	_think_timer = 1.0
	if state in [State.WALKING, State.PULLING, State.PETTING, State.STRETCHING, State.GAZING]:
		return

	var need_trim := _needs_trim() and role != "helm"
	var need_steer := role != "sails" and not Voyage.moored

	# 1) 돛이 많이 어긋났으면 윈치로 (이미 있으면 바로 당김)
	if need_trim:
		if at_spot == "winch":
			_start_pull()
		else:
			_walk_to("winch", winch_spot, _start_pull)
		return
	# 2) 헬름 담당인데 헬름에 없으면 돌아간다
	if need_steer and at_spot != "helm":
		_walk_to("helm", helm_spot, func() -> void: state = State.IDLE_HELM)
		return
	# 3) 돛 담당인데 윈치에 없으면 거기서 대기
	if role == "sails" and at_spot != "winch":
		_walk_to("winch", winch_spot, func() -> void: state = State.IDLE_WINCH)
		return
	# 4) 여유 행동
	if _vignette_timer <= 0.0 and role == "both" and not _sim.tacking:
		_vignette_timer = _rng.randf_range(vignette_interval_min, vignette_interval_max)
		_start_vignette()
		return
	state = State.STEERING if (need_steer and at_spot == "helm") else (State.IDLE_WINCH if at_spot == "winch" else State.IDLE_HELM)


## 정박 중엔 돛을 접는 것이 목표.
func _wanted_furl() -> float:
	return SailingSim.SAIL_FURL_MIN if Voyage.moored else _sim.target_sail_furl


func _needs_trim() -> bool:
	if Voyage.moored:
		return _sim.sail_furl > SailingSim.SAIL_FURL_MIN + 0.02
	return absf(_sim.sail_angle - _sim.target_sail_angle) > sail_deadband_deg \
		or absf(_sim.sail_furl - _sim.target_sail_furl) > furl_deadband


func _start_vignette() -> void:
	match _rng.randi_range(0, 2):
		0:
			_walk_to("otter", otter_spot, func() -> void:
				state = State.PETTING
				_timer = 3.5
				captain.set_pose("pet"))
		1:
			state = State.STRETCHING
			_timer = 2.5
			captain.set_pose("stretch")
		_:
			state = State.GAZING
			_timer = _rng.randf_range(4.0, 8.0)
			captain.set_pose("idle")
			captain.facing = -1.0 if _rng.randf() < 0.5 else 1.0


func _go_home() -> void:
	var home := _home_spot_name()
	var spot := winch_spot if home == "winch" else helm_spot
	_walk_to(home, spot, func() -> void: state = State.IDLE_WINCH if home == "winch" else State.IDLE_HELM)


# ---------------------------------------------------------------- 행동

func _walk_to(spot_name: String, spot: Vector2, on_arrive: Callable) -> void:
	_walk_target = spot
	_walk_target_name = spot_name
	_after_walk = on_arrive
	state = State.WALKING
	_walk_t = 0.0
	captain.set_pose("walk")
	captain.facing = 1.0 if spot.x >= captain.position.x else -1.0
	captain.pose_scale = Vector2.ONE
	captain.pose_skew = 0.0


func _start_pull() -> void:
	state = State.PULLING
	_tug_index = 0
	_tug_phase = 0.0
	_pull_wait = _rng.randf_range(0.6, 1.4)   # 줄을 잡기 전 한 박자
	_tug_from_angle = _sim.sail_angle
	_tug_to_angle = _sim.target_sail_angle
	_tug_from_furl = _sim.sail_furl
	_tug_to_furl = _wanted_furl()
	captain.set_pose("pull")
	captain.facing = 1.0


func _act(delta: float) -> void:
	match state:
		State.WALKING:
			_walk_t += delta
			var to_go := _walk_target - captain.position
			var step := walk_speed * delta
			if to_go.length() <= step:
				captain.position = _walk_target
				at_spot = _walk_target_name
				captain.pose_scale = Vector2.ONE
				captain.set_pose("idle")
				# 도착하면 아주 잠깐 멈췄다가 다음 행동
				state = State.IDLE_HELM if at_spot == "helm" else State.IDLE_WINCH
				_think_timer = 0.4
				if _after_walk.is_valid():
					_after_walk.call()
			else:
				captain.position += to_go.normalized() * step
				# 느긋한 걸음: 살짝 위아래
				captain.pose_scale = Vector2(1.0, 1.0 + 0.02 * absf(sin(_walk_t * 7.0)))
		State.PULLING:
			_do_pull(delta)
		State.PETTING, State.STRETCHING, State.GAZING:
			_timer -= delta
			if state == State.STRETCHING:
				var u := clampf(1.0 - _timer / 2.5, 0.0, 1.0)
				captain.pose_scale = Vector2(1.0, 1.0 + 0.06 * sin(u * PI))
			elif state == State.PETTING and otter != null:
				otter.pose_scale = Vector2(1.0 + 0.03 * sin(_timer * 9.0), 1.0)
			if _timer <= 0.0:
				captain.pose_scale = Vector2.ONE
				if otter != null:
					otter.pose_scale = Vector2.ONE
				captain.set_pose("idle")
				captain.facing = 1.0
				_go_home()
		State.STEERING, State.IDLE_HELM:
			captain.set_pose("steer" if state == State.STEERING and absf(_sim.rudder) > 0.05 else "idle")
		State.IDLE_WINCH:
			captain.set_pose("idle")


## 줄 당기기: tug_count 번에 나눠 돛 각도/펼침을 목표로 옮긴다. 각 당김은 ease, 사이에 쉼.
func _do_pull(delta: float) -> void:
	if _pull_wait > 0.0:
		_pull_wait -= delta
		return
	_tug_phase += delta
	var cycle := tug_duration + tug_rest
	if _tug_phase >= cycle:
		_tug_phase -= cycle
		_tug_index += 1
		if _tug_index >= tug_count:
			_sim.sail_angle = _tug_to_angle
			_sim.sail_furl = _tug_to_furl
			captain.pose_skew = 0.0
			captain.set_pose("idle")
			state = State.IDLE_WINCH
			# 당기고 나서 돛을 한 번 올려다보는 시간
			_think_timer = _rng.randf_range(1.5, 3.0)
			return
	var seg_from := float(_tug_index) / tug_count
	var seg_to := float(_tug_index + 1) / tug_count
	var e := _ease(clampf(_tug_phase / tug_duration, 0.0, 1.0))
	var u := lerpf(seg_from, seg_to, e)
	_sim.sail_angle = lerpf(_tug_from_angle, _tug_to_angle, u)
	_sim.sail_furl = lerpf(_tug_from_furl, _tug_to_furl, u)
	# 몸을 뒤로 젖히며 당기는 느낌
	captain.pose_skew = -0.18 * sin(e * PI)


## 타: 헬름에 있고 헬름 담당이면 목표 방위로 천천히 잡는다. 아니면 중립으로 서서히 풀린다(타 고정 느낌).
func _apply_rudder(delta: float) -> void:
	var main := SailingMain.instance
	if main != null and main.player_helm_active():
		return   # 플레이어가 잡고 있다
	var steering := at_spot == "helm" and role != "sails" \
		and state in [State.STEERING, State.IDLE_HELM]
	if steering:
		var err := wrapf(_sim.target_heading - _sim.heading, -180.0, 180.0)
		var target := clampf(err / steer_gain_deg, -1.0, 1.0)
		_sim.rudder = lerpf(_sim.rudder, target, minf(1.0, delta * 1.5))
	else:
		_sim.rudder = lerpf(_sim.rudder, 0.0, minf(1.0, delta / rudder_release_tau))


static func _ease(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)


func state_name() -> String:
	return State.keys()[state]
