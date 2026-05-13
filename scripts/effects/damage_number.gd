extends Node2D

func setup(amount: float, color: Color = Color(1.0, 0.90, 0.08)) -> void:
	var lbl: Label = $Label
	lbl.text = str(int(amount))
	lbl.add_theme_color_override("font_color", color)

	# Critical hit: large damage
	var is_big := amount >= 45.0
	lbl.add_theme_font_size_override("font_size", 24 if is_big else 18)
	lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)

	var rise := 70.0 if is_big else 52.0
	var dur  := 0.85 if is_big else 0.72

	var tween = create_tween()
	if is_big:
		# Pop up before rising
		tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.08)
		tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.12)
	tween.tween_property(self, "position:y", position.y - rise, dur).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(lbl, "modulate:a", 0.0, dur * 0.75).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)
