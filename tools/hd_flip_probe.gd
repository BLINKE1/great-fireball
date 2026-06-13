extends SceneTree
# Valida numericamente o fix do flip/escala HD: força anim+facing e lê o
# sprite.scale / flip_h / position resultantes.
var _f := 0
var _lvl
var _player
var _phase := 0
var _cases: Array = []
var _results: Array = []

func _initialize() -> void:
	_lvl = load("res://scenes/world/dungeon_1.tscn").instantiate()
	get_root().add_child.call_deferred(_lvl)

	# (anim_base, mana_lvl, facing) — testamos cada par de anim × direção.
	_cases = [
		["idle",  5,  1.0],
		["idle",  5, -1.0],
		["walk",  0,  1.0],
		["walk",  0, -1.0],
		["run",   0,  1.0],
		["run",   0, -1.0],
		["jump",  0,  1.0],
		["jump",  0, -1.0],
		["fall",  0,  1.0],
		["fall",  0, -1.0],
		["cast",  5,  1.0],
		["cast",  5, -1.0],
		["slash", 5,  1.0],
		["slash", 5, -1.0],
		["hurt",  0,  1.0],
		["hurt",  0, -1.0],
	]

func _find_player() -> Node:
	if _player and is_instance_valid(_player): return _player
	for n in get_root().get_tree().get_nodes_in_group("player"):
		return n
	return null

func _process(_d) -> bool:
	_f += 1
	if _f < 30: return false   # deixa o jogo carregar
	_player = _find_player()
	if not _player:
		print("FAIL: player not found"); quit(1); return true

	var sprite: AnimatedSprite2D = _player.get_node("Sprite2D")
	if _phase >= _cases.size():
		_dump_table()
		quit(0); return true

	var c = _cases[_phase]
	var anim_base: String = c[0]
	var lvl: int = int(c[1])
	var facing: float = float(c[2])

	# Força a anim diretamente — pulamos _update_anim chamando _update_visuals
	# após setar o estado interno.
	var anim_name := "%s_%d" % [anim_base, lvl] if lvl > 0 else anim_base
	sprite.play(anim_name)
	_player.facing = facing
	# Pulo da animação dinâmica: _update_visuals sobrescreverá a anim via
	# _update_anim(); pra fixar, setamos velocity coerente com a anim.
	match anim_base:
		"idle":
			_player.velocity = Vector2.ZERO
		"walk":
			_player.velocity = Vector2(facing * 100.0, 0)
		"run":
			_player.velocity = Vector2(facing * 250.0, 0)
		"jump":
			_player.velocity = Vector2(facing * 60.0, -300.0)
		"fall":
			_player.velocity = Vector2(facing * 60.0, 200.0)
		"cast", "slash":
			# attack_pose_timer > 0 prioriza essas anims.
			_player.velocity = Vector2.ZERO
			_player._attack_pose = anim_base
			_player._attack_pose_timer = 0.5
		"hurt":
			_player.velocity = Vector2.ZERO
			_player.iframe_timer = 0.9

	_player._update_visuals()

	var info := {
		"case": "%s facing=%+.0f" % [anim_base, facing],
		"anim": sprite.animation,
		"flip_h": sprite.flip_h,
		"scale": sprite.scale,
		"pos": sprite.position,
	}
	_results.append(info)
	_phase += 1
	return false

func _dump_table() -> void:
	print("\n==== FLIP / SCALE / POS por (anim × facing) ====")
	print("%-20s %-14s %-7s %-22s %s" % ["case", "anim played", "flip_h", "scale", "pos"])
	for r in _results:
		print("%-20s %-14s %-7s %-22s %s" % [r["case"], r["anim"], str(r["flip_h"]), str(r["scale"]), str(r["pos"])])
	# Sanidade: idle face direita = flip_h false. walk face direita = flip_h true (XOR).
	print("\nesperado:")
	print("  idle/run faces RIGHT (native right): facing=+1 → flip_h=false ; facing=-1 → flip_h=true")
	print("  walk/jump/fall/cast/slash/hurt (native left): facing=+1 → flip_h=true ; facing=-1 → flip_h=false")
