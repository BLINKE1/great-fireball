extends SceneTree
## Valida a arena do boss no test room: a torre é construída e, ao pisar na
## plataforma do topo, o Goblin Mutante spawna.
var _room; var _player; var _f := 0; var _tp := false
func _initialize() -> void:
	_room = load("res://scenes/world/soph_test_room.tscn").instantiate()
	get_root().add_child.call_deferred(_room)
func _process(_d) -> bool:
	_f += 1
	if _f == 10:
		_player = _room.get_node_or_null("Player")
		if _player == null: print("NO PLAYER"); quit(1); return true
		# conta plataformas estáticas (torre construída?)
		var statics := 0
		for c in _room.get_children():
			if c is StaticBody2D: statics += 1
		print("StaticBody2D na sala: ", statics)
		# teleporta pra arena do topo
		var ay: float = _room._arena_center_y()
		_player.global_position = Vector2(580, ay - 70.0)
		_player.velocity = Vector2.ZERO
		_tp = true
	if _tp and _f > 14 and _f < 60:
		# segura o player na arena pra garantir o overlap do gatilho
		var ay: float = _room._arena_center_y()
		if _player.global_position.y < ay - 40.0:
			_player.global_position.y = ay - 20.0
	if _f == 70:
		var spawned = _room._arena_boss_spawned
		var has_mut := false
		for e in get_nodes_in_group("enemy"):
			if is_instance_valid(e) and String(e.name).begins_with("GoblinMutant"):
				has_mut = true
		print("arena_boss_spawned: ", spawned, " | mutante na cena: ", has_mut)
		print("RESULTADO arena: ", ("✓" if spawned and has_mut else "✗ REVER"))
		quit(0 if (spawned and has_mut) else 1); return true
	return false
