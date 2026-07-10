extends SceneTree
## Tour de screenshots do dungeon_1: uma foto em cada trecho do stage.
##   xvfb-run -a "$GODOT" --rendering-driver opengl3 -s tools/_stage_tour.gd
const SPOTS := [
	["01_entrada",      Vector2(420, 400),  1.35],
	["02_lanceiro",     Vector2(1300, 400), 1.35],
	["03_lider",        Vector2(2400, 400), 1.35],
	["04_bau",          Vector2(2830, 390), 1.5],
	["05_descida",      Vector2(3600, 390), 1.2],
	["06_arena_boss",   Vector2(4400, 400), 1.2],
]
var _f := 0
var _i := 0
var _cam: Camera2D = null
var _lvl: Node = null

func _initialize() -> void:
	_lvl = load("res://scenes/world/dungeon_1.tscn").instantiate()
	get_root().add_child.call_deferred(_lvl)

func _process(_d: float) -> bool:
	_f += 1
	if _f == 30:
		for c in get_root().get_children():
			_hide_ui(c)
		_cam = Camera2D.new()
		_lvl.add_child(_cam)
		_cam.make_current()
	if _f >= 40 and (_f - 40) % 22 == 0:
		if _i >= SPOTS.size():
			quit(0); return true
		var s: Array = SPOTS[_i]
		_cam.position = s[1]
		_cam.zoom = Vector2(s[2], s[2])
		_i += 1
	elif _f >= 40 and (_f - 40) % 22 == 16:
		# 16 ticks depois de mover: captura (parallax/fx assentados)
		var s: Array = SPOTS[_i - 1]
		get_root().get_texture().get_image().save_png(
			ProjectSettings.globalize_path("res://tools/art_director/iterations/godot_shots/tour_%s.png" % s[0]))
		print("shot ", s[0])
	if _f > 400:
		quit(1); return true
	return false

func _hide_ui(n: Node) -> void:
	if n is CanvasLayer and n.layer >= 0:
		n.visible = false
		return
	for c in n.get_children():
		_hide_ui(c)
