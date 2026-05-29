extends Node2D

signal completed(success: bool)

# ── Phases ────────────────────────────────────────────────────────────────────
enum Phase { FADEIN, DIALOGUE, TENSION, QTE_ACTIVE, SUCCESS_ANIM, FAIL_ANIM }

# ── Layout (viewport 640×360) ─────────────────────────────────────────────────
const VW  := 640.0
const VH  := 360.0
const LB  := 38.0   # letterbox bar height

const SOPH_POS     := Vector2(320.0, 236.0)
const SOPH_SCALE   := Vector2(3.0,   3.0)
const GOLEM_SCALE  := Vector2(3.8,   3.8)
const GL_START     := Vector2(-90.0, 242.0)
const GL_END       := Vector2(162.0, 242.0)
const GR_START     := Vector2(730.0, 242.0)
const GR_END       := Vector2(478.0, 242.0)

# ── Timing ────────────────────────────────────────────────────────────────────
const FADEIN_DUR    = 1.3
const DIALOGUE_DUR  = 3.8
const TENSION_PRE   = 1.6   # silence before golems slide in
const GOLEM_SLIDE   = 1.4
const QTE_WINDOW    = 3.2
const SUCCESS_DUR   = 3.0
const FAIL_DUR      = 2.2

# ── State ─────────────────────────────────────────────────────────────────────
const TYPEWRITER_SPD = 22.0   # chars per second

var _phase:         Phase   = Phase.FADEIN
var _dial_full:     String  = ""
var _dial_chars:    int     = 0
var _dial_char_t:   float   = 0.0
var _timer:         float   = 0.0
var _torch_t:       float   = 0.0
var _qte_ratio:     float   = 1.0
var _qte_alpha:     float   = 0.0
var _golems_shown:  bool    = false
var _ts_radius:     float   = 0.0    # time-stop ring radius
var _ts_alpha:      float   = 0.0
var _fail_shake:    float   = 0.0
var _fail_lunge:    float   = 0.0
var _escape_dx:     float   = 0.0
var _soph_startle:  float   = 0.0   # squash/stretch on golem surprise

# Node references (all built procedurally)
var _soph:      Sprite2D
var _hair:      Sprite2D
var _golem_l:   Sprite2D
var _golem_r:   Sprite2D
var _overlay:   ColorRect
var _dial_lbl:  Label
var _qte_lbl:   Label

func _ready() -> void:
	_build_scene()

# ── Scene construction ────────────────────────────────────────────────────────

func _build_scene() -> void:
	# Golem sprites (added first so Soph renders in front)
	_golem_l = _mk_sprite("golem", GL_START, GOLEM_SCALE)
	_golem_l.flip_h  = false
	_golem_l.visible = false
	_golem_r = _mk_sprite("golem", GR_START, GOLEM_SCALE)
	_golem_r.flip_h  = true
	_golem_r.visible = false

	# Soph
	_soph = _mk_sprite("player_body", SOPH_POS, SOPH_SCALE)
	_hair = _mk_sprite("player_hair", SOPH_POS, SOPH_SCALE)

	# Dialogue label
	_dial_lbl = _mk_label(16, Color(0.92, 0.88, 0.78))
	_dial_lbl.size     = Vector2(560.0, 70.0)
	_dial_lbl.position = Vector2(40.0, VH - LB - 80.0)
	_dial_lbl.modulate.a = 0.0
	add_child(_dial_lbl)

	# QTE label (on CanvasLayer so it overlays everything)
	var cl := CanvasLayer.new(); cl.layer = 12; add_child(cl)
	_qte_lbl = _mk_label(24, Color(0.30, 0.88, 1.0))
	_qte_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1.0))
	_qte_lbl.add_theme_constant_override("shadow_offset_x", 3)
	_qte_lbl.add_theme_constant_override("shadow_offset_y", 3)
	_qte_lbl.text     = "PRESSIONE  X  —  TIME STOP !"
	_qte_lbl.size     = Vector2(VW, 44.0)
	_qte_lbl.position = Vector2(0.0, VH * 0.66)
	_qte_lbl.modulate.a = 0.0
	cl.add_child(_qte_lbl)

	# Letterbox
	var lb_cl := CanvasLayer.new(); lb_cl.layer = 20; add_child(lb_cl)
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color    = Color(0, 0, 0)
		bar.size     = Vector2(VW, LB)
		bar.position = Vector2(0, 0 if top else VH - LB)
		lb_cl.add_child(bar)

	# Full-screen overlay (fade in/out, flash)
	_overlay = ColorRect.new()
	_overlay.color        = Color(0, 0, 0, 1.0)
	_overlay.size         = Vector2(VW, VH)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.z_index      = 40
	add_child(_overlay)

