extends Node2D

signal finished

const VW := 640.0
const VH := 360.0
const LB := 38.0

enum Phase {
	HORDE_ADVANCE, GLOW_WARNING, FIREBALL_SWEEP,
	AFTERMATH, MAGE_REVEAL, DIALOGUE_1, DIALOGUE_2,
	MAGE_EXIT, SOPH_AWE, FADE
}

const SOPH_BASE_X := 460.0
const SOPH_Y      := VH - LB - 58.0
const GROUND_Y    := SOPH_Y - 54.0

var _phase: Phase = Phase.HORDE_ADVANCE
var _t: float = 0.0

var _horde: Array = []

var _sky_glow: float = 0.0
var _fb_x: float = VW + 80.0
var _fb_y: float = LB + 52.0
var _fb_r: float = 22.0
var _scorch: float = 0.0

var _embers: Array = []
var _mage_x: float = VW + 20.0
var _mage_visible: bool = false

var _soph_push: float = 0.0
var _soph_lit: float = 0.0

var _soph_spr: Sprite2D
var _hair_spr: Sprite2D
var _text_lbl: Label
var _overlay: ColorRect

func _ready() -> void:
	_build_horde()
	_build_ui()
	_build_soph()

func _build_horde() -> void:
	for i in 22:
		_horde.append({
			"x": randf_range(18.0, SOPH_BASE_X - 90.0),
			"y": SOPH_Y + randf_range(-3.0, 3.0),
			"big": false, "alive": true,
			"spd": randf_range(18.0, 30.0)
		})
	for i in 4:
		_horde.append({
			"x": randf_range(30.0, SOPH_BASE_X - 130.0),
			"y": SOPH_Y + randf_range(-2.0, 2.0),
			"big": true, "alive": true,
			"spd": randf_range(10.0, 16.0)
		})

func _build_ui() -> void:
	var cl_lb := CanvasLayer.new(); cl_lb.layer = 20; add_child(cl_lb)
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK; bar.size = Vector2(VW, LB)
		bar.position = Vector2(0.0, 0.0 if top else VH - LB)
		cl_lb.add_child(bar)

	var cl_ui := CanvasLayer.new(); cl_ui.layer = 15; add_child(cl_ui)
	_text_lbl = Label.new()
	_text_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text_lbl.add_theme_font_size_override("font_size", 18)
	_text_lbl.add_theme_color_override("font_color", Color(0.96, 0.90, 0.68))
	_text_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1.0))
	_text_lbl.add_theme_constant_override("shadow_offset_x", 2)
	_text_lbl.add_theme_constant_override("shadow_offset_y", 2)
	_text_lbl.size = Vector2(VW, 42.0)
	_text_lbl.position = Vector2(0.0, VH - LB - 46.0)
	_text_lbl.modulate.a = 0.0
	cl_ui.add_child(_text_lbl)

	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.0); _overlay.size = Vector2(VW, VH)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)

func _build_soph() -> void:
	_soph_spr = _mk_spr("player_body", Vector2(SOPH_BASE_X, SOPH_Y), Vector2(2.6, 2.6))
	_hair_spr = _mk_spr("player_hair", Vector2(SOPH_BASE_X, SOPH_Y - 1.0), Vector2(2.6, 2.6))
	_soph_spr.flip_h = true
	_hair_spr.flip_h = true

