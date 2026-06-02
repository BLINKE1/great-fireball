extends SceneTree
## Captura determinística do juice (sem input/AI): chão + goblin, força o windup
## (telegrafia) e depois um impacto (faísca/flash/número). Salva PNGs e sai limpo.
##   xvfb-run -a godot --rendering-driver opengl3 -s tools/combat_capture.gd

var _g: Node = null
var _cam: Camera2D = null
var _f := 0
var _phase := 0
var _shots := 0
var _out := "res://tools/art_director/iterations/godot_shots/"

class Stub extends Node2D:
	func take_damage(_a: float, _b: Vector2 = Vector2.ZERO) -> void: pass
	func shake(_a: float, _b: float) -> void: pass

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var stub := Stub.new()
	stub.add_to_group("player")
	stub.position = Vector2(70, 0)
	get_root().add_child.call_deferred(stub)
	# Chão estático pra o goblin assentar e ficar enquadrado.
	var floor_body := StaticBody2D.new()
	floor_body.position = Vector2(0, 40)
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(400, 40)
	cs.shape = rect
	floor_body.add_child(cs)
	get_root().add_child.call_deferred(floor_body)
	_g = load("res://scenes/enemies/goblin.tscn").instantiate()
	get_root().add_child.call_deferred(_g)
	_cam = Camera2D.new()
	get_root().add_child.call_deferred(_cam)

func _process(_d: float) -> bool:
	_f += 1
	if not is_instance_valid(_g):
		print("CAPTURE: goblin sumiu cedo"); quit(0); return true
	if _f < 6:
		_g.global_position = Vector2(0, 0)
		_cam.global_position = Vector2(0, -12)
		_cam.zoom = Vector2(4.5, 4.5)
		_cam.make_current()
		return false
	match _phase:
		0:
			_g._start_windup()      # telegrafia (brilho quente + anticipation)
			_phase = 1
		3:
			_shot("juice_windup")
			_phase = 4
		4:
			_g.take_damage(20.0, Vector2(-60, 0))   # impacto: faísca/flash/número
			_phase = 5
		7:
			_shot("juice_impact")
			_phase = 8
		8:
			print("CAPTURE: %d shots ✓" % _shots)
			quit(0); return true
		_:
			_phase += 1
	return false

func _shot(tag: String) -> void:
	var img := get_root().get_texture().get_image()
	if img == null:
		print("CAPTURE: viewport sem imagem (", tag, ")"); return
	var path := _out + "%s.png" % tag
	if img.save_png(ProjectSettings.globalize_path(path)) == OK:
		_shots += 1
		print("shot -> ", path)
