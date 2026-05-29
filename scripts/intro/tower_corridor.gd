extends Node2D

signal finished

const VW := 640.0
const VH := 360.0
const LB := 38.0
const FLOOR_Y := 286.0
const CORRIDOR_END_X := 1020.0
const WINDOW_X := 1100.0
const WALK_SPEED := 115.0
const STAGE_WIDTH := 1240.0

var _soph: Sprite2D
var _hair: Sprite2D
var _camera: Camera2D
var _prompt_lbl: Label
var _hint_lbl: Label
var _torch_t: float = 0.0
var _step_t: float = 0.0
var _walk_t: float = 0.0
var _done: bool = false
var _prompt_visible: bool = false
var _hint_shown: bool = false
var _hint_t: float = 0.0

func _ready() -> void:
	_build()
	MusicManager.play("tower")

func _build() -> void:
	_soph = _mk_sprite("player_body", Vector2(120.0, FLOOR_Y), Vector2(2.6, 2.6))
	_hair = _mk_sprite("player_hair", Vector2(120.0, FLOOR_Y), Vector2(2.6, 2.6))

	_camera = Camera2D.new()
	_camera.position = Vector2(VW * 0.5, VH * 0.5)
	_camera.limit_left = 0
	_camera.limit_right = int(STAGE_WIDTH)
	_camera.limit_top = 0
	_camera.limit_bottom = int(VH)
	add_child(_camera)
	_camera.make_current()

	var cl_lb := CanvasLayer.new(); cl_lb.layer = 20; add_child(cl_lb)
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color(0, 0, 0)
		bar.size = Vector2(VW, LB)
		bar.position = Vector2(0, 0 if top else VH - LB)
		cl_lb.add_child(bar)

	var cl_ui := CanvasLayer.new(); cl_ui.layer = 12; add_child(cl_ui)
	_hint_lbl = _mk_label("← →  ou  A D  para andar", 13, Color(0.78, 0.74, 0.92, 0.85))
	_hint_lbl.size = Vector2(VW, 22.0)
	_hint_lbl.position = Vector2(0.0, VH - LB - 24.0)
	_hint_lbl.modulate.a = 0.0
	cl_ui.add_child(_hint_lbl)

	_prompt_lbl = _mk_label("PRESSIONE  Q  —  QUEBRAR JANELA", 18, Color(0.92, 0.88, 0.78))
	_prompt_lbl.size = Vector2(VW, 30.0)
	_prompt_lbl.position = Vector2(0.0, VH * 0.20)
	_prompt_lbl.modulate.a = 0.0
	cl_ui.add_child(_prompt_lbl)

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
	return lbl

func _process(delta: float) -> void:
	if _done:
		return
	_torch_t += delta
	_hint_t += delta

	if not _hint_shown and _hint_t >= 0.8:
		_hint_shown = true
		var tw := _hint_lbl.create_tween()
		tw.tween_property(_hint_lbl, "modulate:a", 1.0, 0.6)
		tw.tween_interval(3.5)
		tw.tween_property(_hint_lbl, "modulate:a", 0.0, 0.6)

	var inp: float = 0.0
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		inp = 1.0
	elif Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		inp = -1.0

	if inp != 0.0:
		var new_x: float = _soph.position.x + inp * WALK_SPEED * delta
		new_x = clampf(new_x, 90.0, WINDOW_X - 30.0)
		_soph.position.x = new_x
		_hair.position.x = new_x
		_soph.flip_h = inp < 0.0
		_hair.flip_h = inp < 0.0
		_walk_t += delta * 9.0
		var bob: float = sin(_walk_t) * 1.8
		_soph.position.y = FLOOR_Y + bob
		_hair.position.y = FLOOR_Y + bob - 1.0
		_step_t += delta
		if _step_t > 0.34:
			_step_t = 0.0
			AudioManager.play("step", 0.92 + randf_range(-0.06, 0.06))
	else:
		_soph.position.y = FLOOR_Y
		_hair.position.y = FLOOR_Y - 1.0
		_step_t = 0.28

	var target_x: float = clampf(_soph.position.x, VW * 0.5, STAGE_WIDTH - VW * 0.5)
	_camera.position.x = lerpf(_camera.position.x, target_x, delta * 4.5)

	var near_window: bool = _soph.position.x >= CORRIDOR_END_X
	if near_window != _prompt_visible:
		_prompt_visible = near_window
		var tw := _prompt_lbl.create_tween()
		tw.tween_property(_prompt_lbl, "modulate:a", 1.0 if near_window else 0.0, 0.30)

	if near_window and Input.is_action_just_pressed("attack_sword"):
		_done = true
		AudioManager.play("hit", 1.2)
		AudioManager.play("shield_break", 0.95)
		finished.emit()

	queue_redraw()

func _draw() -> void:
	_draw_corridor()
	_draw_window()
	_draw_torches()

