extends SceneTree
## Valida o parry de flechas headless (normal + fogo).
##   $GODOT --headless -s tools/parry_probe.gd
## Pra cada flecha: coloca um sword_slash sobreposto e confirma que ela é aparada
## (cortada/liberada) sem dano — i.e., o player escaparia do hit.

const SCENES := [
	"res://scenes/enemies/goblin_arrow.tscn",
	"res://scenes/enemies/fire_goblin_arrow.tscn",
]

var _arrow: Node = null
var _hit := false
var _f := 0
var _idx := 0
var _fails := 0

class FakePlayer:
	extends Node2D
	var probe = null
	func _enter_tree() -> void: add_to_group("player")
	func take_damage(_a: float, _b: Vector2 = Vector2.ZERO) -> void:
		if probe: probe._hit = true
	func apply_burn(_d: float, _t: float) -> void: pass
	func shake(_i: float, _d: float) -> void: pass

func _initialize() -> void:
	var fake := FakePlayer.new()
	fake.probe = self
	fake.position = Vector2(500, 0)
	get_root().add_child.call_deferred(fake)
	_spawn(_idx)

func _spawn(idx: int) -> void:
	_hit = false
	var slash = load("res://scenes/player/sword_slash.tscn").instantiate()
	slash.facing = 1.0
	slash.global_position = Vector2(0, 0)
	get_root().add_child.call_deferred(slash)
	_arrow = load(SCENES[idx]).instantiate()
	_arrow.direction = 1.0
	_arrow.global_position = Vector2(0, 0)
	get_root().add_child.call_deferred(_arrow)

func _process(_d: float) -> bool:
	_f += 1
	if _f < 20:
		return false
	var freed := (_arrow == null) or (not is_instance_valid(_arrow))
	var parried: bool = freed or bool(_arrow._parried)
	var name: String = SCENES[_idx].get_file()
	if parried and not _hit:
		print("✓ %s: aparada, sem dano" % name)
	else:
		print("✗ %s: parry=%s dano=%s" % [name, parried, _hit])
		_fails += 1
	_idx += 1
	if _idx >= SCENES.size():
		if _fails == 0:
			print("RESULTADO: parry OK ✓ em todas as flechas")
			quit(0)
		else:
			print("FALHA: %d flecha(s) não aparada(s)" % _fails)
			quit(1)
		return true
	_f = 0
	_spawn(_idx)
	return false
