class_name WarpSprite
extends Polygon2D
## 텍스처를 격자 메시로 그려 정점을 흔들 수 있는 스프라이트(파도 출렁임, 돛 부풀기 등).
## PlaceholderSprite 와 같은 규칙: texture_path 가 있으면 로드(art_scale 적용), 없으면 단색 플레이스홀더.
## 정점 위치는 텍스처 픽셀 단위이며 pivot_normalized 기준점이 노드 원점이 된다.
## 서브클래스는 displacement(u, v, t) 를 재정의해 각 격자점의 변위(텍스처 픽셀)를 돌려준다.

@export var texture_path: String = ""
@export var art_scale: float = 0.5
@export var placeholder_size: Vector2i = Vector2i(100, 100)
@export var placeholder_color: Color = Color.MAGENTA
@export var pivot_normalized: Vector2 = Vector2(0.5, 1.0)
@export var grid_x: int = 16
@export var grid_y: int = 6
## 변형 갱신 주기(초). 0 이면 매 프레임.
@export var update_interval: float = 0.0

var uses_real_texture: bool = false
var tex_size: Vector2 = Vector2.ONE

var _t: float = 0.0
var _acc: float = 0.0
var _base: PackedVector2Array


func _ready() -> void:
	_setup_texture()
	_build_grid()


func _setup_texture() -> void:
	uses_real_texture = false
	if texture_path != "" and ResourceLoader.exists(texture_path, "Texture2D"):
		var loaded := load(texture_path) as Texture2D
		if loaded != null:
			texture = loaded
			uses_real_texture = true
	if not uses_real_texture:
		var img := Image.create(maxi(placeholder_size.x, 1), maxi(placeholder_size.y, 1), false, Image.FORMAT_RGBA8)
		img.fill(placeholder_color)
		texture = ImageTexture.create_from_image(img)
	tex_size = texture.get_size()
	scale = Vector2.ONE * (art_scale if uses_real_texture else 1.0)


func _build_grid() -> void:
	var verts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var origin := -tex_size * pivot_normalized
	for j in grid_y + 1:
		for i in grid_x + 1:
			var u := float(i) / grid_x
			var v := float(j) / grid_y
			verts.append(origin + Vector2(u * tex_size.x, v * tex_size.y))
			uvs.append(Vector2(u * tex_size.x, v * tex_size.y))
	var polys: Array = []
	for j in grid_y:
		for i in grid_x:
			var a := j * (grid_x + 1) + i
			polys.append(PackedInt32Array([a, a + 1, a + grid_x + 2, a + grid_x + 1]))
	_base = verts
	polygon = verts
	uv = uvs
	polygons = polys


func _process(delta: float) -> void:
	_t += delta
	if update_interval > 0.0:
		_acc += delta
		if _acc < update_interval:
			return
		_acc = 0.0
	_apply_displacement()


func _apply_displacement() -> void:
	var verts := PackedVector2Array()
	verts.resize(_base.size())
	var k := 0
	for j in grid_y + 1:
		var v := float(j) / grid_y
		for i in grid_x + 1:
			var u := float(i) / grid_x
			verts[k] = _base[k] + displacement(u, v, _t)
			k += 1
	polygon = verts


## 격자점 (u, v) ∈ [0,1]² 의 변위(텍스처 픽셀). 서브클래스에서 재정의.
func displacement(_u: float, _v: float, _t_now: float) -> Vector2:
	return Vector2.ZERO
