extends SceneTree
## Valida o Goblin Mutante de forma DETERMINÍSTICA: força cada golpe da árvore
## (swipe/slam/charge/summon/toss), cruza as 3 fases e mata — tudo sem crash.
var _boss; var _player; var _floor
var _f := 0
var _moves := ["swipe", "slam", "charge", "summon", "toss"]
var _mi := 0
var _next := 20
var _done := {}
var _phases := {}
var _died := false
var _crashed := false

class Stub extends Node2D:
	func take_damage(_a: float, _b: Vector2 = Vector2.ZERO) -> void: pass
	func shake(_a: float, _b: float) -> void: pass

func _initialize() -> void:
	_player = Stub.new(); _player.add_to_group("player"); _player.position = Vector2(700, 0)
	get_root().add_child.call_deferred(_player)
	_floor = StaticBody2D.new(); _floor.position = Vector2(0, 70)
	var cs := CollisionShape2D.new(); var r := RectangleShape2D.new()
	r.size = Vector2(1400, 40); cs.shape = r; _floor.add_child(cs)
	get_root().add_child.call_deferred(_floor)
	_boss = load("res://scenes/enemies/goblin_mutant.tscn").instantiate()
	get_root().add_child.call_deferred(_boss)

func _process(_d: float) -> bool:
	_f += 1
	if _f == 5:
		_boss.boss_died.connect(func(): _died = true)
	if _f < 6: return false
	if not is_instance_valid(_boss):
		return _finish()
	# player longe -> boss não auto-ataca; forçamos cada golpe na mão
	_player.global_position = _boss.global_position + Vector2(700, 0)
	_phases[_boss.phase] = true

	if _f >= _next and _mi < _moves.size():
		var m: String = _moves[_mi]
		# reseta gates e estado, força o golpe
		_boss._state = 0          # IDLE
		_boss._move = ""
		_boss._global_cd = 0.0; _boss._summon_cd = 0.0; _boss._toss_cd = 0.0; _boss._charge_cd = 0.0
		_boss._enter_windup(m)
		_done[m] = true
		_mi += 1
		_next = _f + 140          # espaço pro windup+active+recover

	# depois de exercitar todos os golpes em fase 1, cruza fases e mata
	if _mi >= _moves.size():
		if not _phases.has(1) and _f % 6 == 0:
			_boss.take_damage(70.0, _player.global_position)   # -> fase 2
		elif _phases.has(1) and not _phases.has(2) and _f % 6 == 0:
			_boss.take_damage(70.0, _player.global_position)   # -> fase 3
		elif _phases.has(2) and _f % 8 == 0:
			# fase 3: força um swipe (testa duplo golpe) e depois mata
			if not _done.has("swipe2"):
				_boss._state = 0; _boss._global_cd = 0.0; _boss._enter_windup("swipe")
				_done["swipe2"] = true
			else:
				_boss.take_damage(999.0, _player.global_position)

	if _died or _f > 900:
		return _finish()
	return false

func _finish() -> bool:
	print("golpes exercitados: ", _done.keys())
	print("fases vistas (0=I,1=II,2=III): ", _phases.keys())
	print("boss_died: ", _died)
	var all_moves := _done.has("swipe") and _done.has("slam") and _done.has("charge") and _done.has("summon") and _done.has("toss")
	var ok := all_moves and _phases.has(1) and _phases.has(2) and _died
	print("RESULTADO boss: ", ("✓" if ok else "✗ REVER"))
	quit(0 if ok else 1)
	return true
