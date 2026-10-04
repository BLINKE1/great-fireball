extends SceneTree
## Tour de screenshots da Torre dos Magos (tower.tscn): 1 foto por sala.
##   xvfb-run -a "$GODOT" --rendering-driver opengl3 -s tools/_tower_tour.gd
const SPOTS := [
	["01_atrio",     Vector2(400, 400),  1.35],
	["02_salao",     Vector2(1140, 400), 1.35],
	["03_poco",      Vector2(1800, 330), 1.30],
	["04_camara",    Vector2(2650, 380), 1.25],
	["05_ala",       Vector2(3500, 400), 1.35],
	["06_cume",      Vector2(4050, 400), 1.35],
]
var _f := 0
var _i := 0
var _cam: Camera2D = null
var _lvl: Node = null

func _initialize() -> void:
	_lvl = load("res://scenes/world/tower.tscn").instantiate()
	get_root().add_child.call_deferred(_lvl)

func _process(_d: float) -> bool:
	_f += 1
	if _f == 40:
		for c in get_root().get_children():
			_hide_ui(c)
		_cam = Camera2D.new()
		_lvl.add_child(_cam)
		_cam.make_current()
	if _f >= 50 and (_f - 50) % 24 == 0:
		if _i >= SPOTS.size():
			quit(0); return true
		var s: Array = SPOTS[_i]
		_cam.position = s[1]
		_cam.zoom = Vector2(s[2], s[2])
		_i += 1
	elif _f >= 50 and (_f - 50) % 24 == 18:
		var s: Array = SPOTS[_i - 1]
		get_root().get_texture().get_image().save_png(
			ProjectSettings.globalize_path("res://tools/art_director/iterations/godot_shots/tower_%s.png" % s[0]))
		print("shot ", s[0])
	if _f > 400:
		quit(1); return true
	return false

func _hide_ui(n: Node) -> void:
	if n is CanvasLayer and n.layer >= 8:
		n.visible = false
		return
	for c in n.get_children():
		_hide_ui(c)
