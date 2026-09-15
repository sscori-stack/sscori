extends Node
## 실제 바람 관측: Open-Meteo(무료, 키 불필요)에서 현재 배 위치의 풍향·풍속·거스트를 주기적으로 받아
## Voyage.wind 의 기준값으로 넣는다. 실패하거나 설정에서 끄면 계절풍 폴백이 그대로 유지된다.

signal wind_updated(direction_deg: float, speed_kn: float, gust_kn: float)
signal request_failed(reason: String)

const ENDPOINT := "https://api.open-meteo.com/v1/forecast"
const REFRESH_SECONDS := 1800.0
const RETRY_SECONDS := 300.0
const FIRST_FETCH_DELAY := 3.0
## 연속 실패가 이 횟수를 넘으면 계절풍으로 되돌린다.
const MAX_FAILURES_BEFORE_FALLBACK := 3

var last_success_unix: int = 0
var last_error: String = ""
var consecutive_failures: int = 0

var _http: HTTPRequest
var _timer: float = FIRST_FETCH_DELAY
var _busy: bool = false


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = 15.0
	_http.request_completed.connect(_on_request_completed)
	add_child(_http)


func _process(delta: float) -> void:
	if not Settings.wind_online_enabled or _busy:
		return
	_timer -= delta
	if _timer <= 0.0:
		fetch_now()


## 현재 배 위치 기준으로 즉시 요청.
func fetch_now() -> void:
	if _busy or not Settings.wind_online_enabled:
		return
	var sim: SailingSim = Voyage.sim
	var url := build_url(sim.lat, sim.lon)
	var err := _http.request(url)
	if err != OK:
		_fail("request error %s" % error_string(err))
		return
	_busy = true


static func build_url(lat: float, lon: float) -> String:
	return "%s?latitude=%.3f&longitude=%.3f&current=wind_speed_10m,wind_direction_10m,wind_gusts_10m&wind_speed_unit=kn" % [ENDPOINT, lat, lon]


## 응답 JSON → {dir, speed, gust} 또는 빈 Dictionary.
static func parse_response(body: PackedByteArray) -> Dictionary:
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		return {}
	var data: Variant = json.data
	if not (data is Dictionary) or not data.has("current"):
		return {}
	var current: Dictionary = data["current"]
	if not current.has("wind_direction_10m") or not current.has("wind_speed_10m"):
		return {}
	var dir_v: Variant = current["wind_direction_10m"]
	var spd_v: Variant = current["wind_speed_10m"]
	if dir_v == null or spd_v == null:
		return {}
	var gust_v: Variant = current.get("wind_gusts_10m", null)
	return {
		"dir": float(dir_v),
		"speed": float(spd_v),
		"gust": float(gust_v) if gust_v != null else -1.0,
	}


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_busy = false
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_fail("http result=%d code=%d" % [result, response_code])
		return
	var parsed := parse_response(body)
	if parsed.is_empty():
		_fail("unexpected response")
		return
	apply_observation(parsed["dir"], parsed["speed"], parsed["gust"])
	_timer = REFRESH_SECONDS


## 관측값을 바람 모델에 적용(테스트에서도 직접 호출).
func apply_observation(direction_deg: float, speed_kn: float, gust_kn: float) -> void:
	consecutive_failures = 0
	last_error = ""
	last_success_unix = int(Time.get_unix_time_from_system())
	Voyage.wind.set_base(direction_deg, speed_kn, gust_kn, "api")
	wind_updated.emit(direction_deg, speed_kn, gust_kn)


func _fail(reason: String) -> void:
	last_error = reason
	consecutive_failures += 1
	_timer = RETRY_SECONDS
	if consecutive_failures >= MAX_FAILURES_BEFORE_FALLBACK and Voyage.wind.source == "api":
		Voyage.wind.source = "climatology"
		Voyage.apply_climatology_fallback(false)
	request_failed.emit(reason)


func status_text() -> String:
	if not Settings.wind_online_enabled:
		return "offline"
	if _busy:
		return "fetching"
	if last_success_unix > 0:
		var age := int(Time.get_unix_time_from_system()) - last_success_unix
		return "api %dm ago" % (age / 60)
	return "no data" if last_error == "" else "error"
