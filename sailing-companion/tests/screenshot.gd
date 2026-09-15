extends Node
## 렌더링 확인용: 메인 씬을 띄우고 지정 프레임에 스크린샷을 저장한다.
## 실행 예: xvfb-run godot --path . res://tests/screenshot.tscn -- out=/tmp/shot.png frames=90

var _f := 0
var _main: Node
var _out := "user://screenshot.png"
var _frames := 90
var _chart := false
var _seq := 1
var _every := 6


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out="):
			_out = arg.substr(4)
		elif arg.begins_with("frames="):
			_frames = int(arg.substr(7))
		elif arg == "chart=1":
			_chart = true
		elif arg.begins_with("seq="):
			_seq = int(arg.substr(4))
		elif arg.begins_with("every="):
			_every = int(arg.substr(6))
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(_main)


func _process(_d: float) -> void:
	_f += 1
	if _f == 2 and _chart:
		_main.get_node("UI/ChartInset").visible = true
	if _f >= _frames and (_f - _frames) % _every == 0:
		var idx := (_f - _frames) / _every
		if idx >= _seq:
			get_tree().quit()
			return
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var path := _out if _seq == 1 else _out.get_basename() + "_%03d." % idx + _out.get_extension()
		var err := img.save_png(path)
		print("screenshot ", path, " size=", img.get_size(), " err=", err)
		if _seq == 1:
			get_tree().quit()
