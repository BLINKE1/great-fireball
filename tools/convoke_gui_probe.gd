extends SceneTree
## Smoke test do CONVOKE do Gui Fenrir (headless).
##   $GODOT --headless -s tools/convoke_gui_probe.gd
##
## [A] 5 mobs (sem boss): espetinho (3) + lobisomem (até 4) limpam a sala.
## [B] 3 mobs + Boss: espeta os 3, vira lobo e dilacera o Boss (~90, vivo).
## [C] Boss sozinho: crava (40) + ferocidade (90) = ~130 no Boss, VIVO.

var GoblinScene: PackedScene
var MutantScene: PackedScene
var GuiScene: PackedScene

const WOLF_ONLY := 12.0 * 5 + 30.0   # 90 (ferocidade)
const STAB := 40.0

var _f := 0
var _t := 0.0
var _phase := 0
var _fails := 0
var _spawned := false

var mobs: Array = []
var boss: Node = null
var boss_max := 0.0

func _spawn_gui() -> void:
	var g := GuiScene.instantiate()
	g.facing = 1.0
	get_root().add_child(g)
	g.global_position = Vector2(440.0, 300.0)
	_spawned = true

func _setup(n_mobs: int, with_boss: bool) -> void:
	mobs.clear(); boss = null
	for i in n_mobs:
		var m := GoblinScene.instantiate()
		get_root().add_child(m)
		m.global_position = Vector2(540.0 + i * 56.0, 300.0)
		mobs.append(m)
	if with_boss:
		boss = MutantScene.instantiate()
		get_root().add_child(boss)
		boss.global_position = Vector2(880.0, 300.0)
		boss_max = boss.hp
	_spawn_gui()

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

func _done() -> bool:
	return _spawned and get_nodes_in_group("gui_fenrir").is_empty()

func _cleanup() -> void:
	for e in get_nodes_in_group("enemy"):
		if is_instance_valid(e):
			e.queue_free()
	mobs.clear(); boss = null; _spawned = false

func _check_boss(expected: float, tag: String) -> void:
	if not is_instance_valid(boss):
		print("  %s ✗ Boss morreu (não devia)" % tag); _fails += 1; return
	var dmg: float = boss_max - boss.hp
	if absf(dmg - expected) < 1.0 and boss.hp > 0.0:
		print("  %s ✓ Boss levou %.0f (esperado %.0f), VIVO" % [tag, dmg, expected])
	else:
		print("  %s ✗ Boss levou %.0f, esperado %.0f (hp %.0f)" % [tag, dmg, expected, boss.hp]); _fails += 1

func _process(delta: float) -> bool:
	_f += 1
	if _f < 4:
		return false
	if GoblinScene == null:
		GoblinScene = load("res://scenes/enemies/goblin.tscn")
		MutantScene = load("res://scenes/enemies/goblin_mutant.tscn")
		GuiScene    = load("res://scenes/spells/gui.tscn")
	_pin()
	_t += delta

	match _phase:
		0:
			print("[A] 5 mobs + Gui…"); _setup(5, false); _t = 0.0; _phase = 1
		1:
			if _done() or _t > 10.0:
				if _alive_mobs() == 0: print("  ✓ sala limpa (espetinho + lobo)")
				else: print("  ✗ sobraram %d mobs" % _alive_mobs()); _fails += 1
				_cleanup(); _t = 0.0; _phase = 2
		2:
			if _t > 0.5:
				print("[B] 3 mobs + Boss + Gui…"); _setup(3, true); _t = 0.0; _phase = 3
		3:
			if _done() or _t > 10.0:
				if _alive_mobs() == 0: print("  ✓ 3 mobs espetados")
				else: print("  ✗ sobraram %d mobs" % _alive_mobs()); _fails += 1
				_check_boss(WOLF_ONLY, "[B]")
				_cleanup(); _t = 0.0; _phase = 4
		4:
			if _t > 0.5:
				print("[C] Boss sozinho + Gui…"); _setup(0, true); _t = 0.0; _phase = 5
		5:
			if _done() or _t > 10.0:
				_check_boss(STAB + WOLF_ONLY, "[C]")
				if _fails == 0:
					print("RESULTADO: CONVOKE do Gui Fenrir OK ✓")
					quit(0)
				else:
					print("RESULTADO: %d falha(s) ✗" % _fails)
					quit(1)
				return true
	return false
