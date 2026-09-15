extends HBoxContainer
## 음악 위젯: 트랙 이름 표시 + ▼ 버튼으로 BGM on/off.

@export var radio_name: String = "Lo-Fi radio"

@onready var _label: Label = $TrackLabel
@onready var _toggle: IconButton = $ToggleButton


func _ready() -> void:
	_toggle.pressed.connect(_on_toggle_pressed)
	refresh()


func _on_toggle_pressed() -> void:
	AudioManager.toggle_bgm()
	refresh()


func refresh() -> void:
	var track := AudioManager.bgm_track_name()
	if track == "":
		track = "(no bgm file)"
	_label.text = "%s\n%s" % [radio_name, track]
	var on: bool = Settings.bgm_enabled
	_toggle.kind = IconButton.Kind.TRIANGLE_DOWN if on else IconButton.Kind.TRIANGLE_UP
	_label.modulate = Color.WHITE if on else Color(1, 1, 1, 0.55)
