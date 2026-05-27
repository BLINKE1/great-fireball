extends Node2D

signal finished

const VW := 640.0
const VH := 360.0
const LB := 38.0

enum Phase { SOPH_SCARED, STAFF_GLOW, CHARGE, FIREBALL, AFTERMATH, FADE }

const SOPH_X := VW * 0.72
const SOPH_Y := VH - LB - 58.0

var _phase: Phase = Phase.SOPH_SCARED
var _t: float = 0.0

var _staff_glow:    float = 0.0
var _charge_radius: float = 0.0
var _charge_alpha:  float = 0.0
var _fireball_x:    float = VW * 0.72
var _fireball_r:    float = 0.0
var _fireball_alpha: float = 0.0
var _aftermath_t:   float = 0.0
var _shockwave_r:   float = 0.0
var _debris:        Array = []
var _char_particles: Array = []
var _soph_pushed:   float = 0.0

# Goblins (horde frozen in place for the anime)
var _horde: Array = []

var _soph: Sprite2D
var _hair: Sprite2D
var _staff_crystal: Node2D
var _overlay: ColorRect
var _text_lbl: Label

func _ready() -> void:
	_build()
	_spawn_horde()

func _build() -> void:
	for i in 28:
		_horde.append({
			"x": randf_range(18.0, SOPH_X - 50.0),
			"y": SOPH_Y + randf_range(-4.0, 4.0),
			"big": i < 4, "alive": true, "burn_t": 0.0
		})

	_soph = _mk_spr("player_body", Vector2(SOPH_X, SOPH_Y), Vector2(2.6, 2.6))
	_soph.flip_h = false
	_hair = _mk_spr("player_hair", Vector2(SOPH_X, SOPH_Y - 1.0), Vector2(2.6, 2.6))
	_hair.flip_h = false

	var cl_lb := CanvasLayer.new(); cl_lb.layer = 20; add_child(cl_lb)
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color(0, 0, 0); bar.size = Vector2(VW, LB)
		bar.position = Vector2(0, 0 if top else VH - LB)
		cl_lb.add_child(bar)

	var cl_ui := CanvasLayer.new(); cl_ui.layer = 15; add_child(cl_ui)
	_text_lbl = Label.new()
	_text_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text_lbl.add_theme_font_size_override("font_size", 20)
	_text_lbl.add_theme_color_override("font_color", Color(0.96, 0.88, 0.62))
	_text_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	_text_lbl.add_theme_constant_override("shadow_offset_x", 2)
	_text_lbl.add_theme_constant_override("shadow_offset_y", 2)
	_text_lbl.size = Vector2(VW, 36.0)
	_text_lbl.position = Vector2(0.0, LB + 14.0)
	_text_lbl.modulate.a = 0.0
	cl_ui.add_child(_text_lbl)

	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.0); _overlay.size = Vector2(VW, VH)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE; _overlay.z_index = 40
	add_child(_overlay)

func _spawn_horde() -> void:
	for i in 28:
		_horde.append({
			"x": randf_range(18.0, SOPH_X - 50.0),
			"y": SOPH_Y + randf_range(-4.0, 4.0),
			"big": i < 4, "alive": true, "burn_t": 0.0
		})

func _mk_spr(key: String, pos: Vector2, sc: Vector2) -> Sprite2D:
	var spr := Sprite2D.new()
	spr.texture = SpriteSetup.get_texture(key)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.position = pos; spr.scale = sc; add_child(spr); return spr

