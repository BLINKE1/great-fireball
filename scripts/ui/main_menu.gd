extends Control

const ORB_COUNT = 22

func _ready() -> void:
	$VBox/PlayButton.pressed.connect(_on_play)
	$VBox/QuitButton.pressed.connect(get_tree().quit)
	$VBox/PlayButton.grab_focus()
	call_deferred("_init_atmosphere")

func _on_play() -> void:
	GameState.fade_out_then(func():
		get_tree().change_scene_to_file("res://scenes/world/tutorial_level.tscn")
	, 0.45)

func _init_atmosphere() -> void:
	MusicManager.play("menu")
	_animate_title()
	_spawn_orbs()
	_add_lore_quote()

func _add_lore_quote() -> void:
	var vp := get_viewport_rect().size
	var quote := Label.new()
	quote.text = "\"Toda aprendiz de magia sonha com o Fireball.\"\n— Soph"
	quote.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quote.add_theme_font_size_override("font_size", 11)
	quote.add_theme_color_override("font_color", Color(0.55, 0.50, 0.72, 0.80))
	quote.size = Vector2(vp.x * 0.70, 40)
	quote.position = Vector2(vp.x * 0.15, vp.y - 52)
	add_child(quote)

	var ver := Label.new()
	ver.text = "Demo v0.4"
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ver.add_theme_font_size_override("font_size", 10)
	ver.add_theme_color_override("font_color", Color(0.40, 0.38, 0.52, 0.65))
	ver.size = Vector2(vp.x - 16, 20)
	ver.position = Vector2(8, vp.y - 22)
	add_child(ver)

func _animate_title() -> void:
	var title = $VBox/Title
	var tw := title.create_tween().set_loops()
	tw.tween_property(title, "theme_override_colors/font_color",
			Color(1.0, 0.88, 0.40), 1.6).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(title, "theme_override_colors/font_color",
			Color(1.0, 0.55, 0.06), 1.6).set_ease(Tween.EASE_IN_OUT)

func _spawn_orbs() -> void:
	var vp := get_viewport_rect().size
	for i in ORB_COUNT:
		_make_orb(vp, randf_range(0.0, 1.0))

func _make_orb(vp: Vector2, progress: float) -> void:
	var orb := ColorRect.new()
	var sz  := randf_range(3.0, 10.0)
	orb.custom_minimum_size = Vector2(sz, sz)
	orb.size = Vector2(sz, sz)
	# Start randomly distributed in height according to progress (0=bottom, 1=top)
	orb.position = Vector2(randf_range(0.0, vp.x), vp.y * (1.0 - progress))
	var hue := randf_range(0.62, 0.85)  # purple–blue range
	orb.color = Color.from_hsv(hue, randf_range(0.65, 0.95), 1.0, randf_range(0.25, 0.70))
	add_child(orb)
	move_child(orb, 1)  # above ColorRect background, below VBox
	_float_orb(orb, vp)

func _float_orb(orb: ColorRect, vp: Vector2) -> void:
	var rise := randf_range(80.0, 220.0)
	var dur  := randf_range(4.0, 8.5)
	var tw := orb.create_tween()
	tw.tween_property(orb, "position:y", orb.position.y - rise, dur).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(orb, "modulate:a", 0.0, dur * 0.70).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		if not is_instance_valid(orb): return
		var sz2 := randf_range(3.0, 10.0)
		orb.custom_minimum_size = Vector2(sz2, sz2)
		orb.size = Vector2(sz2, sz2)
		var hue2 := randf_range(0.62, 0.85)
		orb.color = Color.from_hsv(hue2, randf_range(0.65, 0.95), 1.0, randf_range(0.25, 0.70))
		orb.modulate.a = orb.color.a
		orb.position = Vector2(randf_range(0.0, vp.x), vp.y + 8.0)
		_float_orb(orb, vp)
	)