func _draw_corridor() -> void:
	var act_top: float = LB
	var act_bot: float = VH - LB
	var stage_w: float = STAGE_WIDTH

	draw_rect(Rect2(0, act_top, stage_w, act_bot - act_top), Color(0.030, 0.018, 0.055))
	draw_rect(Rect2(0, act_top + 8.0, stage_w, 26.0), Color(0.018, 0.010, 0.038))

	var bw: float = 36.0
	var bh: float = 15.0
	var bc: Color = Color(0.125, 0.095, 0.170)
	for row in range(int((act_top + 76.0 - (act_top + 34.0)) / bh) + 3):
		var y: float = act_top + 34.0 + row * bh
		var off: float = bw * 0.5 if row % 2 == 0 else 0.0
		for col in range(-1, int(stage_w / bw) + 2):
			var x: float = col * bw + off
			draw_rect(Rect2(x + 1, y + 1, bw - 2, bh - 2), bc)

	draw_rect(Rect2(0, act_top + 76.0, stage_w, 8.0), Color(0.090, 0.066, 0.140))

	var floor_y: float = act_bot - 28.0
	draw_rect(Rect2(0, floor_y, stage_w, act_bot - floor_y), Color(0.068, 0.050, 0.098))
	var fbw: float = 48.0
	for col in range(-1, int(stage_w / fbw) + 2):
		var x: float = col * fbw
		draw_line(Vector2(x, floor_y), Vector2(x, act_bot), Color(0.10, 0.075, 0.148, 0.55), 1.0)
	for r in 4:
		var ly: float = floor_y + (r + 1) * 7.0
		draw_line(Vector2(0, ly), Vector2(stage_w, ly), Color(0.10, 0.075, 0.148, 0.55), 1.0)

	# Wall trim at floor level
	draw_rect(Rect2(0, floor_y - 4.0, stage_w, 4.0), Color(0.040, 0.030, 0.068))

func _draw_window() -> void:
	var act_top: float = LB
	var wx: float = WINDOW_X
	var wy: float = act_top + 60.0
	var ww: float = 60.0
	var wh: float = 140.0
	draw_rect(Rect2(wx - 4, wy - 4, ww + 8, wh + 8), Color(0.180, 0.140, 0.260))
	draw_rect(Rect2(wx, wy, ww, wh), Color(0.10, 0.14, 0.30))
	draw_rect(Rect2(wx, wy, ww, wh * 0.4), Color(0.08, 0.10, 0.25))
	for i in 8:
		var sx: float = wx + 4.0 + (i * 7.0) + sin(_torch_t + i) * 1.5
		var sy: float = wy + 8.0 + fposmod(i * 11.0, wh - 20.0)
		var alpha: float = 0.45 + 0.35 * sin(_torch_t * 2.0 + i)
		draw_circle(Vector2(sx, sy), 1.0, Color(1, 1, 1, alpha))
	draw_line(Vector2(wx + ww * 0.5, wy), Vector2(wx + ww * 0.5, wy + wh), Color(0.22, 0.18, 0.30), 3.0)
	draw_line(Vector2(wx, wy + wh * 0.5), Vector2(wx + ww, wy + wh * 0.5), Color(0.22, 0.18, 0.30), 3.0)

	if _prompt_visible:
		var glow: float = 0.5 + 0.5 * sin(_torch_t * 4.0)
		draw_arc(Vector2(wx + ww * 0.5, wy + wh * 0.5), 80.0, 0.0, TAU, 28,
				Color(0.45, 0.78, 1.0, 0.06 + glow * 0.06), 32.0)

func _draw_torches() -> void:
	var act_top: float = LB
	var torch_positions: Array = [180.0, 460.0, 760.0]
	for tx in torch_positions:
		var tp: Vector2 = Vector2(tx, act_top + 70.0)
		var fl: float = 0.68 + 0.32 * sin(_torch_t * 7.1 + tx * 0.01) * sin(_torch_t * 4.5 + tx * 0.02)
		draw_rect(Rect2(tp.x - 3, tp.y, 6, 13), Color(0.22, 0.18, 0.28))
		draw_rect(Rect2(tp.x - 6, tp.y + 10, 12, 4), Color(0.22, 0.18, 0.28))
		draw_rect(Rect2(tp.x - 3, tp.y - 6, 6, 8), Color(0.94, 0.48, 0.08, fl))
		draw_rect(Rect2(tp.x - 2, tp.y - 11, 4, 7), Color(1.00, 0.78, 0.18, fl * 0.88))
		draw_rect(Rect2(tp.x - 1, tp.y - 15, 2, 5), Color(1.00, 0.96, 0.62, fl * 0.70))
		var hr: float = 56.0 + fl * 20.0
		draw_arc(tp, hr, 0.0, TAU, 24, Color(0.95, 0.52, 0.12, 0.034 * fl), hr * 0.38)
