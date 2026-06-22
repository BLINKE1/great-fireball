extends SceneTree
## Captura o idle do player_rig_v2 no engine -> frames p/ montar GIF.
##   xvfb-run -a godot --rendering-driver opengl3 -s tools/rig_v2_probe.gd
var _rig
var _cam: Camera2D
var _f := 0
var _shots := 0
var _out := "res://tools/art_director/iterations/rig/cap/"

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var RigScript = load("res://scripts/player/player_rig_v2.gd")
	_rig = RigScript.new()
	get_root().add_child.call_deferred(_rig)
	_cam = Camera2D.new()
	_cam.position = Vector2(59, 123)
	_cam.zoom = Vector2(1.2, 1.2)
	get_root().add_child.call_deferred(_cam)

func _process(_d: float) -> bool:
	_f += 1
	if _f < 4:
		_cam.make_current()
		return false
	# 16 shots espaçados ~0.18s (cobre ~1 ciclo de idle de 3s)
	if _f % 9 == 0:
		var img := get_root().get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path(_out + "f%02d.png" % _shots))
		_shots += 1
		if _shots >= 16:
			print("RIGCAP: %d shots ✓" % _shots)
			quit(0)
			return true
	return false
