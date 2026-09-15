extends Node
## 사용자 설정 저장/복원 (user://settings.cfg).
## 창 위치, 볼륨, BGM on/off 를 담당한다. OS 의존 경로는 사용하지 않는다.

const SETTINGS_PATH := "user://settings.cfg"

## 저장된 창 위치. (-1, -1)이면 "저장 안 됨" → 기본 위치 사용.
var window_position: Vector2i = Vector2i(-1, -1)
## 0.0 ~ 1.0 선형 볼륨
var ambient_volume: float = 0.8
var music_volume: float = 0.6
var bgm_enabled: bool = true
## 온라인(Open-Meteo) 바람 관측 사용 여부. 끄면 계절풍 통계만 사용.
var wind_online_enabled: bool = true


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	window_position = cfg.get_value("window", "position", window_position)
	ambient_volume = clampf(float(cfg.get_value("audio", "ambient_volume", ambient_volume)), 0.0, 1.0)
	music_volume = clampf(float(cfg.get_value("audio", "music_volume", music_volume)), 0.0, 1.0)
	bgm_enabled = bool(cfg.get_value("audio", "bgm_enabled", bgm_enabled))
	wind_online_enabled = bool(cfg.get_value("voyage", "wind_online_enabled", wind_online_enabled))


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("window", "position", window_position)
	cfg.set_value("audio", "ambient_volume", ambient_volume)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "bgm_enabled", bgm_enabled)
	cfg.set_value("voyage", "wind_online_enabled", wind_online_enabled)
	var err := cfg.save(SETTINGS_PATH)
	if err != OK:
		push_warning("settings.cfg 저장 실패: %s" % error_string(err))
