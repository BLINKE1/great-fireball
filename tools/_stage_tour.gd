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
var _prefix := ""

func _initialize() -> void:
	var scene := "res://scenes/world/dungeon_1.tscn"
	var u := OS.get_cmdline_user_args()
	if u.size() > 0:
		scene = "res://scenes/world/%s.tscn" % u[0]   # ex.: -- dungeon_cave_test
		_prefix = u[0] + "_"
	_lvl = load(scene).instantiate()
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
			ProjectSettings.globalize_path("res://tools/art_director/iterations/godot_shots/tour_%s%s.png" % [_prefix, s[0]]))
		print("shot ", s[0])
	if _f > 400:
		quit(1); return true
	return false

func _hide_ui(n: Node) -> void:
	# esconde so' a UI (layers >= 8: HUD 10, dialogo 20, popup 25); mantem os
	# visuais de cena (Lake 2, LilyPads 3, Mist 4, Foreground 5, parallax).
	if n is CanvasLayer and n.layer >= 8:
		n.visible = false
		return
	for c in n.get_children():
		_hide_ui(c)
