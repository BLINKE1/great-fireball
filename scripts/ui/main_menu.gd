extends Control

func _ready() -> void:
	$VBox/PlayButton.pressed.connect(_on_play)
	$VBox/QuitButton.pressed.connect(get_tree().quit)
	$VBox/PlayButton.grab_focus()

func _on_play() -> void:
	get_tree().change_scene_to_file("res://scenes/world/tutorial_level.tscn")
