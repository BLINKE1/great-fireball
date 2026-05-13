extends Area2D

var activated: bool = false

@onready var crystal: Sprite2D = $Crystal

func _ready() -> void:
	# Apply generated sprite
	var tex_off := SpriteSetup.get_texture("checkpoint_off")
	if tex_off:
		crystal.texture = tex_off
		crystal.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player") or activated:
		return
	activated = true

	# Save spawn point slightly above the checkpoint base
	body.spawn_position = global_position + Vector2(0, -40)

	# Restore player HP, mana, and clear status effects
	body.hp.restore_full()
	body.mana.restore_full()
	if body.has_method("clear_burn"):
		body.clear_burn()

	AudioManager.play("unlock")
	_activate()

func _activate() -> void:
	var tex_on := SpriteSetup.get_texture("checkpoint_on")
	if tex_on:
		crystal.texture = tex_on

	# Glow burst + double ring cascade
	VFX.burst(global_position, get_parent(), Color(0.25, 0.70, 1.0), 24, 95.0, 110.0)
	VFX.ring(global_position, get_parent(), Color(0.30, 0.75, 1.0, 0.85), 48.0, 0.42)
	VFX.sparkle(global_position, get_parent(), Color(0.55, 0.88, 1.0), 14)
	await get_tree().create_timer(0.18).timeout
	if is_instance_valid(self):
		VFX.ring(global_position, get_parent(), Color(0.45, 0.88, 1.0, 0.60), 68.0, 0.38)

	# Breathing scale pulse
	var tw := create_tween().set_loops()
	tw.tween_property(crystal, "scale", Vector2(1.10, 1.10), 0.85).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(crystal, "scale", Vector2(1.00, 1.00), 0.85).set_ease(Tween.EASE_IN_OUT)

	# Floating "Salvo!" notification with sub-text
	var lbl := Label.new()
	lbl.text = "✦ Checkpoint salvo! ✦\nHP e Mana restaurados"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.38, 0.88, 1.0))
	lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.80))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	lbl.position = global_position + Vector2(-72, -60)
	get_parent().add_child(lbl)
	var ltw := lbl.create_tween()
	ltw.tween_property(lbl, "scale", Vector2(1.15, 1.15), 0.10)
	ltw.tween_property(lbl, "scale", Vector2(1.00, 1.00), 0.14)
	ltw.tween_property(lbl, "position:y", lbl.position.y - 52, 1.6).set_ease(Tween.EASE_OUT)
	ltw.parallel().tween_property(lbl, "modulate:a", 0.0, 1.6).set_ease(Tween.EASE_IN)
	ltw.tween_callback(lbl.queue_free)
