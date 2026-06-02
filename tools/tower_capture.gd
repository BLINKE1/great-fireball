extends SceneTree
var _room; var _cam; var _f := 0
func _initialize():
	_room = load("res://scenes/world/soph_test_room.tscn").instantiate()
	get_root().add_child.call_deferred(_room)
	_cam = Camera2D.new(); get_root().add_child.call_deferred(_cam)
func _process(_d):
	_f += 1
	if _f < 20:
		_cam.global_position = Vector2(580, -430)
		_cam.zoom = Vector2(0.34, 0.34)
		_cam.make_current()
		return false
	var img := get_root().get_texture().get_image()
	if img:
		var p := ProjectSettings.globalize_path("res://tools/art_director/iterations/godot_shots/bhop_tower.png")
		img.save_png(p); print("saved tower")
	quit(0); return true