func _process(delta: float) -> void:
	_t += delta

	for d in _debris:
		d.vx *= 0.97; d.vy += 380.0 * delta
		d.x += d.vx * delta; d.y += d.vy * delta; d.life -= delta
	_debris = _debris.filter(func(d): return d.life > 0.0)

	for p in _char_particles:
		p.vy -= 60.0 * delta; p.x += p.vx * delta; p.y += p.vy * delta; p.life -= delta
	_char_particles = _char_particles.filter(func(p): return p.life > 0.0)

	match _phase:
		Phase.SOPH_SCARED:
			# Staff starts to vibrate with no input from Soph
			if _t >= 1.6: _set_phase(Phase.STAFF_GLOW)

		Phase.STAFF_GLOW:
			_staff_glow = minf(_staff_glow + delta * 1.2, 1.0)
			if _t >= 0.3:
				_show_text("\"Espera... o cajado...\nEu não estou fazendo nada!\"")
			if _t >= 2.0: _set_phase(Phase.CHARGE)

		Phase.CHARGE:
			_charge_radius = minf(_charge_radius + delta * 180.0, 220.0)
			_charge_alpha  = minf(_charge_alpha + delta * 2.5, 1.0)
			_staff_glow    = minf(_staff_glow + delta * 0.8, 1.0)
			if _t >= 0.5: _show_text("\"ESPERA  ESPERA  ESPERA—\"")
			if _t >= 2.2: _set_phase(Phase.FIREBALL)

		Phase.FIREBALL:
			_fireball_x -= delta * 640.0
			_fireball_r  = minf(_fireball_r + delta * 420.0, 280.0)
			_fireball_alpha = 1.0
			# Burn horde as fireball passes
			for h in _horde:
				if h.alive and h.x < _fireball_x + _fireball_r * 0.7:
					h.alive = false; h.burn_t = 0.0
					for i in 8:
						_debris.append({
							"x": h.x, "y": h.y - 14.0,
							"vx": randf_range(-180, 180), "vy": randf_range(-220, -60),
							"life": randf_range(0.4, 0.9)
						})
					AudioManager.play("fireball")
			# Push Soph back from shockwave
			_soph_pushed = minf(_soph_pushed + delta * 120.0, 60.0)
			_soph.position.x = SOPH_X + _soph_pushed
			_hair.position.x = SOPH_X + _soph_pushed
			if _t >= 2.0: _set_phase(Phase.AFTERMATH)

		Phase.AFTERMATH:
			_shockwave_r = minf(_shockwave_r + delta * 280.0, 500.0)
			_aftermath_t += delta
			if _aftermath_t < 0.1: AudioManager.play("boss_appear")
			# Char particles rising from scorched ground
			if randi() % 3 == 0:
				_char_particles.append({
					"x": randf_range(20.0, SOPH_X - 30.0),
					"y": SOPH_Y,
					"vx": randf_range(-18, 18),
					"vy": randf_range(-80, -40),
					"life": randf_range(0.8, 1.8), "max_life": 1.8
				})
			if _t >= 0.6: _show_text("\"O que... o que foi ISSO?\"")
			if _t >= 3.2: _set_phase(Phase.FADE)

		Phase.FADE:
			_overlay.color.a = minf(_t / 1.2, 1.0)
			if _t >= 1.2: finished.emit(); set_process(false)

	queue_redraw()

func _show_text(txt: String) -> void:
	if _text_lbl.text != txt:
		_text_lbl.text = txt
		if _text_lbl.modulate.a < 1.0:
			_text_lbl.create_tween().tween_property(_text_lbl, "modulate:a", 1.0, 0.35)

func _set_phase(p: Phase) -> void:
	_phase = p; _t = 0.0
	match p:
		Phase.STAFF_GLOW:
			AudioManager.play("cast", 0.75)
		Phase.CHARGE:
			AudioManager.play("time_stop", 0.80)
			_text_lbl.create_tween().tween_property(_text_lbl, "modulate:a", 0.0, 0.25)
		Phase.FIREBALL:
			AudioManager.play("fireball")
			AudioManager.play("roar", 0.75)
			_text_lbl.create_tween().tween_property(_text_lbl, "modulate:a", 0.0, 0.2)
			MusicManager.stop()
		Phase.AFTERMATH:
			_fireball_alpha = 0.0

func _draw() -> void:
	_draw_bg()
	_draw_horde()
	_draw_debris()
	_draw_char_smoke()
	_draw_soph_staff()
	_draw_charge_aura()
	_draw_fireball()
	_draw_shockwave()
	_draw_aftermath_glow()

