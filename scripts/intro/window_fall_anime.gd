extends Node2D

signal finished(air_hike_success: bool)

const VW := 640.0
const VH := 360.0
const LB := 38.0

enum Phase { GLASS, FALLING, QTE, POST_QTE, IMPACT, END }

const FALL_DUR_BEFORE_QTE = 1.4
const QTE_DUR             = 0.60
const POST_QTE_DUR        = 1.0
const IMPACT_DUR          = 0.8
const END_DUR             = 0.6

var _phase: Phase = Phase.GLASS
var _t: float = 0.0
var _air_hike_pressed: bool = false
var _air_hike_too_late: bool = false
var _shards: Array = []
var _soph_y: float = 70.0
var _soph_x: float = VW * 0.58
var _fall_speed: float = 0.0
var _fall_distance: float = 0.0
var _air_hike_flash: float = 0.0
var _impact_shake: float = 0.0

var _soph: Sprite2D
var _hair: Sprite2D
var _qte_lbl: Label
var _overlay: ColorRect

func _ready() -> void:
	_build()
	_spawn_shards()

func _build() -> void:
	_soph = _mk_sprite("player_body", Vector2(_soph_x, _soph_y), Vector2(2.6, 2.6))
	_hair = _mk_sprite("player_hair", Vector2(_soph_x, _soph_y - 1.0), Vector2(2.6, 2.6))

	var cl_lb := CanvasLayer.new(); cl_lb.layer = 20; add_child(cl_lb)
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color(0, 0, 0)
		bar.size = Vector2(VW, LB)
		bar.position = Vector2(0, 0 if top else VH - LB)
		cl_lb.add_child(bar)

	var cl_lbl := CanvasLayer.new(); cl_lbl.layer = 12; add_child(cl_lbl)
	_qte_lbl = Label.new()
	_qte_lbl.text = "PRESSIONE  SPACE  —  AIR HIKE !"
	_qte_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_qte_lbl.add_theme_font_size_override("font_size", 22)
	_qte_lbl.add_theme_color_override("font_color", Color(0.30, 0.88, 1.0))
	_qte_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_qte_lbl.add_theme_constant_override("shadow_offset_x", 3)
	_qte_lbl.add_theme_constant_override("shadow_offset_y", 3)
	_qte_lbl.size = Vector2(VW, 36.0)
	_qte_lbl.position = Vector2(0.0, VH * 0.40)
	_qte_lbl.pivot_offset = Vector2(VW * 0.5, 18.0)
	_qte_lbl.modulate.a = 0.0
	cl_lbl.add_child(_qte_lbl)

	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.0)
	_overlay.size = Vector2(VW, VH)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.z_index = 40
	add_child(_overlay)

func _spawn_shards() -> void:
	for i in 28:
		_shards.append({
			"x": _soph_x + randf_range(-30, 30),
			"y": _soph_y + randf_range(-30, 30),
			"vx": randf_range(-160, 160),
			"vy": randf_range(-260, 20),
			"rot": randf() * TAU,
			"vrot": randf_range(-4.0, 4.0),
			"life": randf_range(0.9, 1.6),
			"max_life": 1.6,
			"size": randf_range(3.0, 6.5)
		})
	AudioManager.play("hit", 1.3)
	AudioManager.play("shield_break")

func _mk_sprite(key: String, pos: Vector2, sc: Vector2) -> Sprite2D:
	var spr := Sprite2D.new()
	var tex := SpriteSetup.get_texture(key)
	if tex: spr.texture = tex
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.position = pos
	spr.scale = sc
	add_child(spr)
	return spr

