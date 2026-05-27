extends Node2D

signal finished

const VW         := 640.0
const VH         := 360.0
const LB         := 38.0
const FLOOR_Y    := VH - LB - 54.0
const SOPH_X     := VW * 0.52
const WALK_SPEED := 108.0
const MANA_MAX   := 5
const BOSS_HP_MAX := 5
const MISSILE_SPD := 530.0

enum Phase { WALK_1, GOBLINS, WALK_2, BOSS_INTRO, BOSS_FIGHT, BOSS_DEATH, WALK_3, HORDE, END }
enum BossAct { IDLE, CHARGE, ROAR }

var _phase:      Phase   = Phase.WALK_1
var _t:          float   = 0.0
var _ambient:    float   = 0.0
var _scroll:     float   = 0.0   # parallax (increases as Soph walks left)
var _walk_dist:  float   = 0.0
var _walk_t:     float   = 0.0
var _step_t:     float   = 0.34
var _hint_done:  bool    = false

var _mana:       int     = MANA_MAX
var _shot_cd:    float   = 0.0
var _orb_pos:    Vector2 = Vector2.ZERO
var _orb_active: bool    = false
var _orb_t:      float   = 0.0

var _missiles:   Array   = []   # {x,y,vx,vy,trail:Array}

# Three-goblin wave
var _g3: Array = []   # {x,y,vy,alive,delay,started}

# Boss
var _boss_x:    float    = -120.0
var _boss_y:    float    = FLOOR_Y
var _boss_hp:   int      = BOSS_HP_MAX
var _boss_act:  BossAct  = BossAct.IDLE
var _boss_t:    float    = 0.0
var _boss_flash: float   = 0.0
var _boss_vis:  bool     = false
var _boss_cvx:  float    = 0.0   # charge velocity x

# Shake
var _shake_t:   float = 0.0
var _shake_i:   float = 0.0

# Blood / explosion
var _blood:     Array = []
var _expl:      Array = []   # boss death sparks

# Horde (drawn procedurally)
var _horde:     Array = []   # {x,y,big,hop_t,hop_phase}
var _horde_in:  float = 0.0
var _scare_t:   float = 0.0

# Nodes
var _soph:      Sprite2D
var _hair:      Sprite2D
var _overlay:   ColorRect
var _qte_lbl:   Label
var _walk_hint: Label
var _mana_lbl:  Label
var _boss_bar:  Label

func _ready() -> void:
	_build()
	_spawn_horde()
	MusicManager.play("game")

func _build() -> void:
	_soph = _mk_spr("player_body", Vector2(SOPH_X, FLOOR_Y), Vector2(2.6, 2.6))
	_soph.flip_h = true
	_hair = _mk_spr("player_hair", Vector2(SOPH_X, FLOOR_Y - 1.0), Vector2(2.6, 2.6))
	_hair.flip_h = true

	var cl_lb := CanvasLayer.new(); cl_lb.layer = 20; add_child(cl_lb)
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color(0, 0, 0); bar.size = Vector2(VW, LB)
		bar.position = Vector2(0, 0 if top else VH - LB)
		cl_lb.add_child(bar)

	var cl_ui := CanvasLayer.new(); cl_ui.layer = 12; add_child(cl_ui)

	_walk_hint = _mk_lbl("← A  para avançar", 13, Color(0.78, 0.74, 0.92, 0.80))
	_walk_hint.size = Vector2(VW, 22.0); _walk_hint.position = Vector2(0, VH - LB - 24.0)
	_walk_hint.modulate.a = 0.0; cl_ui.add_child(_walk_hint)

	_qte_lbl = _mk_lbl("PRESSIONE  Z  —  MÍSSIL MÁGICO !", 22, Color(0.30, 0.88, 1.0))
	_qte_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1.0))
	_qte_lbl.add_theme_constant_override("shadow_offset_x", 3)
	_qte_lbl.add_theme_constant_override("shadow_offset_y", 3)
	_qte_lbl.size = Vector2(VW, 36.0); _qte_lbl.position = Vector2(0, VH * 0.18)
	_qte_lbl.pivot_offset = Vector2(VW * 0.5, 18.0); _qte_lbl.modulate.a = 0.0
	cl_ui.add_child(_qte_lbl)

	_mana_lbl = _mk_lbl("", 13, Color(0.45, 0.88, 1.0))
	_mana_lbl.size = Vector2(200.0, 22.0); _mana_lbl.position = Vector2(20.0, VH - LB - 24.0)
	_mana_lbl.modulate.a = 0.0; cl_ui.add_child(_mana_lbl)

	_boss_bar = _mk_lbl("", 12, Color(0.92, 0.22, 0.14))
	_boss_bar.size = Vector2(VW * 0.5, 22.0); _boss_bar.position = Vector2(VW * 0.25, LB + 8.0)
	_boss_bar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_bar.modulate.a = 0.0; cl_ui.add_child(_boss_bar)

	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.0); _overlay.size = Vector2(VW, VH)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE; _overlay.z_index = 40
	add_child(_overlay)

	get_tree().create_timer(0.5).timeout.connect(func():
		if _phase == Phase.WALK_1:
			_walk_hint.create_tween().tween_property(_walk_hint, "modulate:a", 1.0, 0.5))