func _mk_sprite(key: String, pos: Vector2, sc: Vector2) -> Sprite2D:
	var spr := Sprite2D.new()
	var tex := SpriteSetup.get_texture(key)
	if tex: spr.texture = tex
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.position = pos
	spr.scale    = sc
	add_child(spr)
	return spr

func _mk_label(sz: int, col: Color) -> Label:
	var lbl := Label.new()
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", sz)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	lbl.add_theme_constant_override("shadow_offset_x", 2)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	return lbl

# ── Main loop ─────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	_torch_t += delta
	_timer   += delta
	queue_redraw()

	match _phase:
		Phase.FADEIN:
			_overlay.color.a = maxf(1.0 - _timer / FADEIN_DUR, 0.0)
			if _timer >= FADEIN_DUR:
				_overlay.color.a = 0.0
				_set_phase(Phase.DIALOGUE)

		Phase.DIALOGUE:
			# Typewriter reveal
			_dial_char_t += delta * TYPEWRITER_SPD
			var nc := mini(int(_dial_char_t), _dial_full.length())
			if nc != _dial_chars:
				_dial_chars = nc
				_dial_lbl.text = _dial_full.substr(0, _dial_chars)
			if _timer >= DIALOGUE_DUR:
				_set_phase(Phase.TENSION)

		Phase.TENSION:
			if _timer >= TENSION_PRE and not _golems_shown:
				_golems_shown = true
				_golem_l.visible = true
				_golem_r.visible = true
				AudioManager.play("stone_emerge")
				_screen_shake(0.28, 5.0)
			if _golems_shown:
				var t := clampf((_timer - TENSION_PRE) / GOLEM_SLIDE, 0.0, 1.0)
				var e := 1.0 - pow(1.0 - t, 3.0)
				_golem_l.position = GL_START.lerp(GL_END, e)
				_golem_r.position = GR_START.lerp(GR_END, e)
				# Soph startled squash when golems first fully visible
				if t >= 0.85 and _soph_startle == 0.0:
					_soph_startle = 1.0
					AudioManager.play("detect", 0.72)
				if _soph_startle > 0.0:
					_soph_startle = maxf(_soph_startle - delta * 4.0, 0.0)
					var sq := 1.0 + sin(_soph_startle * PI) * 0.22
					_soph.scale = Vector2(SOPH_SCALE.x * (2.0 - sq), SOPH_SCALE.y * sq)
					_hair.scale  = _soph.scale
					# Face toward right golem
					_soph.flip_h = true; _hair.flip_h = true
				if t >= 1.0:
					_set_phase(Phase.QTE_ACTIVE)

		Phase.QTE_ACTIVE:
			_qte_ratio = maxf(1.0 - _timer / QTE_WINDOW, 0.0)
			# Fade in QTE elements
			_qte_alpha = minf(_qte_alpha + delta * 5.0, 1.0)
			_qte_lbl.modulate.a = _qte_alpha
			# Pulse label
			var pulse := 1.0 + 0.055 * sin(_timer * TAU * 2.8)
			_qte_lbl.scale = Vector2(pulse, pulse)
			# Color shifts red as time runs out
			var urgency := 1.0 - _qte_ratio
			_qte_lbl.add_theme_color_override("font_color",
				Color(0.30 + urgency * 0.62, 0.88 - urgency * 0.68, 1.0 - urgency * 0.80))
			# Accept input
			if Input.is_action_just_pressed("spell_time_stop"):
				_set_phase(Phase.SUCCESS_ANIM)
			elif _qte_ratio <= 0.0:
				_set_phase(Phase.FAIL_ANIM)

		Phase.SUCCESS_ANIM:
			_ts_radius = minf(_ts_radius + delta * 320.0, 620.0)
			_ts_alpha  = maxf(1.0 - _ts_radius / 620.0, 0.0) * 0.65
			if _timer >= 0.35:
				var prev_dx := _escape_dx
				_escape_dx = (_timer - 0.35) * 440.0
				_soph.position.x = SOPH_POS.x + _escape_dx
				_hair.position.x = SOPH_POS.x + _escape_dx
				# Dash ghosts every 28px of travel
				if int(_escape_dx / 28.0) > int(prev_dx / 28.0):
					_spawn_ghost(_soph.position)
			# White flash and exit
			if _timer >= SUCCESS_DUR - 0.6:
				_overlay.color = Color(1.0, 1.0, 1.0,
					minf((_timer - (SUCCESS_DUR - 0.6)) / 0.6, 1.0))
			if _timer >= SUCCESS_DUR and not _done:
				_done = true
				completed.emit(true)

		Phase.FAIL_ANIM:
			_fail_shake = maxf(_fail_shake - delta * 5.0, 0.0)
			# Golems lunge toward center
			_fail_lunge = minf(_timer / 0.55, 1.0)
			var e := 1.0 - pow(1.0 - _fail_lunge, 2.0)
			_golem_l.position = GL_END.lerp(Vector2(SOPH_POS.x - 18, SOPH_POS.y + 4), e)
			_golem_r.position = GR_END.lerp(Vector2(SOPH_POS.x + 18, SOPH_POS.y + 4), e)
			# Fade to black
			if _timer >= 0.5:
				_overlay.color.a = minf((_timer - 0.5) / (FAIL_DUR - 0.5), 1.0)
				_overlay.color = Color(0.08, 0.0, 0.0, _overlay.color.a)
			if _timer >= FAIL_DUR and not _done:
				_done = true
				completed.emit(false)