func _draw_bg() -> void:
	var act_top: float = LB
	var act_bot: float = VH - LB
	var sky_h: float = act_bot - act_top - 58.0
	for i in 10:
		var tf: float = float(i) / 9.0
		draw_rect(Rect2(0, act_top + tf * sky_h, VW, ceil(sky_h / 10.0) + 1.0),
				Color(0.022, 0.024, 0.080).lerp(Color(0.068, 0.048, 0.105), tf))
	# Stars
	for i in 18:
		var sx: float = fposmod(i * 43.0 + sin(i * 0.4) * 7.0, VW)
		var sy: float = act_top + fposmod(i * 19.0, sky_h * 0.55)
		draw_circle(Vector2(sx, sy), 1.0, Color(1, 1, 1, 0.25))
	# Trees silhouette
	for i in 6:
		var tx: float = 18.0 + i * 72.0
		var th: float = 38.0 + float((i * 11) % 20)
		draw_polygon([Vector2(tx - th * 0.35, SOPH_Y - 58.0),
					  Vector2(tx, SOPH_Y - 58.0 - th),
					  Vector2(tx + th * 0.35, SOPH_Y - 58.0)],
				[Color(0.018, 0.010, 0.026)])
	# Ground
	draw_rect(Rect2(0, SOPH_Y - 54.0, VW, VH - LB - (SOPH_Y - 54.0)), Color(0.048, 0.036, 0.032))
	# Scorched ground after fireball
	if _phase in [Phase.FIREBALL, Phase.AFTERMATH, Phase.FADE]:
		var scorch_w: float = maxf(SOPH_X - _fireball_x, 0.0)
		var sg_alpha: float = clampf(scorch_w / VW, 0.0, 0.75)
		draw_rect(Rect2(0, SOPH_Y - 54.0, minf(SOPH_X - _fireball_x, VW), 60.0),
				Color(0.010, 0.006, 0.008, sg_alpha))

func _draw_horde() -> void:
	for h in _horde:
		if not h.alive: continue
		var sc: float = 3.8 if h.big else 1.8
		var col: Color = Color.WHITE
		if _phase == Phase.SOPH_SCARED:
			# Horde advances slowly
			h.x = lerpf(h.x, h.x + 0.5, 0.05)
		_draw_goblin_at(Vector2(h.x, h.y), sc, col)

func _draw_goblin_at(pos: Vector2, sc: float, tint: Color) -> void:
	var gw: float = 10.0 * sc; var gh: float = 18.0 * sc
	var hy: float = pos.y - gh
	var body_c: Color = Color(0.28, 0.72, 0.20)
	draw_rect(Rect2(pos.x - gw * 0.5, hy, gw, gh * 0.65), body_c)
	draw_rect(Rect2(pos.x - gw * 0.42, hy - gh * 0.32, gw * 0.84, gh * 0.34), body_c)
	draw_rect(Rect2(pos.x - gw * 0.14, hy - gh * 0.22, gw * 0.28, gw * 0.28),
			Color(0.92, 0.88, 0.05))

func _draw_soph_staff() -> void:
	var soph_pos: Vector2 = _soph.position
	var staff_tip: Vector2 = soph_pos + Vector2(-24.0, -52.0)
	var shaft_base: Vector2 = soph_pos + Vector2(-18.0, -10.0)
	# Shaft
	draw_line(shaft_base, staff_tip, Color(0.42, 0.30, 0.16), 3.0)
	# Crystal tip glow
	var glow: float = 0.4 + _staff_glow * 0.6 + sin(_t * TAU * 3.5) * 0.15 * _staff_glow
	draw_rect(Rect2(staff_tip.x - 5, staff_tip.y - 8, 10, 12), Color(0.58, 0.22, 0.90, 0.92))
	draw_rect(Rect2(staff_tip.x - 3, staff_tip.y - 11, 6, 5), Color(0.78, 0.42, 1.00))
	for r in [8.0, 16.0, 28.0, 48.0]:
		draw_arc(staff_tip, r, 0.0, TAU, 24,
				Color(0.88, 0.45, 1.0, _staff_glow * 0.22 * (1.0 - r / 60.0) + glow * 0.08),
				r * 0.22)

