extends SceneTree
## Smoke test do CONVOKE / Juju (headless).
##   $GODOT --headless -s tools/convoke_probe.gd
##
## Test A (sucesso): convoca a Juju com inimigos em cena → após ~3s ela põe
##   TODOS pra dormir (sleep timer > 0).
## Test B (cancelamento): convoca a Juju e bate nela 3x (>2 hits) → o efeito é
##   cortado e os inimigos NÃO dormem.

# NB: usar load() em runtime (não preload no topo) — preload compilaria os
# scripts das cenas ANTES dos autoloads (SpriteSetup) existirem.
var GoblinScene: PackedScene
var ArcherScene: PackedScene
var JujuScene: PackedScene

var _t := 0.0
var _f := 0
var _phase := 0
var _enemies: Array = []
var _juju: Node = null
var _fails := 0

func _spawn_enemies() -> void:
	if GoblinScene == null:
		GoblinScene = load("res://scenes/enemies/goblin.tscn")
		ArcherScene = load("res://scenes/enemies/goblin_archer.tscn")
		JujuScene   = load("res://scenes/spells/juju.tscn")
	_enemies.clear()
	for x in [300.0, 380.0, 460.0]:
		var e := (GoblinScene if x < 400.0 else ArcherScene).instantiate()
		get_root().add_child(e)
		e.global_position = Vector2(x, 300.0)
		_enemies.append(e)

func _spawn_juju() -> Node:
	var j := JujuScene.instantiate()
	get_root().add_child(j)
	j.global_position = Vector2(380.0, 250.0)
	return j

func _all_sleeping() -> bool:
	for e in _enemies:
		if not is_instance_valid(e): return false
		if e._sleep_timer <= 0.0: return false
	return true

func _none_sleeping() -> bool:
	for e in _enemies:
		if is_instance_valid(e) and e._sleep_timer > 0.0: return false
	return true

func _process(delta: float) -> bool:
	_f += 1
	if _f < 4:
		return false   # deixa autoloads/_ready assentarem
	_t += delta
	match _phase:
		0:
			_spawn_enemies()
			_juju = _spawn_juju()
			print("[A] convocada a Juju com %d inimigos" % _enemies.size())
			_t = 0.0
			_phase = 1
		1:
			# Espera passar o FLY_TIME (3s) + folga pra o _do_sleep rodar.
			if _t >= 3.6:
				if _all_sleeping():
					print("[A] ✓ todos os inimigos dormindo após o voo da Juju")
				else:
					print("[A] ✗ inimigos NÃO dormiram"); _fails += 1
				# limpa pro teste B
				for e in _enemies:
					if is_instance_valid(e): e.queue_free()
				_phase = 2
				_t = 0.0
		2:
			# pequena pausa pra limpar a cena
			if _t >= 0.2:
				_spawn_enemies()
				_juju = _spawn_juju()
				print("[B] convocada a Juju (vamos bater nela 3x)")
				_phase = 3
				_t = 0.0
		3:
			# Bate 3x espaçado (cada hit tem i-frame de 0.4s).
			if is_instance_valid(_juju):
				_juju._iframe = 0.0
				_juju._hit()
			if _juju == null or not is_instance_valid(_juju):
				pass
			if _t >= 1.5:
				_phase = 4
				_t = 0.0
		4:
			# Após o cancelamento + tempo de voo, ninguém deve dormir.
			if _t >= 3.8:
				if _none_sleeping():
					print("[B] ✓ efeito cortado: nenhum inimigo dormiu (>2 hits)")
				else:
					print("[B] ✗ inimigos dormiram apesar do cancelamento"); _fails += 1
				if _fails == 0:
					print("RESULTADO: CONVOKE/Juju OK ✓")
					quit(0)
				else:
					print("RESULTADO: %d falha(s) ✗" % _fails)
					quit(1)
				return true
	return false