func _set_phase(p: Phase) -> void:
	_phase = p
	_timer = 0.0
	match p:
		Phase.DIALOGUE:
			MusicManager.play("tower")
			_dial_full    = "\"Não acredito que foi tão fácil\npassar pelas defesas desta torre...\""
			_dial_chars   = 0
			_dial_char_t  = 0.0
			_dial_lbl.text = ""
			_dial_lbl.modulate.a = 1.0
			# Fade out only near end
			get_tree().create_timer(DIALOGUE_DUR - 0.9).timeout.connect(func():
				if _phase == Phase.DIALOGUE:
					_dial_lbl.create_tween().tween_property(
							_dial_lbl, "modulate:a", 0.0, 0.55))

		Phase.TENSION:
			_golems_shown = false
			_golem_l.position = GL_START
			_golem_r.position = GR_START

		Phase.QTE_ACTIVE:
			AudioManager.play("qte_alert")
			# Brief white flash to signal QTE start
			_overlay.color = Color(1.0, 1.0, 1.0, 0.45)
			_overlay.create_tween().tween_property(_overlay, "color:a", 0.0, 0.30)

		Phase.SUCCESS_ANIM:
			AudioManager.play("time_stop")
			get_tree().create_timer(0.3).timeout.connect(func():
				AudioManager.play("dash", 1.1))
			_qte_lbl.create_tween().tween_property(_qte_lbl, "modulate:a", 0.0, 0.18)
			# Freeze golems with blue tint
			_golem_l.create_tween().tween_property(_golem_l, "modulate",
				Color(0.38, 0.62, 1.0, 0.65), 0.25)
			_golem_r.create_tween().tween_property(_golem_r, "modulate",
				Color(0.38, 0.62, 1.0, 0.65), 0.25)
			# Soph turns cyan briefly
			_soph.create_tween().tween_property(_soph, "modulate",
				Color(0.55, 0.90, 1.0), 0.20)

		Phase.FAIL_ANIM:
			AudioManager.play("stomp")
			_qte_lbl.create_tween().tween_property(_qte_lbl, "modulate:a", 0.0, 0.12)
			_fail_shake = 1.0
			# Red tint on Soph
			_soph.create_tween().tween_property(_soph, "modulate",
				Color(1.4, 0.2, 0.2), 0.15)
			_hair.create_tween().tween_property(_hair, "modulate",
				Color(1.0, 0.25, 0.25), 0.15)

