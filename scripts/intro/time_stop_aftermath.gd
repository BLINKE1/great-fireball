extends Node2D

signal finished

const VW := 640.0
const VH := 360.0
const LB := 38.0

const PEDESTAL_X := VW * 0.50
const PEDESTAL_Y := VH * 0.74

const STATE_FROZEN := 0
const STATE_UNFREEZE := 1
const STATE_LUNGE := 2
const STATE_SMASH_HOLD := 3
const STATE_FADE := 4

var _state: int = STATE_FROZEN
var _state_t: float = 0.0
var _torch_t: float = 0.0
var _pedestal_smashed: bool = false
var _shake: float = 0.0
var _debris: Array = []
var _confused_lbl: Label

var _golem_l: Sprite2D
var _golem_r: Sprite2D
var _overlay: ColorRect

func _ready() -> void:
	_build()

func _build() -> void:
	_golem_l = _mk_sprite("golem", Vector2(PEDESTAL_X - 70.0, PEDESTAL_Y + 6.0), Vector2(3.8, 3.8))
	_golem_l.modulate = Color(0.38, 0.62, 1.0, 0.95)
	_golem_r = _mk_sprite("golem", Vector2(PEDESTAL_X + 70.0, PEDESTAL_Y + 6.0), Vector2(3.8, 3.8))
	_golem_r.modulate = Color(0.38, 0.62, 1.0, 0.95)
	_golem_r.flip_h = true

	var cl := CanvasLayer.new(); cl.layer = 20; add_child(cl)
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color(0, 0, 0)
		bar.size = Vector2(VW, LB)
		bar.position = Vector2(0, 0 if top else VH - LB)
		cl.add_child(bar)

	var lbl_cl := CanvasLayer.new(); lbl_cl.layer = 12; add_child(lbl_cl)
	_confused_lbl = Label.new()
	_confused_lbl.text = "\"...?\""
	_confused_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confused_lbl.add_theme_font_size_override("font_size", 22)
	_confused_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.95))
	_confused_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_confused_lbl.add_theme_constant_override("shadow_offset_x", 2)
	_confused_lbl.add_theme_constant_override("shadow_offset_y", 2)
	_confused_lbl.size = Vector2(VW, 30.0)
	_confused_lbl.position = Vector2(0.0, VH * 0.30)
	_confused_lbl.modulate.a = 0.0
	lbl_cl.add_child(_confused_lbl)

	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.0)
	_overlay.size = Vector2(VW, VH)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.z_index = 40
	add_child(_overlay)

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
	_state_t += delta
	_torch_t += delta
	if _shake > 0.0:
		_shake = maxf(_shake - delta * 4.0, 0.0)
		position = Vector2(randf_range(-_shake, _shake) * 5.0, randf_range(-_shake, _shake) * 5.0)
	else:
		position = Vector2.ZERO

	match _state:
		STATE_FROZEN:
			if _state_t >= 0.9:
				_set_state(STATE_UNFREEZE)
		STATE_UNFREEZE:
			var t: float = clampf(_state_t / 0.55, 0.0, 1.0)
			var c: Color = Color(0.38, 0.62, 1.0, 0.95).lerp(Color(1, 1, 1, 1), t)
			_golem_l.modulate = c
			_golem_r.modulate = c
			if _state_t >= 0.55:
				_set_state(STATE_LUNGE)
		STATE_LUNGE:
			var t: float = clampf(_state_t / 0.40, 0.0, 1.0)
			var e: float = pow(t, 2.0)
			_golem_l.position.x = (PEDESTAL_X - 70.0) + e * 56.0
			_golem_r.position.x = (PEDESTAL_X + 70.0) - e * 56.0
			if t >= 1.0 and not _pedestal_smashed:
				_smash()
				_set_state(STATE_SMASH_HOLD)
		STATE_SMASH_HOLD:
			for d in _debris:
				d.vx *= 0.99
				d.vy += 320.0 * delta
				d.x += d.vx * delta
				d.y += d.vy * delta
				d.life -= delta
			_debris = _debris.filter(func(d): return d.life > 0.0)
			if _state_t >= 0.4 and _confused_lbl.modulate.a < 1.0:
				_confused_lbl.modulate.a = minf(_confused_lbl.modulate.a + delta * 2.5, 1.0)
			if _state_t >= 1.8:
				_set_state(STATE_FADE)
		STATE_FADE:
			_overlay.color.a = minf(_state_t / 0.7, 1.0)
			if _state_t >= 0.7:
				finished.emit()
				set_process(false)

	queue_redraw()

func _smash() -> void:
	_pedestal_smashed = true
	_shake = 1.0
	AudioManager.play("stomp")
	AudioManager.play("hit", 0.6)
	for i in 22:
		_debris.append({
			"x": PEDESTAL_X + randf_range(-12, 12),
			"y": PEDESTAL_Y + randf_range(-8, 8),
			"vx": randf_range(-200, 200),
			"vy": randf_range(-280, -120),
			"life": randf_range(0.7, 1.2),
			"max_life": 1.2,
			"size": randf_range(2.0, 4.5)
		})

