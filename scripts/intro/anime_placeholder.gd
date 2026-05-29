extends Node2D

signal finished

const VW := 640.0
const VH := 360.0
const LB := 38.0

const CARDS := [
	["Uma floresta antiga, à meia-noite.", 0.62, 0.78, 4.5],
	["No alto da torre, o cajado de mana\nesperava há séculos...", 0.08, 0.14, 4.2],
	["Soph havia passado pelas defesas\ncom uma facilidade suspeita...", 0.68, 0.82, 3.8],
]

var _card_idx: int   = 0
var _card_t:   float = 0.0
var _scene_t:  float = 0.0
var _skip_ok:  bool  = false

var _px: PackedFloat32Array; var _py: PackedFloat32Array
var _pvx: PackedFloat32Array; var _pvy: PackedFloat32Array
var _pa: PackedFloat32Array;  var _ph: PackedFloat32Array
var _ps: PackedFloat32Array
const PC := 32

# Seeded stars (scene 0)
var _star_x: PackedFloat32Array; var _star_y: PackedFloat32Array
var _star_r: PackedFloat32Array
const SC := 28

# Soph close-up (scene 2)
var _soph_close: Sprite2D
var _hair_close: Sprite2D

var _label:    Label
var _overlay:  ColorRect
var _finishing: bool = false

func _ready() -> void:
	_init_stars()
	_init_particles()
	_build_ui()
	_build_soph_close()
	_show_card(0)
	queue_redraw()
	get_tree().create_timer(0.7).timeout.connect(func(): _skip_ok = true)

func _build_ui() -> void:
	var cl := CanvasLayer.new(); cl.layer = 20; add_child(cl)
	for top in [true, false]:
		var bar := ColorRect.new(); bar.color = Color(0,0,0)
		bar.size = Vector2(VW, LB); bar.position = Vector2(0, 0 if top else VH - LB)
		cl.add_child(bar)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 15)
	_label.add_theme_color_override("font_color", Color(0.92, 0.90, 0.98))
	_label.add_theme_color_override("font_shadow_color", Color(0,0,0,0.95))
	_label.add_theme_constant_override("shadow_offset_x", 2)
	_label.add_theme_constant_override("shadow_offset_y", 2)
	_label.size = Vector2(520.0, 80.0)
	_label.position = Vector2(60.0, VH - LB - 82.0)
	_label.modulate.a = 0.0
	add_child(_label)
	var hint := Label.new(); hint.text = "Qualquer tecla para pular"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color(0.45,0.42,0.58,0.65))
	hint.size = Vector2(VW, 18); hint.position = Vector2(0, VH - LB - 22); add_child(hint)
	var btw := hint.create_tween().set_loops()
	btw.tween_property(hint,"modulate:a",0.15,0.9).set_ease(Tween.EASE_IN_OUT)
	btw.tween_property(hint,"modulate:a",0.65,0.9).set_ease(Tween.EASE_IN_OUT)
	_overlay = ColorRect.new(); _overlay.color = Color(0,0,0,0)
	_overlay.size = Vector2(VW,VH); _overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.z_index = 10; add_child(_overlay)

func _build_soph_close() -> void:
	_soph_close = Sprite2D.new()
	_soph_close.texture = SpriteSetup.get_texture("player_body")
	_soph_close.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_soph_close.scale = Vector2(5.5, 5.5)
	_soph_close.position = Vector2(VW * 0.52, VH * 0.48)
	_soph_close.modulate.a = 0.0
	add_child(_soph_close)
	_hair_close = Sprite2D.new()
	_hair_close.texture = SpriteSetup.get_texture("player_hair")
	_hair_close.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_hair_close.scale = Vector2(5.5, 5.5)
	_hair_close.position = Vector2(VW * 0.52, VH * 0.48)
	_hair_close.modulate.a = 0.0
	add_child(_hair_close)

