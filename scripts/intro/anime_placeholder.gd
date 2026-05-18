extends Node2D

signal finished

const VW := 640.0
const VH := 360.0
const LB := 38.0   # letterbox height

# Scene card data: [text, particle_hue_min, particle_hue_max, duration]
const CARDS := [
	["Uma floresta antiga, à meia-noite.\nNo alto da colina, a Torre da Magia esperava silenciosa.", 0.62, 0.78, 4.2],
	["Dentro da torre, no topo de um pedestal de pedra,\no cajado de mana repousava há séculos.", 0.08, 0.14, 4.0],
	["Soph havia passado pelas defesas\ncom uma facilidade suspeita...", 0.68, 0.82, 3.6],
]

var _card_idx:  int   = 0
var _card_t:    float = 0.0
var _skip_ok:   bool  = false

# Particles
var _px:  PackedFloat32Array
var _py:  PackedFloat32Array
var _pvx: PackedFloat32Array
var _pvy: PackedFloat32Array
var _pa:  PackedFloat32Array
var _ph:  PackedFloat32Array
var _ps:  PackedFloat32Array
const PC := 36

var _label:      Label
var _overlay:    ColorRect

func _ready() -> void:
	_init_particles()
	_build_ui()
	_show_card(0)
	# Allow skip after a brief delay
	get_tree().create_timer(0.8).timeout.connect(func(): _skip_ok = true)

func _build_ui() -> void:
	# Black background
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0)
	bg.size  = Vector2(VW, VH)
	add_child(bg)

	# Letterbox
	var cl := CanvasLayer.new(); cl.layer = 20; add_child(cl)
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color(0, 0, 0)
		bar.size  = Vector2(VW, LB)
		bar.position = Vector2(0, 0 if top else VH - LB)
		cl.add_child(bar)

	# Text label
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 15)
	_label.add_theme_color_override("font_color", Color(0.88, 0.85, 0.96))
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.92))
	_label.add_theme_constant_override("shadow_offset_x", 2)
	_label.add_theme_constant_override("shadow_offset_y", 2)
	_label.size     = Vector2(540.0, 120.0)
	_label.position = Vector2(50.0, VH * 0.5 - 60.0)
	_label.modulate.a = 0.0
	add_child(_label)

	# Skip hint
	var hint := Label.new()
	hint.text = "Pressione qualquer tecla para pular"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color(0.45, 0.42, 0.58, 0.70))
	hint.size     = Vector2(VW, 20.0)
	hint.position = Vector2(0.0, VH - LB - 24.0)
	add_child(hint)
	var btw := hint.create_tween().set_loops()
	btw.tween_property(hint, "modulate:a", 0.15, 1.0).set_ease(Tween.EASE_IN_OUT)
	btw.tween_property(hint, "modulate:a", 0.70, 1.0).set_ease(Tween.EASE_IN_OUT)

	# Flash overlay
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0)
	_overlay.size  = Vector2(VW, VH)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.z_index = 10
	add_child(_overlay)

func _init_particles() -> void:
	_px.resize(PC); _py.resize(PC); _pvx.resize(PC)
	_pvy.resize(PC); _pa.resize(PC); _ph.resize(PC); _ps.resize(PC)
	for i in PC:
		_reset_particle(i, true)

func _reset_particle(i: int, random_y: bool = false) -> void:
	_px[i]  = randf_range(0.0, VW)
	_py[i]  = randf_range(LB, VH - LB) if random_y else VH - LB + 4.0
	_pvx[i] = randf_range(-8.0, 8.0)
	_pvy[i] = randf_range(-28.0, -10.0)
	_pa[i]  = randf_range(0.04, 0.16)
	var card := CARDS[_card_idx]
	_ph[i]  = randf_range(card[1], card[2])
	_ps[i]  = randf_range(1.2, 3.0)

func _show_card(idx: int) -> void:
	_card_idx = idx
	_card_t   = 0.0
	_label.text = CARDS[idx][0]
	for i in PC:
		var card := CARDS[idx]
		_ph[i] = randf_range(card[1], card[2])
	var tw := _label.create_tween()
	tw.tween_property(_label, "modulate:a", 1.0, 0.55).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
	_card_t += delta
	var dur: float = CARDS[_card_idx][3]

	# Fade out near end, advance to next
	if _card_t >= dur - 0.6:
		_label.modulate.a = maxf(_label.modulate.a - delta * 2.2, 0.0)
	if _card_t >= dur:
		_next_card()
		return

	# Update particles
	for i in PC:
		_px[i]  += _pvx[i] * delta
		_py[i]  += _pvy[i] * delta
		_pa[i]  -= delta * 0.022
		if _pa[i] <= 0.0 or _py[i] < LB:
			_reset_particle(i)
	queue_redraw()

func _next_card() -> void:
	if _card_idx + 1 < CARDS.size():
		_show_card(_card_idx + 1)
	else:
		_finish()

func _finish() -> void:
	var tw := _overlay.create_tween()
	tw.tween_property(_overlay, "color:a", 1.0, 0.50)
	tw.tween_callback(finished.emit)

func _input(event: InputEvent) -> void:
	if not _skip_ok: return
	if event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		_skip_ok = false
		_label.create_tween().tween_property(_label, "modulate:a", 0.0, 0.2)
		_finish()

func _draw() -> void:
	for i in PC:
		draw_circle(Vector2(_px[i], _py[i]), _ps[i],
				Color.from_hsv(_ph[i], 0.55, 1.0, _pa[i]))
