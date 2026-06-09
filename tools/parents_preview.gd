extends SceneTree
func _process(_d: float) -> bool:
	var ss := get_root().get_node_or_null("SpriteSetup")
	if ss == null:
		return false
	for key in ["rose", "ze", "ze_fireball", "rose_aurora"]:
		var tex: Texture2D = ss.get_texture(key)
		if tex == null:
			print("x %s" % key); quit(1); return true
		var img := tex.get_image()
		img.resize(img.get_width() * 8, img.get_height() * 8, Image.INTERPOLATE_NEAREST)
		img.save_png("user://%s_preview.png" % key)
		print("ok %s (%dx%d)" % [key, tex.get_width(), tex.get_height()])
	quit(0)
	return true