func _init_stars() -> void:
	_star_x.resize(SC); _star_y.resize(SC); _star_r.resize(SC)
	var rng := RandomNumberGenerator.new(); rng.seed = 8317
	for i in SC:
		_star_x[i] = rng.randf_range(8.0, VW - 8.0)
		_star_y[i] = rng.randf_range(LB + 4.0, VH * 0.56)
		_star_r[i] = rng.randf_range(0.7, 2.0)

func _init_particles() -> void:
	_px.resize(PC); _py.resize(PC); _pvx.resize(PC); _pvy.resize(PC)
	_pa.resize(PC); _ph.resize(PC); _ps.resize(PC)
	for i in PC: _reset_particle(i, true)

func _reset_particle(i: int, rand_y: bool = false) -> void:
	_px[i]  = randf_range(0.0, VW)
	_py[i]  = randf_range(LB, VH-LB) if rand_y else VH - LB + 4.0
	_pvx[i] = randf_range(-7.0, 7.0); _pvy[i] = randf_range(-26.0, -9.0)
	_pa[i]  = randf_range(0.05, 0.18)
	var c: Array = CARDS[_card_idx]
	_ph[i]  = randf_range(c[1], c[2]); _ps[i] = randf_range(1.0, 2.8)

func _show_card(idx: int) -> void:
	_card_idx = idx; _card_t = 0.0; _scene_t = 0.0
	_label.text = CARDS[idx][0]
	for i in PC:
		var c: Array = CARDS[idx]; _ph[i] = randf_range(c[1], c[2])
	var tw := _label.create_tween()
	tw.tween_property(_label, "modulate:a", 1.0, 0.55).set_ease(Tween.EASE_OUT)
	if idx == 2:
		var st := _soph_close.create_tween()
		st.tween_property(_soph_close, "modulate:a", 1.0, 0.7)
		_hair_close.create_tween().tween_property(_hair_close, "modulate:a", 1.0, 0.7)
	else:
		_soph_close.modulate.a = 0.0; _hair_close.modulate.a = 0.0

func _process(delta: float) -> void:
	_card_t += delta; _scene_t += delta
	var dur: float = CARDS[_card_idx][3]
	if _card_t >= dur - 0.55:
		_label.modulate.a = maxf(_label.modulate.a - delta * 2.4, 0.0)
		if _card_idx == 2:
			_soph_close.modulate.a = maxf(_soph_close.modulate.a - delta * 2.4, 0.0)
			_hair_close.modulate.a = maxf(_hair_close.modulate.a - delta * 2.4, 0.0)
	if _card_t >= dur: _next_card(); return
	for i in PC:
		_px[i] += _pvx[i] * delta; _py[i] += _pvy[i] * delta
		_pa[i] -= delta * 0.022
		if _pa[i] <= 0.0 or _py[i] < LB: _reset_particle(i)
	queue_redraw()

func _next_card() -> void:
	if _card_idx + 1 < CARDS.size(): _show_card(_card_idx + 1)
	else: _finish()

func _finish() -> void:
	if _finishing: return
	_finishing = true
	var tw := _overlay.create_tween()
	tw.tween_property(_overlay, "color:a", 1.0, 0.55)
	tw.tween_callback(func(): finished.emit())

func _input(event: InputEvent) -> void:
	if not _skip_ok: return
	if event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled(); _skip_ok = false
		_label.create_tween().tween_property(_label, "modulate:a", 0.0, 0.18)
		_soph_close.create_tween().tween_property(_soph_close, "modulate:a", 0.0, 0.18)
		_hair_close.create_tween().tween_property(_hair_close, "modulate:a", 0.0, 0.18)
		_finish()

func _draw() -> void:
	# Full-screen black base (in case _draw scenes leave gaps)
	draw_rect(Rect2(0, 0, VW, VH), Color(0, 0, 0))
	match _card_idx:
		0: _draw_forest()
		1: _draw_tower_glow()
		2: _draw_soph_bg()
	for i in PC:
		draw_circle(Vector2(_px[i], _py[i]), _ps[i],
				Color.from_hsv(_ph[i], 0.55, 1.0, _pa[i]))