func _mk_spr(key: String, pos: Vector2, sc: Vector2) -> Sprite2D:
	var spr := Sprite2D.new()
	spr.texture = SpriteSetup.get_texture(key)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.position = pos; spr.scale = sc; add_child(spr); return spr

func _mk_lbl(txt: String, sz: int, col: Color) -> Label:
	var lbl := Label.new(); lbl.text = txt
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	lbl.add_theme_font_size_override("font_size", sz)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	lbl.add_theme_constant_override("shadow_offset_x", 2)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	return lbl

# ── Horde init ────────────────────────────────────────────────────────────────

func _spawn_horde() -> void:
	for i in 22:
		_horde.append({
			"x": -VW * 0.5 - i * 28.0 - randf_range(0, 20),
			"y": FLOOR_Y + randf_range(-4.0, 4.0),
			"big": false, "hop_t": randf() * TAU, "hop_phase": randf_range(0, 1.0)
		})
	for i in 4:
		_horde.append({
			"x": -VW * 0.5 - i * 80.0 - 60.0,
			"y": FLOOR_Y, "big": true, "hop_t": randf() * TAU, "hop_phase": randf_range(0, 0.5)
		})

# ── Main loop ─────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	_t += delta; _ambient += delta
	_shot_cd = maxf(_shot_cd - delta, 0.0)

	if _shake_t > 0.0:
		_shake_t -= delta
		position = Vector2(randf_range(-_shake_i, _shake_i) * 5.0,
						   randf_range(-_shake_i, _shake_i) * 3.0)
	else:
		position = Vector2.ZERO

	_tick_missiles(delta)
	_tick_blood(delta)

	if _orb_active:
		_orb_t += delta
		_orb_pos = _orb_pos.lerp(Vector2(SOPH_X - 40.0, FLOOR_Y - 28.0), delta * 1.8)
		if _orb_pos.distance_to(Vector2(SOPH_X, FLOOR_Y - 18.0)) < 36.0:
			_collect_orb()

	match _phase:
		Phase.WALK_1:   _tick_walk_1(delta)
		Phase.GOBLINS:  _tick_goblins(delta)
		Phase.WALK_2:   _tick_walk_n(delta, 280.0, func(): _set_phase(Phase.BOSS_INTRO))
		Phase.BOSS_INTRO: _tick_boss_intro(delta)
		Phase.BOSS_FIGHT: _tick_boss_fight(delta)
		Phase.BOSS_DEATH: _tick_boss_death(delta)
		Phase.WALK_3:   _tick_walk_n(delta, 260.0, func(): _set_phase(Phase.HORDE))
		Phase.HORDE:    _tick_horde(delta)
		Phase.END:
			_overlay.color.a = minf(_t / 1.0, 1.0)
			if _t >= 1.0: finished.emit(); set_process(false)

	_update_soph_visuals()
	queue_redraw()

func _tick_walk_1(delta: float) -> void:
	var inp: float = _walk_inp()
	if inp < 0.0:
		_scroll += WALK_SPEED * delta
		_walk_dist += WALK_SPEED * delta
		_do_step(delta)
	if _walk_dist >= 300.0:
		_set_phase(Phase.GOBLINS)

func _tick_walk_n(delta: float, needed: float, on_done: Callable) -> void:
	var inp: float = _walk_inp()
	if inp < 0.0:
		_scroll += WALK_SPEED * delta
		_walk_dist += WALK_SPEED * delta
		_do_step(delta)
	if _walk_dist >= needed:
		on_done.call()

func _walk_inp() -> float:
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A): return -1.0
	return 0.0

