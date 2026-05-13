extends CanvasLayer

var _panel: Panel
var _name_label: Label
var _bar_bg: ColorRect
var _bar_fill: ColorRect
var _bar_shine: ColorRect
var _hp_ratio: float = 1.0
var _bar_tween: Tween = null

func _ready() -> void:
	layer = 8
	visible = false
	call_deferred("_build_ui")

func _build_ui() -> void:
	var vs := get_viewport().get_visible_rect().size
	var pw := minf(vs.x * 0.68, 640.0)
	var ph := 62.0
	var px := (vs.x - pw) * 0.5
	var py := vs.y - ph - 14.0

	_panel = Panel.new()
	_panel.size     = Vector2(pw, ph)
	_panel.position = Vector2(px, py)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.02, 0.08, 0.94)
	sb.border_width_left   = 2
	sb.border_width_right  = 2
	sb.border_width_top    = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.55, 0.20, 0.08, 0.88)
	sb.corner_radius_top_left     = 5
	sb.corner_radius_top_right    = 5
	sb.corner_radius_bottom_left  = 5
	sb.corner_radius_bottom_right = 5
	_panel.add_theme_stylebox_override("panel", sb)

	add_child(_panel)

	_name_label = Label.new()
	_name_label.position = Vector2(8, 6)
	_name_label.size = Vector2(pw - 16, 20)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 13)
	_name_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.28))
	_name_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.80))
	_name_label.add_theme_constant_override("shadow_offset_x", 1)
	_name_label.add_theme_constant_override("shadow_offset_y", 1)
	_panel.add_child(_name_label)

	# Bar track (background)
	_bar_bg = ColorRect.new()
	_bar_bg.color = Color(0.12, 0.04, 0.04, 1.0)
	_bar_bg.position = Vector2(10, 30)
	_bar_bg.size = Vector2(pw - 20, 20)
	_panel.add_child(_bar_bg)

	# Bar fill
	_bar_fill = ColorRect.new()
	_bar_fill.color = Color(0.82, 0.12, 0.08)
	_bar_fill.position = Vector2(0, 0)
	_bar_fill.size = _bar_bg.size
	_bar_bg.add_child(_bar_fill)

	# Shine strip on top of bar fill
	_bar_shine = ColorRect.new()
	_bar_shine.color = Color(1.0, 1.0, 1.0, 0.18)
	_bar_shine.position = Vector2(0, 0)
	_bar_shine.size = Vector2(_bar_bg.size.x, 5.0)
	_bar_fill.add_child(_bar_shine)

func _process(_delta: float) -> void:
	if not visible or not _panel: return
	var vs := get_viewport().get_visible_rect().size
	var pw := minf(vs.x * 0.68, 640.0)
	_panel.position = Vector2((vs.x - pw) * 0.5, vs.y - 76.0)

func show_boss(boss_name: String, boss: Node) -> void:
	if not _panel:
		await get_tree().process_frame
	_name_label.text = boss_name
	_hp_ratio = 1.0
	_update_bar()
	_panel.modulate.a = 0.0
	visible = true
	var tw := create_tween()
	tw.tween_property(_panel, "modulate:a", 1.0, 0.55)
	if boss.has_signal("boss_hp_changed"):
		boss.boss_hp_changed.connect(_on_hp_changed)
	if boss.has_signal("boss_died"):
		boss.boss_died.connect(_on_boss_died, CONNECT_ONE_SHOT)

func _on_hp_changed(ratio: float) -> void:
	_hp_ratio = clampf(ratio, 0.0, 1.0)
	_update_bar()

func _update_bar() -> void:
	if not _bar_fill or not _bar_bg: return
	var target_w := _bar_bg.size.x * _hp_ratio
	if _bar_tween and _bar_tween.is_valid():
		_bar_tween.kill()
	_bar_tween = _bar_fill.create_tween()
	_bar_tween.tween_property(_bar_fill, "size:x", target_w, 0.25).set_ease(Tween.EASE_OUT)
	# Color: green → yellow → orange → red as HP drops
	var t := 1.0 - _hp_ratio
	var r := 0.20 + t * 0.65
	var g := 0.80 - t * 0.72
	var b := 0.06
	_bar_fill.color = Color(r, g, b, 1.0)
	if is_instance_valid(_bar_shine):
		_bar_shine.size.x = target_w

func _on_boss_died() -> void:
	var tw := create_tween()
	tw.tween_property(_panel, "modulate:a", 0.0, 0.85)
	await tw.finished
	visible = false
