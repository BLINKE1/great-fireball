extends SceneTree
func _initialize():
	var tex: Texture2D = ResourceLoader.load("res://assets/sprites/player/soph_hd_walk_0.png")
	if tex:
		var img := tex.get_image()
		img.save_png("/tmp/truth_walk0.png")
		print("salvo ", img.get_size())
	else:
		print("FALHOU o load")
	quit(0)
