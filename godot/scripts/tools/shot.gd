extends Node
## Test helper: `godot -- --shot=out.png --frames=60 --eval=script.gd` renders, saves a screenshot and quits.

var _out := ""
var _frames := 90
var _n := 0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="): _out = a.substr(7)
		elif a.begins_with("--frames="): _frames = int(a.substr(9))
	if _out == "": set_process(false)

func _process(_dt: float) -> void:
	_n += 1
	if _n == _frames:
		var img := get_viewport().get_texture().get_image()
		img.save_png(_out)
		print("SHOT saved ", _out)
		get_tree().quit()
