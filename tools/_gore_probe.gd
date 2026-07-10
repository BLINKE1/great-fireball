extends SceneTree
## Probe: mata o goblin_leader com dano no ponto da CABECA -> deve disparar
## _head_explode (sangue verde + gibs) sem erros e morrer decapitado.
var _g: Node = null
var _f := 0

class Stub extends Node2D:
	func take_damage(_a: float, _b: Vector2 = Vector2.ZERO) -> void: pass
	func shake(_a: float, _b: float) -> void: pass

func _initialize() -> void:
	var stub := Stub.new()
	stub.add_to_group("player")
	stub.position = Vector2(120, 0)
	get_root().add_child.call_deferred(stub)
	var floor_body := StaticBody2D.new()
	floor_body.position = Vector2(0, 40)
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(600, 40)
	cs.shape = rect
	floor_body.add_child(cs)
	get_root().add_child.call_deferred(floor_body)
	_g = load("res://scenes/enemies/goblin_leader.tscn").instantiate()
	_g.position = Vector2(0, 0)
	get_root().add_child.call_deferred(_g)

func _process(_d: float) -> bool:
	_f += 1
	if _f == 20 and is_instance_valid(_g):
		var head: Vector2 = _g.global_position + Vector2(0, -18)
		print("[gore] head-shot letal em ", head)
		_g.take_damage(999.0, head)
	if _f == 25:
		print("[gore] head_gone=", _g._head_gone if is_instance_valid(_g) else "(freed)")
	if _f >= 80:
		print("[gore] fim sem crash")
		quit(0)
		return true
	return false