# ── Scene 0: Forest at night ──────────────────────────────────────────────────

func _draw_forest() -> void:
	var at := LB; var ab := VH - LB; var w := VW
	# Sky gradient (dark blue-purple)
	for i in 12:
		var t := float(i) / 11.0
		var y := at + t * (ab - at) * 0.65
		var h := (ab - at) * 0.65 / 11.0
		var c := Color(0.06 - t * 0.03, 0.03 - t * 0.01, 0.22 - t * 0.10)
		draw_rect(Rect2(0, y, w, h + 1.0), c)
	# Ground
	draw_rect(Rect2(0, at + (ab-at)*0.62, w, (ab-at)*0.38), Color(0.010, 0.016, 0.010))
	# Stars
	var twinkle := 0.75 + 0.25 * sin(_scene_t * 1.8)
	for i in SC:
		draw_circle(Vector2(_star_x[i], _star_y[i]), _star_r[i],
				Color(0.88, 0.88, 0.96, twinkle * (0.5 + _star_r[i] * 0.25)))
	# Moon
	var moon := Vector2(88.0, at + 46.0)
	var glow := 0.55 + 0.45 * sin(_scene_t * 0.7)
	for r in [52.0, 36.0]: draw_arc(moon, r, 0.0, TAU, 24, Color(0.90,0.86,0.65, 0.04*glow), r*0.3)
	draw_circle(moon, 17.0, Color(0.92, 0.90, 0.78))
	draw_circle(moon, 14.5, Color(0.96, 0.94, 0.86))
	# Trees
	var tree_line_y := at + (ab-at) * 0.62
	var trees := [[40.0,85.0],[90.0,95.0],[145.0,75.0],[195.0,88.0],[250.0,70.0],
				  [290.0,82.0],[350.0,90.0],[400.0,68.0],[445.0,80.0],[500.0,60.0],
				  [545.0,72.0],[595.0,86.0],[630.0,78.0],[15.0,70.0]]
	for td in trees:
		_draw_pine(td[0], tree_line_y, td[1], td[1]*0.38)
	# Tower (right side)
	_draw_tower_silhouette(490.0, tree_line_y, 55.0, 155.0)
	# Fog at treeline
	for i in 5:
		var fy := tree_line_y - 2.0 + i * 3.0
		draw_line(Vector2(0, fy), Vector2(w, fy),
				Color(0.08, 0.06, 0.12, 0.06 - i * 0.01), 2.0)

func _draw_pine(cx: float, base_y: float, height: float, width: float) -> void:
	var col := Color(0.014, 0.022, 0.014)
	for layer in 3:
		var f := float(layer) / 2.0
		var lw := width * (0.28 + 0.72 * f)
		var top_y := base_y - height * (1.0 - f * 0.28)
		var bot_y := base_y - height * f * 0.22
		draw_polygon([Vector2(cx, top_y), Vector2(cx - lw, bot_y),
					  Vector2(cx + lw, bot_y)], [col])

func _draw_tower_silhouette(tx: float, base_y: float, tw: float, th: float) -> void:
	var stone := Color(0.080, 0.065, 0.115)
	draw_rect(Rect2(tx, base_y - th, tw, th), stone)
	# Battlements
	var bw := tw / 5.0
	for i in 5:
		if i % 2 == 0:
			draw_rect(Rect2(tx + i * bw, base_y - th - 10, bw, 11), stone)
	# Lit window
	var wx := tx + tw * 0.30; var wy := base_y - th * 0.52; var wsz := tw * 0.38
	draw_rect(Rect2(wx, wy, wsz, wsz * 1.2), Color(0.88, 0.56, 0.14, 0.92))
	var wglow := 0.6 + 0.4 * sin(_scene_t * 1.4)
	draw_arc(Vector2(wx + wsz*0.5, wy + wsz*0.6), wsz * 1.1, 0, TAU, 20,
			Color(0.80, 0.48, 0.10, 0.06 * wglow), wsz * 0.6)

