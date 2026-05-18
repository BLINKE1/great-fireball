extends Node2D

func _ready() -> void:
	GameState.fade_in(0.9)
	call_deferred("_show_anime")

func _show_anime() -> void:
	var scene = load("res://scenes/intro/anime_placeholder.tscn").instantiate()
	add_child(scene)
	scene.finished.connect(func():
		scene.queue_free()
		_transition_to_qte()
	, CONNECT_ONE_SHOT)

func _transition_to_qte() -> void:
	GameState.fade_out_then(func():
		var scene = load("res://scenes/intro/qte_tower.tscn").instantiate()
		add_child(scene)
		GameState.fade_in(0.55)
		scene.completed.connect(func(success: bool):
			scene.queue_free()
			_transition_to_outcome(success)
		, CONNECT_ONE_SHOT)
	, 0.45)

func _transition_to_outcome(success: bool) -> void:
	GameState.fade_out_then(func():
		var scene = load("res://scenes/intro/outcome_screen.tscn").instantiate()
		scene.success = success
		add_child(scene)
		GameState.fade_in(0.65)
		scene.restart_requested.connect(func():
			scene.queue_free()
			_show_anime()
		, CONNECT_ONE_SHOT)
	, 0.50)
