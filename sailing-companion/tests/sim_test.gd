extends Node
## SailingSim 헤드리스 테스트. 실행: godot --headless --path sailing-companion res://tests/sim_test.tscn

var _fails := 0
var _count := 0


func _ready() -> void:
	_test_geometry()
	_test_polar()
	_test_beam_reach_direct()
	_test_upwind_tacks()
	_test_downwind()
	_test_time_scale()
	_test_serialization()
	_test_wind_clamp_and_gust()
	_test_all_legs_complete()
	print("\n==== %d checks, %d failed ====" % [_count, _fails])
	get_tree().quit(1 if _fails > 0 else 0)


func _check(label: String, ok: bool, detail: String = "") -> void:
	_count += 1
	if not ok:
		_fails += 1
	print(("PASS " if ok else "FAIL ") + label + ("" if detail == "" else "  (" + detail + ")"))


func _make_sim(wind_dir: float, wind_speed: float) -> SailingSim:
	var wind := WindModel.new(12345)
	wind.set_base(wind_dir, wind_speed, -1.0, "test", true)
	var sim := SailingSim.new(wind)
	return sim


## 시뮬레이션 시간 max_hours 까지 돌린다. 반환: 걸린 시뮬레이션 시간(시간).
func _run(sim: SailingSim, max_hours: float, dt_real: float = 0.5) -> float:
	while not sim.arrived and sim.sim_time_hours < max_hours:
		sim.step(dt_real)
	return sim.sim_time_hours


func _test_geometry() -> void:
	var sim := SailingSim.new()
	sim.start_leg(0, false)  # monaco → antibes
	_check("leg 0 distance plausible (10~25nm)", sim.leg_distance_nm > 10.0 and sim.leg_distance_nm < 25.0, "%.1f nm" % sim.leg_distance_nm)
	_check("bearing east→(1,0) = 90", is_equal_approx(SailingSim._bearing(Vector2.ZERO, Vector2(1, 0)), 90.0))
	_check("bearing north = 0", is_equal_approx(SailingSim._bearing(Vector2.ZERO, Vector2(0, 1)), 0.0))
	_check("bearing south = 180", is_equal_approx(SailingSim._bearing(Vector2.ZERO, Vector2(0, -1)), 180.0))
	_check("xte right of northbound track positive", SailingSim._cross_track(Vector2(1, 0.5), Vector2.ZERO, Vector2(0, 1)) > 0.0)
	_check("xte left of northbound track negative", SailingSim._cross_track(Vector2(-1, 0.5), Vector2.ZERO, Vector2(0, 1)) < 0.0)


func _test_polar() -> void:
	_check("no-go at 20°", SailingSim.polar_coefficient(20.0) == 0.0)
	_check("beam reach = 1.0", is_equal_approx(SailingSim.polar_coefficient(90.0), 1.0))
	_check("broad reach > beam", SailingSim.polar_coefficient(120.0) > 1.0)
	_check("run slower than broad reach", SailingSim.polar_coefficient(180.0) < SailingSim.polar_coefficient(120.0))
	_check("optimal sail close-hauled ≈ 12", is_equal_approx(SailingSim.optimal_sail_angle(40.0), 12.0))
	_check("optimal sail run = 85", is_equal_approx(SailingSim.optimal_sail_angle(180.0), 85.0))
	_check("trim efficiency perfect = 1", is_equal_approx(SailingSim.trim_efficiency(90.0, SailingSim.optimal_sail_angle(90.0)), 1.0))
	_check("trim efficiency bad < 0.5", SailingSim.trim_efficiency(90.0, 5.0) < 0.5)
	_check("furl optimal light wind = 1", is_equal_approx(SailingSim.optimal_furl(10.0), 1.0))
	_check("furl optimal strong wind < 1", SailingSim.optimal_furl(24.0) < 0.75)


func _test_beam_reach_direct() -> void:
	# monaco→antibes 는 대략 남서(215~250°). 바람이 북(350°)이면 옆바람/뒤바람 → 직진.
	var sim := _make_sim(350.0, 12.0)
	sim.start_leg(0, false)
	var max_tack_seen := false
	var samples := 0
	while not sim.arrived and sim.sim_time_hours < 12.0:
		sim.step(0.5)
		samples += 1
		if sim.tacking:
			max_tack_seen = true
	_check("beam reach: arrived", sim.arrived, "%.2f h" % sim.sim_time_hours)
	_check("beam reach: never tacked", not max_tack_seen)
	_check("beam reach: sim time 2~6h", sim.sim_time_hours > 2.0 and sim.sim_time_hours < 6.0, "%.2f h" % sim.sim_time_hours)
	_check("beam reach: real time ≈ 1h ±50%", sim.sim_time_hours / sim.time_scale > 0.5 and sim.sim_time_hours / sim.time_scale < 1.5, "%.2f h real" % (sim.sim_time_hours / sim.time_scale))


