extends SceneTree
## Smoke test do CONVOKE do Gus (headless) — valida a ALOCAÇÃO de alvos.
##   $GODOT --headless -s tools/convoke_gus_probe.gd
##
## [3 mobs]      → mata os 3 (adaga, adaga, jiu-jítsu) e NÃO toca no Boss.
## [2 mobs+Boss] → mata os 2 e arranca o braço (Boss leva só ARM_RIP = 55).
## [1 mob +Boss] → mata 1, joga adaga no Boss e arranca (22 + 55 = 77).
## [0 mob +Boss] → 2 adagas + arrancada no Boss (22 + 22 + 55 = 99). Não mata.

var GoblinScene: PackedScene
var MutantScene: PackedScene
var GusScene: PackedScene

const DAGGER_BOSS := 22.0
const ARM_RIP     := 55.0

var _f := 0
var _t := 0.0
var _phase := 0
var _fails := 0
var _gus_spawned := false

var mobs: Array = []
var boss: Node = null
var boss_max := 0.0

func _setup(n_mobs: int, with_boss: bool) -> void:
	mobs.clear()
	boss = null
	for i in n_mobs:
		var g := GoblinScene.instantiate()
		get_root().add_child(g)
		g.global_position = Vector2(560.0 + i * 70.0, 300.0)
		mobs.append(g)
	if with_boss:
		boss = MutantScene.instantiate()
		get_root().add_child(boss)
		boss.global_position = Vector2(880.0, 300.0)
		boss_max = boss.hp
	var gus := GusScene.instantiate()
	gus.facing = 1.0
	get_root().add_child(gus)
	gus.global_position = Vector2(440.0, 300.0)
	_gus_spawned = true

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

func _gus_done() -> bool:
	return _gus_spawned and get_nodes_in_group("gus").is_empty()

func _cleanup() -> void:
	for e in get_nodes_in_group("enemy"):
		if is_instance_valid(e):
			e.queue_free()
	mobs.clear()
	boss = null
	_gus_spawned = false

func _check_boss(expected_dmg: float, tag: String) -> void:
	if boss == null:
		return
	if not is_instance_valid(boss):
		print("  %s ✗ Boss morreu (não devia)" % tag); _fails += 1
		return
	var dmg: float = boss_max - boss.hp
	if absf(dmg - expected_dmg) < 1.0:
		print("  %s ✓ Boss levou %.0f (esperado %.0f), vivo" % [tag, dmg, expected_dmg])
	else:
		print("  %s ✗ Boss levou %.0f, esperado %.0f" % [tag, dmg, expected_dmg]); _fails += 1

func _process(delta: float) -> bool:
	_f += 1
	if _f < 4:
		return false
	if GoblinScene == null:
		GoblinScene = load("res://scenes/enemies/goblin.tscn")
		MutantScene = load("res://scenes/enemies/goblin_mutant.tscn")
		GusScene    = load("res://scenes/spells/gus.tscn")
	_pin()
	_t += delta

	match _phase:
		0:
			print("[3 mobs] convocando Gus…"); _setup(3, true); _t = 0.0; _phase = 1
		1:
			if _gus_done() or _t > 12.0:
				if _alive_mobs() == 0: print("  ✓ 3 mobs abatidos")
				else: print("  ✗ sobraram %d mobs" % _alive_mobs()); _fails += 1
				_check_boss(0.0, "[3 mobs]")   # não chega no Boss
				_cleanup(); _t = 0.0; _phase = 2
		2:
			if _t > 0.5:
				print("[2 mobs+Boss] convocando Gus…"); _setup(2, true); _t = 0.0; _phase = 3
		3:
			if _gus_done() or _t > 12.0:
				if _alive_mobs() == 0: print("  ✓ 2 mobs abatidos")
				else: print("  ✗ sobraram %d mobs" % _alive_mobs()); _fails += 1
				_check_boss(ARM_RIP, "[2 mobs+Boss]")
				_cleanup(); _t = 0.0; _phase = 4
		4:
			if _t > 0.5:
				print("[1 mob+Boss] convocando Gus…"); _setup(1, true); _t = 0.0; _phase = 5
		5:
			if _gus_done() or _t > 12.0:
				if _alive_mobs() == 0: print("  ✓ 1 mob abatido")
				else: print("  ✗ sobrou mob"); _fails += 1
				_check_boss(DAGGER_BOSS + ARM_RIP, "[1 mob+Boss]")
				_cleanup(); _t = 0.0; _phase = 6
		6:
			if _t > 0.5:
				print("[0 mob+Boss] convocando Gus…"); _setup(0, true); _t = 0.0; _phase = 7
		7:
			if _gus_done() or _t > 12.0:
				_check_boss(DAGGER_BOSS * 2.0 + ARM_RIP, "[0 mob+Boss]")
				if _fails == 0:
					print("RESULTADO: CONVOKE do Gus OK ✓")
					quit(0)
				else:
					print("RESULTADO: %d falha(s) ✗" % _fails)
					quit(1)
				return true
	return false
