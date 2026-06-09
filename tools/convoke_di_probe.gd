extends SceneTree
## Smoke test do CONVOKE da Di (headless).
##   $GODOT --headless -s tools/convoke_di_probe.gd
##
## [mobs] A chuva de flechas limpa os mobs da sala.
## [Boss] Sozinha ela CRAVA dano no Boss mas NÃO o mata (sobrevive).

var GoblinScene: PackedScene
var MutantScene: PackedScene
var DiScene: PackedScene

var _f := 0
var _t := 0.0
var _phase := 0
var _fails := 0
var _di_spawned := false

var mobs: Array = []
var boss: Node = null
var boss_max := 0.0

func _spawn_di() -> void:
	var di := DiScene.instantiate()
	di.facing = 1.0
	get_root().add_child(di)
	di.global_position = Vector2(440.0, 280.0)
	_di_spawned = true

func _setup_mobs(n: int) -> void:
	mobs.clear()
	for i in n:
		var g := GoblinScene.instantiate()
		get_root().add_child(g)
		g.global_position = Vector2(560.0 + i * 60.0, 300.0)
		mobs.append(g)
	_spawn_di()

func _setup_boss() -> void:
	boss = MutantScene.instantiate()
	get_root().add_child(boss)
	boss.global_position = Vector2(760.0, 300.0)
	boss_max = boss.hp
	_spawn_di()

func _pin() -> void:
	for e in get_nodes_in_group("enemy"):
		if is_instance_valid(e):
			e.global_position.y = 300.0
			e.velocity = Vector2.ZERO

func _alive_mobs() -> int:
	var n := 0
	for m in mobs:
		if is_instance_valid(m) and not m.is_dead:
			n += 1
	return n

func _di_done() -> bool:
	return _di_spawned and get_nodes_in_group("di").is_empty()

func _cleanup() -> void:
	for e in get_nodes_in_group("enemy"):
		if is_instance_valid(e):
			e.queue_free()
	mobs.clear(); boss = null; _di_spawned = false

func _process(delta: float) -> bool:
	_f += 1
	if _f < 4:
		return false
	if GoblinScene == null:
		GoblinScene = load("res://scenes/enemies/goblin.tscn")
		MutantScene = load("res://scenes/enemies/goblin_mutant.tscn")
		DiScene     = load("res://scenes/spells/di.tscn")
	_pin()
	_t += delta

	match _phase:
		0:
			print("[mobs] 4 goblins + Di…"); _setup_mobs(4); _t = 0.0; _phase = 1
		1:
			if _di_done() or _t > 9.0:
				if _alive_mobs() == 0: print("  ✓ chuva de flechas limpou os mobs")
				else: print("  ✗ sobraram %d mobs" % _alive_mobs()); _fails += 1
				_cleanup(); _t = 0.0; _phase = 2
		2:
			if _t > 0.5:
				print("[Boss] Boss sozinho + Di…"); _setup_boss(); _t = 0.0; _phase = 3
		3:
			if _di_done() or _t > 9.0:
				if not is_instance_valid(boss):
					print("  ✗ Di matou o Boss sozinha (não devia)"); _fails += 1
				else:
					var dmg: float = boss_max - boss.hp
					if dmg > 0.0 and boss.hp > 0.0:
						print("  ✓ Boss cravado em %.0f e VIVO (hp %.0f/%.0f)" % [dmg, boss.hp, boss_max])
					else:
						print("  ✗ dano no Boss inesperado (dmg %.0f, hp %.0f)" % [dmg, boss.hp]); _fails += 1
				if _fails == 0:
					print("RESULTADO: CONVOKE da Di OK ✓")
					quit(0)
				else:
					print("RESULTADO: %d falha(s) ✗" % _fails)
					quit(1)
				return true
	return false
