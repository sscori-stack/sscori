extends PanelContainer
## 하단 UI 바. 설정 팝업 열기, 공유 버튼(MVP: 동작 없음), 음악 위젯 상태 갱신.

@onready var _settings_button: Button = %SettingsButton
@onready var _share_button: Button = %ShareButton
@onready var _settings_popup: PopupPanel = %SettingsPopup
@onready var _music_widget: HBoxContainer = %MusicWidget


func _ready() -> void:
	# 우클릭을 포함한 모든 마우스 이벤트를 소비해 배경 드래그가 UI 위에서 시작되지 않게 한다.
	mouse_filter = Control.MOUSE_FILTER_STOP
	_settings_button.pressed.connect(_on_settings_pressed)
	_share_button.pressed.connect(_on_share_pressed)
	_settings_popup.popup_hide.connect(func() -> void: _music_widget.refresh())


func _on_settings_pressed() -> void:
	_settings_popup.popup_centered(Vector2i(220, 170))


func _on_share_pressed() -> void:
	# MVP: 버튼만. 이후 OS.shell_open(URL) 등으로 확장.
	pass