func _do_step(delta: float) -> void:
	_walk_t += delta * 9.0
	_soph.flip_h = true; _hair.flip_h = true
	_step_t += delta
	if _step_t > 0.34:
		_step_t = 0.0
		AudioManager.play("step", 0.88 + randf_range(-0.06, 0.06))

func _tick_goblins(delta: float) -> void:
	var all_dead := true
	for g in _g3:
		if not g.started:
			g.delay -= delta
			if g.delay <= 0.0:
				g.started = true
				AudioManager.play("jump", 0.78)
		if g.started and g.alive:
			g.vy += 620.0 * delta
			g.y += g.vy * delta
			var progress: float = clampf((-g.delay_orig - g.delay_orig + delta) / 0.55, 0.0, 1.0)
			# slide from offscreen
			if g.x < g.land_x:
				g.x = minf(g.x + 280.0 * delta, g.land_x)
			if g.y >= FLOOR_Y:
				g.y = FLOOR_Y
				if g.vy > 0.0:
					AudioManager.play("land", 0.9)
					g.vy = 0.0
		if g.alive:
			all_dead = false

	if all_dead and _g3.size() > 0:
		_walk_hint.create_tween().tween_property(_walk_hint, "modulate:a", 0.0, 0.4)
		_qte_lbl.create_tween().tween_property(_qte_lbl, "modulate:a", 0.0, 0.3)
		_mana_lbl.create_tween().tween_property(_mana_lbl, "modulate:a", 0.0, 0.4)
		get_tree().create_timer(0.8).timeout.connect(func():
			if _phase == Phase.GOBLINS: _set_phase(Phase.WALK_2))

	if Input.is_action_just_pressed("spell_magic_missile"):
		_try_shoot_goblins()

func _try_shoot_goblins() -> void:
	if _shot_cd > 0.0 or _mana <= 0: return
	var nearest: Dictionary = {}
	var best: float = INF
	for g in _g3:
		if not g.alive: continue
		var d: float = abs(g.x - SOPH_X)
		if d < best: best = d; nearest = g
	if nearest.is_empty(): return
	_shoot_at(Vector2(nearest.x, nearest.y - 22.0))
	_mana -= 1; _update_mana_hud()
	if _mana == 0: _drop_orb()

func _tick_boss_intro(delta: float) -> void:
	_boss_vis = true
	_boss_x = minf(_boss_x + 220.0 * delta, 140.0)
	if _t >= 1.0 and _boss_x >= 140.0:
		_set_phase(Phase.BOSS_FIGHT)

func _tick_boss_fight(delta: float) -> void:
	if not _boss_vis: return
	_boss_flash = maxf(_boss_flash - delta * 4.0, 0.0)
	_boss_t += delta

	match _boss_act:
		BossAct.IDLE:
			if _boss_t >= 2.2:
				if randi() % 2 == 0:
					_set_boss_act(BossAct.CHARGE)
				else:
					_set_boss_act(BossAct.ROAR)
		BossAct.CHARGE:
			_boss_x += _boss_cvx * delta
			if _boss_cvx > 0.0 and _boss_x >= SOPH_X + 20.0:
				AudioManager.play("hit_player")
				_soph.modulate = Color(1.5, 0.4, 0.4)
				_hair.modulate  = Color(1.5, 0.4, 0.4)
				get_tree().create_timer(0.18).timeout.connect(func():
					_soph.modulate = Color.WHITE; _hair.modulate = Color.WHITE)
				_set_boss_act(BossAct.IDLE)
				_boss_x = 140.0
			elif _boss_cvx < 0.0 and _boss_x <= 140.0:
				_boss_cvx = 0.0
				_set_boss_act(BossAct.IDLE)
		BossAct.ROAR:
			if _boss_t >= 1.2:
				_set_boss_act(BossAct.IDLE)

	if Input.is_action_just_pressed("spell_magic_missile"):
		_try_shoot_boss()

func _set_boss_act(a: BossAct) -> void:
	_boss_act = a; _boss_t = 0.0
	match a:
		BossAct.CHARGE:
			_boss_cvx = 320.0
			AudioManager.play("dash", 0.65)
		BossAct.ROAR:
			AudioManager.play("roar")
			_shake(0.5, 1.0)

func _try_shoot_boss() -> void:
	if _shot_cd > 0.0 or _mana <= 0: return
	_shoot_at(Vector2(_boss_x, _boss_y - 45.0))
	_mana -= 1; _update_mana_hud()
	if _mana == 0: _drop_orb()

