extends SceneTree
## Captura a Soph HD parada (idle) renderizada no engine.
##   xvfb-run -a godot --rendering-driver opengl3 -s tools/idle_capture.gd
var _room; var _p; var _cam: Camera2D; var _f := 0; var _phase := 0
var _out := "res://tools/art_director/iterations/godot_shots/"

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_room = load("res://scenes/world/soph_test_room.tscn").instantiate()
	get_root().add_child.call_deferred(_room)
	_cam = Camera2D.new()
	get_root().add_child.call_deferred(_cam)

func _process(_d: float) -> bool:
	_f += 1
	if _p == null:
		if _room: _p = _room.get_node_or_null("Player")
		return false
	if _phase == 0:
		_p.set_physics_process(false); _p.set_process(false)
		_p.sprite.animation = "idle"; _p.sprite.pause()
		_cam.zoom = Vector2(3.0, 3.0); _cam.make_current()
		_phase = 1
		return false
	_cam.global_position = _p.global_position + Vector2(0, -6)
	# frame 0 (aberto) no tick 8, frame 1 (blink) no tick 16
	if _f == 8:
		_p.sprite.frame = 0
	elif _f == 10:
		_save("idle_open")
	elif _f == 12:
		_p.sprite.frame = 1
	elif _f == 14:
		_save("idle_blink"); quit(0); return true
	return false

func _save(tag: String) -> void:
	var img := get_root().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(_out + tag + ".png"))
	print("shot -> ", tag)
