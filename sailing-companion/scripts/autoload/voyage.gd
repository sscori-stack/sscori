extends Node
## 항해 상태 오토로드. SailingSim + WindModel 을 소유하고 매 프레임 진행시킨다.
## 도착하면 DWELL_SECONDS 동안 정박한 뒤 연결된 다음 구간으로 자동 출항한다.

signal leg_started(sim: SailingSim)
signal arrived(marina_id: String)
signal departed(marina_id: String)

## 도착 후 정박 시간(실시간 초).
const DWELL_SECONDS := 300.0
const SAVE_PATH := "user://voyage.cfg"
const AUTOSAVE_SECONDS := 30.0
## 저장된 온라인 바람이 이보다 오래되면 무시(초).
const SAVED_WIND_MAX_AGE := 3 * 3600

var _autosave_timer: float = AUTOSAVE_SECONDS

var sim: SailingSim
var wind: WindModel
var moored: bool = false
var dwell_remaining: float = 0.0

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	wind = WindModel.new()
	sim = SailingSim.new(wind)
	if not load_state():
		start_leg(Marinas.DEFAULT_LEG, false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_EXIT_TREE:
		save_state()


func _process(delta: float) -> void:
	_autosave_timer -= delta
	if _autosave_timer <= 0.0:
		_autosave_timer = AUTOSAVE_SECONDS
		save_state()
	if moored:
		wind.step(delta)
		dwell_remaining -= delta
		if dwell_remaining <= 0.0:
			depart_next()
		return
	sim.step(delta)
	if sim.arrived:
		moored = true
		dwell_remaining = DWELL_SECONDS
		arrived.emit(sim.end_id)
		save_state()


func start_leg(index: int, reversed: bool) -> void:
	sim.start_leg(index, reversed)
	moored = false
	apply_climatology_fallback(true)
	leg_started.emit(sim)
	departed.emit(sim.start_id)
	save_state()


func depart_next() -> void:
	var from_id := sim.end_id
	sim.start_next_leg(_rng)
	moored = false
	apply_climatology_fallback(false)
	leg_started.emit(sim)
	departed.emit(from_id)
	save_state()


## 온라인 바람이 없을 때: 출발 마리나 해역의 이번 달 계절풍을 기준값으로.
func apply_climatology_fallback(immediate: bool) -> void:
	if wind.source == "api":
		return
	var region: String = Marinas.get_marina(sim.start_id).get("region", "ligurian")
	var month: int = Time.get_datetime_dict_from_system()["month"]
	wind.set_base_from_climatology(region, month, immediate)


# ---------------------------------------------------------------- 저장/복원

func save_state() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("sim", "state", sim.to_dict())
	cfg.set_value("sim", "moored", moored)
	cfg.set_value("sim", "dwell_remaining", dwell_remaining)
	cfg.set_value("wind", "source", wind.source)
	cfg.set_value("wind", "base_dir", wind.base_dir)
	cfg.set_value("wind", "base_speed", wind.base_speed)
	cfg.set_value("wind", "base_gust", wind.base_gust)
	cfg.set_value("wind", "saved_unix", int(Time.get_unix_time_from_system()))
	var err := cfg.save(SAVE_PATH)
	if err != OK:
		push_warning("voyage.cfg 저장 실패: %s" % error_string(err))


## 저장된 항해가 있으면 복원하고 true. 없거나 깨졌으면 false.
func load_state() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return false
	var state: Variant = cfg.get_value("sim", "state", null)
	if not (state is Dictionary) or not state.has("leg_index"):
		return false
	var leg_index := int(state["leg_index"])
	if leg_index < 0 or leg_index >= Marinas.LEGS.size():
		return false
	sim.from_dict(state)
	moored = bool(cfg.get_value("sim", "moored", false))
	dwell_remaining = float(cfg.get_value("sim", "dwell_remaining", 0.0))
	if moored and dwell_remaining <= 0.0:
		dwell_remaining = 5.0

	var saved_unix := int(cfg.get_value("wind", "saved_unix", 0))
	var age := int(Time.get_unix_time_from_system()) - saved_unix
	if str(cfg.get_value("wind", "source", "")) == "api" and age >= 0 and age < SAVED_WIND_MAX_AGE:
		wind.set_base(float(cfg.get_value("wind", "base_dir", 0.0)), float(cfg.get_value("wind", "base_speed", 10.0)),
			float(cfg.get_value("wind", "base_gust", -1.0)), "api", true)
	else:
		apply_climatology_fallback(true)
	leg_started.emit(sim)
	return true


## 저장 파일 삭제 후 기본 구간부터 새로 시작.
func reset_voyage() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	start_leg(Marinas.DEFAULT_LEG, false)


## 표시용 요약 문자열(디버그/위젯).
func summary_text() -> String:
	var a := Marinas.get_marina(sim.start_id)
	var b := Marinas.get_marina(sim.end_id)
	var state := "정박 %d초" % int(dwell_remaining) if moored else "%d%%" % int(sim.progress() * 100.0)
	return "%s → %s  %s\nWIND %03d° %.1fkn%s  HDG %03d°  SOG %.1fkn\nTWA %+.0f°  SAIL %.0f°/%.0f%%  HEEL %+.0f°%s  x%.1f" % [
		a.get("name_ko", sim.start_id), b.get("name_ko", sim.end_id), state,
		int(wind.dir), wind.speed, " GUST" if wind.is_gusting() else "",
		int(sim.heading), sim.speed_kn,
		sim.true_wind_angle(), sim.sail_angle, sim.sail_furl * 100.0, sim.heel,
		"  TACK" if sim.tacking else "", sim.time_scale]