func _draw_charge_aura() -> void:
	if _phase != Phase.CHARGE: return
	var staff_tip: Vector2 = _soph.position + Vector2(-24.0, -52.0)
	for r in [_charge_radius, _charge_radius * 0.7, _charge_radius * 0.4]:
		draw_arc(staff_tip, r, 0.0, TAU, 36,
				Color(1.0, 0.55, 0.10, _charge_alpha * 0.35 * (1.0 - r / _charge_radius * 0.5)),
				r * 0.06 + 4.0)
	# Incoming energy lines (streaks converging on staff tip)
	for i in 16:
		var ang: float = i * TAU / 16.0 + _t * 0.8
		var p_start: Vector2 = staff_tip + Vector2(cos(ang), sin(ang)) * _charge_radius
		var p_end: Vector2   = staff_tip + Vector2(cos(ang), sin(ang)) * (_charge_radius * 0.15)
		draw_line(p_start, p_end, Color(1.0, 0.65, 0.15, _charge_alpha * 0.55), 2.0)

func _draw_fireball() -> void:
	if _fireball_alpha <= 0.01: return
	var pos: Vector2 = Vector2(_fireball_x, SOPH_Y - 40.0)
	# Outer inferno
	for r in [_fireball_r * 1.0, _fireball_r * 0.75, _fireball_r * 0.5, _fireball_r * 0.28]:
		var t: float = r / _fireball_r
		var c: Color = Color(1.0, 0.55 - t * 0.40, 0.05, _fireball_alpha * (0.5 - t * 0.25))
		draw_arc(pos, r, 0.0, TAU, 36, c, r * 0.20)
	# Core (white-hot)
	draw_circle(pos, _fireball_r * 0.20, Color(1.0, 0.92, 0.70, _fireball_alpha * 0.95))
	draw_circle(pos, _fireball_r * 0.10, Color(1.0, 1.0, 1.0, _fireball_alpha))
	# Heat trail (left side)
	for i in 12:
		var tx: float = pos.x + (i + 1) * 22.0
		var tr: float = _fireball_r * (0.55 - float(i) / 12.0 * 0.50)
		if tr > 2.0:
			draw_arc(Vector2(tx, pos.y), tr, 0.0, TAU, 18,
					Color(1.0, 0.38, 0.05, _fireball_alpha * (0.20 - float(i) / 12.0 * 0.18)),
					tr * 0.25)

func _draw_shockwave() -> void:
	if _shockwave_r <= 0.0: return
	var pos: Vector2 = Vector2(0.0, SOPH_Y - 40.0)
	var a: float = clampf(1.0 - _shockwave_r / 500.0, 0.0, 1.0)
	draw_arc(pos, _shockwave_r, -PI * 0.5, PI * 0.5, 28, Color(1.0, 0.65, 0.25, a * 0.55), 8.0)

func _draw_aftermath_glow() -> void:
	if _phase != Phase.AFTERMATH and _phase != Phase.FADE: return
	var fade: float = clampf(1.0 - _aftermath_t / 3.5, 0.0, 1.0)
	draw_rect(Rect2(0, LB, VW * 0.55, VH - LB * 2), Color(0.55, 0.22, 0.05, fade * 0.18))

func _draw_debris() -> void:
	for d in _debris:
		draw_circle(Vector2(d.x, d.y), 3.5, Color(0.18, 0.12, 0.06, clampf(d.life, 0.0, 1.0)))

func _draw_char_smoke() -> void:
	for p in _char_particles:
		var a: float = clampf(p.life / p.max_life, 0.0, 1.0)
		draw_circle(Vector2(p.x, p.y), 4.0 + (1.0 - a) * 6.0, Color(0.12, 0.09, 0.07, a * 0.55))