func _mk_spr(key: String, pos: Vector2, sc: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = SpriteSetup.get_texture(key)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.position = pos; s.scale = sc; add_child(s); return s

func _process(delta: float) -> void:
	_t += delta
	_tick_embers(delta)

	# Light Soph from the fireball
	var lit_c: Color = Color(1.0, 1.0, 1.0).lerp(Color(1.05, 0.78, 0.48), _soph_lit)
	_soph_spr.modulate = lit_c
	_hair_spr.modulate = lit_c

	match _phase:
		Phase.HORDE_ADVANCE:
			for h in _horde:
				h.x = minf(h.x + h.spd * delta, SOPH_BASE_X - 40.0)
			_soph_push = minf(_soph_push + delta * 12.0, 18.0)
			_soph_spr.position.x = SOPH_BASE_X + _soph_push
			_hair_spr.position.x = SOPH_BASE_X + _soph_push
			if _t >= 2.2: _set_phase(Phase.GLOW_WARNING)

		Phase.GLOW_WARNING:
			_sky_glow = minf(_sky_glow + delta * 0.55, 0.45)
			if _t >= 1.5: _set_phase(Phase.FIREBALL_SWEEP)

		Phase.FIREBALL_SWEEP:
			_fb_x -= delta * 310.0
			var sweep_span: float = VW + 160.0
			var prog: float = clampf(1.0 - (_fb_x + 80.0) / sweep_span, 0.0, 1.0)
			_fb_r = lerpf(22.0, 95.0, sinf(prog * PI))
			_sky_glow = 0.3 + sinf(prog * PI) * 0.7
			_soph_lit = sinf(prog * PI) * clampf((SOPH_BASE_X - _fb_x) / 300.0, 0.0, 1.0)
			for h in _horde:
				if h.alive and _fb_x <= h.x + _fb_r * 0.6:
					h.alive = false
					_burst_embers(h.x, h.y, h.big)
			if _fb_x < -120.0: _set_phase(Phase.AFTERMATH)

		Phase.AFTERMATH:
			_sky_glow = lerpf(_sky_glow, 0.04, delta * 0.35)
			_scorch = minf(_scorch + delta * 1.2, 1.0)
			_soph_lit = maxf(_soph_lit - delta * 0.8, 0.0)
			# Soph turns right to look at where the mage will appear
			if _t >= 1.0:
				_soph_spr.flip_h = false
				_hair_spr.flip_h = false
			if _t >= 2.8: _set_phase(Phase.MAGE_REVEAL)

		Phase.MAGE_REVEAL:
			_mage_visible = true
			_mage_x = lerpf(_mage_x, VW - 88.0, minf(delta * 3.8, 0.28))
			if _t >= 1.5: _set_phase(Phase.DIALOGUE_1)

		Phase.DIALOGUE_1:
			if _t >= 0.5: _show_text("\"Não importa o tamanho do problema...\"")
			if _t >= 3.2: _set_phase(Phase.DIALOGUE_2)

		Phase.DIALOGUE_2:
			if _t >= 0.3:
				_show_text("\"...o que importa é o tamanho da bola de fogo.\"")
			if _t >= 3.8: _set_phase(Phase.MAGE_EXIT)

		Phase.MAGE_EXIT:
			_hide_text()
			_mage_x += delta * 48.0
			if _mage_x > VW + 32.0:
				_mage_visible = false
				_set_phase(Phase.SOPH_AWE)

		Phase.SOPH_AWE:
			# Soph stands still, staring right — awed silence
			if _t >= 2.6: _set_phase(Phase.FADE)

		Phase.FADE:
			_overlay.color.a = minf(_t / 1.4, 1.0)
			if _t >= 1.4: finished.emit(); set_process(false)

	queue_redraw()

func _show_text(txt: String) -> void:
	if _text_lbl.text == txt: return
	_text_lbl.text = txt
	if _text_lbl.modulate.a < 0.9:
		_text_lbl.create_tween().tween_property(_text_lbl, "modulate:a", 1.0, 0.4)

func _hide_text() -> void:
	if _text_lbl.modulate.a > 0.05:
		_text_lbl.create_tween().tween_property(_text_lbl, "modulate:a", 0.0, 0.3)

func _set_phase(p: Phase) -> void:
	_phase = p; _t = 0.0
	match p:
		Phase.GLOW_WARNING:
			MusicManager.stop()
		Phase.FIREBALL_SWEEP:
			AudioManager.play("roar", 0.65)
			AudioManager.play("fireball")
		Phase.AFTERMATH:
			AudioManager.play("boss_appear", 0.5)
		Phase.DIALOGUE_1:
			_text_lbl.create_tween().tween_property(_text_lbl, "modulate:a", 0.0, 0.2)

# ─── Embers ───────────────────────────────────────────────────────────────────

func _burst_embers(x: float, y: float, big: bool) -> void:
	var count: int = 14 if big else 8
	var spd: float = 230.0 if big else 145.0
	for i in count:
		_embers.append({
			"x": x, "y": y - 10.0,
			"vx": randf_range(-spd, spd),
			"vy": randf_range(-spd * 1.3, -spd * 0.25),
			"life": randf_range(0.5, 1.2),
			"max": 1.2, "big": big
		})

func _tick_embers(delta: float) -> void:
	for e in _embers:
		e.vx *= 0.96; e.vy += 310.0 * delta
		e.x += e.vx * delta; e.y += e.vy * delta; e.life -= delta
	_embers = _embers.filter(func(e): return e.life > 0.0)

# ─── Drawing ──────────────────────────────────────────────────────────────────

func _draw() -> void:
	_draw_bg()
	_draw_fireball_corona()
	_draw_horde()
	_draw_embers()
	_draw_fireball()
	_draw_mage()

func _draw_bg() -> void:
	var sky_h: float = GROUND_Y - LB
	for i in 12:
		var tf: float = float(i) / 11.0
		var base: Color = Color(0.022, 0.024, 0.080).lerp(Color(0.068, 0.048, 0.105), tf)
		var warm: Color = Color(0.58, 0.26, 0.05)
		var glow_factor: float = _sky_glow * (1.0 - tf * 0.45)
		draw_rect(Rect2(0.0, LB + tf * sky_h, VW, ceil(sky_h / 12.0) + 1.0),
				base.lerp(warm, glow_factor))
	# Stars fade with glow
	var star_a: float = maxf(1.0 - _sky_glow * 1.8, 0.0)
	for i in 18:
		var sx: float = fposmod(float(i) * 43.0 + sin(float(i) * 0.4) * 7.0, VW)
		var sy: float = LB + fposmod(float(i) * 19.0, sky_h * 0.50)
		draw_circle(Vector2(sx, sy), 1.0, Color(1, 1, 1, 0.28 * star_a))
	# Tree silhouettes
	for i in 7:
		var tx: float = 14.0 + float(i) * 68.0
		var th: float = 38.0 + float((i * 11) % 22)
		draw_polygon([
			Vector2(tx - th * 0.35, GROUND_Y),
			Vector2(tx, GROUND_Y - th),
			Vector2(tx + th * 0.35, GROUND_Y)
		], [Color(0.014, 0.008, 0.020, 0.92)])
	# Ground
	draw_rect(Rect2(0.0, GROUND_Y, VW, VH - LB - GROUND_Y), Color(0.048, 0.036, 0.032))
	# Scorched earth left behind
	if _scorch > 0.01:
		draw_rect(Rect2(0.0, GROUND_Y, VW * _scorch, 60.0),
				Color(0.008, 0.005, 0.006, _scorch * 0.82))

func _draw_fireball_corona() -> void:
	if _sky_glow < 0.06: return
	var cx: float = _fb_x if _phase == Phase.FIREBALL_SWEEP else (VW + 80.0 if _phase == Phase.GLOW_WARNING else -80.0)
	for r in [300.0, 200.0, 120.0]:
		var a: float = _sky_glow * 0.16 * (1.0 - r / 320.0)
		draw_arc(Vector2(cx, _fb_y), r, 0.0, TAU, 28,
				Color(0.88, 0.42, 0.06, a), r * 0.30)
	# Ground lit patch below fireball
	if _phase == Phase.FIREBALL_SWEEP:
		for i in 5:
			var a2: float = _sky_glow * 0.10 * (1.0 - float(i) / 5.0)
			draw_arc(Vector2(_fb_x, GROUND_Y), 80.0 + float(i) * 18.0, 0.0, TAU, 18,
					Color(0.75, 0.38, 0.06, a2), 5.0)

func _draw_fireball() -> void:
	if _phase != Phase.FIREBALL_SWEEP: return
	var pos := Vector2(_fb_x, _fb_y)
	# Outer corona
	for r in [_fb_r * 1.55, _fb_r * 1.15, _fb_r]:
		var t: float = r / (_fb_r * 1.55)
		draw_arc(pos, r, 0.0, TAU, 32,
				Color(1.0, 0.48 * (1.0 - t), 0.02, 0.45 * (1.0 - t * 0.6)), r * 0.20)
	# Body layers (hot → white core)
	draw_circle(pos, _fb_r * 0.88, Color(1.0, 0.58, 0.08, 0.92))
	draw_circle(pos, _fb_r * 0.60, Color(1.0, 0.80, 0.22, 0.96))
	draw_circle(pos, _fb_r * 0.32, Color(1.0, 0.95, 0.70, 1.0))
	draw_circle(pos, _fb_r * 0.12, Color(1.0, 1.0, 1.0, 1.0))
	# Heat wake trailing right
	for i in 10:
		var tx: float = pos.x + float(i + 1) * 26.0
		var tr: float = _fb_r * (0.60 - float(i) / 10.0 * 0.58)
		if tr > 3.0:
			draw_arc(Vector2(tx, pos.y), tr, 0.0, TAU, 14,
					Color(1.0, 0.38, 0.05, 0.18 - float(i) / 10.0 * 0.17), tr * 0.22)

func _draw_horde() -> void:
	for h in _horde:
		if not h.alive: continue
		_draw_goblin(Vector2(h.x, h.y), 4.0 if h.big else 2.0)

func _draw_goblin(pos: Vector2, sc: float) -> void:
	var gw: float = 10.0 * sc; var gh: float = 18.0 * sc; var hy: float = pos.y - gh
	var col := Color(0.28, 0.72, 0.20)
	draw_rect(Rect2(pos.x - gw * 0.5, hy, gw, gh * 0.65), col)
	draw_rect(Rect2(pos.x - gw * 0.42, hy - gh * 0.32, gw * 0.84, gh * 0.34), col)
	draw_rect(Rect2(pos.x - gw * 0.14, hy - gh * 0.22, gw * 0.28, gw * 0.28),
			Color(0.92, 0.88, 0.05))

func _draw_mage() -> void:
	if not _mage_visible: return
	var mx: float = _mage_x
	var my: float = SOPH_Y
	var dark := Color(0.04, 0.02, 0.07, 0.97)

	# Robe body (narrow top, wide hem)
	var tw: float = 24.0; var bw: float = 40.0; var rh: float = 66.0
	var chest_y: float = my - rh
	draw_polygon([
		Vector2(mx - tw * 0.5, chest_y),
		Vector2(mx + tw * 0.5, chest_y),
		Vector2(mx + bw * 0.5, my),
		Vector2(mx - bw * 0.5, my)
	], [dark])

	# Sleeves (slight drape on both sides)
	draw_polygon([
		Vector2(mx - tw * 0.5, chest_y),
		Vector2(mx - tw * 0.5 - 10.0, chest_y + 24.0),
		Vector2(mx - bw * 0.3, chest_y + 30.0)
	], [dark])
	draw_polygon([
		Vector2(mx + tw * 0.5, chest_y),
		Vector2(mx + tw * 0.5 + 10.0, chest_y + 24.0),
		Vector2(mx + bw * 0.3, chest_y + 30.0)
	], [dark])

	# Head circle
	var neck_y: float = chest_y - 2.0
	var head_cy: float = neck_y - 12.0
	draw_circle(Vector2(mx, head_cy), 13.0, dark)

	# Hood (pointed tip above head, draping sides)
	draw_polygon([
		Vector2(mx - 14.0, head_cy + 4.0),
		Vector2(mx + 14.0, head_cy + 4.0),
		Vector2(mx + 10.0, head_cy - 10.0),
		Vector2(mx,        head_cy - 32.0),
		Vector2(mx - 10.0, head_cy - 10.0)
	], [dark])
	# Hood side drapes onto shoulders
	draw_polygon([
		Vector2(mx - 14.0, head_cy + 4.0),
		Vector2(mx - tw * 0.5, chest_y),
		Vector2(mx - tw * 0.4, chest_y - 4.0),
		Vector2(mx - 8.0, head_cy)
	], [dark])
	draw_polygon([
		Vector2(mx + 14.0, head_cy + 4.0),
		Vector2(mx + tw * 0.5, chest_y),
		Vector2(mx + tw * 0.4, chest_y - 4.0),
		Vector2(mx + 8.0, head_cy)
	], [dark])

	# Staff (held on left side of the figure)
	var s_base := Vector2(mx - bw * 0.38, my - 10.0)
	var s_tip  := Vector2(mx - tw * 0.3,  head_cy - 36.0)
	draw_line(s_base, s_tip, Color(0.22, 0.15, 0.08, 0.92), 3.0)

	# Crystal — residual warm glow after the Great Fireball
	var glow: float = 0.32 + sinf(_t * 3.6) * 0.10
	draw_circle(s_tip, 5.0, Color(0.85, 0.45, 0.10, glow * 0.85))
	draw_circle(s_tip, 3.0, Color(1.0, 0.72, 0.28, glow))

func _draw_embers() -> void:
	for e in _embers:
		var a: float = clampf(e.life / e.max, 0.0, 1.0)
		var r: float = 3.8 if e.big else 2.2
		draw_circle(Vector2(e.x, e.y), r, Color(0.95, 0.52 * a, 0.05, a * 0.92))
