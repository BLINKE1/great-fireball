extends SceneTree
## Smoke test do modo run-and-gun (headless).
##   $GODOT --headless -s tools/runner_probe.gd

var stage: Node = null
var f := 0
var t := 0.0
var phase := 0
var fails := 0
var _ek: Node = null
var _lives0 := 0

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
				print("[setup] ✓ hero + %d inimigos + nível" % en.size())
			else:
				print("[setup] ✗ faltou hero/inimigos"); fails += 1
			if en.size() > 0:
				_ek = en[0]; _ek.take_hit()
			t = 0.0; phase = 1
		1:
			if t > 0.15:
				if not is_instance_valid(_ek):
					print("[tiro]  ✓ inimigo morre em 1 acerto")
				else:
					print("[tiro]  ✗ inimigo sobreviveu"); fails += 1
				var hero := get_first_node_in_group("rhero")
				_lives0 = stage.lives
				hero.invuln = 0.0
				var en2 := get_nodes_in_group("renemy")
				if en2.size() > 0:
					hero.global_position = en2[0].global_position
				t = 0.0; phase = 2
		2:
			if t > 0.25:
				if stage.lives < _lives0:
					print("[dano]  ✓ Soph morre em 1 hit (vidas %d -> %d)" % [_lives0, stage.lives])
				else:
					print("[dano]  ✗ não morreu no contato"); fails += 1
				var hero := get_first_node_in_group("rhero")
				hero.global_position = Vector2(2200, 440)
				t = 0.0; phase = 3
		3:
			if t > 0.4:
				var b := get_first_node_in_group("rboss")
				if b:
					print("[boss]  ✓ boss apareceu na arena")
					for i in range(b.max_hp):
						if is_instance_valid(b):
							b.take_hit()
				else:
					print("[boss]  ✗ boss não apareceu"); fails += 1
				t = 0.0; phase = 4
		4:
			if t > 0.25:
				if stage.won:
					print("[s1]    ✓ boss 1 derrotado → estágio concluído")
				else:
					print("[s1]    ✗ não concluiu"); fails += 1
				# Monta o ESTÁGIO 2 (via static boot_stage)
				stage.queue_free()
				var S := load("res://scripts/runner/runner_stage.gd")
				S.boot_stage = 2
				stage = load("res://scenes/runner/runner.tscn").instantiate()
				get_root().add_child(stage)
				t = 0.0; phase = 5
		5:
			if t > 0.2:
				if stage.stage_num == 2:
					var turrets := 0
					for e in get_nodes_in_group("renemy"):
						if e.kind == "turret": turrets += 1
					print("[s2]    ✓ estágio 2 montado (%d torretas)" % turrets)
					if turrets == 0: fails += 1
				else:
					print("[s2]    ✗ não entrou no estágio 2"); fails += 1
				var hero := get_first_node_in_group("rhero")
				if hero: hero.global_position = Vector2(2200, 440)
				t = 0.0; phase = 6
		6:
			if t > 0.4:
				var b := get_first_node_in_group("rboss")
				if b:
					print("[s2]    ✓ boss 2 apareceu (pattern %d, hp %d)" % [b.pattern, b.max_hp])
					for i in range(b.max_hp):
						if is_instance_valid(b): b.take_hit()
				else:
					print("[s2]    ✗ boss 2 não apareceu"); fails += 1
				t = 0.0; phase = 7
		7:
			if t > 0.25:
				if stage.won:
					print("[s2]    ✓ boss 2 derrotado → VOCÊ VENCEU")
				else:
					print("[s2]    ✗ não concluiu"); fails += 1
				if fails == 0:
					print("RESULTADO: run-and-gun estágios 1 e 2 OK ✓")
					quit(0)
				else:
					print("RESULTADO: %d falha(s) ✗" % fails)
					quit(1)
				return true
	return false
