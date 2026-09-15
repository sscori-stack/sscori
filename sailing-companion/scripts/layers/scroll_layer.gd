extends PlaceholderSprite
## 좌우로 느리게 흐르는 타일링 레이어(구름). 텍스처 반복 + region 스크롤로 구현.
## 조타(heading)에 따라 parallax_px 만큼 좌우 오프셋.

## 스크롤 속도(화면 픽셀/초). 양수 = 왼쪽으로 흐름.
@export var scroll_speed: float = 3.0
## heading = ±1 일 때 좌우로 움직이는 최대 픽셀.
@export var parallax_px: float = 15.0
## 화면 폭보다 여유 있게 그릴 추가 폭(화면 픽셀).
@export var extra_width: float = 20.0

var _scroll: float = 0.0
var _wind_factor: float = 1.0
var _base_position: Vector2
var _tex_width: float = 1.0


func _ready() -> void:
	super()
	pivot_normalized = Vector2.ZERO
	offset = Vector2.ZERO
	_base_position = position
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	region_enabled = true
	_tex_width = maxf(texture.get_size().x, 1.0)
	var view_w := float(SailingMain.WINDOW_SIZE.x)
	var draw_w := (view_w + parallax_px * 2.0 + extra_width) / scale.x
	region_rect = Rect2(0.0, 0.0, draw_w, texture.get_size().y)
	position.x = _base_position.x - parallax_px - extra_width * 0.5


func _process(delta: float) -> void:
	# 풍속에 비례해 빨라지고, 바람이 우현(TWA>0)에서 오면 왼쪽으로(양수), 좌현이면 오른쪽으로 흐른다.
	if Voyage.sim != null:
		var lateral := sin(deg_to_rad(Voyage.sim.true_wind_angle()))
		var target := (0.4 + 0.06 * Voyage.wind.speed) * clampf(lateral * 2.0, -1.0, 1.0)
		_wind_factor = lerpf(_wind_factor, target, minf(1.0, delta * 0.2))
	_scroll = fposmod(_scroll + scroll_speed * _wind_factor * delta / scale.x, _tex_width)
	region_rect.position.x = _scroll
	var heading := SailingMain.instance.heading if SailingMain.instance else 0.0
	position.x = _base_position.x - parallax_px - extra_width * 0.5 - heading * parallax_px