func _tick_boss_death(delta: float) -> void:
	for e in _expl:
		e.vy += 380.0 * delta; e.x += e.vx * delta; e.y += e.vy * delta; e.life -= delta
	_expl = _expl.filter(func(e): return e.life > 0.0)
	if _t >= 2.5:
		_boss_vis = false
		_boss_bar.create_tween().tween_property(_boss_bar, "modulate:a", 0.0, 0.4)
		_mana_lbl.create_tween().tween_property(_mana_lbl, "modulate:a", 0.0, 0.4)
		_set_phase(Phase.WALK_3)

func _tick_horde(delta: float) -> void:
	_horde_in = minf(_horde_in + delta * 0.55, 1.0)
	for h in _horde:
		var tx: float = (VW * 0.40 - h.x) * 0.15
		h.x = lerpf(h.x, VW * 0.40 + h.x * 0.22, delta * 0.55)
		h.hop_t += delta * 6.0
	if _t >= 1.2 and not _soph_scared:
		_soph_scared = true
		AudioManager.play("detect", 0.82)
		_soph.flip_h = false; _hair.flip_h = false
	if _t >= 3.8:
		_set_phase(Phase.END)

func _tick_missiles(delta: float) -> void:
	for m in _missiles:
		m.x += m.vx * delta; m.y += m.vy * delta; m.life -= delta
		m.trail.append({"x": m.x, "y": m.y, "a": 1.0})
		for tp in m.trail: tp.a -= delta * 6.0
		m.trail = m.trail.filter(func(tp): return tp.a > 0.0)
		# Hit goblins
		for g in _g3:
			if not g.alive: continue
			if Vector2(m.x - g.x, m.y - (g.y - 22.0)).length() < 20.0:
				m.life = -1.0; g.alive = false
				_spawn_blood(Vector2(g.x, g.y - 20.0), 32, Color(0.15, 0.72, 0.18))
				AudioManager.play("enemy_die")
		# Hit boss
		if _boss_vis and _boss_hp > 0 and _boss_act != BossAct.CHARGE:
			if Vector2(m.x - _boss_x, m.y - (_boss_y - 45.0)).length() < 40.0:
				m.life = -1.0; _boss_hp -= 1; _boss_flash = 1.0
				AudioManager.play("hit", 1.2); _shake(0.15, 0.5)
				_update_boss_bar()
				if _boss_hp <= 0:
					AudioManager.play("boss_appear")
					_shake(0.6, 1.4)
					_spawn_blood(Vector2(_boss_x, _boss_y - 30.0), 64, Color(0.18, 0.75, 0.22))
					for i in 20:
						_expl.append({"x": _boss_x, "y": _boss_y - 20.0,
							"vx": randf_range(-280, 280), "vy": randf_range(-360, -100),
							"life": randf_range(0.6, 1.2)})
					AudioManager.play("victory")
					_set_phase(Phase.BOSS_DEATH)

	_missiles = _missiles.filter(func(m): return m.life > 0.0)

func _tick_blood(delta: float) -> void:
	for b in _blood:
		b.vx *= 0.97; b.vy += 480.0 * delta
		b.x += b.vx * delta; b.y += b.vy * delta; b.life -= delta
	_blood = _blood.filter(func(b): return b.life > 0.0)

func _shoot_at(target: Vector2) -> void:
	var origin := Vector2(SOPH_X - 18.0, FLOOR_Y - 32.0)
	var dir := (target - origin).normalized()
	_missiles.append({"x": origin.x, "y": origin.y,
		"vx": dir.x * MISSILE_SPD, "vy": dir.y * MISSILE_SPD,
		"life": 1.2, "trail": []})
	_shot_cd = 0.38
	AudioManager.play("missile")

func _drop_orb() -> void:
	_orb_pos = Vector2(SOPH_X - 90.0, FLOOR_Y - 20.0)
	_orb_active = true; _orb_t = 0.0
	AudioManager.play("orb_pickup", 0.75)

func _collect_orb() -> void:
	_orb_active = false; _mana = MANA_MAX
	AudioManager.play("orb_pickup")
	_update_mana_hud()

func _spawn_blood(pos: Vector2, count: int, col: Color) -> void:
	for i in count:
		_blood.append({"x": pos.x + randf_range(-10, 10), "y": pos.y + randf_range(-10, 10),
			"vx": randf_range(-220, 220), "vy": randf_range(-300, -80),
			"life": randf_range(0.5, 1.1), "max_life": 1.1, "size": randf_range(2.5, 5.0),
			"col": col})

