extends SceneTree
var _f:=0; var _s
func _initialize():
	_s = load("res://scenes/intro/qte_tower.tscn").instantiate()
	get_root().add_child.call_deferred(_s)
func _process(_d):
	_f+=1
	if _f==20 and _s:
		# força overlay/letterbox-fade transparente p/ enxergar o cenário
		if "_overlay" in _s and _s._overlay: _s._overlay.color.a = 0.0
	if _f<30: return false
	var img := get_root().get_texture().get_image()
	if img: img.save_png(ProjectSettings.globalize_path("res://tools/art_director/iterations/godot_shots/tower.png")); print("saved")
	quit(0); return true