func _process(delta: float) -> void:
	_t += delta

	for s in _shards:
		s.vy += 380.0 * delta
		s.x += s.vx * delta
		s.y += s.vy * delta
		s.rot += s.vrot * delta
		s.life -= delta
	_shards = _shards.filter(func(s): return s.life > 0.0)

	match _phase:
		Phase.GLASS:
			_soph_x = lerpf(_soph_x, VW * 0.50, delta * 1.8)
			_fall_speed = lerpf(_fall_speed, 80.0, delta * 2.4)
			_soph_y += _fall_speed * delta
			_fall_distance += _fall_speed * delta
			_soph.position = Vector2(_soph_x, _soph_y)
			_hair.position = Vector2(_soph_x, _soph_y - 1.0 - sin(_t * 10.0) * 0.8)
			if _t >= 0.5:
				_set_phase(Phase.FALLING)
		Phase.FALLING:
			_fall_speed = minf(_fall_speed + 340.0 * delta, 380.0)
			_soph_y += _fall_speed * delta
			_fall_distance += _fall_speed * delta
			_soph.position = Vector2(_soph_x, _soph_y)
			_hair.position = Vector2(_soph_x, _soph_y - 1.0 - sin(_t * 12.0) * 1.4)
			if _t >= FALL_DUR_BEFORE_QTE:
				_set_phase(Phase.QTE)
		Phase.QTE:
			_qte_lbl.modulate.a = minf(_qte_lbl.modulate.a + delta * 8.0, 1.0)
			var pulse: float = 1.0 + 0.08 * sin(_t * TAU * 4.0)
			_qte_lbl.scale = Vector2(pulse, pulse)
			# Slow fall during QTE window (player has time to react)
			_fall_speed = lerpf(_fall_speed, 180.0, delta * 4.0)
			_soph_y += _fall_speed * delta
			_fall_distance += _fall_speed * delta
			_soph.position = Vector2(_soph_x, _soph_y)
			_hair.position = Vector2(_soph_x, _soph_y - 1.0 - sin(_t * 12.0) * 1.4)
			if Input.is_action_just_pressed("spell_magic_dash"):
				_air_hike_pressed = true
				_set_phase(Phase.POST_QTE)
			elif _t >= QTE_DUR:
				_air_hike_too_late = true
				_set_phase(Phase.POST_QTE)
		Phase.POST_QTE:
			_qte_lbl.modulate.a = maxf(_qte_lbl.modulate.a - delta * 5.0, 0.0)
			if _air_hike_pressed:
				_air_hike_flash = maxf(1.0 - _t / 0.45, 0.0)
				if _t < 0.40:
					_fall_speed = lerpf(_fall_speed, 50.0, delta * 7.0)
					_soph_y -= 20.0 * delta * (1.0 - _t / 0.40)
				else:
					_fall_speed = minf(_fall_speed + 380.0 * delta, 280.0)
			else:
				_fall_speed = minf(_fall_speed + 360.0 * delta, 440.0)
			_soph_y += _fall_speed * delta
			_fall_distance += _fall_speed * delta
			_soph.position = Vector2(_soph_x, _soph_y)
			_hair.position = Vector2(_soph_x, _soph_y - 1.0)
			if _t >= POST_QTE_DUR:
				_set_phase(Phase.IMPACT)
		Phase.IMPACT:
			_impact_shake = maxf(_impact_shake - delta * 4.0, 0.0)
			position = Vector2(randf_range(-_impact_shake, _impact_shake) * 7.0,
							   randf_range(-_impact_shake, _impact_shake) * 7.0)
			if _t >= IMPACT_DUR:
				_set_phase(Phase.END)
		Phase.END:
			_overlay.color.a = minf(_t / END_DUR, 1.0)
			if _t >= END_DUR:
				finished.emit(_air_hike_pressed and not _air_hike_too_late)
				set_process(false)

	queue_redraw()

func _set_phase(p: Phase) -> void:
	_phase = p
	_t = 0.0
	match p:
		Phase.QTE:
			AudioManager.play("qte_alert", 1.1)
		Phase.IMPACT:
			AudioManager.play("stomp", 0.8)
			AudioManager.play("hit_player")
			_impact_shake = 1.0
			_soph.position.y = VH - LB - 40.0
			_hair.position.y = _soph.position.y - 4.0
			position = Vector2.ZERO

func _draw() -> void:
	_draw_sky_and_wall()
	_draw_shards()
	if _air_hike_flash > 0.001:
		_draw_air_hike_burst()
	if _phase == Phase.IMPACT:
		_draw_impact_dust()

