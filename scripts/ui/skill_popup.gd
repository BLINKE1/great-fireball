extends CanvasLayer

@onready var panel: Control = $Panel
@onready var skill_label: Label = $Panel/VBox/SkillLabel
@onready var key_label: Label = $Panel/VBox/KeyLabel

func show_skill(skill: String) -> void:
	skill_label.text = SkillManager.display_name(skill)
	key_label.text = "Tecla: " + SkillManager.key_for(skill)
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.72, 0.72)
	visible = true
	AudioManager.play("unlock")

	var tween = create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.22)
	tween.parallel().tween_property(panel, "scale", Vector2(1.06, 1.06), 0.18).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.10).set_ease(Tween.EASE_IN)
	tween.tween_interval(2.0)
	tween.tween_property(panel, "modulate:a", 0.0, 0.40)
	await tween.finished
	panel.scale = Vector2(1.0, 1.0)
	visible = false
