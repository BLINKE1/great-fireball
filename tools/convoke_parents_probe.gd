extends SceneTree
## Smoke test dos Convokes da família (Rose=gelo, Zé=fogo) — headless.
##   $GODOT --headless -s tools/convoke_parents_probe.gd
##
## Ambos são ultimates de NG+: OVERKILL em TODOS os inimigos, inclusive o Boss.
## [Rose] 3 mobs + Boss -> sala zerada.
## [Zé]   3 mobs + Boss -> sala zerada.

var GoblinScene: PackedScene
var MutantScene: PackedScene
var RoseScene: PackedScene
var ZeScene: PackedScene

var _f := 0
var _t := 0.0
var _phase := 0
var _fails := 0
var _spawned_group := ""

func _setup() -> void:
	for i in 3:
		var m := GoblinScene.instantiate()
		get_root().add_child(m)
		m.global_position = Vector2(560.0 + i * 60.0, 300.0)
	var b := MutantScene.instantiate()
	get_root().add_child(b)
	b.global_position = Vector2(820.0, 300.0)

func _convoke(scene: PackedScene, grp: String) -> void:
	var a := scene.instantiate()
	a.facing = 1.0
	get_root().add_child(a)
	a.global_position = Vector2(440.0, 220.0)
	_spawned_group = grp

func _alive_enemies() -> int:
	var n := 0
	for e in get_nodes_in_group("enemy"):
		if is_instance_valid(e) and not e.is_dead:
			n += 1
	return n

func _ally_gone() -> bool:
	return _spawned_group != "" and get_nodes_in_group(_spawned_group).is_empty()

func _clear() -> void:
	for e in get_nodes_in_group("enemy"):
		if is_instance_valid(e):
			e.queue_free()
	_spawned_group = ""

func _process(delta: float) -> bool:
	_f += 1
	if _f < 4:
		return false
	if GoblinScene == null:
		GoblinScene = load("res://scenes/enemies/goblin.tscn")
		MutantScene = load("res://scenes/enemies/goblin_mutant.tscn")
		RoseScene   = load("res://scenes/spells/rose.tscn")
		ZeScene     = load("res://scenes/spells/ze.tscn")
	_t += delta

	match _phase:
		0:
			print("[Rose] 3 mobs + Boss + Rose (Execução Aurora)…")
			_setup(); _convoke(RoseScene, "rose"); _t = 0.0; _phase = 1
		1:
			if _ally_gone() or _t > 8.0:
				if _alive_enemies() == 0: print("  ✓ sala zerada pela Rose (overkill geral)")
				else: print("  ✗ sobraram %d inimigos" % _alive_enemies()); _fails += 1
				_clear(); _t = 0.0; _phase = 2
		2:
			if _t > 0.5:
				print("[Zé] 3 mobs + Boss + Zé (Grande Bola de Fogo)…")
				_setup(); _convoke(ZeScene, "ze"); _t = 0.0; _phase = 3
		3:
			if _ally_gone() or _t > 8.0:
				if _alive_enemies() == 0: print("  ✓ sala zerada pelo Zé (overkill geral)")
				else: print("  ✗ sobraram %d inimigos" % _alive_enemies()); _fails += 1
				if _fails == 0:
					print("RESULTADO: Convokes da família OK ✓")
					quit(0)
				else:
					print("RESULTADO: %d falha(s) ✗" % _fails)
					quit(1)
				return true
	return false
