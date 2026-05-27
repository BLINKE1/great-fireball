extends Node2D

signal restart_requested

const VW := 640.0
const VH := 360.0

var _t: float = 0.0

func _ready() -> void:
	call_deferred("_build")

func _build() -> void:
	var cl := CanvasLayer.new(); cl.layer = 5; add_child(cl)
	var root := Control.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(root)

	var vbox := VBoxContainer.new()
	vbox.anchor_left = 0.10
	vbox.anchor_right = 0.90
	vbox.anchor_top = 0.18
	vbox.anchor_bottom = 0.82
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	root.add_child(vbox)

	_add_label(vbox, "CAPÍTULO 1", 14, Color(0.62, 0.55, 0.80, 0.85))
	_add_label(vbox, "FUGA DA TORRE", 38, Color(0.92, 0.85, 0.60))
	_add_spacer(vbox, 22)
	_add_label(vbox, "A Soph escapou. O cajado é dela agora.", 16, Color(0.85, 0.80, 0.95))
	_add_label(vbox, "Mas a noite mal começou.", 14, Color(0.75, 0.70, 0.88, 0.92))
	_add_spacer(vbox, 32)

	var cont := _add_label(vbox, "CONTINUA…", 18, Color(0.55, 0.78, 1.0))
	var tw := cont.create_tween().set_loops()
	tw.tween_property(cont, "modulate:a", 0.30, 0.85).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(cont, "modulate:a", 1.00, 0.85).set_ease(Tween.EASE_IN_OUT)

	_add_spacer(vbox, 22)
	_add_label(vbox, "Pressione qualquer tecla para reiniciar", 12, Color(0.60, 0.55, 0.72, 0.65))

	for child in vbox.get_children():
		child.modulate.a = 0.0
		var idx: int = child.get_index()
		var tw_in := child.create_tween()
		tw_in.tween_interval(idx * 0.18)
		tw_in.tween_property(child, "modulate:a", 1.0, 0.55).set_ease(Tween.EASE_OUT)

	get_tree().create_timer(1.6).timeout.connect(func(): set_process_input(true))
	set_process_input(false)

func _add_label(parent: Control, txt: String, sz: int, col: Color) -> Label:
	var lbl := Label.new()
	lbl.text = txt
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", sz)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.88))
	lbl.add_theme_constant_override("shadow_offset_x", 2)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	parent.add_child(lbl)
	return lbl

func _add_spacer(parent: Control, height: int) -> void:
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, height)
	parent.add_child(sp)

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(0, 0, VW, VH), Color(0.025, 0.018, 0.050))
	for i in 28:
		var x: float = fposmod(i * 41.0 + sin(_t * 0.3 + i) * 30.0, VW)
		var y: float = fposmod(i * 17.0 - _t * 12.0, VH)
		var a: float = 0.16 + 0.12 * sin(_t * 1.5 + i)
		draw_circle(Vector2(x, y), 1.6, Color(0.65, 0.55, 0.85, a))

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		set_process_input(false)
		GameState.fade_out_then(func(): restart_requested.emit(), 0.5)
