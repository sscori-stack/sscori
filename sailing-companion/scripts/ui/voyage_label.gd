extends Label
## 항해 요약: "출발 → 도착 · 진행률" / "속도 · 바람 출처". 정박 중엔 남은 시간.

var _timer: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh()


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = 1.0
		_refresh()


func _refresh() -> void:
	var sim: SailingSim = Voyage.sim
	if sim == null:
		return
	var ko := UiTheme.korean_font_available
	var a: Dictionary = Marinas.get_marina(sim.start_id)
	var b: Dictionary = Marinas.get_marina(sim.end_id)
	var name_a: String = a.get("name_ko" if ko else "name", sim.start_id)
	var name_b: String = b.get("name_ko" if ko else "name", sim.end_id)
	if not ko:
		name_a = name_a.get_slice(",", 0)
		name_b = name_b.get_slice(",", 0)
	var line1: String
	var line2: String
	if Voyage.moored:
		line1 = ("%s 정박 중" if ko else "Moored at %s") % name_b
		line2 = ("다음 출항까지 %d분" if ko else "Departing in %d min") % maxi(1, int(ceil(Voyage.dwell_remaining / 60.0)))
	else:
		line1 = "%s → %s  %d%%" % [name_a, name_b, int(sim.progress() * 100.0)]
		var src := "live" if Voyage.wind.source == "api" else ("계절풍" if ko else "seasonal")
		line2 = "%.1f kn · %s%s" % [sim.speed_kn, src, ("  태킹" if ko else "  tacking") if sim.tacking else ""]
	text = line1 + "\n" + line2
