extends Node2D

signal finished

const VW        := 640.0
const VH        := 360.0
const LB        := 38.0
const FLOOR_Y   := VH - LB - 54.0
const WALK_SPEED := 108.0

enum Phase { WALK, GOBLIN_JUMP, QTE, MISSILE_FLY, EXPLODE, LEARN, FADE_OUT }

const QTE_DUR      = 2.8
const GOBLIN_LAND_X  = 210.0
const SOPH_START_X   = VW * 0.82

var _phase:   Phase   = Phase.WALK
var _t:       float   = 0.0
var _ambient: float   = 0.0

# Soph
var _soph_x:    float = SOPH_START_X
var _walk_t:    float = 0.0
var _step_t:    float = 0.0
var _hint_done: bool  = false

# Goblin
var _gob_x:    float = -80.0
var _gob_y:    float = FLOOR_Y
var _gob_vy:   float = 0.0
var _gob_alive: bool = true
var _gob_angle: float = 0.0
var _gob_body_vy: float = 0.0

# Missile
var _mis_x:   float = 0.0
var _mis_y:   float = 0.0
var _mis_vx:  float = 0.0
var _mis_vy:  float = 0.0
var _mis_on:  bool  = false
var _mis_trail: Array = []

# Blood / debris
var _blood: Array = []

# QTE state
var _qte_ratio:  float = 1.0
var _qte_alpha:  float = 0.0
var _qte_failed: int   = 0

# Learn
var _learn_alpha: float = 0.0

# Nodes
var _soph:     Sprite2D
var _hair:     Sprite2D
var _goblin:   Sprite2D
var _qte_lbl:  Label
var _learn_lbl: Label
var _hint_lbl: Label
var _overlay:  ColorRect

func _ready() -> void:
	_build()

func _build() -> void:
	_goblin = _mk_sprite("goblin", Vector2(-80, FLOOR_Y), Vector2(2.2, 2.2))
	_goblin.visible = false

	_soph = _mk_sprite("player_body", Vector2(_soph_x, FLOOR_Y), Vector2(2.6, 2.6))
	_soph.flip_h = true
	_hair = _mk_sprite("player_hair", Vector2(_soph_x, FLOOR_Y - 1.0), Vector2(2.6, 2.6))
	_hair.flip_h = true

	var cl_lb := CanvasLayer.new(); cl_lb.layer = 20; add_child(cl_lb)
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color(0, 0, 0)
		bar.size = Vector2(VW, LB)
		bar.position = Vector2(0, 0 if top else VH - LB)
		cl_lb.add_child(bar)

	var cl_ui := CanvasLayer.new(); cl_ui.layer = 12; add_child(cl_ui)

	_hint_lbl = _mk_label("← A  para andar", 13, Color(0.78, 0.74, 0.92, 0.80))
	_hint_lbl.size = Vector2(VW, 22.0)
	_hint_lbl.position = Vector2(0.0, VH - LB - 24.0)
	_hint_lbl.modulate.a = 0.0
	cl_ui.add_child(_hint_lbl)

	_qte_lbl = _mk_label("PRESSIONE  Z  —  MÍSSIL MÁGICO !", 22, Color(0.30, 0.88, 1.0))
	_qte_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1.0))
	_qte_lbl.add_theme_constant_override("shadow_offset_x", 3)
	_qte_lbl.add_theme_constant_override("shadow_offset_y", 3)
	_qte_lbl.size = Vector2(VW, 36.0)
	_qte_lbl.position = Vector2(0.0, VH * 0.22)
	_qte_lbl.pivot_offset = Vector2(VW * 0.5, 18.0)
	_qte_lbl.modulate.a = 0.0
	cl_ui.add_child(_qte_lbl)

	_learn_lbl = _mk_label("✦  APRENDEU:  MÍSSIL MÁGICO  ✦\nPressione  Z  para lançar", 18, Color(0.30, 0.95, 1.0))
	_learn_lbl.size = Vector2(VW, 64.0)
	_learn_lbl.position = Vector2(0.0, VH * 0.25)
	_learn_lbl.modulate.a = 0.0
	cl_ui.add_child(_learn_lbl)

	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.0)
	_overlay.size = Vector2(VW, VH)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.z_index = 40
	add_child(_overlay)

	get_tree().create_timer(0.7).timeout.connect(func():
		if _phase == Phase.WALK:
			var tw := _hint_lbl.create_tween()
			tw.tween_property(_hint_lbl, "modulate:a", 1.0, 0.5)
			tw.tween_interval(3.5)
			tw.tween_property(_hint_lbl, "modulate:a", 0.0, 0.6))

