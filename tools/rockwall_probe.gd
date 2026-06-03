extends SceneTree
var _f:=0; var _lvl; var _dm; var _p; var _wall
func _initialize():
	_lvl = load("res://scenes/world/dungeon_1.tscn").instantiate()
	get_root().add_child.call_deferred(_lvl)
func _process(_d) -> bool:
	_f += 1
	if _p == null: _p = _lvl.get_node_or_null("Player")
	if _dm == null: _dm = _lvl.get_node_or_null("DungeonManager")
	if _f == 30 and _p and _dm:
		_p.global_position = Vector2(4120, 440)
		_wall = _dm._drop_rockwall(4020.0)
		print("rockwall criado: ", is_instance_valid(_wall), " | é StaticBody2D: ", _wall is StaticBody2D)
	if _f == 75:
		_shot("rockwall_drop")
	if _f == 85 and is_instance_valid(_wall):
		_dm._clear_rockwall(_wall)
	if _f == 120:
		print("rockwall após clear válido? ", is_instance_valid(_wall), " (esperado: false/sumindo)")
		print("RESULTADO rockwall: ok")
		quit(0); return true
	return false
func _shot(t):
	var img := get_root().get_texture().get_image()
	if img: img.save_png(ProjectSettings.globalize_path("res://tools/art_director/iterations/godot_shots/"+t+".png"))
