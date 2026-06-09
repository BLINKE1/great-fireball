extends SceneTree
## Smoke test do CONVOKE do Will (headless).
##   $GODOT --headless -s tools/convoke_will_probe.gd
##
## [A] Will cai e ESMAGA (overkill) o mob no ponto de queda; em guarda, absorve
##     100% de um hit comum (a Soph não toma dano).
## [B] UM facho do boss NÃO estoura o escudo (shield_hp cai, mas > 0).
## [C] TRÊS fachos simultâneos estouram o escudo e o raio VARA até a Soph (hp cai).
##
## NB: load() em runtime (não preload) — autoloads precisam existir antes de
## compilar os scripts das cenas.

var PlayerScene: PackedScene
var GoblinScene: PackedScene
var MutantScene: PackedScene
var WillScene: PackedScene

var _f := 0
var _t := 0.0
var _phase := 0
var _fails := 0

var player: Node = null
var will: Node = null
var goblin: Node = null
var bosses: Array = []
var p_hp0 := 0.0

func _spawn_will() -> void:
	will = WillScene.instantiate()
	will.facing = 1.0
	get_root().add_child(will)
	will.global_position = Vector2(470, 300)

func _spawn_boss(x: float) -> void:
	var b := MutantScene.instantiate()
	get_root().add_child(b)
	b.global_position = Vector2(x, 300)
	bosses.append(b)

func _clear_bosses() -> void:
	for b in bosses:
		if is_instance_valid(b):
			b.queue_free()
	bosses.clear()

func _pin() -> void:
	# Mantém a geometria estável (sem gravidade puxando todo mundo pra fora da linha).
	if is_instance_valid(player):
		player.global_position = Vector2(400, 300)
		player.velocity = Vector2.ZERO
	for b in bosses:
		if is_instance_valid(b):
			b.global_position.y = 300.0
			b.velocity = Vector2.ZERO

func _process(delta: float) -> bool:
	_f += 1
	if _f < 4:
		return false
	if PlayerScene == null:
		PlayerScene = load("res://scenes/player/player.tscn")
		GoblinScene = load("res://scenes/enemies/goblin.tscn")
		MutantScene = load("res://scenes/enemies/goblin_mutant.tscn")
		WillScene   = load("res://scenes/spells/will.tscn")
	if player == null:
		player = PlayerScene.instantiate()
		get_root().add_child(player)
		player.global_position = Vector2(400, 300)
		return false
	_pin()
	_t += delta

	match _phase:
		0:
			goblin = GoblinScene.instantiate()
			get_root().add_child(goblin)
			goblin.global_position = Vector2(470, 300)
			_spawn_will()
			print("[A] Will convocado (mob no ponto de queda)")
			_t = 0.0; _phase = 1
		1:
			if will.is_guarding():
				var smashed: bool = goblin == null or not is_instance_valid(goblin) or goblin.is_dead
				if smashed: print("[A] ✓ overkill: mob esmagado na aterrissagem")
				else: print("[A] ✗ mob sobreviveu ao esmagamento"); _fails += 1
				p_hp0 = player.hp.current_hp
				player.take_damage(15.0, Vector2(800, 300))
				_t = 0.0; _phase = 2
			elif _t > 3.0:
				print("[A] ✗ Will nunca entrou em guarda"); _fails += 1; quit(1); return true
		2:
			if _t > 0.2:
				if absf(player.hp.current_hp - p_hp0) < 0.01:
					print("[A] ✓ guarda absorveu o hit comum (Soph intacta)")
				else:
					print("[A] ✗ Soph tomou dano com a guarda ativa"); _fails += 1
				if is_instance_valid(will): will.queue_free()
				_t = 0.0; _phase = 3
		3:
			if _t > 0.4:
				_spawn_will(); _spawn_boss(700.0)
				print("[B] Will + 1 boss (um facho só)")
				_t = 0.0; _phase = 4
		4:
			if will.is_guarding():
				bosses[0].force_beam()
				_t = 0.0; _phase = 5
			elif _t > 3.0:
				print("[B] ✗ Will não entrou em guarda"); _fails += 1; quit(1); return true
		5:
			if _t > 3.4:
				var ok: bool = is_instance_valid(will) and not will._broken and will.shield_hp > 0.0
				if ok:
					print("[B] ✓ 1 facho NÃO estoura (shield_hp=%.0f de %.0f)" % [will.shield_hp, will.SHIELD_MAX])
				else:
					print("[B] ✗ 1 facho estourou o escudo (não devia)"); _fails += 1
				if is_instance_valid(will): will.queue_free()
				_clear_bosses()
				_t = 0.0; _phase = 6
		6:
			if _t > 0.4:
				_spawn_will()
				_spawn_boss(700.0); _spawn_boss(735.0); _spawn_boss(770.0)
				print("[C] Will + 3 bosses (fachos simultâneos)")
				_t = 0.0; _phase = 7
		7:
			if will.is_guarding():
				p_hp0 = player.hp.current_hp
				for b in bosses:
					if is_instance_valid(b): b.force_beam()
				_t = 0.0; _phase = 8
			elif _t > 3.0:
				print("[C] ✗ Will não entrou em guarda"); _fails += 1; quit(1); return true
		8:
			if _t > 3.6:
				var broke: bool = (not is_instance_valid(will)) or will._broken
				var hit: bool = player.hp.current_hp < p_hp0 - 0.01
				if broke: print("[C] ✓ 3 fachos estouraram o escudo")
				else: print("[C] ✗ escudo aguentou 3 fachos (devia estourar)"); _fails += 1
				if hit: print("[C] ✓ o facho varou e acertou a Soph (hp %.0f -> %.0f)" % [p_hp0, player.hp.current_hp])
				else: print("[C] ✗ a Soph não tomou o facho após o estouro"); _fails += 1
				if _fails == 0:
					print("RESULTADO: CONVOKE do Will OK ✓")
					quit(0)
				else:
					print("RESULTADO: %d falha(s) ✗" % _fails)
					quit(1)
				return true
	return false