func _mk_sprite(key: String, pos: Vector2, sc: Vector2) -> Sprite2D:
	var spr := Sprite2D.new()
	var tex := SpriteSetup.get_texture(key)
	if tex: spr.texture = tex
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.position = pos
	spr.scale = sc
	add_child(spr)
	return spr

func _mk_label(txt: String, sz: int, col: Color) -> Label:
	var lbl := Label.new()
	lbl.text = txt
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", sz)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	lbl.add_theme_constant_override("shadow_offset_x", 2)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return lbl

# ── Main loop ─────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	_t += delta
	_ambient += delta

	for p in _mis_trail:
		p.life -= delta
	_mis_trail = _mis_trail.filter(func(p): return p.life > 0.0)

	for b in _blood:
		b.vx *= 0.96
		b.vy += 480.0 * delta
		b.x += b.vx * delta
		b.y += b.vy * delta
		b.life -= delta
	_blood = _blood.filter(func(b): return b.life > 0.0)

	match _phase:
		Phase.WALK:
			_tick_walk(delta)
			if _soph_x <= VW * 0.62 and not _hint_done:
				_hint_done = true
				_set_phase(Phase.GOBLIN_JUMP)

		Phase.GOBLIN_JUMP:
			_gob_vy += 620.0 * delta
			_gob_y += _gob_vy * delta
			var jump_t: float = clampf(_t / 0.55, 0.0, 1.0)
			_gob_x = lerpf(-80.0, GOBLIN_LAND_X, jump_t)
			if _gob_y >= FLOOR_Y:
				_gob_y = FLOOR_Y
				AudioManager.play("land", 1.05)
				AudioManager.play("detect", 0.85)
				_set_phase(Phase.QTE)

		Phase.QTE:
			_qte_ratio = maxf(1.0 - _t / QTE_DUR, 0.0)
			_qte_alpha = minf(_qte_alpha + delta * 7.0, 1.0)
			_qte_lbl.modulate.a = _qte_alpha
			var pulse: float = 1.0 + 0.065 * sin(_t * TAU * 2.8)
			_qte_lbl.scale = Vector2(pulse, pulse)
			var urg: float = 1.0 - _qte_ratio
			_qte_lbl.add_theme_color_override("font_color",
				Color(0.30 + urg * 0.62, 0.88 - urg * 0.68, 1.0 - urg * 0.80))
			if Input.is_action_just_pressed("spell_magic_missile"):
				_fire_missile()
				_set_phase(Phase.MISSILE_FLY)
			elif _qte_ratio <= 0.0:
				_qte_failed += 1
				AudioManager.play("hit_player")
				_soph.modulate = Color(1.5, 0.4, 0.4)
				_hair.modulate  = Color(1.5, 0.4, 0.4)
				get_tree().create_timer(0.18).timeout.connect(func():
					_soph.modulate = Color(1, 1, 1)
					_hair.modulate  = Color(1, 1, 1))
				_set_phase(Phase.QTE)

		Phase.MISSILE_FLY:
			_qte_lbl.modulate.a = maxf(_qte_lbl.modulate.a - delta * 8.0, 0.0)
			_mis_x += _mis_vx * delta
			_mis_y += _mis_vy * delta
			_mis_trail.append({"x": _mis_x, "y": _mis_y, "life": 0.12})
			var dist: float = Vector2(_mis_x - _gob_x, _mis_y - (_gob_y - 28.0)).length()
			if dist < 18.0:
				_explode_goblin()
				_set_phase(Phase.EXPLODE)

		Phase.EXPLODE:
			if _gob_body_vy > 0.0 or _t < 0.4:
				_gob_body_vy += 620.0 * delta
				_gob_y += _gob_body_vy * delta
				_gob_angle += 4.5 * delta
				if _gob_y > FLOOR_Y + 18.0:
					_gob_y = FLOOR_Y + 18.0
					_gob_body_vy = 0.0
			if _t >= 1.4:
				_set_phase(Phase.LEARN)

		Phase.LEARN:
			_learn_alpha = minf(_learn_alpha + delta * 2.2, 1.0)
			_learn_lbl.modulate.a = _learn_alpha
			if _t >= 3.0:
				_set_phase(Phase.FADE_OUT)

		Phase.FADE_OUT:
			_overlay.color.a = minf(_t / 0.9, 1.0)
			if _t >= 0.9:
				finished.emit()
				set_process(false)

	_goblin.position = Vector2(_gob_x, _gob_y)
	_goblin.rotation = _gob_angle
	_goblin.visible = (_phase != Phase.WALK)
	_goblin.modulate.a = 1.0 if _gob_alive else 0.0

	queue_redraw()

