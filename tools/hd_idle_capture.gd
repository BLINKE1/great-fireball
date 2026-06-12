extends SceneTree
var _f := 0; var _lvl
func _initialize():
	_lvl = load("res://scenes/world/dungeon_1.tscn").instantiate()
	get_root().add_child.call_deferred(_lvl)
func _process(_d):
	_f += 1
	if _f < 90: return false
	var img := get_root().get_texture().get_image()
	if img: img.save_png("/tmp/hd_idle_ingame.png"); print("saved")
	quit(0); return true
