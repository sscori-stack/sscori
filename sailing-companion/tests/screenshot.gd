extends Node
## 렌더링 확인용: 메인 씬을 띄우고 지정 프레임에 스크린샷을 저장한다.
## 실행 예: xvfb-run godot --path . res://tests/screenshot.tscn -- out=/tmp/shot.png frames=90

var _f := 0
var _main: Node
var _out := "user://screenshot.png"
var _frames := 90
var _chart := false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			_out = arg.substr(4)
		elif arg.begins_with("frames="):
			_frames = int(arg.substr(7))
		elif arg == "chart=1":
			_chart = true
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(_main)


func _process(_d: float) -> void:
	_f += 1
	if _f == 2 and _chart:
		_main.get_node("UI/ChartInset").visible = true
	if _f == _frames:
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var err := img.save_png(_out)
		print("screenshot ", _out, " size=", img.get_size(), " err=", err)
		get_tree().quit()
