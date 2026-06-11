extends SceneTree
## Smoke test do run-and-gun (headless): travessia, voador que mergulha, 1-hit,
## e os dois estágios até o boss.
##   $GODOT --headless -s tools/runner_probe.gd

var stage: Node = null
var f := 0
var t := 0.0
var phase := 0
var fails := 0
var _ek: Node = null
var _fl: Node = null
var _saw_dive := false
var _lives0 := 0

func _safe_invuln(v: float) -> void:
	var h := get_first_node_in_group("rhero")
	if h: h.invuln = v

func _process(d: float) -> bool:
	f += 1
	if f < 4:
		return false
	if stage == null:
		stage = load("res://scenes/runner/runner.tscn").instantiate()
		get_root().add_child(stage)
		return false
	t += d
	match phase:
		0:
			var hero := get_first_node_in_group("rhero")
			var en := get_nodes_in_group("renemy")
			if hero and en.size() > 0:
				print("[setup] ✓ hero + %d inimigos" % en.size())
			else:
				print("[setup] ✗ faltou hero/inimigos"); fails += 1
			# Travessia: buracos saltáveis + começo aberto (sem parede travando)
			var segs: Array = stage.ground_segs.duplicate()
			segs.sort_custom(func(a, b): return a[0] < b[0])
			var maxgap := 0.0
			for i in range(1, segs.size()):
				maxgap = maxf(maxgap, segs[i][0] - segs[i - 1][1])
			var open_start: bool = segs[0][0] <= 0.1 and (segs[0][1] - segs[0][0]) >= 600.0
			if maxgap <= 110.0 and open_start:
				print("[nível] ✓ corrível (maior buraco %.0f px, começo aberto)" % maxgap)
			else:
				print("[nível] ✗ travessia ruim (buraco %.0f, open=%s)" % [maxgap, open_start]); fails += 1
			for e in en:
				if e.kind == "flyer":
					_fl = e; break
			_safe_invuln(999.0)
			t = 0.0; phase = 1
		1:
			if _fl and is_instance_valid(_fl) and _fl._fstate == "dive":
				_saw_dive = true
			if t > 2.2:
				if _saw_dive: print("[voador] ✓ mergulha no herói (estado 'dive')")
				else: print("[voador] ✗ não mergulhou"); fails += 1
				var en := get_nodes_in_group("renemy")
				if en.size() > 0:
					_ek = en[0]; _ek.take_hit()
				t = 0.0; phase = 2
		2:
			if t > 0.15:
				if not is_instance_valid(_ek): print("[tiro]  ✓ inimigo morre em 1 acerto")
				else: print("[tiro]  ✗ inimigo sobreviveu"); fails += 1
				var hero := get_first_node_in_group("rhero")
				_lives0 = stage.lives
				hero.invuln = 0.0
				var en := get_nodes_in_group("renemy")
				for e in en:
					if e.kind != "flyer":
						hero.global_position = e.global_position; break
				t = 0.0; phase = 3
		3:
			if t > 0.3:
				if stage.lives < _lives0:
					print("[dano]  ✓ Soph morre em 1 hit (vidas %d -> %d)" % [_lives0, stage.lives])
				else:
					print("[dano]  ✗ não morreu"); fails += 1
				_safe_invuln(999.0)
				get_first_node_in_group("rhero").global_position = Vector2(2400, 440)
				t = 0.0; phase = 4
		4:
			if t > 0.4:
				var b := get_first_node_in_group("rboss")
				if b:
					print("[s1]    ✓ boss 1 apareceu")
					for i in range(b.max_hp):
						if is_instance_valid(b): b.take_hit()
				else:
					print("[s1]    ✗ boss 1 não apareceu"); fails += 1
				t = 0.0; phase = 5
		5:
			if t > 0.25:
				if stage.won: print("[s1]    ✓ boss 1 derrotado → estágio concluído")
				else: print("[s1]    ✗ não concluiu"); fails += 1
				stage.queue_free()
				var S := load("res://scripts/runner/runner_stage.gd")
				S.boot_stage = 2
				stage = load("res://scenes/runner/runner.tscn").instantiate()
				get_root().add_child(stage)
				t = 0.0; phase = 6
		6:
			if t > 0.25:
				var turrets := 0
				for e in get_nodes_in_group("renemy"):
					if e.kind == "turret": turrets += 1
				if stage.stage_num == 2 and turrets > 0:
					print("[s2]    ✓ estágio 2 montado (%d torretas)" % turrets)
				else:
					print("[s2]    ✗ estágio 2 incorreto"); fails += 1
				_safe_invuln(999.0)
				get_first_node_in_group("rhero").global_position = Vector2(2400, 440)
				t = 0.0; phase = 7
		7:
			if t > 0.4:
				var b := get_first_node_in_group("rboss")
				if b:
					print("[s2]    ✓ boss 2 apareceu (pattern %d, hp %d)" % [b.pattern, b.max_hp])
					for i in range(b.max_hp):
						if is_instance_valid(b): b.take_hit()
				else:
					print("[s2]    ✗ boss 2 não apareceu"); fails += 1
				t = 0.0; phase = 8
		8:
			if t > 0.25:
				if stage.won: print("[s2]    ✓ boss 2 derrotado → VOCÊ VENCEU")
				else: print("[s2]    ✗ não concluiu"); fails += 1
				if fails == 0:
					print("RESULTADO: run-and-gun (estágios 1 e 2, voador, travessia) OK ✓")
					quit(0)
				else:
					print("RESULTADO: %d falha(s) ✗" % fails)
					quit(1)
				return true
	return false
