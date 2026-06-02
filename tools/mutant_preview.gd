extends SceneTree
var _f := 0
func _process(_d):
	_f += 1
	if _f < 5: return false
	var ss = get_root().get_node_or_null("SpriteSetup")
	if ss == null: print("NO SpriteSetup"); quit(1); return true
	var tex = ss.get_texture("goblin_mutant")
	if tex == null: print("NO TEX"); quit(1); return true
	var img: Image = tex.get_image()
	print("size: ", img.get_width(), "x", img.get_height())
	img.resize(img.get_width()*5, img.get_height()*5, Image.INTERPOLATE_NEAREST)
	var p := ProjectSettings.globalize_path("res://tools/art_director/iterations/godot_shots/mutant_preview.png")
	DirAccess.make_dir_recursive_absolute(p.get_base_dir())
	img.save_png(p); print("saved")
	quit(0); return true