func _shake(dur: float, intensity: float) -> void:
	_shake_t = dur; _shake_i = intensity

func _update_mana_hud() -> void:
	var dots := "◆".repeat(_mana) + "◇".repeat(MANA_MAX - _mana)
	_mana_lbl.text = "MP  " + dots

func _update_boss_bar() -> void:
	var hearts := "♥".repeat(_boss_hp) + "♡".repeat(BOSS_HP_MAX - _boss_hp)
	_boss_bar.text = "  " + hearts + "  "

func _update_soph_visuals() -> void:
	var walking: bool = (_walk_inp() < 0.0 and
		(_phase == Phase.WALK_1 or _phase == Phase.WALK_2 or _phase == Phase.WALK_3))
	if walking:
		var bob: float = sin(_walk_t) * 1.8
		_soph.position = Vector2(SOPH_X, FLOOR_Y + bob)
		_hair.position = Vector2(SOPH_X, FLOOR_Y + bob - 1.0)
	else:
		_soph.position = Vector2(SOPH_X, FLOOR_Y)
		_hair.position = Vector2(SOPH_X, FLOOR_Y - 1.0)

func _set_phase(p: Phase) -> void:
	_phase = p; _t = 0.0; _walk_dist = 0.0
	match p:
		Phase.WALK_1:
			pass
		Phase.GOBLINS:
			_walk_hint.create_tween().tween_property(_walk_hint, "modulate:a", 0.0, 0.3)
			_qte_lbl.create_tween().tween_property(_qte_lbl, "modulate:a", 1.0, 0.4)
			_mana_lbl.modulate.a = 1.0
			_update_mana_hud()
			# Spawn 3 goblins staggered
			_g3 = []
			for i in 3:
				var g := {
					"x": -70.0 - i * 40.0,
					"y": -40.0 - i * 20.0,
					"vy": -260.0 + i * 30.0,
					"alive": true,
					"land_x": 120.0 + i * 75.0,
					"delay": float(i) * 0.35,
					"delay_orig": float(i) * 0.35,
					"started": false
				}
				_g3.append(g)
		Phase.WALK_2:
			_walk_hint.create_tween().tween_property(_walk_hint, "modulate:a", 1.0, 0.4)
		Phase.BOSS_INTRO:
			MusicManager.play("boss")
			_walk_hint.create_tween().tween_property(_walk_hint, "modulate:a", 0.0, 0.3)
			_boss_x = -120.0; _boss_y = FLOOR_Y; _boss_hp = BOSS_HP_MAX
			_boss_act = BossAct.IDLE; _boss_t = 0.0; _boss_vis = true
			_shake(0.5, 1.2)
			AudioManager.play("boss_appear")
		Phase.BOSS_FIGHT:
			_qte_lbl.create_tween().tween_property(_qte_lbl, "modulate:a", 1.0, 0.4)
			_mana_lbl.create_tween().tween_property(_mana_lbl, "modulate:a", 1.0, 0.3)
			_boss_bar.modulate.a = 1.0; _update_boss_bar(); _update_mana_hud()
		Phase.BOSS_DEATH:
			_qte_lbl.create_tween().tween_property(_qte_lbl, "modulate:a", 0.0, 0.3)
		Phase.WALK_3:
			MusicManager.play("game")
			_walk_hint.create_tween().tween_property(_walk_hint, "modulate:a", 1.0, 0.4)
		Phase.HORDE:
			_walk_hint.create_tween().tween_property(_walk_hint, "modulate:a", 0.0, 0.3)
			for h in _horde:
				h.x = -VW * 0.55 - h.x * 0.5
		Phase.END:
			pass

# ── Drawing ───────────────────────────────────────────────────────────────────

func _draw() -> void:
	_draw_bg()
	_draw_ground()
	_draw_goblins_3()
	_draw_boss()
	_draw_horde()
	_draw_missiles()
	_draw_blood()
	_draw_boss_death_sparks()
	if _orb_active: _draw_orb()
	if _soph_scared: _draw_scare_vignette()

