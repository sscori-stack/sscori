extends PanelContainer
## 하단 UI 바. 설정 팝업 열기, 공유 버튼(MVP: 동작 없음), 음악 위젯 상태 갱신.

@onready var _settings_button: Button = %SettingsButton
@onready var _share_button: Button = %ShareButton
@onready var _settings_popup: PopupPanel = %SettingsPopup
@onready var _music_widget: HBoxContainer = %MusicWidget


func _enter_tree() -> void:
	# 자식들의 _ready 보다 먼저 테마(폰트 유무 포함)를 준비한다.
	UiTheme.apply(self)


func _ready() -> void:
	# 우클릭을 포함한 모든 마우스 이벤트를 소비해 배경 드래그가 UI 위에서 시작되지 않게 한다.
	mouse_filter = Control.MOUSE_FILTER_STOP
	_settings_button.pressed.connect(_on_settings_pressed)
	_share_button.pressed.connect(_on_share_pressed)
	_settings_popup.popup_hide.connect(func() -> void: _music_widget.refresh())
	# 씬 인스턴스화 중 계산된 최소 크기 캐시가 테마 적용 후에도 남을 수 있어 한 번 재계산한다.
	_refresh_minimum_sizes.call_deferred()


func _refresh_minimum_sizes() -> void:
	for child in find_children("*", "Control", true, false):
		child.update_minimum_size()
	update_minimum_size()


func _on_settings_pressed() -> void:
	_settings_popup.popup_centered(Vector2i(220, 200))


func _on_share_pressed() -> void:
	# MVP: 버튼만. 이후 OS.shell_open(URL) 등으로 확장.
	pass
