extends SceneTree
## Valida a mira do magic missile: time_scale na mira, disparo em ângulo
## (míssil anda na diagonal) e restauração do tempo. Headless.
##   $GODOT --headless -s tools/aim_probe.gd
var _f := 0
var _room
var _p
var _missile
var _p0: Vector2

func _initialize() -> void:
	_room = load("res://scenes/world/soph_test_room.tscn").instantiate()
	get_root().add_child.call_deferred(_room)

func _process(_d: float) -> bool:
	_f += 1
	if _p == null and _room:
		_p = _room.get_node_or_null("Player")
	if _p == null:
		return false
	if _f == 4:
		_p.mana.current_mana = 999.0
		# entra na mira
		_p._start_aim()
		print("aiming=", _p.is_aiming, " time_scale=", Engine.time_scale)
		# mira 45° pra cima-direita e dispara
		_p._aim_angle = -PI / 4.0
		_p._fire_aimed_missile()
		for c in _p.get_parent().get_children():
			if c.has_method("_on_body_entered") and "aim_dir" in c:
				_missile = c
		if _missile:
			print("missile aim_dir=", _missile.aim_dir)
			_p0 = _missile.global_position
		else:
			print("FALHOU: missile nao encontrado"); quit(1); return true
		_p._end_aim()
		print("time_scale apos end=", Engine.time_scale)
	elif _f == 10 and _missile and is_instance_valid(_missile):
		var d: Vector2 = _missile.global_position - _p0
		print("deslocamento dx=", d.x, " dy=", d.y)
		var ok: bool = d.x > 1.0 and d.y < -1.0 and abs(Engine.time_scale - 1.0) < 0.001
		print("RESULT: ", "OK ✓" if ok else "FALHOU ✗")
		quit(0 if ok else 1)
		return true
	return false
