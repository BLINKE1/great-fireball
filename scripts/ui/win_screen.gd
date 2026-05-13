extends Control

const EMBER_COUNT = 28

var _exiting: bool = false

func _ready() -> void:
	GameState.fade_in(0.70)
	MusicManager.play("menu")
	call_deferred("_build_ui")

func _build_ui() -> void:
	_spawn_embers()

	var vbox := VBoxContainer.new()
	vbox.anchor_left   = 0.15
	vbox.anchor_top    = 0.15
	vbox.anchor_right  = 0.85
	vbox.anchor_bottom = 0.85
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 18)
	add_child(vbox)

	var title := Label.new()
	title.text = "GREAT FIREBALL"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color(1.0, 0.72, 0.12))
	vbox.add_child(title)
	_pulse_tween(title, Color(1.0, 0.72, 0.12), Color(1.0, 0.52, 0.06))

	var sub := Label.new()
	sub.text = "Fim do Demo"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 22)
	sub.add_theme_color_override("font_color", Color(0.68, 0.58, 0.82))
	vbox.add_child(sub)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 28)
	vbox.add_child(spacer)

	var lore := Label.new()
	lore.text = "Soph derrotou o Ogro da Floresta e descobriu\na localização da Montanha de Cinzas.\n\nEla aprendeu o Míssil Duplo, o Míssil Perfurante,\no Míssil Curvo e o temido Míssil Gigante —\nmas o Fireball ainda escapa entre seus dedos.\n\nA Montanha de Cinzas guarda o segredo.\nE Soph está indo até lá."
	lore.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lore.add_theme_font_size_override("font_size", 14)
	lore.add_theme_color_override("font_color", Color(0.80, 0.76, 0.90))
	vbox.add_child(lore)

	var score := Label.new()
	score.text = "Inimigos derrotados: %d      Tempo: %s" % [GameState.kill_count, GameState.get_elapsed_time()]
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score.add_theme_font_size_override("font_size", 13)
	score.add_theme_color_override("font_color", Color(0.95, 0.82, 0.42))
	vbox.add_child(score)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 24)
	vbox.add_child(spacer2)

	var hint := Label.new()
	hint.text = "Pressione qualquer tecla para voltar ao menu"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.55, 0.55, 0.70))
	vbox.add_child(hint)
	# Blink hint text
	var btw := hint.create_tween().set_loops()
	btw.tween_property(hint, "modulate:a", 0.18, 0.65).set_ease(Tween.EASE_IN_OUT)
	btw.tween_property(hint, "modulate:a", 1.00, 0.65).set_ease(Tween.EASE_IN_OUT)

func _pulse_tween(label: Label, col_a: Color, col_b: Color) -> void:
	var tw := label.create_tween().set_loops()
	tw.tween_property(label, "theme_override_colors/font_color", col_b, 1.5).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(label, "theme_override_colors/font_color", col_a, 1.5).set_ease(Tween.EASE_IN_OUT)

func _spawn_embers() -> void:
	var vp := get_viewport_rect().size
	for i in EMBER_COUNT:
		_make_ember(vp, randf_range(0.0, 1.0))

func _make_ember(vp: Vector2, progress: float) -> void:
	var e := ColorRect.new()
	var sz := randf_range(2.0, 7.0)
	e.custom_minimum_size = Vector2(sz, sz)
	e.size = Vector2(sz, sz)
	e.position = Vector2(randf_range(0.0, vp.x), vp.y * (1.0 - progress))
	var hue := randf_range(0.02, 0.12)  # orange-red range
	e.color = Color.from_hsv(hue, randf_range(0.7, 1.0), 1.0, randf_range(0.3, 0.75))
	add_child(e)
	move_child(e, 0)
	_float_ember(e, vp)

func _float_ember(e: ColorRect, vp: Vector2) -> void:
	var rise := randf_range(70.0, 200.0)
	var dur  := randf_range(3.5, 8.0)
	var tw := e.create_tween()
	tw.tween_property(e, "position:y", e.position.y - rise, dur).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(e, "modulate:a", 0.0, dur * 0.65).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		if not is_instance_valid(e): return
		var sz2 := randf_range(2.0, 7.0)
		e.custom_minimum_size = Vector2(sz2, sz2)
		e.size = Vector2(sz2, sz2)
		var hue2 := randf_range(0.02, 0.12)
		e.color = Color.from_hsv(hue2, randf_range(0.7, 1.0), 1.0, randf_range(0.3, 0.75))
		e.modulate.a = e.color.a
		e.position = Vector2(randf_range(0.0, vp.x), vp.y + 8.0)
		_float_ember(e, vp)
	)

func _input(event: InputEvent) -> void:
	if _exiting: return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel") \
			or (event is InputEventKey and event.pressed and not event.echo):
		_exiting = true
		get_viewport().set_input_as_handled()
		GameState.fade_out_then(func():
			get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
		)