# ── Drawing ───────────────────────────────────────────────────────────────────

func _draw() -> void:
	_draw_tower_bg()
	_draw_torches()
	if _phase == Phase.SUCCESS_ANIM and _ts_radius > 0.0:
		_draw_time_stop_ring()
	if _phase in [Phase.QTE_ACTIVE, Phase.SUCCESS_ANIM]:
		_draw_countdown()
	if _phase in [Phase.FAIL_ANIM] and _fail_shake > 0.0:
		_draw_fail_vignette()

func _draw_tower_bg() -> void:
	var act_top := LB
	var act_bot := VH - LB

	# Deep background
	draw_rect(Rect2(0, act_top, VW, act_bot - act_top), Color(0.030, 0.018, 0.055))

	# Stone bricks — left and right wall panels
	var bw := 36.0; var bh := 15.0
	var bc := Color(0.125, 0.095, 0.170)
	for row in range(int((act_bot - act_top) / bh) + 2):
		var y := act_top + row * bh
		var off := bw * 0.5 if row % 2 == 0 else 0.0
		# Left wall
		for col in range(-1, 6):
			var x := col * bw + off
			if x + bw < VW * 0.26:
				draw_rect(Rect2(x + 1, y + 1, bw - 2, bh - 2), bc)
		# Right wall
		for col in range(int(VW * 0.74 / bw), int(VW / bw) + 2):
			var x := col * bw + off
			draw_rect(Rect2(x + 1, y + 1, bw - 2, bh - 2), bc)

	# Central dark void (the chamber interior)
	draw_rect(Rect2(VW * 0.24, act_top, VW * 0.52, act_bot - act_top),
			Color(0.018, 0.010, 0.038))

	# Gothic arch outline — series of decreasing arcs
	var cx := VW * 0.50
	var arch_base_y := act_top + 28.0
	for i in 7:
		var f := float(i) / 6.0
		var aw := VW * 0.26 * (1.0 - f * 0.12)
		var ay := arch_base_y + f * 22.0
		var ac := Color(0.14, 0.10, 0.21, 1.0 - f * 0.82)
		draw_arc(Vector2(cx, ay), aw, PI, TAU, 36, ac, 2.5)

	# Floor
	var floor_y := act_bot - 28.0
	draw_rect(Rect2(0, floor_y, VW, act_bot - floor_y), Color(0.068, 0.050, 0.098))
	# Perspective convergence lines
	for i in 9:
		var t := float(i) / 8.0
		var lx: float = lerpf(-VW * 0.15, VW * 1.15, t)
		draw_line(Vector2(lx, act_bot), Vector2(cx, floor_y),
				Color(0.11, 0.082, 0.155, 0.45), 1.0)
	# Horizontal grout lines
	for r in 5:
		draw_line(Vector2(0, floor_y + r * 6.0), Vector2(VW, floor_y + r * 6.0),
				Color(0.10, 0.075, 0.148, 0.55), 1.0)

	# Pedestal (only before Soph escapes)
	if _phase not in [Phase.SUCCESS_ANIM] or _escape_dx < 60.0:
		_draw_pedestal(cx, floor_y - 2.0)

	# Ambient torch-light gradient on floor
	var tl := 0.55 + 0.45 * sin(_torch_t * 3.2)
	for r in [80.0, 55.0, 32.0]:
		draw_arc(Vector2(VW * 0.15, floor_y), r, -PI * 0.5, PI * 0.5,
				24, Color(0.78, 0.40, 0.10, 0.03 * tl), r * 0.28)
		draw_arc(Vector2(VW * 0.85, floor_y), r, PI * 0.5, PI * 1.5,
				24, Color(0.78, 0.40, 0.10, 0.03 * tl), r * 0.28)

