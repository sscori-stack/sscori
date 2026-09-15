extends PopupPanel
## 설정 팝업: 파도/음악 볼륨 슬라이더, BGM on/off, 종료.

@onready var _ambient_label: Label = %AmbientLabel
@onready var _ambient_slider: HSlider = %AmbientSlider
@onready var _music_label: Label = %MusicLabel
@onready var _music_slider: HSlider = %MusicSlider
@onready var _bgm_check: CheckButton = %BgmCheck
@onready var _wind_online_check: CheckButton = %WindOnlineCheck
@onready var _quit_button: Button = %QuitButton
@onready var _wind_status: Label = %WindStatus
@onready var _route_option: OptionButton = %RouteOption
@onready var _depart_button: Button = %DepartButton

var _route_entries: Array = []   # [{index, reversed}]


func _ready() -> void:
	var ko := UiTheme.korean_font_available
	_ambient_label.text = "파도 소리" if ko else "Waves"
	_music_label.text = "음악" if ko else "Music"
	_bgm_check.text = "BGM 켜기" if ko else "BGM on"
	_wind_online_check.text = "실제 바람(온라인)" if ko else "Online wind"
	_quit_button.text = "종료" if ko else "Quit"
	_depart_button.text = "출항" if ko else "Depart"
	_fill_routes(ko)
	_depart_button.pressed.connect(_on_depart_pressed)

	_ambient_slider.value_changed.connect(func(v: float) -> void: AudioManager.set_ambient_volume(v))
	_music_slider.value_changed.connect(func(v: float) -> void: AudioManager.set_music_volume(v))
	_bgm_check.toggled.connect(func(on: bool) -> void: AudioManager.set_bgm_enabled(on))
	_wind_online_check.toggled.connect(_on_wind_online_toggled)
	_quit_button.pressed.connect(_on_quit_pressed)
	about_to_popup.connect(_sync_from_settings)
	popup_hide.connect(func() -> void: Settings.save_settings())


func _fill_routes(ko: bool) -> void:
	_route_option.clear()
	_route_entries.clear()
	for i in Marinas.LEGS.size():
		for rev in [false, true]:
			var a: Dictionary = Marinas.get_marina(Marinas.leg_start_id(i, rev))
			var b: Dictionary = Marinas.get_marina(Marinas.leg_end_id(i, rev))
			var na: String = a.get("name_ko" if ko else "name", "").get_slice(",", 0)
			var nb: String = b.get("name_ko" if ko else "name", "").get_slice(",", 0)
			_route_option.add_item("%s → %s  (%d nm)" % [na, nb, int(Marinas.leg_distance_nm(i))])
			_route_entries.append({"index": i, "reversed": rev})


func _on_depart_pressed() -> void:
	var sel := _route_option.selected
	if sel < 0 or sel >= _route_entries.size():
		return
	var e: Dictionary = _route_entries[sel]
	Voyage.start_leg(e["index"], e["reversed"])
	hide()


func _sync_from_settings() -> void:
	var sim: SailingSim = Voyage.sim
	if sim != null:
		for i in _route_entries.size():
			if _route_entries[i]["index"] == sim.leg_index and _route_entries[i]["reversed"] == sim.leg_reversed:
				_route_option.select(i)
				break
	_wind_status.text = "wind: %s  %03d° %.0f kn" % [WindService.status_text(), int(Voyage.wind.dir), Voyage.wind.speed]
	_ambient_slider.set_value_no_signal(Settings.ambient_volume)
	_music_slider.set_value_no_signal(Settings.music_volume)
	_bgm_check.set_pressed_no_signal(Settings.bgm_enabled)
	_wind_online_check.set_pressed_no_signal(Settings.wind_online_enabled)


func _on_wind_online_toggled(on: bool) -> void:
	Settings.wind_online_enabled = on
	if on:
		WindService.fetch_now()
	else:
		Voyage.wind.source = "climatology"
		Voyage.apply_climatology_fallback(false)


func _on_quit_pressed() -> void:
	hide()
	Settings.save_settings()
	if SailingMain.instance != null:
		SailingMain.instance.quit_app()
	else:
		get_tree().quit()