# ── Scene 1: Tower interior glow ─────────────────────────────────────────────

func _draw_tower_glow() -> void:
	var at := LB; var ab := VH - LB; var w := VW; var cx := w * 0.5
	# Dark chamber
	draw_rect(Rect2(0, at, w, ab - at), Color(0.016, 0.010, 0.030))
	# Pedestal light cone (golden)
	var floor_y := ab - 20.0
	var glow := 0.7 + 0.3 * sin(_scene_t * 1.8)
	for i in 8:
		var f := float(i) / 7.0
		var cone_w := 18.0 + f * 160.0
		var cone_y := floor_y - f * (floor_y - at - 20)
		draw_line(Vector2(cx - cone_w, cone_y + 12), Vector2(cx, floor_y - 22),
				Color(0.85, 0.60, 0.12, 0.018 * glow * (1.0 - f * 0.6)), 2.0)
		draw_line(Vector2(cx + cone_w, cone_y + 12), Vector2(cx, floor_y - 22),
				Color(0.85, 0.60, 0.12, 0.018 * glow * (1.0 - f * 0.6)), 2.0)
	# Pedestal glow rings
	for r in [60.0, 42.0, 26.0, 14.0]:
		draw_arc(Vector2(cx, floor_y - 22), r, 0.0, TAU, 32,
				Color(0.80, 0.45, 0.95, (0.07 + 0.05 * glow) * (60.0/r) * 0.18), r*0.18)
	# Staff crystal glow
	draw_circle(Vector2(cx, floor_y - 56), 6.0, Color(1.0, 0.72, 1.0, 0.9 * glow))
	draw_circle(Vector2(cx, floor_y - 56), 3.0, Color(1.0, 0.92, 1.0))
	# Arch silhouette top
	draw_arc(Vector2(cx, at + 10), w * 0.28, PI, TAU, 28, Color(0.12, 0.09, 0.18, 0.65), 3.0)
	draw_arc(Vector2(cx, at + 10), w * 0.22, PI, TAU, 24, Color(0.10, 0.07, 0.14, 0.45), 2.0)
	# Floor
	draw_rect(Rect2(0, floor_y, w, ab - floor_y), Color(0.050, 0.038, 0.072))
	# Soph silhouette approaching pedestal (small, in shadow)
	var soph_x := cx - 38.0 + _scene_t * 12.0
	var soph_y := floor_y
	draw_rect(Rect2(soph_x - 5, soph_y - 22, 10, 22), Color(0.04, 0.02, 0.06))
	draw_circle(Vector2(soph_x, soph_y - 26), 6.0, Color(0.04, 0.02, 0.06))

# ── Scene 2: Soph close-up background ────────────────────────────────────────

func _draw_soph_bg() -> void:
	var at := LB; var ab := VH - LB
	draw_rect(Rect2(0, at, VW, ab - at), Color(0.018, 0.010, 0.038))
	# Atmospheric glow behind Soph (purple/gold mix)
	var g := 0.55 + 0.45 * sin(_scene_t * 1.6)
	draw_arc(Vector2(VW * 0.52, VH * 0.46), 72.0, 0.0, TAU, 32,
			Color(0.62, 0.28, 0.92, 0.07 * g), 28.0)
	draw_arc(Vector2(VW * 0.52, VH * 0.46), 48.0, 0.0, TAU, 24,
			Color(0.85, 0.50, 0.15, 0.05 * g), 18.0)
	# Staff glow in her hand (bottom right of sprite)
	var staff_pos := Vector2(VW * 0.52 + 28, VH * 0.52)
	draw_circle(staff_pos, 5.0 + g * 3.0, Color(0.78, 0.35, 1.0, 0.65 * g))
	draw_circle(staff_pos, 3.0, Color(1.0, 0.75, 1.0, 0.9 * g))
