extends SceneTree
## Valida o ataque telegrafado do goblin (headless, sem crash):
##   - entra em windup quando o player está no alcance;
##   - desfere o golpe (player recebe dano) se o player continua perto;
##   - levar dano DURANTE o windup cancela o golpe.
##   $GODOT --headless -s tools/goblin_attack_probe.gd

var _goblin: Node = null
var _player: Node2D = null
var _f := 0
var _saw_windup := false
var _cancel_ok := false
var _struck := false

class StubPlayer extends Node2D:
	var hits := 0
	func take_damage(_amount: float, _src: Vector2 = Vector2.ZERO) -> void:
		hits += 1
	func shake(_a: float, _b: float) -> void:
		pass

func _initialize() -> void:
	_player = StubPlayer.new()
	_player.add_to_group("player")
	get_root().add_child.call_deferred(_player)
	var packed := load("res://scenes/enemies/goblin.tscn")
	_goblin = packed.instantiate()
	get_root().add_child.call_deferred(_goblin)

func _process(_d: float) -> bool:
	_f += 1
	if not is_instance_valid(_goblin) or not is_instance_valid(_player):
		print("⚠ nó inválido cedo demais"); quit(1); return true
	if _f < 3:
		return false
	# Mantém o player coladinho ao goblin pra garantir engajamento contínuo.
	_player.global_position = _goblin.global_position + Vector2(20, 0)

	if _goblin._winding and not _saw_windup:
		_saw_windup = true
		print("✓ goblin entrou em windup")
		_goblin.take_damage(3.0, _player.global_position)   # bater cancela
		_cancel_ok = not _goblin._winding
		print("✓ hit cancelou o windup: %s" % _cancel_ok)

	if _player.hits > 0 and not _struck:
		_struck = true
		print("✓ goblin desferiu o golpe (player levou dano)")

	if _f > 300:
		var ok := _saw_windup and _struck and _cancel_ok
		print("RESULTADO windup/strike/cancel: %s" % ("✓" if ok else "✗ REVER"))
		quit(0 if ok else 1); return true
	return false
