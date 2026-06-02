extends SceneTree
## Captura de escala: Soph + goblin normal + Goblin Mutante lado a lado.
var _f := 0
var _cam: Camera2D
var _mut
func _initialize() -> void:
	var floor_body := StaticBody2D.new(); floor_body.position = Vector2(120, 70)
	var cs := CollisionShape2D.new(); var r := RectangleShape2D.new()
	r.size = Vector2(600, 40); cs.shape = r; floor_body.add_child(cs)
	get_root().add_child.call_deferred(floor_body)
	# Soph (player real)
	var p = load("res://scenes/world/../player/player.tscn") if false else load("res://scenes/player/player.tscn")
	if p:
		var pl = p.instantiate(); pl.position = Vector2(20, 20); get_root().add_child.call_deferred(pl)
	# goblin normal (escala de referência)
	var g = load("res://scenes/enemies/goblin.tscn").instantiate()
	g.position = Vector2(110, 30); get_root().add_child.call_deferred(g)
	# Goblin Mutante
	_mut = load("res://scenes/enemies/goblin_mutant.tscn").instantiate()
	_mut.position = Vector2(210, 0); get_root().add_child.call_deferred(_mut)
	_cam = Camera2D.new(); get_root().add_child.call_deferred(_cam)

func _process(_d: float) -> bool:
	_f += 1
	if _f < 24:
		_cam.global_position = Vector2(120, 5)
		_cam.zoom = Vector2(2.0, 2.0)
		_cam.make_current()
		# trava o mutante parado pra não andar pra fora do quadro
		if is_instance_valid(_mut): _mut.global_position = Vector2(210, 8)
		return false
	var img := get_root().get_texture().get_image()
	if img:
		var pth := ProjectSettings.globalize_path("res://tools/art_director/iterations/godot_shots/boss_scale.png")
		DirAccess.make_dir_recursive_absolute(pth.get_base_dir())
		img.save_png(pth); print("saved boss_scale")
	quit(0); return true
