extends CanvasLayer

# Boss HP bar: auto-positions at bottom center of screen, built entirely in code.

var _panel: ColorRect
var _name_label: Label
var _bar_bg: ColorRect
var _bar_fill: ColorRect
var _hp_ratio: float = 1.0
var _bar_tween: Tween = null

func _ready() -> void:
	layer = 8
	visible = false
	call_deferred("_build_ui")

func _build_ui() -> void:
	var vs := get_viewport().get_visible_rect().size
	var pw := minf(vs.x * 0.68, 620.0)
	var ph := 58.0
	var px := (vs.x - pw) * 0.5
	var py := vs.y - ph - 12.0

	_panel = ColorRect.new()
	_panel.color = Color(0.04, 0.04, 0.08, 0.88)
	_panel.size  = Vector2(pw, ph)
	_panel.position = Vector2(px, py)
	add_child(_panel)

	_name_label = Label.new()
	_name_label.position = Vector2(8, 5)
	_name_label.size = Vector2(pw - 16, 20)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 13)
	_name_label.modulate = Color(1.0, 0.72, 0.26)
	_panel.add_child(_name_label)

	# Bar background
	_bar_bg = ColorRect.new()
	_bar_bg.color = Color(0.14, 0.06, 0.06, 1.0)
	_bar_bg.position = Vector2(8, 28)
	_bar_bg.size = Vector2(pw - 16, 18)
	_panel.add_child(_bar_bg)

	# Bar fill
	_bar_fill = ColorRect.new()
	_bar_fill.color = Color(0.82, 0.12, 0.08)
	_bar_fill.position = Vector2(0, 0)
	_bar_fill.size = _bar_bg.size
	_bar_bg.add_child(_bar_fill)

func _process(_delta: float) -> void:
	if not visible or not _panel: return
	# Reposition if viewport resized
	var vs := get_viewport().get_visible_rect().size
	var pw := minf(vs.x * 0.68, 620.0)
	_panel.position = Vector2((vs.x - pw) * 0.5, vs.y - 70.0)

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
	_bar_tween.tween_property(_bar_fill, "size:x", target_w, 0.28).set_ease(Tween.EASE_OUT)
	# Color shifts red→orange as health drops
	var t := 1.0 - _hp_ratio
	_bar_fill.color = Color(0.80 + t * 0.18, 0.12 + t * 0.28, 0.06, 1.0)

func _on_boss_died() -> void:
	var tw := create_tween()
	tw.tween_property(_panel, "modulate:a", 0.0, 0.85)
	await tw.finished
	visible = false
