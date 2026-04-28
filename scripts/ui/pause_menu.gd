extends CanvasLayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	$Panel/VBox/ResumeButton.pressed.connect(_resume)
	$Panel/VBox/MenuButton.pressed.connect(_main_menu)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if visible: _resume()
		else: _pause()
		get_viewport().set_input_as_handled()

func _pause() -> void:
	visible = true
	get_tree().paused = true

func _resume() -> void:
	visible = false
	get_tree().paused = false

func _main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