func _tick_walk(delta: float) -> void:
	var inp: float = 0.0
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		inp = -1.0
	elif Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		inp = 1.0

	if inp != 0.0:
		_soph_x = clampf(_soph_x + inp * WALK_SPEED * delta, 120.0, VW * 0.88)
		_soph.flip_h = inp > 0.0
		_hair.flip_h  = inp > 0.0
		_walk_t += delta * 9.0
		var bob: float = sin(_walk_t) * 1.8
		_soph.position = Vector2(_soph_x, FLOOR_Y + bob)
		_hair.position = Vector2(_soph_x, FLOOR_Y + bob - 1.0)
		_step_t += delta
		if _step_t > 0.34:
			_step_t = 0.0
			AudioManager.play("step", 0.90 + randf_range(-0.06, 0.06))
	else:
		_soph.position = Vector2(_soph_x, FLOOR_Y)
		_hair.position = Vector2(_soph_x, FLOOR_Y - 1.0)
		_step_t = 0.28

func _fire_missile() -> void:
	AudioManager.play("missile")
	_soph.flip_h = true
	_hair.flip_h  = true
	_mis_on = true
	_mis_x = _soph_x - 20.0
	_mis_y = FLOOR_Y - 32.0
	var target: Vector2 = Vector2(_gob_x, _gob_y - 28.0)
	var dir: Vector2 = (target - Vector2(_mis_x, _mis_y)).normalized()
	_mis_x = _soph_x - 20.0
	_mis_y = FLOOR_Y - 32.0
	_mis_vx = dir.x * 580.0
	_mis_vy = dir.y * 580.0

func _explode_goblin() -> void:
	_gob_alive = false
	_gob_body_vy = -220.0
	_mis_on = false
	AudioManager.play("hit", 0.9)
	AudioManager.play("enemy_die", 1.1)
	for i in 48:
		_blood.append({
			"x": _gob_x + randf_range(-12, 12),
			"y": _gob_y - randf_range(8, 40),
			"vx": randf_range(-240, 240),
			"vy": randf_range(-320, -80),
			"life": randf_range(0.5, 1.1),
			"max_life": 1.1,
			"size": randf_range(2.5, 5.5)
		})

func _set_phase(p: Phase) -> void:
	_phase = p
	_t = 0.0
	match p:
		Phase.GOBLIN_JUMP:
			_goblin.visible = true
			_goblin.flip_h = true
			_gob_vy = -440.0
			AudioManager.play("jump", 0.82)
		Phase.QTE:
			AudioManager.play("qte_alert")
		Phase.LEARN:
			_learn_lbl.modulate.a = 0.0
			MusicManager.play("menu")
			AudioManager.play("unlock")

