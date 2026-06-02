extends Node2D

# Sentinela: se o chamador não passar cor, escolhemos pela magnitude do dano.
const _AUTO := Color(0, 0, 0, -1.0)

func setup(amount: float, color: Color = _AUTO) -> void:
	var lbl: Label = $Label
	lbl.text = str(int(amount))

	# Escala por magnitude: leve / sólido / pesado (crit).
	var is_big  := amount >= 45.0
	var is_huge := amount >= 70.0

	# Cor por magnitude (quando não veio cor explícita — ex.: dano de fogo).
	if color.a < 0.0:
		if is_huge:    color = Color(1.0, 0.32, 0.16)   # vermelho-laranja (pesado)
		elif is_big:   color = Color(1.0, 0.62, 0.10)   # laranja (crit)
		elif amount < 12.0: color = Color(0.92, 0.95, 1.0)  # branco-azulado (leve)
		else:          color = Color(1.0, 0.90, 0.08)   # amarelo (padrão)
	lbl.add_theme_color_override("font_color", color)

	lbl.add_theme_font_size_override("font_size", 30 if is_huge else (24 if is_big else 18))
	lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)

	var rise := 70.0 if is_big else 52.0
	var dur  := 0.85 if is_big else 0.72
	# Deriva horizontal aleatória → números empilhados se espalham (legibilidade).
	var drift := randf_range(-20.0, 20.0)

	var tween = create_tween()
	if is_big:
		# Pop maior pra crits (pesa o golpe forte).
		var pop := 1.8 if is_huge else 1.5
		tween.tween_property(self, "scale", Vector2(pop, pop), 0.08)
		tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.12)
	# Sobe, deriva e some — tudo em paralelo (âncora = position:y).
	tween.tween_property(self, "position:y", position.y - rise, dur).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "position:x", position.x + drift, dur).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(lbl, "modulate:a", 0.0, dur * 0.75).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)
