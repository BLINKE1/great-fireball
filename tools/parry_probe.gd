extends SceneTree
## Valida o parry de flecha headless.
##   $GODOT --headless -s tools/parry_probe.gd
## Coloca um sword_slash e uma goblin_arrow sobrepostos e confirma que a flecha
## é aparada (cortada/liberada) sem dano — i.e., o player escaparia do hit.

var _arrow: Node = null
var _hit := false
var _f := 0

# Player-stub no grupo "player" só pra detectar se a flecha causaria dano.
class FakePlayer:
	extends Node2D
	var probe = null
	func _enter_tree() -> void: add_to_group("player")
	func take_damage(_a: float, _b: Vector2 = Vector2.ZERO) -> void:
		if probe: probe._hit = true
	func shake(_i: float, _d: float) -> void: pass

func _initialize() -> void:
	var fake := FakePlayer.new()
	fake.probe = self
	fake.position = Vector2(500, 0)   # longe: só conta se a flecha "alcançar"
	get_root().add_child.call_deferred(fake)

	var slash = load("res://scenes/player/sword_slash.tscn").instantiate()
	slash.facing = 1.0
	slash.global_position = Vector2(0, 0)
	get_root().add_child.call_deferred(slash)

	_arrow = load("res://scenes/enemies/goblin_arrow.tscn").instantiate()
	_arrow.direction = 1.0
	_arrow.global_position = Vector2(0, 0)   # dentro da área do slash (44x34)
	get_root().add_child.call_deferred(_arrow)

func _process(_d: float) -> bool:
	_f += 1
	if _f < 20:
		return false
	var freed := (_arrow == null) or (not is_instance_valid(_arrow))
	var parried: bool = freed or bool(_arrow._parried)
	print("flecha liberada/aparada=%s | causou dano=%s" % [parried, _hit])
	if parried and not _hit:
		print("RESULTADO: parry OK ✓ (flecha cortada, sem dano no player)")
		quit(0)
	else:
		print("FALHA: parry não funcionou como esperado")
		quit(1)
	return true