func _draw_sky_and_wall() -> void:
	var act_top: float = LB
	var act_h: float = VH - LB * 2.0

	var sky_top: Color = Color(0.022, 0.024, 0.080)
	var sky_bot: Color = Color(0.080, 0.050, 0.130)
	var slices: int = 14
	for i in slices:
		var t: float = float(i) / float(slices - 1)
		var y: float = act_top + t * act_h
		var c: Color = sky_top.lerp(sky_bot, t)
		draw_rect(Rect2(0, y, VW, ceil(act_h / float(slices)) + 1.0), c)

	# Distant moon
	draw_circle(Vector2(VW * 0.20, act_top + 38.0), 14.0, Color(0.96, 0.92, 0.78, 0.88))
	draw_arc(Vector2(VW * 0.20, act_top + 38.0), 24.0, 0.0, TAU, 28, Color(1.0, 0.94, 0.78, 0.10), 12.0)

	# Stars
	for i in 32:
		var sx: float = fposmod(i * 37.0 + sin(i * 0.7) * 11.0, VW)
		var sy: float = act_top + fposmod(i * 19.0, act_h * 0.6)
		var twinkle: float = 0.4 + 0.4 * sin(_t * 2.4 + i)
		draw_circle(Vector2(sx, sy), 1.0, Color(1, 1, 1, twinkle))

	# Distant ground
	var ground_y: float = VH - LB - 38.0
	draw_rect(Rect2(0, ground_y, VW, 38.0), Color(0.030, 0.018, 0.050))
	for i in 6:
		var tx: float = i * 110.0 + 18.0
		var th: float = 18.0 + float((i * 7) % 14)
		draw_polygon([
			Vector2(tx, ground_y),
			Vector2(tx + 22, ground_y - th),
			Vector2(tx + 44, ground_y)
		], [Color(0.015, 0.010, 0.028)])

	# Tower wall on the left, scrolling with fall_distance to give sense of falling
	var wall_w: float = VW * 0.36
	var bw: float = 36.0
	var bh: float = 15.0
	var bc: Color = Color(0.155, 0.118, 0.220)
	var scroll: float = fmod(_fall_distance * 0.42, bh * 2.0)
	for row in range(-1, int(act_h / bh) + 4):
		var y: float = act_top + row * bh + scroll
		var off: float = bw * 0.5 if row % 2 == 0 else 0.0
		for col in range(int(wall_w / bw) + 2):
			var x: float = col * bw + off - 10.0
			draw_rect(Rect2(x + 1, y + 1, bw - 2, bh - 2), bc)
	# Outer edge shadow
	draw_rect(Rect2(wall_w, act_top, 6.0, act_h), Color(0.012, 0.008, 0.024, 0.85))
	draw_line(Vector2(wall_w + 3, act_top), Vector2(wall_w + 3, VH - LB), Color(0.020, 0.012, 0.034), 4.0)

	# Faint window opening visible only at start
	if _phase == Phase.GLASS:
		var wy: float = 38.0
		draw_rect(Rect2(wall_w - 36, wy, 36, 96), Color(0.10, 0.14, 0.30, 0.55))

func _draw_shards() -> void:
	for s in _shards:
		var alpha: float = clampf(s.life / s.max_life, 0.0, 1.0)
		var c: Color = Color(0.55, 0.78, 1.0, alpha * 0.85)
		var p1: Vector2 = Vector2(cos(s.rot), sin(s.rot)) * float(s.size)
		var p2: Vector2 = Vector2(cos(s.rot + PI * 0.5), sin(s.rot + PI * 0.5)) * float(s.size) * 0.4
		var center: Vector2 = Vector2(s.x, s.y)
		draw_polygon([
			center + p1 + p2,
			center - p1 + p2,
			center - p1 - p2,
			center + p1 - p2
		], [c])

func _draw_air_hike_burst() -> void:
	var pos: Vector2 = _soph.position + Vector2(0, 18.0)
	var f: float = _air_hike_flash
	var r: float = 60.0 * (1.0 - f * 0.5)
	draw_arc(pos, r, 0.0, TAU, 28, Color(0.45, 0.92, 1.0, f * 0.8), 6.0)
	draw_arc(pos, r * 0.5, 0.0, TAU, 24, Color(0.85, 0.98, 1.0, f * 0.95), 3.5)
	draw_circle(pos, 14.0 * f, Color(0.78, 0.95, 1.0, f * 0.50))
	# Boom rays
	for i in 8:
		var ang: float = i * TAU / 8.0
		var p1: Vector2 = pos + Vector2(cos(ang), sin(ang)) * (r * 0.4)
		var p2: Vector2 = pos + Vector2(cos(ang), sin(ang)) * (r * 1.0)
		draw_line(p1, p2, Color(0.60, 0.95, 1.0, f * 0.6), 2.0)

func _draw_impact_dust() -> void:
	var ground_y: float = VH - LB - 36.0
	var sx: float = _soph.position.x
	var t: float = clampf(_t / IMPACT_DUR, 0.0, 1.0)
	for i in 16:
		var ang: float = lerpf(-PI * 0.88, -PI * 0.12, float(i) / 15.0)
		var r: float = 8.0 + t * 80.0
		var x: float = sx + cos(ang) * r
		var y: float = ground_y + sin(ang) * r * 0.5
		var alpha: float = (1.0 - t) * 0.65
		draw_circle(Vector2(x, y), 4.0 + t * 3.5, Color(0.55, 0.42, 0.40, alpha))