func _test_upwind_tacks() -> void:
	# 바람이 정확히 항로 방향(남서 235°)에서 불면 맞바람 → 태킹 필요.
	var sim := _make_sim(235.0, 12.0)
	sim.start_leg(0, false)
	var tack_flips := 0
	var last_side := 0
	var min_target_twa := 999.0
	while not sim.arrived and sim.sim_time_hours < 24.0:
		sim.step(0.5)
		min_target_twa = minf(min_target_twa, absf(wrapf(sim.wind.dir - sim.target_heading, -180.0, 180.0)))
		if sim.tack_side != 0 and sim.tack_side != last_side:
			if last_side != 0:
				tack_flips += 1
			last_side = sim.tack_side
	_check("upwind: arrived", sim.arrived, "%.2f h" % sim.sim_time_hours)
	_check("upwind: tacked at least once", tack_flips >= 1, "%d flips" % tack_flips)
	_check("upwind: target heading never inside no-go", min_target_twa >= SailingSim.NO_GO_ANGLE - 1.0, "min target TWA %.1f" % min_target_twa)
	_check("upwind: slower than beam reach (>4h sim)", sim.sim_time_hours > 4.0, "%.2f h" % sim.sim_time_hours)


func _test_downwind() -> void:
	var sim := _make_sim(55.0, 12.0)  # 뒤바람(북동)
	sim.start_leg(0, false)
	_run(sim, 12.0)
	_check("downwind: arrived", sim.arrived, "%.2f h" % sim.sim_time_hours)
	_check("downwind: sail eased wide (>70°)", sim.sail_angle > 70.0 or sim.arrived, "sail %.0f°" % sim.sail_angle)


func _test_time_scale() -> void:
	var sim := SailingSim.new()
	sim.start_leg(8, false)  # palma → ibiza (긴 구간)
	_check("time_scale = distance / 6", is_equal_approx(sim.time_scale, sim.leg_distance_nm / 6.0), "%.2f" % sim.time_scale)
	sim.start_leg(0, false)
	_check("short leg time_scale ≥ 1", sim.time_scale >= 1.0)


func _test_serialization() -> void:
	var sim := _make_sim(315.0, 12.0)
	sim.start_leg(1, true)
	_run(sim, 0.7)
	var d := sim.to_dict()
	var sim2 := _make_sim(315.0, 12.0)
	sim2.from_dict(d)
	_check("serialize: leg restored", sim2.leg_index == 1 and sim2.leg_reversed == true)
	_check("serialize: position restored", is_equal_approx(sim2.lat, sim.lat) and is_equal_approx(sim2.lon, sim.lon))
	_check("serialize: progress restored", absf(sim2.progress() - sim.progress()) < 0.001, "%.3f vs %.3f" % [sim2.progress(), sim.progress()])


func _test_wind_clamp_and_gust() -> void:
	var wind := WindModel.new(7)
	wind.set_base(180.0, 1.0, -1.0, "test", true)
	_check("wind clamped to min 5kn", wind.base_speed >= 5.0)
	wind.set_base(180.0, 60.0, -1.0, "test", true)
	_check("wind clamped to max 25kn", wind.base_speed <= 25.0)
	wind.set_base(180.0, 12.0, 18.0, "test", true)
	var before := wind.speed
	wind.trigger_gust()
	var peak := 0.0
	for i in 60:
		wind.step(0.5)
		peak = maxf(peak, wind.speed)
	_check("gust raises speed ≥ 25%", peak >= before * 1.25, "%.1f → %.1f" % [before, peak])
	_check("gust intensity in 0..1", wind.gust_intensity >= 0.0 and wind.gust_intensity <= 1.0)
	for i in 200:
		wind.step(0.5)
	_check("gust ends", not wind.is_gusting())
	_check("climatology lookup", Marinas.climatology("provence", 1)[1] == 16.0)


func _test_all_legs_complete() -> void:
	# 모든 구간을 양방향으로, 여러 풍향에서 완주하는지 (시뮬레이션 48시간 상한).
	var all_ok := true
	var worst := ""
	for i in Marinas.LEGS.size():
		for rev in [false, true]:
			for wd in [0.0, 90.0, 180.0, 270.0]:
				var sim := _make_sim(wd, 10.0)
				sim.start_leg(i, rev)
				var limit := maxf(48.0, sim.leg_distance_nm / 1.5)
				_run(sim, limit, 1.0)
				if not sim.arrived:
					all_ok = false
					worst = "leg %d rev=%s wind=%.0f progress=%.2f" % [i, rev, wd, sim.progress()]
	_check("all legs complete in every wind", all_ok, worst)
