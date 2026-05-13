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

	# Restore player HP and mana
	body.hp.restore_full()
	body.mana.restore_full()

	AudioManager.play("unlock")
	_activate()

func _activate() -> void:
	var tex_on := SpriteSetup.get_texture("checkpoint_on")
	if tex_on:
		crystal.texture = tex_on

	# Glow burst
	VFX.burst(global_position, get_parent(), Color(0.25, 0.70, 1.0), 20, 90.0, 100.0)

	# Breathing scale pulse
	var tw := create_tween().set_loops()
	tw.tween_property(crystal, "scale", Vector2(1.08, 1.08), 0.9).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(crystal, "scale", Vector2(1.00, 1.00), 0.9).set_ease(Tween.EASE_IN_OUT)

	# Floating "Salvo!" notification
	var lbl := Label.new()
	lbl.text = "Checkpoint salvo!"
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.38, 0.82, 1.0))
	lbl.position = global_position + Vector2(-48, -52)
	get_parent().add_child(lbl)
	var ltw := lbl.create_tween()
	ltw.tween_property(lbl, "position:y", lbl.position.y - 44, 1.4).set_ease(Tween.EASE_OUT)
	ltw.parallel().tween_property(lbl, "modulate:a", 0.0, 1.4).set_ease(Tween.EASE_IN)
	ltw.tween_callback(lbl.queue_free)
