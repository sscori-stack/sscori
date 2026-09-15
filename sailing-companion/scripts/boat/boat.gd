class_name Boat
extends Node2D
## 파도 흔들림. 주기가 다른 sin 을 합성해 상하(bob)·롤(rotation)·피칭(scale.y)을 만든다.
## 피벗은 선체 하단 중앙(씬에서 position 으로 지정).

@export_group("Bob (상하)")
@export var bob_amplitude: float = 4.5
@export var bob_period: float = 7.0
@export var bob_amplitude_2: float = 1.0
@export var bob_period_2: float = 4.3

@export_group("Roll (기울기)")
@export var roll_amplitude_deg: float = 2.2
@export var roll_period: float = 10.0
@export var roll_amplitude_2_deg: float = 0.5
@export var roll_period_2: float = 6.1

@export_group("Pitch (scale.y)")
@export var pitch_amplitude: float = 0.004
@export var pitch_period: float = 8.5

@export_group("Wind/Heel")
## 시뮬레이션 힐(도)을 화면 회전(도)으로 바꾸는 배율.
@export var heel_visual_scale: float = 0.45
## 풍속 25kn 일 때 상하 진폭 배율(5kn 일 때 1.0 에서 선형).
@export var wind_bob_multiplier: float = 1.8

@export_group("Cockpit view")
## true 면 배는 거의 고정(bob × cockpit_bob_scale)하고 회전하지 않으며, World 가 대신 기운다.
@export var cockpit_mode: bool = false
@export var cockpit_bob_scale: float = 0.3

## 현재 상하 위상(-1 ~ 1). Sea, AudioManager 가 읽는다.
var bob_normalized: float = 0.0
## 현재 상하 변위(px). World 가 반대로 쓴다.
var bob_px: float = 0.0
## 현재 화면 힐(도), 부드럽게 따라감.
var heel_visual: float = 0.0
## 세계가 기울어야 할 각(도) = 롤 + 힐. cockpit_mode 에서 World 가 읽는다.
var view_roll_deg: float = 0.0

var _base_position: Vector2
var _t: float = 0.0


func _ready() -> void:
	_base_position = position
	add_to_group("boat")


func _process(delta: float) -> void:
	_t += delta
	var wind_norm := 0.0
	if Voyage.wind != null:
		wind_norm = clampf((Voyage.wind.speed - 5.0) / 20.0, 0.0, 1.0)
	var bob_mul := lerpf(1.0, wind_bob_multiplier, wind_norm)
	var bob_main := sin(TAU * _t / bob_period)
	var bob_sub := sin(TAU * _t / bob_period_2 + 1.3)
	bob_px = (bob_main * bob_amplitude + bob_sub * bob_amplitude_2) * bob_mul
	bob_normalized = clampf(bob_px / maxf(bob_amplitude + bob_amplitude_2, 0.001), -1.0, 1.0)

	var roll_deg := sin(TAU * _t / roll_period + 0.7) * roll_amplitude_deg \
		+ sin(TAU * _t / roll_period_2 + 2.1) * roll_amplitude_2_deg

	if Voyage.sim != null:
		heel_visual = lerpf(heel_visual, Voyage.sim.heel * heel_visual_scale, minf(1.0, delta * 1.5))

	view_roll_deg = roll_deg + heel_visual
	if cockpit_mode:
		position = _base_position + Vector2(0.0, bob_px * cockpit_bob_scale)
		rotation = 0.0
	else:
		position = _base_position + Vector2(0.0, bob_px)
		rotation = deg_to_rad(roll_deg + heel_visual)
	scale = Vector2(1.0, 1.0 + sin(TAU * _t / pitch_period + 0.4) * pitch_amplitude)
