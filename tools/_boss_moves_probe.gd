extends SceneTree
## Probe do moveset HK do Goblin Mutante: bombas (toss), pedras do teto (slam
## fase 2+) e wall-stun (charge na parede). Roda cada golpe e confere que nada
## explode em erro de script.
var _b: Node = null
var _f := 0

class Stub extends Node2D:
	func take_damage(_a: float, _b2: Vector2 = Vector2.ZERO) -> void: pass
	func shake(_a: float, _b2: float) -> void: pass

func _initialize() -> void:
	var stub := Stub.new()
	stub.add_to_group("player")
	stub.position = Vector2(220, 20)
	get_root().add_child.call_deferred(stub)
	var floor_body := StaticBody2D.new()
	floor_body.position = Vector2(0, 60)
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(1200, 40)
	cs.shape = rect
	floor_body.add_child(cs)
	get_root().add_child.call_deferred(floor_body)
	var wall := StaticBody2D.new()
	wall.position = Vector2(-120, -20)
	var wcs := CollisionShape2D.new()
	var wrect := RectangleShape2D.new()
	wrect.size = Vector2(40, 220)
	wcs.shape = wrect
	wall.add_child(wcs)
	get_root().add_child.call_deferred(wall)
	_b = load("res://scenes/enemies/goblin_mutant.tscn").instantiate()
	_b.position = Vector2(0, 0)
	get_root().add_child.call_deferred(_b)

func _process(_d: float) -> bool:
	_f += 1
	if not is_instance_valid(_b):
		print("[boss] sumiu?!"); quit(1); return true
	match _f:
		30:
			print("[boss] forca TOSS (bombas)")
			_b._enter_windup("toss")
		160:
			var bombs := get_nodes_in_group("enemy_projectile").size()
			print("[boss] pos-toss ok (projeteis vivos agora: %d)" % bombs)
			_b.phase = 1   # Phase.TWO
			print("[boss] forca SLAM fase 2 (pedras do teto)")
			_b._enter_windup("slam")
		300:
			print("[boss] forca CHARGE contra a parede (stun)")
			_b.position = Vector2(-40, 0)   # perto da parede -> garante o impacto
			_b.facing = -1.0
			_b._enter_windup("charge")
		420, 460, 500, 540:
			print("[boss] f=%d state=%d move=%s x=%.0f stun=%.2f" %
					[_f, _b._state, _b._move, _b.position.x, _b._stun_t])
		560:
			print("[boss] stun_t=%.2f (esperado >0 se comeu a parede)" % _b._stun_t)
			print("[boss] fim sem crash")
			quit(0)
			return true
	return false