# ── Drawing ───────────────────────────────────────────────────────────────────

func _draw() -> void:
	_draw_bg()
	_draw_tower_wall()
	_draw_ground()
	if _mis_on:
		_draw_missile()
	elif _mis_trail.size() > 0:
		_draw_missile_trail()
	_draw_blood()
	if _phase in [Phase.QTE, Phase.MISSILE_FLY]:
		_draw_qte_bar()
	if _phase == Phase.EXPLODE:
		_draw_explosion_flash()

func _draw_bg() -> void:
	var act_top: float = LB
	var act_bot: float = VH - LB
	var sky_h: float = act_bot - act_top - 62.0
	var sky_top: Color = Color(0.022, 0.024, 0.080)
	var sky_bot: Color = Color(0.080, 0.060, 0.140)
	for i in 12:
		var tf: float = float(i) / 11.0
		draw_rect(Rect2(0, act_top + tf * sky_h, VW, ceil(sky_h / 12.0) + 1.0),
				sky_top.lerp(sky_bot, tf))

	# Moon
	draw_circle(Vector2(VW * 0.65, act_top + 42.0), 13.0, Color(0.96, 0.92, 0.78, 0.85))
	draw_arc(Vector2(VW * 0.65, act_top + 42.0), 22.0, 0.0, TAU, 24, Color(1.0, 0.94, 0.78, 0.10), 10.0)
	# Stars
	for i in 22:
		var sx: float = fposmod(i * 43.0 + sin(i * 0.5) * 8.0, VW)
		var sy: float = act_top + fposmod(i * 17.0, sky_h * 0.65)
		draw_circle(Vector2(sx, sy), 1.0, Color(1, 1, 1, 0.30 + 0.25 * sin(_ambient * 1.8 + i)))

func _draw_tower_wall() -> void:
	var act_top: float = LB
	var wall_x: float = VW * 0.76
	var wall_h: float = VH - LB * 2.0
	draw_rect(Rect2(wall_x, act_top, VW - wall_x, wall_h), Color(0.055, 0.038, 0.080))
	var bw: float = 14.0
	var bh: float = 9.0
	for row in range(int(wall_h / bh) + 2):
		var y: float = act_top + row * bh
		var off: float = bw * 0.5 if row % 2 == 0 else 0.0
		for col in range(int((VW - wall_x) / bw) + 2):
			var x: float = wall_x + col * bw + off
			if x + bw - 1.0 < VW:
				draw_rect(Rect2(x + 1.0, y + 1.0, bw - 2.0, bh - 2.0), Color(0.085, 0.062, 0.118))
	draw_line(Vector2(wall_x, act_top), Vector2(wall_x, VH - LB), Color(0.020, 0.012, 0.034), 4.0)

	# Broken window facing outward (where Soph came from)
	var win_y: float = act_top + 38.0
	var win_x: float = wall_x + 6.0
	draw_rect(Rect2(win_x, win_y, 14, 22), Color(0.055, 0.025, 0.040))
	# Shards around window
	for i in 5:
		var ang: float = lerpf(-PI * 0.8, PI * 0.2, float(i) / 4.0)
		var p1: Vector2 = Vector2(win_x + 7, win_y + 11)
		var p2: Vector2 = p1 + Vector2(cos(ang), sin(ang)) * (8.0 + float(i % 3) * 4.0)
		draw_line(p1, p2, Color(0.55, 0.78, 1.0, 0.45), 1.0)

