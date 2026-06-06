extends Node2D

var _qte_packed: PackedScene

func _ready() -> void:
	call_deferred("_start")

func _start() -> void:
	GameState.fade_in(0.9)
	_show_anime()

func _show_anime() -> void:
	_qte_packed = load("res://scenes/intro/qte_tower.tscn")
	# Abertura anime de verdade (cinematic) no lugar do placeholder conceitual.
	var scene = load("res://scenes/intro/anime_opening.tscn").instantiate()
	add_child(scene)
	scene.finished.connect(func():
		scene.queue_free()
		_transition_to_qte()
	, CONNECT_ONE_SHOT)

func _transition_to_qte() -> void:
	var scene = _qte_packed.instantiate()
	add_child(scene)
	GameState.fade_in(0.55)
	scene.completed.connect(func(success: bool):
		scene.queue_free()
		if success:
			_transition_to_aftermath()
		else:
			_transition_to_capture_outcome()
	, CONNECT_ONE_SHOT)

func _transition_to_aftermath() -> void:
	GameState.fade_out_then(func():
		var scene = load("res://scenes/intro/time_stop_aftermath.tscn").instantiate()
		add_child(scene)
		GameState.fade_in(0.5)
		scene.finished.connect(func():
			scene.queue_free()
			_transition_to_corridor()
		, CONNECT_ONE_SHOT)
	, 0.40)

func _transition_to_corridor() -> void:
	GameState.fade_out_then(func():
		var scene = load("res://scenes/intro/tower_corridor.tscn").instantiate()
		add_child(scene)
		GameState.fade_in(0.55)
		scene.finished.connect(func():
			scene.queue_free()
			_transition_to_fall()
		, CONNECT_ONE_SHOT)
	, 0.40)

func _transition_to_fall() -> void:
	GameState.fade_out_then(func():
		var scene = load("res://scenes/intro/window_fall_anime.tscn").instantiate()
		add_child(scene)
		GameState.fade_in(0.45)
		scene.finished.connect(func(_air_hike_success: bool):
			scene.queue_free()
			_transition_to_landing()
		, CONNECT_ONE_SHOT)
	, 0.40)

func _transition_to_landing() -> void:
	# Depois da queda da torre, entra no NÍVEL JOGÁVEL DE VERDADE (floresta real:
	# Player físico, goblins, boss com rockfall) — substitui as cutscenes
	# scriptadas (landing/goblin/forest_fight) que eram só conceituais.
	GameState.fade_out_then(func():
		get_tree().change_scene_to_file("res://scenes/world/dungeon_1.tscn")
	, 0.40)

func _transition_to_goblin() -> void:
	GameState.fade_out_then(func():
		var scene = load("res://scenes/intro/goblin_encounter.tscn").instantiate()
		add_child(scene)
		GameState.fade_in(0.6)
		scene.finished.connect(func():
			scene.queue_free()
			_transition_to_forest()
		, CONNECT_ONE_SHOT)
	, 0.45)

func _transition_to_forest() -> void:
	GameState.fade_out_then(func():
		var scene = load("res://scenes/intro/forest_fight.tscn").instantiate()
		add_child(scene)
		GameState.fade_in(0.55)
		scene.finished.connect(func():
			scene.queue_free()
			_transition_to_anime_fireball()
		, CONNECT_ONE_SHOT)
	, 0.45)

func _transition_to_anime_fireball() -> void:
	GameState.fade_out_then(func():
		var scene = load("res://scenes/intro/anime_fireball.tscn").instantiate()
		add_child(scene)
		GameState.fade_in(0.6)
		scene.finished.connect(func():
			scene.queue_free()
			_transition_to_chapter_end()
		, CONNECT_ONE_SHOT)
	, 0.50)

func _transition_to_chapter_end() -> void:
	GameState.fade_out_then(func():
		var scene = load("res://scenes/intro/chapter_end.tscn").instantiate()
		add_child(scene)
		GameState.fade_in(0.6)
		scene.restart_requested.connect(func():
			scene.queue_free()
			_show_anime()
		, CONNECT_ONE_SHOT)
	, 0.50)

func _transition_to_capture_outcome() -> void:
	GameState.fade_out_then(func():
		var scene = load("res://scenes/intro/outcome_screen.tscn").instantiate()
		scene.success = false
		add_child(scene)
		GameState.fade_in(0.65)
		scene.restart_requested.connect(func():
			scene.queue_free()
			_show_anime()
		, CONNECT_ONE_SHOT)
	, 0.50)
