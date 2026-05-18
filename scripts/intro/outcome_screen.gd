extends Node2D

signal restart_requested

const VW := 640.0
const VH := 360.0

var success: bool = true

# Particles
var _px: PackedFloat32Array; var _py: PackedFloat32Array
var _pvx: PackedFloat32Array; var _pvy: PackedFloat32Array
var _pa: PackedFloat32Array;  var _ph: PackedFloat32Array
var _ps: PackedFloat32Array
const PC := 32

func _ready() -> void:
	_init_particles()
	call_deferred("_build")

func _build() -> void:
	# Background
	var bg_col := Color(0.02, 0.01, 0.05) if success else Color(0.04, 0.00, 0.00)
	var bg := ColorRect.new()
	bg.color = bg_col; bg.size = Vector2(VW, VH)
	add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.anchor_left = 0.10; vbox.anchor_right  = 0.90
	vbox.anchor_top  = 0.18; vbox.anchor_bottom = 0.82
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	add_child(vbox)

	if success:
		_add_label(vbox, "A SOPH ESCAPOU", 38, Color(0.35, 0.88, 1.0))
		_add_label(vbox, "O cajado responde à sua magia.", 16, Color(0.70, 0.88, 1.0))
		_add_label(vbox, "\"Agora sim. Que comecem os problemas.\"", 14, Color(0.68, 0.82, 0.96, 0.88))
		_add_label(vbox, "— Soph", 12, Color(0.50, 0.60, 0.78, 0.72))
	else:
		_add_label(vbox, "CAPTURADA", 42, Color(0.92, 0.18, 0.14))
		_add_label(vbox, "Os golens foram mais rápidos desta vez.", 16, Color(0.82, 0.55, 0.52))
		_add_label(vbox, "\"Tudo bem. Eu me planejei mal.\nDa próxima vez uso o Time Stop.\"", 14,
				Color(0.70, 0.50, 0.50, 0.85))
		_add_label(vbox, "— Soph", 12, Color(0.55, 0.38, 0.38, 0.70))

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 28)
	vbox.add_child(spacer)

	var btn := _add_label(vbox, "Tentar novamente", 14,
			Color(0.80, 0.78, 0.92))
	btn.add_theme_color_override("font_color", Color(0.80, 0.78, 0.92))
	# Blink hint
	var btw := btn.create_tween().set_loops()
	btw.tween_property(btn, "modulate:a", 0.20, 0.72).set_ease(Tween.EASE_IN_OUT)
	btw.tween_property(btn, "modulate:a", 1.00, 0.72).set_ease(Tween.EASE_IN_OUT)

	# Fade-in all children
	for child in vbox.get_children():
		child.modulate.a = 0.0
		var idx: int = child.get_index()
		var tw := child.create_tween()
		tw.tween_interval(idx * 0.18)
		tw.tween_property(child, "modulate:a", 1.0, 0.45).set_ease(Tween.EASE_OUT)

	# Allow restart after a short delay
	get_tree().create_timer(1.2).timeout.connect(func():
		set_process_input(true))
	set_process_input(false)

func _add_label(parent: Control, txt: String, sz: int, col: Color) -> Label:
	var lbl := Label.new()
	lbl.text = txt
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", sz)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	lbl.add_theme_constant_override("shadow_offset_x", 2)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	parent.add_child(lbl)
	return lbl

func _init_particles() -> void:
	_px.resize(PC); _py.resize(PC); _pvx.resize(PC); _pvy.resize(PC)
	_pa.resize(PC); _ph.resize(PC); _ps.resize(PC)
	for i in PC: _reset_particle(i, true)

func _reset_particle(i: int, rand_y: bool = false) -> void:
	_px[i]  = randf_range(0.0, VW)
	_py[i]  = randf_range(0.0, VH) if rand_y else VH + 4.0
	_pvx[i] = randf_range(-10.0, 10.0)
	_pvy[i] = randf_range(-32.0, -12.0)
	_pa[i]  = randf_range(0.05, 0.18)
	_ph[i]  = randf_range(0.62, 0.82) if success else randf_range(0.94, 1.02)
	_ps[i]  = randf_range(1.0, 2.8)

func _process(delta: float) -> void:
	for i in PC:
		_px[i] += _pvx[i] * delta
		_py[i] += _pvy[i] * delta
		_pa[i] -= delta * 0.020
		if _pa[i] <= 0.0 or _py[i] < 0.0:
			_reset_particle(i)
	queue_redraw()

func _draw() -> void:
	for i in PC:
		draw_circle(Vector2(_px[i], _py[i]), _ps[i],
				Color.from_hsv(fmod(_ph[i], 1.0), 0.60, 1.0, _pa[i]))

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		set_process_input(false)
		GameState.fade_out_then(restart_requested.emit, 0.45)