func _draw_bg() -> void:
	var act_top: float = LB
	var act_bot: float = VH - LB
	var sky_h: float = act_bot - act_top - 60.0

	for i in 12:
		var tf: float = float(i) / 11.0
		draw_rect(Rect2(0, act_top + tf * sky_h, VW, ceil(sky_h / 12.0) + 1.0),
				Color(0.022, 0.024, 0.080).lerp(Color(0.068, 0.048, 0.105), tf))

	# Stars
	for i in 26:
		var sx: float = fposmod(i * 41.0 + sin(i * 0.5) * 8.0 - fmod(_scroll, 400.0) * 0.18, VW)
		var sy: float = act_top + fposmod(i * 17.0, sky_h * 0.55)
		draw_circle(Vector2(sx, sy), 1.0, Color(1, 1, 1, 0.28 + 0.22 * sin(_ambient * 1.6 + i)))

	# Moon (slow parallax)
	var moon_x: float = fposmod(VW * 0.68 - fmod(_scroll, 1200.0) * 0.04, VW)
	draw_circle(Vector2(moon_x, act_top + 40.0), 13.0, Color(0.96, 0.92, 0.78, 0.84))

	# Distant hills (very slow)
	var hill_off: float = fmod(_scroll * 0.10, VW)
	for i in 3:
		var hx: float = fposmod(i * 240.0 - hill_off, VW + 60.0) - 30.0
		var hy: float = act_top + sky_h * 0.6
		draw_polygon([Vector2(hx - 80, hy + 52), Vector2(hx, hy), Vector2(hx + 80, hy + 52)],
				[Color(0.032, 0.020, 0.048)])

	# Far trees (medium parallax)
	var ftree_off: float = fmod(_scroll * 0.28, 180.0)
	for i in 6:
		var tx: float = fposmod(i * 180.0 - ftree_off, VW + 60.0) - 30.0
		var th: float = 34.0 + float((i * 7) % 18)
		_draw_pine(Vector2(tx, act_top + sky_h), th, Color(0.025, 0.016, 0.036))

	# Near trees (fast parallax)
	var ntree_off: float = fmod(_scroll * 0.70, 120.0)
	for i in 9:
		var tx: float = fposmod(i * 120.0 - ntree_off, VW + 80.0) - 40.0
		var th: float = 52.0 + float((i * 13) % 28)
		_draw_pine(Vector2(tx, act_top + sky_h + 12.0), th, Color(0.018, 0.010, 0.026))

func _draw_pine(base: Vector2, h: float, col: Color) -> void:
	draw_polygon([Vector2(base.x - h * 0.38, base.y),
				  Vector2(base.x, base.y - h),
				  Vector2(base.x + h * 0.38, base.y)], [col])

func _draw_ground() -> void:
	var ground_y: float = VH - LB - 60.0
	var act_bot: float = VH - LB
	draw_rect(Rect2(0, ground_y, VW, act_bot - ground_y), Color(0.048, 0.036, 0.032))
	draw_line(Vector2(0, ground_y), Vector2(VW, ground_y), Color(0.032, 0.024, 0.024), 2.0)
	# Dirt detail (scrolls with camera)
	var dirt_off: float = fmod(_scroll, 60.0)
	for i in 70:
		var gx: float = fposmod(i * 29.0 - dirt_off, VW)
		var gy: float = ground_y + 5.0 + fposmod(i * 11.0, act_bot - ground_y - 8.0)
		draw_rect(Rect2(gx, gy, 2, 2), Color(0.120, 0.085, 0.065, 0.50))
	# Grass tufts
	for i in 16:
		var gx: float = fposmod(i * 42.0 - dirt_off, VW + 20.0) - 10.0
		draw_line(Vector2(gx, ground_y), Vector2(gx - 3, ground_y - 6), Color(0.085, 0.140, 0.045, 0.70), 1.0)
		draw_line(Vector2(gx + 4, ground_y), Vector2(gx + 6, ground_y - 8), Color(0.095, 0.150, 0.048, 0.65), 1.0)

func _draw_goblins_3() -> void:
	for g in _g3:
		if not g.started: continue
		if not g.alive: continue
		_draw_goblin_at(Vector2(g.x, g.y), 2.0, false, Color.WHITE)

func _draw_boss() -> void:
	if not _boss_vis: return
	var bc: Color = Color(0.25, 0.65, 0.22)
	if _boss_flash > 0.0:
		bc = bc.lerp(Color.WHITE, _boss_flash)
	_draw_boss_goblin(Vector2(_boss_x, _boss_y), 5.0, bc)

