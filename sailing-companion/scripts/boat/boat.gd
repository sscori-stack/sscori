class_name Boat
extends Node2D
## 파도 흔들림. 주기가 다른 sin 을 합성해 상하(bob)·롤(rotation)·피칭(scale.y)을 만든다.
## 피벗은 선체 하단 중앙(씬에서 position 으로 지정).

@export_group("Bob (상하)")
@export var bob_amplitude: float = 3.0
@export var bob_period: float = 7.0
@export var bob_amplitude_2: float = 1.0
@export var bob_period_2: float = 4.3

@export_group("Roll (기울기)")
@export var roll_amplitude_deg: float = 1.2
@export var roll_period: float = 10.0
@export var roll_amplitude_2_deg: float = 0.3
@export var roll_period_2: float = 6.1

@export_group("Pitch (scale.y)")
@export var pitch_amplitude: float = 0.004
@export var pitch_period: float = 8.5

## 현재 상하 위상(-1 ~ 1). Sea, AudioManager 가 읽는다.
var bob_normalized: float = 0.0

var _base_position: Vector2
var _t: float = 0.0


func _ready() -> void:
	_base_position = position
	add_to_group("boat")


func _process(delta: float) -> void:
	_t += delta
	var bob_main := sin(TAU * _t / bob_period)
	var bob_sub := sin(TAU * _t / bob_period_2 + 1.3)
	var bob_px := bob_main * bob_amplitude + bob_sub * bob_amplitude_2
	bob_normalized = clampf(bob_px / maxf(bob_amplitude + bob_amplitude_2, 0.001), -1.0, 1.0)

	var roll_deg := sin(TAU * _t / roll_period + 0.7) * roll_amplitude_deg \
		+ sin(TAU * _t / roll_period_2 + 2.1) * roll_amplitude_2_deg

	position = _base_position + Vector2(0.0, bob_px)
	rotation = deg_to_rad(roll_deg)
	scale = Vector2(1.0, 1.0 + sin(TAU * _t / pitch_period + 0.4) * pitch_amplitude)
