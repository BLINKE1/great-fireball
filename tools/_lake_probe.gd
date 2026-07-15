extends SceneTree
## Probe visual da FLORESTA no enquadramento REAL de jogo (camera y~452, zoom 1.0).
## Uso: xvfb-run -a "$GODOT" --rendering-driver opengl3 -s tools/_lake_probe.gd
## Captura tools/art_director/iterations/godot_shots/lake_<spot>.png (gitignored).
## Mantem parallax + Lake visiveis, esconde so' a UI.
const SPOTS := [
	["entrada", Vector2(420, 452)],
	["lider",   Vector2(2400, 452)],
	["boss",    Vector2(4400, 452)],
]
var _lvl: Node
var _cam: Camera2D
var _f := 0
var _i := 0

func _process(_d: float) -> bool:
	_f += 1
	if _f == 2:
		_lvl = load("res://scenes/world/dungeon_1.tscn").instantiate()
		get_root().add_child(_lvl)
	if _f == 70:
		for c in get_root().get_children():
			_hide(c)
		_cam = Camera2D.new()
		_lvl.add_child(_cam)
		_cam.make_current()
	if _f >= 80 and (_f - 80) % 24 == 0:
		if _i >= SPOTS.size():
			quit(); return true
		_cam.position = SPOTS[_i][1]
		_i += 1
	elif _f >= 80 and (_f - 80) % 24 == 18:
		var s: Array = SPOTS[_i - 1]
		get_root().get_texture().get_image().save_png(
			ProjectSettings.globalize_path(
				"res://tools/art_director/iterations/godot_shots/lake_%s.png" % s[0]))
		print("shot ", s[0])
	if _f > 400:
		quit()
	return false

func _hide(n: Node) -> void:
	if n is ParallaxBackground or (n is CanvasLayer and n.name == "Lake"):
		return
	if n is CanvasLayer and n.layer >= 0:
		n.visible = false
		return
	for c in n.get_children():
		_hide(c)