func _draw_pedestal(cx: float, base_y: float) -> void:
	# Staff (only while Soph hasn't picked it up yet — removed after SUCCESS phase reaches it)
	var show_staff := _phase in [Phase.FADEIN, Phase.DIALOGUE, Phase.TENSION]
	if show_staff:
		_draw_staff(cx, base_y - 4.0)

	# Base slab
	draw_rect(Rect2(cx - 16, base_y + 16, 32,  8), Color(0.210, 0.168, 0.280))
	draw_rect(Rect2(cx - 12, base_y +  4, 24, 14), Color(0.175, 0.135, 0.235))
	draw_rect(Rect2(cx -  8, base_y,      16,  6), Color(0.155, 0.118, 0.210))
	# Top highlight
	draw_rect(Rect2(cx - 16, base_y + 16,  32, 2), Color(0.28, 0.24, 0.35, 0.75))

	# Crystal glow from pedestal (even without staff, residual glow)
	var glow := 0.4 + 0.6 * sin(_torch_t * 2.6) if show_staff else 0.0
	for r in [36.0, 24.0]:
		draw_arc(Vector2(cx, base_y), r, 0.0, TAU, 28,
				Color(0.60, 0.25, 0.92, 0.06 + glow * 0.06), r * 0.18)

func _draw_staff(cx: float, base_y: float) -> void:
	var tip_y := base_y - 42.0
	var glow  := 0.5 + 0.5 * sin(_torch_t * 2.8)

	# Shaft
	draw_rect(Rect2(cx - 2, tip_y + 14, 4, 30), Color(0.42, 0.30, 0.16))
	draw_rect(Rect2(cx - 1, tip_y + 14, 2, 30), Color(0.54, 0.40, 0.22))
	# Crystal housing
	draw_rect(Rect2(cx - 7, tip_y +  4, 14, 12), Color(0.58, 0.22, 0.90, 0.92))
	draw_rect(Rect2(cx - 5, tip_y +  1, 10,  5), Color(0.78, 0.42, 1.00, 0.96))
	draw_rect(Rect2(cx - 3, tip_y - 1,   6,  4), Color(1.00, 0.72, 1.00))
	# Animated glow ring
	var gr := 12.0 + glow * 5.0
	draw_arc(Vector2(cx, tip_y + 8), gr, 0.0, TAU, 28,
			Color(0.78, 0.35, 1.0, 0.10 + glow * 0.10), 4.5)
	draw_arc(Vector2(cx, tip_y + 8), gr * 1.6, 0.0, TAU, 20,
			Color(0.62, 0.20, 0.88, 0.04 + glow * 0.04), 3.0)

func _draw_torches() -> void:
	var act_top := LB
	var positions: Array[Vector2] = [Vector2(VW * 0.135, act_top + 70.0),
					  Vector2(VW * 0.865, act_top + 70.0)]
	for i in 2:
		var tp: Vector2 = positions[i]
		var fl  := 0.68 + 0.32 * sin(_torch_t * 7.1 + i * 2.3) * sin(_torch_t * 4.5 + i * 1.1)

		# Wall bracket
		draw_rect(Rect2(tp.x - 3, tp.y,      6, 13), Color(0.22, 0.18, 0.28))
		draw_rect(Rect2(tp.x - 6, tp.y + 10, 12, 4), Color(0.22, 0.18, 0.28))
		# Flame layers
		draw_rect(Rect2(tp.x - 3, tp.y -  6, 6,  8), Color(0.94, 0.48, 0.08, fl))
		draw_rect(Rect2(tp.x - 2, tp.y - 11, 4,  7), Color(1.00, 0.78, 0.18, fl * 0.88))
		draw_rect(Rect2(tp.x - 1, tp.y - 15, 2,  5), Color(1.00, 0.96, 0.62, fl * 0.70))
		# Halo glow
		var hr := 58.0 + fl * 22.0
		draw_arc(tp, hr,        0.0, TAU, 24, Color(0.95, 0.52, 0.12, 0.038 * fl), hr * 0.38)
		draw_arc(tp, hr * 0.5,  0.0, TAU, 16, Color(1.00, 0.68, 0.22, 0.068 * fl), hr * 0.18)
		# Cast light on nearby wall
		var wl_x := 0.0 if i == 0 else VW
		draw_rect(Rect2(wl_x - (60.0 if i == 0 else 0.0), act_top,
				60.0, act_top + 140.0), Color(0.80, 0.42, 0.10, 0.028 * fl))

