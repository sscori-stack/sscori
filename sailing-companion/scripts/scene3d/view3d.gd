extends Sprite2D
## 3D 서브뷰포트를 2D 씬 위에 반투명 합성해 보여준다(0.5 배).

@export var viewport_path: NodePath = ^"../../Scene3D"


func _ready() -> void:
	var vp := get_node_or_null(viewport_path) as SubViewport
	if vp == null:
		return
	texture = vp.get_texture()
	centered = false
	scale = Vector2(0.5, 0.5)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
