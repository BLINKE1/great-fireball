extends CanvasLayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	$Panel/VBox/ResumeButton.pressed.connect(_resume)
	$Panel/VBox/MenuButton.pressed.connect(_main_menu)
	_add_controls_hint()

func _add_controls_hint() -> void:
	# Expand panel to fit controls
	$Panel.offset_top    = -185.0
	$Panel.offset_bottom =  185.0
	$Panel.offset_left   = -175.0
	$Panel.offset_right  =  175.0

	var sep := HSeparator.new()
	sep.layout_mode = 2
	$Panel/VBox.add_child(sep)

	var hint := Label.new()
	hint.layout_mode = 2
	hint.text = "Mover: ←→      Pular: Espaço\n" + \
				"Ataque: Q       Míssil: Z\n" + \
				"Míssil Duplo: A     Perfurante: S\n" + \
				"Míssil Gigante: D\n" + \
				"Para o Tempo: X     Cura: C\n" + \
				"Dash: Shift     Pause: Esc"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.70, 0.70, 0.85))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	$Panel/VBox.add_child(hint)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if visible: _resume()
		elif not GameState.dialogue_active: _pause()
		get_viewport().set_input_as_handled()

func _pause() -> void:
	visible = true
	get_tree().paused = true

func _resume() -> void:
	visible = false
	get_tree().paused = false

func _main_menu() -> void:
	get_tree().paused = false
	GameState.fade_out_then(func():
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
	)