func _draw_goblin_at(pos: Vector2, sc: float, flip: bool, tint: Color) -> void:
	var gw: float = 10.0 * sc
	var gh: float = 18.0 * sc
	var hx: float = pos.x
	var hy: float = pos.y - gh

	# Body
	var body_c: Color = Color(0.28, 0.72, 0.20).lerp(tint, 0.15)
	draw_rect(Rect2(hx - gw * 0.5, hy, gw, gh * 0.65), body_c)
	# Head
	draw_rect(Rect2(hx - gw * 0.42, hy - gh * 0.32, gw * 0.84, gh * 0.34), body_c)
	# Eyes
	var eye_c: Color = Color(0.92, 0.88, 0.05)
	var ex: float = hx + (gw * 0.14) * (1.0 if not flip else -1.0)
	draw_rect(Rect2(ex - 2 * sc, hy - gh * 0.22, 4 * sc, 4 * sc), eye_c)
	# Teeth
	draw_rect(Rect2(hx - 3 * sc, hy - gh * 0.04, 6 * sc, 3 * sc), Color(0.92, 0.88, 0.80))
	# Arms
	draw_rect(Rect2(hx - gw * 0.8, hy + gh * 0.04, gw * 0.30, gh * 0.40),
			Color(0.16, 0.48, 0.10))
	draw_rect(Rect2(hx + gw * 0.50, hy + gh * 0.04, gw * 0.30, gh * 0.40),
			Color(0.16, 0.48, 0.10))
	# Legs
	draw_rect(Rect2(hx - gw * 0.45, hy + gh * 0.64, gw * 0.38, gh * 0.38),
			Color(0.16, 0.48, 0.10))
	draw_rect(Rect2(hx + gw * 0.08, hy + gh * 0.64, gw * 0.38, gh * 0.38),
			Color(0.16, 0.48, 0.10))

func _draw_boss_goblin(pos: Vector2, sc: float, tint: Color) -> void:
	var gw: float = 11.0 * sc
	var gh: float = 20.0 * sc

	# Sickly purple-green mutant tint
	var body_c: Color = Color(0.38, 0.55, 0.22).lerp(tint, 0.30)
	var dark_c: Color = body_c.darkened(0.3)

	# Shadow
	draw_arc(Vector2(pos.x, pos.y + 4.0), gw * 0.7, 0.0, PI, 18,
			Color(0, 0, 0, 0.30), gw * 0.18)

	# Legs (wider)
	draw_rect(Rect2(pos.x - gw * 0.50, pos.y - gh * 0.38, gw * 0.44, gh * 0.40), dark_c)
	draw_rect(Rect2(pos.x + gw * 0.06, pos.y - gh * 0.38, gw * 0.44, gh * 0.40), dark_c)

	# Body (barrel-chested)
	draw_rect(Rect2(pos.x - gw * 0.60, pos.y - gh, gw * 1.20, gh * 0.65), body_c)
	draw_rect(Rect2(pos.x - gw * 0.60, pos.y - gh, gw * 0.18, gh * 0.65),
			body_c.darkened(0.2))

	# Bulging arms
	draw_rect(Rect2(pos.x - gw * 1.10, pos.y - gh * 0.88, gw * 0.50, gh * 0.50), dark_c)
	draw_rect(Rect2(pos.x + gw * 0.60, pos.y - gh * 0.88, gw * 0.50, gh * 0.50), dark_c)

	# Neck + head (big)
	draw_rect(Rect2(pos.x - gw * 0.45, pos.y - gh * 1.38, gw * 0.90, gh * 0.40), body_c)
	# Face
	var fc: Color = body_c.lightened(0.1)
	draw_rect(Rect2(pos.x - gw * 0.52, pos.y - gh * 1.72, gw * 1.04, gh * 0.36), fc)
	# Glowing red eyes (boss)
	draw_rect(Rect2(pos.x - gw * 0.34, pos.y - gh * 1.64, gw * 0.22, gw * 0.22),
			Color(0.92, 0.12, 0.05))
	draw_rect(Rect2(pos.x + gw * 0.12, pos.y - gh * 1.64, gw * 0.22, gw * 0.22),
			Color(0.92, 0.12, 0.05))
	# Tusks
	draw_rect(Rect2(pos.x - gw * 0.28, pos.y - gh * 1.38, gw * 0.16, gh * 0.18),
			Color(0.90, 0.85, 0.70))
	draw_rect(Rect2(pos.x + gw * 0.12, pos.y - gh * 1.38, gw * 0.16, gh * 0.18),
			Color(0.90, 0.85, 0.70))
	# Horns (mutant feature)
	draw_line(Vector2(pos.x - gw * 0.22, pos.y - gh * 1.72),
			  Vector2(pos.x - gw * 0.44, pos.y - gh * 2.00),
			  Color(0.28, 0.20, 0.08), 3.0 * sc)
	draw_line(Vector2(pos.x + gw * 0.22, pos.y - gh * 1.72),
			  Vector2(pos.x + gw * 0.44, pos.y - gh * 2.00),
			  Color(0.28, 0.20, 0.08), 3.0 * sc)
	# Boss aura (pulsing threat)
	if _boss_act == BossAct.ROAR:
		var pulse: float = 0.4 + 0.6 * sin(_boss_t * TAU * 4.0)
		draw_arc(Vector2(pos.x, pos.y - gh * 0.8), gw * 1.5,
				0.0, TAU, 24, Color(0.85, 0.18, 0.04, pulse * 0.45), gw * 0.18)