func _draw_time_stop_ring() -> void:
	if _ts_alpha <= 0.001: return
	# Outer ring
	draw_arc(SOPH_POS, _ts_radius, 0.0, TAU, 72,
			Color(0.35, 0.72, 1.0, _ts_alpha), 5.0)
	# Inner shimmer
	if _ts_radius > 30.0:
		draw_arc(SOPH_POS, _ts_radius * 0.75, 0.0, TAU, 56,
				Color(0.60, 0.88, 1.0, _ts_alpha * 0.4), 2.5)

func _draw_countdown() -> void:
	if _qte_alpha <= 0.001: return
	var cx := VW * 0.50; var cy := VH * 0.58
	var r   := 28.0
	# Background ring
	draw_arc(Vector2(cx, cy), r, 0.0, TAU, 48,
			Color(0.12, 0.12, 0.18, 0.75 * _qte_alpha), 7.0)
	# Progress arc
	if _qte_ratio > 0.0:
		var urgency := 1.0 - _qte_ratio
		var c := Color(0.28 + urgency * 0.64, 0.84 - urgency * 0.66,
					   1.0  - urgency * 0.72, _qte_alpha)
		draw_arc(Vector2(cx, cy), r, -PI * 0.5,
				-PI * 0.5 + TAU * _qte_ratio, 48, c, 7.0)
	# Center dot
	draw_circle(Vector2(cx, cy), 4.2,
			Color(1.0, 1.0, 1.0, _qte_alpha * 0.85))

func _draw_fail_vignette() -> void:
	var a := _fail_shake * 0.38
	draw_rect(Rect2(0, LB,         VW, 45.0), Color(0.75, 0.0, 0.0, a))
	draw_rect(Rect2(0, VH - LB - 45, VW, 45.0), Color(0.75, 0.0, 0.0, a))
	draw_rect(Rect2(0, LB,       45.0, VH - LB * 2), Color(0.75, 0.0, 0.0, a))
	draw_rect(Rect2(VW - 45, LB, 45.0, VH - LB * 2), Color(0.75, 0.0, 0.0, a))

# ── Screen shake (moves root position) ───────────────────────────────────────

var _shake_t: float = 0.0
var _shake_i: float = 0.0
var _done: bool = false

func _spawn_ghost(pos: Vector2) -> void:
	if not _soph.texture: return
	var g := Sprite2D.new()
	g.texture        = _soph.texture
	g.flip_h         = _soph.flip_h
	g.scale          = _soph.scale
	g.global_position = pos
	g.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	g.modulate        = Color(0.35, 0.80, 1.0, 0.48)
	g.z_index         = -1
	add_child(g)
	var tw := g.create_tween()
	tw.tween_property(g, "modulate:a", 0.0, 0.22)
	tw.tween_callback(g.queue_free)

func _screen_shake(dur: float, intensity: float) -> void:
	_shake_t = dur; _shake_i = intensity

func _update_shake(delta: float) -> void:
	if _shake_t > 0.0:
		_shake_t -= delta
		position = Vector2(randf_range(-_shake_i, _shake_i),
						   randf_range(-_shake_i, _shake_i))
	else:
		position = Vector2.ZERO

func _physics_process(delta: float) -> void:
	_update_shake(delta)
