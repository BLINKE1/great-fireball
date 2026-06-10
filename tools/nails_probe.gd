extends SceneTree
## Smoke test do sistema de UNHAS PODEROSAS (headless).
##   $GODOT --headless -s tools/nails_probe.gd
##
## [Lava]  on_hit aplica queimadura (DoT): dano ao longo do tempo, mata se baixo.
## [Raios] on_hit salta pra um inimigo próximo (corrente).
## [Gelo]  on_hit tem chance de congelar (sleep) o inimigo.
## [Tint]  a cor do projétil muda por conjunto.

var GoblinScene: PackedScene

var _f := 0
var _t := 0.0
var _phase := 0
var _fails := 0

var a: Node = null
var b: Node = null
var a_hp0 := 0.0

func _spawn(x: float) -> Node:
	var g := GoblinScene.instantiate()
	get_root().add_child(g)
	g.global_position = Vector2(x, 300.0)
	return g

func _pin() -> void:
	for e in get_nodes_in_group("enemy"):
		if is_instance_valid(e):
			e.global_position.y = 300.0
			e.velocity = Vector2.ZERO

func _cleanup() -> void:
	for e in get_nodes_in_group("enemy"):
		if is_instance_valid(e):
			e.queue_free()
	a = null; b = null

func _nails() -> Node:
	return get_root().get_node_or_null("Nails")

func _process(delta: float) -> bool:
	_f += 1
	if _f < 4:
		return false
	if GoblinScene == null:
		GoblinScene = load("res://scenes/enemies/goblin.tscn")
	_pin()
	_t += delta
	var N := _nails()
	if N == null:
		print("✗ autoload Nails ausente"); quit(1); return true

	match _phase:
		0:
			a = _spawn(500.0)            # cheio
			b = _spawn(560.0)            # quase morto
			b.hp = 15.0
			a_hp0 = a.hp
			N.equip("lava")
			N.on_hit(a, a.global_position)
			N.on_hit(b, b.global_position)
			print("[Lava] queimadura aplicada…")
			_t = 0.0; _phase = 1
		1:
			if _t > 2.8:
				var burned: bool = is_instance_valid(a) and a.hp < a_hp0 - 1.0
				var killed: bool = (not is_instance_valid(b)) or b.is_dead
				if burned: print("  ✓ DoT queimou (hp %.0f -> %.0f)" % [a_hp0, a.hp if is_instance_valid(a) else 0.0])
				else: print("  ✗ DoT não causou dano"); _fails += 1
				if killed: print("  ✓ alvo em baixa foi consumido pelo fogo")
				else: print("  ✗ alvo em baixa sobreviveu"); _fails += 1
				_cleanup(); _t = 0.0; _phase = 2
		2:
			if _t > 0.3:
				a = _spawn(500.0); b = _spawn(560.0)
				N.equip("raios")
				N.on_hit(a, a.global_position)
				print("[Raios] corrente disparada…")
				_t = 0.0; _phase = 3
		3:
			if _t > 0.2:
				if is_instance_valid(b) and b.hp < 40.0:
					print("  ✓ raio saltou pro vizinho (hp %.0f)" % b.hp)
				else:
					print("  ✗ raio não saltou"); _fails += 1
				_cleanup(); _t = 0.0; _phase = 4
		4:
			if _t > 0.3:
				a = _spawn(500.0)
				N.equip("gelo")
				for i in 30:
					N.on_hit(a, a.global_position)
				if is_instance_valid(a) and a._sleep_timer > 0.0:
					print("[Gelo] ✓ inimigo congelado (sleep %.2f)" % a._sleep_timer)
				else:
					print("[Gelo] ✗ não congelou em 30 tentativas"); _fails += 1
				_cleanup(); _t = 0.0; _phase = 5
		5:
			N.equip("lava")
			var lava_c: Color = N.tint()
			N.equip("none")
			var none_c: Color = N.tint()
			if lava_c != none_c and none_c == Color(1, 1, 1):
				print("[Tint] ✓ cor muda por conjunto (lava=%s, none=branco)" % str(lava_c))
			else:
				print("[Tint] ✗ tint inesperado"); _fails += 1
			if _fails == 0:
				print("RESULTADO: Unhas Poderosas OK ✓")
				quit(0)
			else:
				print("RESULTADO: %d falha(s) ✗" % _fails)
				quit(1)
			return true
	return false