func _set_state(s: int) -> void:
	_state = s
	_state_t = 0.0

func _draw() -> void:
	_draw_tower_bg()
	_draw_torches()
	_draw_pedestal()
	_draw_debris()

func _draw_tower_bg() -> void:
	var act_top: float = LB
	var act_bot: float = VH - LB
	draw_rect(Rect2(0, act_top, VW, act_bot - act_top), Color(0.030, 0.018, 0.055))
	var bw: float = 36.0
	var bh: float = 15.0
	var bc: Color = Color(0.125, 0.095, 0.170)
	for row in range(int((act_bot - act_top) / bh) + 2):
		var y: float = act_top + row * bh
		var off: float = bw * 0.5 if row % 2 == 0 else 0.0
		for col in range(-1, 6):
			var x: float = col * bw + off
			if x + bw < VW * 0.26:
				draw_rect(Rect2(x + 1, y + 1, bw - 2, bh - 2), bc)
		for col in range(int(VW * 0.74 / bw), int(VW / bw) + 2):
			var x: float = col * bw + off
			draw_rect(Rect2(x + 1, y + 1, bw - 2, bh - 2), bc)
	draw_rect(Rect2(VW * 0.24, act_top, VW * 0.52, act_bot - act_top), Color(0.018, 0.010, 0.038))
	var cx: float = VW * 0.50
	var arch_base_y: float = act_top + 28.0
	for i in 7:
		var f: float = float(i) / 6.0
		var aw: float = VW * 0.26 * (1.0 - f * 0.12)
		var ay: float = arch_base_y + f * 22.0
		var ac: Color = Color(0.14, 0.10, 0.21, 1.0 - f * 0.82)
		draw_arc(Vector2(cx, ay), aw, PI, TAU, 36, ac, 2.5)
	var floor_y: float = act_bot - 28.0
	draw_rect(Rect2(0, floor_y, VW, act_bot - floor_y), Color(0.068, 0.050, 0.098))
	for r in 5:
		draw_line(Vector2(0, floor_y + r * 6.0), Vector2(VW, floor_y + r * 6.0),
				Color(0.10, 0.075, 0.148, 0.55), 1.0)

func _draw_pedestal() -> void:
	var cx: float = VW * 0.50
	var base_y: float = PEDESTAL_Y
	if _pedestal_smashed:
		draw_rect(Rect2(cx - 16, base_y + 16, 32, 8), Color(0.140, 0.105, 0.190))
		draw_line(Vector2(cx - 8, base_y + 18), Vector2(cx + 6, base_y + 22), Color(0, 0, 0, 0.8), 1.0)
		draw_line(Vector2(cx + 4, base_y + 16), Vector2(cx - 4, base_y + 20), Color(0, 0, 0, 0.8), 1.0)
		draw_line(Vector2(cx - 10, base_y + 20), Vector2(cx + 8, base_y + 16), Color(0, 0, 0, 0.6), 1.0)
	else:
		draw_rect(Rect2(cx - 16, base_y + 16, 32, 8), Color(0.210, 0.168, 0.280))
		draw_rect(Rect2(cx - 12, base_y + 4, 24, 14), Color(0.175, 0.135, 0.235))
		draw_rect(Rect2(cx - 8, base_y, 16, 6), Color(0.155, 0.118, 0.210))
		draw_rect(Rect2(cx - 16, base_y + 16, 32, 2), Color(0.28, 0.24, 0.35, 0.75))

func _draw_torches() -> void:
	var act_top: float = LB
	var positions: Array = [Vector2(VW * 0.135, act_top + 70.0), Vector2(VW * 0.865, act_top + 70.0)]
	for i in 2:
		var tp: Vector2 = positions[i]
		var fl: float = 0.68 + 0.32 * sin(_torch_t * 7.1 + i * 2.3) * sin(_torch_t * 4.5 + i * 1.1)
		draw_rect(Rect2(tp.x - 3, tp.y, 6, 13), Color(0.22, 0.18, 0.28))
		draw_rect(Rect2(tp.x - 6, tp.y + 10, 12, 4), Color(0.22, 0.18, 0.28))
		draw_rect(Rect2(tp.x - 3, tp.y - 6, 6, 8), Color(0.94, 0.48, 0.08, fl))
		draw_rect(Rect2(tp.x - 2, tp.y - 11, 4, 7), Color(1.00, 0.78, 0.18, fl * 0.88))
		draw_rect(Rect2(tp.x - 1, tp.y - 15, 2, 5), Color(1.00, 0.96, 0.62, fl * 0.70))

func _draw_debris() -> void:
	for d in _debris:
		var alpha: float = clampf(d.life / d.max_life, 0.0, 1.0)
		draw_rect(Rect2(d.x, d.y, d.size, d.size), Color(0.40, 0.30, 0.45, alpha))
