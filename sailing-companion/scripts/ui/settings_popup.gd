extends PopupPanel
## 설정 팝업: 파도/음악 볼륨 슬라이더, BGM on/off, 종료.

@onready var _ambient_label: Label = %AmbientLabel
@onready var _ambient_slider: HSlider = %AmbientSlider
@onready var _music_label: Label = %MusicLabel
@onready var _music_slider: HSlider = %MusicSlider
@onready var _bgm_check: CheckButton = %BgmCheck
@onready var _wind_online_check: CheckButton = %WindOnlineCheck
@onready var _quit_button: Button = %QuitButton


func _ready() -> void:
	var ko := UiTheme.korean_font_available
	_ambient_label.text = "파도 소리" if ko else "Waves"
	_music_label.text = "음악" if ko else "Music"
	_bgm_check.text = "BGM 켜기" if ko else "BGM on"
	_wind_online_check.text = "실제 바람(온라인)" if ko else "Online wind"
	_quit_button.text = "종료" if ko else "Quit"

	_ambient_slider.value_changed.connect(func(v: float) -> void: AudioManager.set_ambient_volume(v))
	_music_slider.value_changed.connect(func(v: float) -> void: AudioManager.set_music_volume(v))
	_bgm_check.toggled.connect(func(on: bool) -> void: AudioManager.set_bgm_enabled(on))
	_wind_online_check.toggled.connect(_on_wind_online_toggled)
	_quit_button.pressed.connect(_on_quit_pressed)
	about_to_popup.connect(_sync_from_settings)
	popup_hide.connect(func() -> void: Settings.save_settings())


func _sync_from_settings() -> void:
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
