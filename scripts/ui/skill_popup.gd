extends CanvasLayer

@onready var panel: Control = $Panel
@onready var skill_label: Label = $Panel/VBox/SkillLabel
@onready var key_label: Label = $Panel/VBox/KeyLabel

func show_skill(skill: String) -> void:
	skill_label.text = SkillManager.display_name(skill)
	key_label.text = "Tecla: " + SkillManager.key_for(skill)
	panel.modulate.a = 0.0
	visible = true
	AudioManager.play("unlock")

	var tween = create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.3)
	tween.tween_interval(2.2)
	tween.tween_property(panel, "modulate:a", 0.0, 0.4)
	await tween.finished
	visible = false
