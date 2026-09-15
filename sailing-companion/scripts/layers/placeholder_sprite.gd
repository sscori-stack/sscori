class_name PlaceholderSprite
extends Sprite2D
## 에셋 파일이 있으면 로드하고, 없으면 지정 색의 도형 텍스처를 만들어 표시한다.
## 실제 에셋은 창 2배 해상도(900x560 기준)이므로 로드 시 art_scale(0.5)을 적용한다.
## 플레이스홀더는 창 해상도(450x280) 기준 픽셀 크기로 만든다.

enum Shape { RECT, ELLIPSE, BLOBS }

## 예: "res://assets/art/sky.png". 파일이 있으면 플레이스홀더 대신 사용.
@export var texture_path: String = ""
## 실제 에셋 로드 시 적용할 스케일(2배 해상도 → 0.5).
@export var art_scale: float = 0.5
## 플레이스홀더 크기(창 해상도 기준 픽셀).
@export var placeholder_size: Vector2i = Vector2i(100, 100)
@export var placeholder_color: Color = Color.MAGENTA
## 알파가 0보다 크면 placeholder_color → placeholder_color2 수직 그라데이션(RECT만).
@export var placeholder_color2: Color = Color(0, 0, 0, 0)
@export var placeholder_shape: Shape = Shape.RECT
## 기준점(0~1). (0.5, 1) = 하단 중앙. 노드 position 이 이 점에 놓인다.
@export var pivot_normalized: Vector2 = Vector2(0.5, 0.5)
## layout.json 의 레이어 키. 있으면 파일·위치·피벗을 레이아웃에서 가져온다(부모가 원점에 있어야 한다).
@export var layer_key: String = ""
## false 면 레이아웃의 위치는 쓰지 않고 텍스처·피벗 오프셋만 적용(부모 노드가 위치를 맡는 경우).
@export var layout_sets_position: bool = true

var uses_real_texture: bool = false
var uses_layout: bool = false


func _ready() -> void:
	_setup_texture()


func _setup_texture() -> void:
	uses_real_texture = false
	uses_layout = false
	if layer_key != "" and SceneLayout.has_layer(layer_key):
		var lp := SceneLayout.layer_texture_path(layer_key)
		if ResourceLoader.exists(lp, "Texture2D"):
			texture = load(lp)
			uses_real_texture = true
			uses_layout = true
			scale = Vector2.ONE * art_scale
			centered = false
			offset = -(SceneLayout.pivot(layer_key) - SceneLayout.origin(layer_key))
			if layout_sets_position:
				position = SceneLayout.to_screen(SceneLayout.pivot(layer_key))
			return
	if texture_path != "" and ResourceLoader.exists(texture_path, "Texture2D"):
		var loaded := load(texture_path) as Texture2D
		if loaded != null:
			texture = loaded
			uses_real_texture = true
	if not uses_real_texture:
		texture = _build_placeholder()
	scale = Vector2.ONE * (art_scale if uses_real_texture else 1.0)
	centered = false
	offset = -texture.get_size() * pivot_normalized


func _build_placeholder() -> Texture2D:
	var w: int = maxi(placeholder_size.x, 1)
	var h: int = maxi(placeholder_size.y, 1)
	if placeholder_shape == Shape.RECT and placeholder_color2.a > 0.0:
		return _build_gradient(w, h)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	match placeholder_shape:
		Shape.RECT:
			img.fill(placeholder_color)
		Shape.ELLIPSE:
			_draw_ellipse(img, Vector2(w * 0.5, h * 0.5), Vector2(w * 0.5, h * 0.5), placeholder_color)
		Shape.BLOBS:
			_draw_blobs(img, w, h)
	return ImageTexture.create_from_image(img)


func _build_gradient(w: int, h: int) -> Texture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, placeholder_color)
	gradient.set_color(1, placeholder_color2)
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.width = w
	tex.height = h
	tex.fill_from = Vector2(0.0, 0.0)
	tex.fill_to = Vector2(0.0, 1.0)
	return tex


static func _draw_ellipse(img: Image, center: Vector2, radii: Vector2, color: Color) -> void:
	var x0 := maxi(int(center.x - radii.x), 0)
	var x1 := mini(int(center.x + radii.x) + 1, img.get_width())
	var y0 := maxi(int(center.y - radii.y), 0)
	var y1 := mini(int(center.y + radii.y) + 1, img.get_height())
	for y in range(y0, y1):
		for x in range(x0, x1):
			var dx := (x + 0.5 - center.x) / radii.x
			var dy := (y + 0.5 - center.y) / radii.y
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, color)


## 구름 띠용: 좌우 타일링되도록 양끝을 겹쳐 그린 타원 여러 개.
func _draw_blobs(img: Image, w: int, h: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name)
	var count := maxi(w / 90, 3)
	for _i in count:
		var cx := rng.randf_range(0.0, w)
		var cy := rng.randf_range(h * 0.35, h * 0.65)
		var rx := rng.randf_range(w * 0.06, w * 0.12)
		var ry := rng.randf_range(h * 0.18, h * 0.32)
		for shift in [-w, 0, w]:
			_draw_ellipse(img, Vector2(cx + shift, cy), Vector2(rx, ry), placeholder_color)
