extends Node
## 오디오 2채널(Waves 루프 → Ambient 버스, Bgm 루프 → Music 버스) + 종소리.
## 파일이 없으면 에러 없이 조용히 건너뛴다. 볼륨은 Settings 의 선형 값을 dB 로 변환한다.

const WAVES_PATH := "res://assets/audio/waves_loop.ogg"
const BGM_PATH := "res://assets/audio/bgm_lofi.ogg"
const BELL_PATH := "res://assets/audio/bell.ogg"

const BUS_AMBIENT := "Ambient"
const BUS_MUSIC := "Music"

## 파도 소리 변조 폭(dB). Boat 상하 위상 -1~1 에 곱한다.
const WAVES_MOD_DB := 1.5
## 변조 값을 따라가는 속도(초당). 갑작스런 변화 방지.
const WAVES_MOD_SMOOTH := 3.0

var waves: AudioStreamPlayer
var bgm: AudioStreamPlayer
var bell: AudioStreamPlayer

var _waves_mod_target: float = 0.0
var _waves_mod: float = 0.0
var _wind_db_target: float = 0.0
var _wind_db: float = 0.0


func _ready() -> void:
	_ensure_bus(BUS_AMBIENT)
	_ensure_bus(BUS_MUSIC)

	waves = _make_player("Waves", WAVES_PATH, BUS_AMBIENT, true)
	bgm = _make_player("Bgm", BGM_PATH, BUS_MUSIC, true)
	bell = _make_player("Bell", BELL_PATH, BUS_MUSIC, false)

	apply_settings()
	if waves.stream != null:
		waves.play()
	if bgm.stream != null and Settings.bgm_enabled:
		bgm.play()


func _process(delta: float) -> void:
	if waves.stream == null:
		return
	_waves_mod = lerpf(_waves_mod, _waves_mod_target, minf(1.0, delta * WAVES_MOD_SMOOTH))
	_wind_db = lerpf(_wind_db, _wind_db_target, minf(1.0, delta * 0.5))
	waves.volume_db = _linear_db(Settings.ambient_volume) + _waves_mod + _wind_db


# ---------------------------------------------------------------- 외부 API

## Main 이 매 프레임 Boat 의 상하 위상(-1~1)을 넘긴다.
func set_wave_phase(normalized: float) -> void:
	_waves_mod_target = clampf(normalized, -1.0, 1.0) * WAVES_MOD_DB


## 풍속(노트)·거스트 세기(0~1)에 따라 파도 소리를 최대 +3dB/+2dB 키운다.
func set_wind(speed_kn: float, gust_intensity: float) -> void:
	var norm := clampf((speed_kn - 5.0) / 20.0, 0.0, 1.0)
	_wind_db_target = norm * 3.0 + clampf(gust_intensity, 0.0, 1.0) * 2.0


func set_ambient_volume(linear: float) -> void:
	Settings.ambient_volume = clampf(linear, 0.0, 1.0)
	apply_settings()


func set_music_volume(linear: float) -> void:
	Settings.music_volume = clampf(linear, 0.0, 1.0)
	apply_settings()


func set_bgm_enabled(enabled: bool) -> void:
	Settings.bgm_enabled = enabled
	if bgm.stream == null:
		return
	if enabled and not bgm.playing:
		bgm.play()
	elif not enabled and bgm.playing:
		bgm.stop()


func toggle_bgm() -> void:
	set_bgm_enabled(not Settings.bgm_enabled)


func play_bell() -> void:
	if bell.stream != null:
		bell.play()


## 표시용 트랙 이름(파일명 기반). 파일이 없으면 빈 문자열.
func bgm_track_name() -> String:
	if bgm.stream == null:
		return ""
	return BGM_PATH.get_file().get_basename().replace("_", " ").capitalize()


func apply_settings() -> void:
	waves.volume_db = _linear_db(Settings.ambient_volume) + _waves_mod
	bgm.volume_db = _linear_db(Settings.music_volume)
	bell.volume_db = _linear_db(Settings.music_volume)


# ---------------------------------------------------------------- 내부

func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	var idx := AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")


func _make_player(player_name: String, path: String, bus: String, loop: bool) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.bus = bus
	add_child(player)
	if ResourceLoader.exists(path, "AudioStream"):
		var stream := load(path) as AudioStream
		if stream != null:
			if loop:
				# OGG/MP3 는 loop 프로퍼티, WAV 는 loop_mode. 없는 프로퍼티면 set 은 무시된다.
				stream.set("loop", true)
				if stream is AudioStreamWAV:
					stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			player.stream = stream
	return player


static func _linear_db(linear: float) -> float:
	if linear <= 0.0001:
		return -80.0
	return linear_to_db(linear)
