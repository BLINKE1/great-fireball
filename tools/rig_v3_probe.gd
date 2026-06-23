extends SceneTree
## Captura o idle do player_rig_v3 (cabelo-mola) -> frames p/ montar GIF.
##   "$GODOT" --rendering-driver opengl3 -s tools/rig_v3_probe.gd
var _rig
var _cam: Camera2D
var _f := 0
var _shots := 0
var _out := "res://tools/art_director/iterations/rig/cap3/"

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var RigScript = load("res://scripts/player/player_rig_v3.gd")
	_rig = RigScript.new()
	get_root().add_child.call_deferred(_rig)
	_cam = Camera2D.new()
	_cam.position = Vector2(113, 135)
	_cam.zoom = Vector2(1.8, 1.8)
	get_root().add_child.call_deferred(_cam)

func _process(_d: float) -> bool:
	_f += 1
	if _f < 4:
		_cam.make_current()
		return false
	# 24 shots espaçados ~6 frames (cobre ~2 ciclos de idle)
	if _f % 6 == 0:
		var img := get_root().get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path(_out + "f%02d.png" % _shots))
		_shots += 1
		if _shots >= 24:
			print("RIGCAP3: %d shots ✓" % _shots)
			quit(0)
			return true
	return false
