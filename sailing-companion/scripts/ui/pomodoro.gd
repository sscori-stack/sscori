extends Button
## 뽀모도로 타이머. 클릭: 시작/일시정지, 길게 누름: 리셋, 종료 시 종소리 1회 + 잠깐 반짝임.

@export var duration_minutes: int = 25
@export var long_press_seconds: float = 0.7
@export var flash_color: Color = Color(1.0, 0.95, 0.6)

var _remaining: float = 0.0
var _running: bool = false
var _press_started_msec: int = -1
var _long_press_fired: bool = false
var _shown_seconds: int = -1
var _flash_tween: Tween


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	toggle_mode = false
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	_reset()


func _process(delta: float) -> void:
	if _press_started_msec >= 0 and not _long_press_fired \
			and (Time.get_ticks_msec() - _press_started_msec) >= int(long_press_seconds * 1000.0):
		_long_press_fired = true
		_reset()
	if _running:
		_remaining = maxf(_remaining - delta, 0.0)
		if _remaining <= 0.0:
			_finish()
	_update_text()


func _on_button_down() -> void:
	_press_started_msec = Time.get_ticks_msec()
	_long_press_fired = false


func _on_button_up() -> void:
	var was_long := _long_press_fired
	_press_started_msec = -1
	_long_press_fired = false
	if was_long:
		return
	_running = not _running
	_update_text()


func _reset() -> void:
	_running = false
	_remaining = float(duration_minutes * 60)
	_shown_seconds = -1
	_update_text()


func _finish() -> void:
	_running = false
	_remaining = float(duration_minutes * 60)
	AudioManager.play_bell()
	_flash()


func _flash() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	modulate = Color.WHITE
	_flash_tween = create_tween().set_loops(3)
	_flash_tween.tween_property(self, "modulate", flash_color, 0.15)
	_flash_tween.tween_property(self, "modulate", Color.WHITE, 0.25)


func _update_text() -> void:
	var seconds := int(ceil(_remaining))
	if seconds == _shown_seconds:
		return
	_shown_seconds = seconds
	var title := "뽀모도로" if UiTheme.korean_font_available else "Pomodoro"
	text = "%s\n%02d:%02d" % [title, seconds / 60, seconds % 60]
	# 일시정지/대기 상태는 살짝 어둡게 표시
	self_modulate = Color.WHITE if _running else Color(0.85, 0.85, 0.85)
