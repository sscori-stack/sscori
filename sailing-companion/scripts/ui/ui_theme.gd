class_name UiTheme
extends RefCounted
## 목재 톤 UI 테마를 코드로 만든다. assets/fonts/ 에 폰트 파일이 있으면 기본 폰트로 지정(한글 지원).
## 파일이 없으면 Godot 기본 폰트로 폴백한다(이 경우 한글은 표시되지 않는다).

const FONT_DIR := "res://assets/fonts"
const FONT_EXTENSIONS := ["ttf", "otf", "ttc", "woff2"]

const COLOR_CREAM := Color(0.97, 0.92, 0.82)
const COLOR_WOOD := Color(0.45, 0.29, 0.16)
const COLOR_WOOD_LIGHT := Color(0.55, 0.37, 0.21)
const COLOR_WOOD_DARK := Color(0.33, 0.2, 0.11)
const COLOR_WOOD_EDGE := Color(0.72, 0.52, 0.3)

static var korean_font_available: bool = false


## CanvasLayer 아래의 Control 은 Window 테마를 상속하지 않으므로, UI 루트 Control 에 직접 적용한다.
static func apply(ui_root: Control) -> void:
	var theme := Theme.new()
	var font := _find_font()
	if font != null:
		theme.default_font = font
		korean_font_available = true
	theme.default_font_size = 12

	theme.set_stylebox("normal", "Button", _wood_box(COLOR_WOOD, 6.0, 2.0))
	theme.set_stylebox("hover", "Button", _wood_box(COLOR_WOOD_LIGHT, 6.0, 2.0))
	theme.set_stylebox("pressed", "Button", _wood_box(COLOR_WOOD_DARK, 6.0, 2.0))
	theme.set_stylebox("disabled", "Button", _wood_box(COLOR_WOOD_DARK, 6.0, 2.0))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		theme.set_color(state, "Button", COLOR_CREAM)
	theme.set_color("font_color", "Label", COLOR_CREAM)
	theme.set_color("font_color", "CheckButton", COLOR_CREAM)
	theme.set_stylebox("panel", "PopupPanel", _wood_box(COLOR_WOOD_DARK, 8.0))

	ui_root.theme = theme


static func _wood_box(color: Color, margin_h: float = 4.0, margin_v: float = 4.0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(6)
	box.set_border_width_all(1)
	box.border_color = COLOR_WOOD_EDGE
	box.content_margin_left = margin_h
	box.content_margin_right = margin_h
	box.content_margin_top = margin_v
	box.content_margin_bottom = margin_v
	return box


static func _find_font() -> Font:
	if not DirAccess.dir_exists_absolute(FONT_DIR):
		return null
	for file in DirAccess.get_files_at(FONT_DIR):
		var candidate: String = file
		if candidate.ends_with(".import"):
			candidate = candidate.trim_suffix(".import")
		if not FONT_EXTENSIONS.has(candidate.get_extension().to_lower()):
			continue
		var path := FONT_DIR + "/" + candidate
		if ResourceLoader.exists(path, "Font"):
			var font := load(path) as Font
			if font != null:
				return font
	return null
