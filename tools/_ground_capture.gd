extends SceneTree
## Screenshot da floresta (dungeon_1) pra ver o tileset novo em contexto.
##   xvfb-run -a "$GODOT" --rendering-driver opengl3 -s tools/_ground_capture.gd
var _f := 0
var _lvl: Node = null

func _initialize() -> void:
	_lvl = load("res://scenes/world/dungeon_1.tscn").instantiate()
	get_root().add_child.call_deferred(_lvl)

func _process(_d: float) -> bool:
	_f += 1
	if _f == 30:
		# esconde UI (HUD/dialogo) pra ver so' o mundo
		for c in get_root().get_children():
			_hide_canvas_layers(c)
		# camera mirando o chao (topo do chao da floresta ~y=492)
		var cam := Camera2D.new()
		cam.position = Vector2(620, 440)
		cam.zoom = Vector2(2.2, 2.2)
		_lvl.add_child(cam)
		cam.make_current()
	if _f == 45:
		get_root().get_texture().get_image().save_png(
			ProjectSettings.globalize_path("res://tools/art_director/iterations/godot_shots/ground_ingame.png"))
		print("shot salvo")
		quit(0)
		return true
	if _f > 120:
		quit(1)
		return true
	return false

func _hide_canvas_layers(n: Node) -> void:
	if n is CanvasLayer and n.layer >= 0:   # UI na frente; mantem backdrops (layer<0)
		n.visible = false
		return
	for c in n.get_children():
		_hide_canvas_layers(c)