func _draw_ground() -> void:
	var ground_y: float = VH - LB - 62.0
	var act_bot: float = VH - LB
	draw_rect(Rect2(0, ground_y, VW, act_bot - ground_y), Color(0.060, 0.045, 0.042))
	for i in 80:
		var gx: float = fposmod(i * 28.0 + sin(i) * 6.0, VW)
		var gy: float = ground_y + 5.0 + fposmod(i * 11.0, act_bot - ground_y - 8.0)
		draw_rect(Rect2(gx, gy, 2, 2), Color(0.130, 0.090, 0.070, 0.50))
	draw_line(Vector2(0, ground_y), Vector2(VW, ground_y), Color(0.042, 0.032, 0.035), 2.0)

	# Shadow under tower base
	for r in [48.0, 28.0]:
		draw_arc(Vector2(VW * 0.85, ground_y + 2.0), r, PI, TAU, 20,
				Color(0.0, 0.0, 0.0, 0.22), r * 0.22)

	# Trees silhouette (far left)
	for i in 4:
		var tx: float = 30.0 + i * 80.0
		var th: float = 22.0 + float((i * 9) % 12)
		draw_polygon([
			Vector2(tx, ground_y),
			Vector2(tx + 14, ground_y - th),
			Vector2(tx + 28, ground_y)
		], [Color(0.018, 0.010, 0.024)])

func _draw_missile() -> void:
	if not _mis_on: return
	var ang: float = atan2(_mis_vy, _mis_vx)
	var pos: Vector2 = Vector2(_mis_x, _mis_y)
	# Core
	draw_circle(pos, 5.0, Color(0.40, 0.95, 1.0, 0.95))
	draw_circle(pos, 3.0, Color(0.85, 1.0, 1.0, 1.0))
	# Tail
	var tail: Vector2 = pos - Vector2(cos(ang), sin(ang)) * 18.0
	draw_line(pos, tail, Color(0.25, 0.80, 1.0, 0.55), 4.0)
	draw_line(pos, tail, Color(1.0, 1.0, 1.0, 0.30), 2.0)
	# Glow
	draw_arc(pos, 10.0, 0.0, TAU, 16, Color(0.40, 0.90, 1.0, 0.22), 8.0)

func _draw_missile_trail() -> void:
	for p in _mis_trail:
		var a: float = p.life / 0.12
		draw_circle(Vector2(p.x, p.y), 3.5 * a, Color(0.35, 0.80, 1.0, a * 0.6))

func _draw_blood() -> void:
	for b in _blood:
		var a: float = clampf(b.life / b.max_life, 0.0, 1.0)
		var r: float = b.size * (0.5 + a * 0.5)
		draw_circle(Vector2(b.x, b.y), r, Color(0.15, 0.72, 0.18, a))

func _draw_qte_bar() -> void:
	if _qte_alpha < 0.01: return
	var cx: float = VW * 0.50
	var cy: float = VH * 0.54
	var r: float = 26.0
	draw_arc(Vector2(cx, cy), r, 0.0, TAU, 40, Color(0.10, 0.10, 0.18, 0.70 * _qte_alpha), 6.0)
	if _qte_ratio > 0.0:
		var urg: float = 1.0 - _qte_ratio
		draw_arc(Vector2(cx, cy), r, -PI * 0.5,
				-PI * 0.5 + TAU * _qte_ratio, 40,
				Color(0.28 + urg * 0.64, 0.84 - urg * 0.66, 1.0 - urg * 0.72, _qte_alpha), 6.0)
	draw_circle(Vector2(cx, cy), 3.8, Color(1, 1, 1, _qte_alpha * 0.82))

func _draw_explosion_flash() -> void:
	var f: float = clampf(1.0 - _t / 0.35, 0.0, 1.0)
	if f < 0.01: return
	draw_circle(Vector2(_gob_x, _gob_y - 20.0), 50.0 * (1.0 - f * 0.5),
			Color(0.55, 1.0, 0.40, f * 0.55))
	for i in 8:
		var ang: float = i * TAU / 8.0 + _t * 3.0
		var p1: Vector2 = Vector2(_gob_x, _gob_y - 20.0) + Vector2(cos(ang), sin(ang)) * 20.0
		var p2: Vector2 = Vector2(_gob_x, _gob_y - 20.0) + Vector2(cos(ang), sin(ang)) * (50.0 * (2.0 - f))
		draw_line(p1, p2, Color(0.30, 0.90, 0.20, f * 0.65), 2.0)
