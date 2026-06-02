extends SceneTree
## Valida o tiro telegrafado do archer (headless, sem crash):
##   - entra em "draw" (mira) quando o player está no alcance;
##   - solta a flecha ao fim do windup (attack_timer entra em cooldown);
##   - levar dano DURANTE a mira cancela o tiro.
##   $GODOT --headless -s tools/archer_attack_probe.gd

var _a: Node = null
var _player: Node2D = null
var _f := 0
var _saw_draw := false
var _cancel_ok := false
var _released := false

class StubPlayer extends Node2D:
	func take_damage(_amount: float, _src: Vector2 = Vector2.ZERO) -> void: pass
	func shake(_a: float, _b: float) -> void: pass

func _initialize() -> void:
	_player = StubPlayer.new()
	_player.add_to_group("player")
	get_root().add_child.call_deferred(_player)
	var args := OS.get_cmdline_user_args()
	var path := args[0] if args.size() > 0 else "res://scenes/enemies/goblin_archer.tscn"
	print("ALVO: ", path)
	_a = load(path).instantiate()
	get_root().add_child.call_deferred(_a)

func _process(_d: float) -> bool:
	_f += 1
	if not is_instance_valid(_a) or not is_instance_valid(_player):
		print("⚠ nó inválido"); quit(1); return true
	if _f < 3:
		return false
	_player.global_position = _a.global_position + Vector2(200, 0)   # dentro do alcance

	if _a._drawing and not _saw_draw:
		_saw_draw = true
		print("✓ archer entrou em draw (mira)")
		_a.take_damage(3.0, _player.global_position)     # bater cancela a mira
		_cancel_ok = not _a._drawing
		print("✓ hit cancelou a mira: %s" % _cancel_ok)

	# Após o cancelamento, ele re-mira e SOLTA -> attack_timer entra em cooldown.
	if _saw_draw and not _released and _a.attack_timer > 1.5:
		_released = true
		print("✓ archer soltou a flecha (cooldown ativo)")

	if _f > 360:
		var ok := _saw_draw and _cancel_ok and _released
		print("RESULTADO draw/release/cancel: %s" % ("✓" if ok else "✗ REVER"))
		quit(0 if ok else 1); return true
	return false
