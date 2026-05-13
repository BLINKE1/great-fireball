extends CanvasLayer

@onready var panel:       Control = $Panel
@onready var skill_label: Label   = $Panel/VBox/SkillLabel
@onready var desc_label:  Label   = $Panel/VBox/DescLabel
@onready var key_label:   Label   = $Panel/VBox/KeyLabel
@onready var top_accent:  ColorRect = $Panel/TopAccent

# Skill type → accent color
const SKILL_ACCENT_COLORS = {
	"magic_missile":    Color(0.22, 0.82, 1.00),
	"missile_spread":   Color(0.80, 0.35, 1.00),
	"missile_piercing": Color(0.10, 0.95, 0.60),
	"missile_giant":    Color(0.40, 0.90, 1.00),
	"missile_curved":   Color(0.62, 0.18, 1.00),
	"time_stop":        Color(0.55, 0.38, 1.00),
	"heal":             Color(0.22, 0.90, 0.44),
	"magic_dash":       Color(0.12, 0.88, 1.00),
	"sword":            Color(0.95, 0.72, 0.12),
	"double_jump":      Color(0.60, 0.85, 1.00),
}

func show_skill(skill: String) -> void:
	skill_label.text = SkillManager.display_name(skill)
	desc_label.text  = SkillManager.description(skill)
	key_label.text   = "[ " + SkillManager.key_for(skill) + " ]"

	# Color accent based on skill type
	var col: Color = SKILL_ACCENT_COLORS.get(skill, Color(1.0, 0.85, 0.20))
	top_accent.color = Color(col.r, col.g, col.b, 0.92)
	skill_label.add_theme_color_override("font_color", col.lightened(0.20))

	# Style the panel with a dark background + border
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.03, 0.12, 0.96)
	sb.border_width_left   = 2
	sb.border_width_right  = 2
	sb.border_width_top    = 3
	sb.border_width_bottom = 2
	sb.border_color = Color(col.r * 0.70, col.g * 0.70, col.b * 0.70, 0.90)
	sb.corner_radius_top_left     = 4
	sb.corner_radius_top_right    = 4
	sb.corner_radius_bottom_left  = 4
	sb.corner_radius_bottom_right = 4
	panel.add_theme_stylebox_override("panel", sb)

	panel.modulate.a = 0.0
	panel.scale = Vector2(0.72, 0.72)
	visible = true
	AudioManager.play("unlock")
	VFX.sparkle(get_viewport().get_visible_rect().get_center(), get_tree().root,
			col.lightened(0.3), 22)

	var tween = create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.22)
	tween.parallel().tween_property(panel, "scale", Vector2(1.06, 1.06), 0.18).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.10).set_ease(Tween.EASE_IN)
	tween.tween_interval(2.5)
	tween.tween_property(panel, "modulate:a", 0.0, 0.40)
	await tween.finished
	panel.scale = Vector2(1.0, 1.0)
	visible = false
