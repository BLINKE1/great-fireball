extends SceneTree
## Salva um PNG ampliado (8x) da sprite procedural da Juju pra inspeção visual.
##   $GODOT --headless -s tools/juju_preview.gd

func _process(_d: float) -> bool:
	var ss := get_root().get_node_or_null("SpriteSetup")
	if ss == null:
		return false
	var tex: Texture2D = ss.get_texture("juju")
	if tex == null:
		print("✗ textura 'juju' não encontrada"); quit(1); return true
	var img := tex.get_image()
	img.resize(img.get_width() * 8, img.get_height() * 8, Image.INTERPOLATE_NEAREST)
	img.save_png("user://juju_preview.png")
	var path := ProjectSettings.globalize_path("user://juju_preview.png")
	print("✓ preview salvo: %s (%dx%d)" % [path, tex.get_width(), tex.get_height()])
	quit(0)
	return true
