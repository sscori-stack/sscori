extends Node
## 항해 상태 오토로드. SailingSim + WindModel 을 소유하고 매 프레임 진행시킨다.
## 도착하면 DWELL_SECONDS 동안 정박한 뒤 연결된 다음 구간으로 자동 출항한다.

signal leg_started(sim: SailingSim)
signal arrived(marina_id: String)
signal departed(marina_id: String)

## 도착 후 정박 시간(실시간 초).
const DWELL_SECONDS := 300.0

var sim: SailingSim
var wind: WindModel
var moored: bool = false
var dwell_remaining: float = 0.0

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	wind = WindModel.new()
	sim = SailingSim.new(wind)
	start_leg(Marinas.DEFAULT_LEG, false)


func _process(delta: float) -> void:
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


func start_leg(index: int, reversed: bool) -> void:
	sim.start_leg(index, reversed)
	moored = false
	apply_climatology_fallback(true)
	leg_started.emit(sim)
	departed.emit(sim.start_id)


func depart_next() -> void:
	var from_id := sim.end_id
	sim.start_next_leg(_rng)
	moored = false
	apply_climatology_fallback(false)
	leg_started.emit(sim)
	departed.emit(from_id)


## 온라인 바람이 없을 때: 출발 마리나 해역의 이번 달 계절풍을 기준값으로.
func apply_climatology_fallback(immediate: bool) -> void:
	if wind.source == "api":
		return
	var region: String = Marinas.get_marina(sim.start_id).get("region", "ligurian")
	var month: int = Time.get_datetime_dict_from_system()["month"]
	wind.set_base_from_climatology(region, month, immediate)


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
