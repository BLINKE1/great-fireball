extends SceneTree
var _f := 0; var _lvl; var _p
func _initialize():
	_lvl = load("res://scenes/world/dungeon_1.tscn").instantiate()
	get_root().add_child.call_deferred(_lvl)
func _process(_d):
	_f += 1
	if _p == null: _p = _lvl.get_node_or_null("Player")
	if _f == 40 and _p: _p.global_position.x += 700   # anda pra ver o cenário aberto
	if _f < 80: return false
	var img := get_root().get_texture().get_image()
	if img: img.save_png(ProjectSettings.globalize_path("res://tools/art_director/iterations/godot_shots/forest_stage.png")); print("saved")
	quit(0); return true