func _draw_horde() -> void:
	if _phase != Phase.HORDE: return
	for h in _horde:
		var screen_x: float = lerpf(-VW * 0.5, h.x, _horde_in)
		if h.big:
			_draw_boss_goblin(Vector2(screen_x, h.y), 3.5, Color(0.30, 0.60, 0.18))
		else:
			var hop: float = abs(sin(h.hop_t)) * 5.0 * _horde_in
			_draw_goblin_at(Vector2(screen_x, h.y - hop), 1.6, false, Color.WHITE)

func _draw_missiles() -> void:
	for m in _missiles:
		var ang: float = atan2(m.vy, m.vx)
		var pos := Vector2(m.x, m.y)
		for tp in m.trail:
			draw_circle(Vector2(tp.x, tp.y), 3.0 * tp.a, Color(0.35, 0.80, 1.0, tp.a * 0.55))
		draw_circle(pos, 5.0, Color(0.40, 0.95, 1.0, 0.95))
		draw_circle(pos, 3.0, Color(0.85, 1.0, 1.0, 1.0))
		var tail := pos - Vector2(cos(ang), sin(ang)) * 16.0
		draw_line(pos, tail, Color(0.25, 0.80, 1.0, 0.55), 4.0)

func _draw_blood() -> void:
	for b in _blood:
		var a: float = clampf(b.life / b.max_life, 0.0, 1.0)
		draw_circle(Vector2(b.x, b.y), b.size * (0.4 + a * 0.6), Color(b.col.r, b.col.g, b.col.b, a))

func _draw_boss_death_sparks() -> void:
	for e in _expl:
		var a: float = clampf(e.life, 0.0, 1.0)
		draw_circle(Vector2(e.x, e.y), 4.5 * a, Color(0.30, 0.92, 0.20, a))
		draw_circle(Vector2(e.x, e.y), 2.2 * a, Color(0.85, 1.0, 0.60, a * 0.8))

func _draw_orb() -> void:
	var pulse: float = 0.6 + 0.4 * sin(_orb_t * TAU * 2.5)
	draw_circle(_orb_pos, 9.0 + pulse * 3.0, Color(0.42, 0.88, 1.0, 0.85))
	draw_circle(_orb_pos, 5.5, Color(0.85, 0.98, 1.0, 0.95))
	draw_arc(_orb_pos, 18.0, 0.0, TAU, 24, Color(0.42, 0.88, 1.0, 0.35 * pulse), 8.0)
	# Floating text
	var lbl_pos: Vector2 = _orb_pos + Vector2(-14.0, -20.0 - pulse * 2.0)
	draw_string(ThemeDB.fallback_font, lbl_pos, "MP", HORIZONTAL_ALIGNMENT_LEFT,
			-1, 11, Color(0.85, 1.0, 1.0, 0.90))

func _draw_scare_vignette() -> void:
	var a: float = clampf(_scare_t / 1.5, 0.0, 0.55)
	_scare_t += get_process_delta_time()
	draw_rect(Rect2(0, LB, VW, 38.0), Color(0.50, 0.0, 0.0, a))
	draw_rect(Rect2(0, VH - LB - 38.0, VW, 38.0), Color(0.50, 0.0, 0.0, a))
	draw_rect(Rect2(0, LB, 38.0, VH - LB * 2), Color(0.50, 0.0, 0.0, a))
	draw_rect(Rect2(VW - 38.0, LB, 38.0, VH - LB * 2), Color(0.50, 0.0, 0.0, a))
