extends Node2D

signal finished

const VW := 640.0
const VH := 360.0
const LB := 38.0

enum Phase { ENTRY, DIALOGUE_1, DIALOGUE_2, HEAL_PROMPT, HEAL_ACTIVE, FADE_OUT }

const TYPEWRITER_SPD = 28.0

var _phase: Phase = Phase.ENTRY
var _t: float = 0.0
var _hp: float = 0.28
var _ambient_t: float = 0.0
var _heal_flash: float = 0.0
var _heal_pressed: bool = false

var _dial_full: String = ""
var _dial_chars: int = 0
var _dial_char_t: float = 0.0

var _soph: Sprite2D
var _hair: Sprite2D
var _hp_bar_fg: ColorRect
var _dial_lbl: Label
var _prompt_lbl: Label
var _overlay: ColorRect

func _ready() -> void:
	_build()

func _build() -> void:
	_soph = _mk_sprite("player_body", Vector2(VW * 0.50, VH - LB - 56.0), Vector2(2.8, 2.8))
	_soph.modulate = Color(1.0, 0.70, 0.70)
	_hair = _mk_sprite("player_hair", Vector2(VW * 0.50, VH - LB - 57.0), Vector2(2.8, 2.8))
	_hair.modulate = Color(1.0, 0.82, 0.82)

	var cl_lb := CanvasLayer.new(); cl_lb.layer = 20; add_child(cl_lb)
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color(0, 0, 0)
		bar.size = Vector2(VW, LB)
		bar.position = Vector2(0, 0 if top else VH - LB)
		cl_lb.add_child(bar)

	var cl_ui := CanvasLayer.new(); cl_ui.layer = 15; add_child(cl_ui)

	var hp_bg := ColorRect.new()
	hp_bg.color = Color(0.05, 0.02, 0.05, 0.85)
	hp_bg.size = Vector2(180.0, 14.0)
	hp_bg.position = Vector2(30.0, VH - LB - 26.0)
	cl_ui.add_child(hp_bg)

	_hp_bar_fg = ColorRect.new()
	_hp_bar_fg.color = Color(0.88, 0.18, 0.18)
	_hp_bar_fg.size = Vector2(180.0 * _hp, 14.0)
	_hp_bar_fg.position = Vector2(30.0, VH - LB - 26.0)
	cl_ui.add_child(_hp_bar_fg)

	var hp_lbl := Label.new()
	hp_lbl.text = "HP"
	hp_lbl.add_theme_font_size_override("font_size", 11)
	hp_lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.85))
	hp_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	hp_lbl.add_theme_constant_override("shadow_offset_x", 1)
	hp_lbl.add_theme_constant_override("shadow_offset_y", 1)
	hp_lbl.position = Vector2(30.0, VH - LB - 42.0)
	cl_ui.add_child(hp_lbl)

	_dial_lbl = Label.new()
	_dial_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dial_lbl.add_theme_font_size_override("font_size", 16)
	_dial_lbl.add_theme_color_override("font_color", Color(0.92, 0.88, 0.78))
	_dial_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	_dial_lbl.add_theme_constant_override("shadow_offset_x", 2)
	_dial_lbl.add_theme_constant_override("shadow_offset_y", 2)
	_dial_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dial_lbl.size = Vector2(540.0, 110.0)
	_dial_lbl.position = Vector2(50.0, 56.0)
	_dial_lbl.modulate.a = 0.0
	cl_ui.add_child(_dial_lbl)

	_prompt_lbl = Label.new()
	_prompt_lbl.text = "PRESSIONE  C  —  CURAR"
	_prompt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_lbl.add_theme_font_size_override("font_size", 22)
	_prompt_lbl.add_theme_color_override("font_color", Color(0.55, 1.0, 0.62))
	_prompt_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1.0))
	_prompt_lbl.add_theme_constant_override("shadow_offset_x", 3)
	_prompt_lbl.add_theme_constant_override("shadow_offset_y", 3)
	_prompt_lbl.size = Vector2(VW, 36.0)
	_prompt_lbl.position = Vector2(0.0, VH * 0.30)
	_prompt_lbl.pivot_offset = Vector2(VW * 0.5, 18.0)
	_prompt_lbl.modulate.a = 0.0
	cl_ui.add_child(_prompt_lbl)

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
	_t += delta
	_ambient_t += delta
	_heal_flash = maxf(_heal_flash - delta * 1.2, 0.0)

	if _hp < 0.45 and _phase != Phase.FADE_OUT:
		var pulse: float = 0.55 + 0.45 * sin(_t * 5.5)
		_hp_bar_fg.modulate.a = pulse

	match _phase:
		Phase.ENTRY:
			if _t >= 1.1:
				_start_dialogue("\"Tomei muito dano. Tenho que tomar mais cuidado...\"")
				_phase = Phase.DIALOGUE_1
				_t = 0.0
		Phase.DIALOGUE_1:
			_typewriter(delta)
			if _t >= 3.4:
				_start_dialogue("\"A distância do Air Hike não pode ser muito alta,\nou sofrerei os mesmos danos da queda completa.\"")
				_phase = Phase.DIALOGUE_2
				_t = 0.0
		Phase.DIALOGUE_2:
			_typewriter(delta)
			if _t >= 4.6:
				_start_dialogue("\"Preciso me curar.\"")
				_phase = Phase.HEAL_PROMPT
				_t = 0.0
		Phase.HEAL_PROMPT:
			_typewriter(delta)
			if _dial_chars >= _dial_full.length() and _prompt_lbl.modulate.a < 1.0:
				_prompt_lbl.modulate.a = minf(_prompt_lbl.modulate.a + delta * 3.0, 1.0)
			var pulse: float = 1.0 + 0.08 * sin(_t * TAU * 3.0)
			_prompt_lbl.scale = Vector2(pulse, pulse)
			if Input.is_action_just_pressed("spell_heal") and not _heal_pressed:
				_heal_pressed = true
				_start_heal()
				_phase = Phase.HEAL_ACTIVE
				_t = 0.0
		Phase.HEAL_ACTIVE:
			_hp = lerpf(_hp, 1.0, delta * 2.2)
			_hp_bar_fg.size.x = 180.0 * _hp
			_hp_bar_fg.color = Color(0.88, 0.18, 0.18).lerp(Color(0.20, 0.88, 0.34), clampf((_hp - 0.28) / 0.72, 0.0, 1.0))
			_hp_bar_fg.modulate.a = 1.0
			var rest: float = clampf(_t / 1.2, 0.0, 1.0)
			_soph.modulate = Color(1.0, 0.70, 0.70).lerp(Color(1, 1, 1), rest)
			_hair.modulate = Color(1.0, 0.82, 0.82).lerp(Color(1, 1, 1), rest)
			if _t >= 2.4:
				_phase = Phase.FADE_OUT
				_t = 0.0
				_dial_lbl.create_tween().tween_property(_dial_lbl, "modulate:a", 0.0, 0.6)
				_prompt_lbl.create_tween().tween_property(_prompt_lbl, "modulate:a", 0.0, 0.6)
		Phase.FADE_OUT:
			_overlay.color.a = minf(_t / 1.2, 1.0)
			if _t >= 1.2:
				finished.emit()
				set_process(false)

	queue_redraw()

func _typewriter(delta: float) -> void:
	_dial_char_t += delta * TYPEWRITER_SPD
	var nc: int = mini(int(_dial_char_t), _dial_full.length())
	if nc != _dial_chars:
		_dial_chars = nc
		_dial_lbl.text = _dial_full.substr(0, _dial_chars)

func _start_dialogue(txt: String) -> void:
	_dial_full = txt
	_dial_chars = 0
	_dial_char_t = 0.0
	_dial_lbl.text = ""
	if _dial_lbl.modulate.a < 1.0:
		_dial_lbl.create_tween().tween_property(_dial_lbl, "modulate:a", 1.0, 0.4)

func _start_heal() -> void:
	AudioManager.play("heal")
	_heal_flash = 1.0

func _draw() -> void:
	_draw_outdoor_bg()
	if _heal_flash > 0.01:
		_draw_heal_aura()

func _draw_outdoor_bg() -> void:
	var act_top: float = LB
	var act_bot: float = VH - LB
	var sky_top: Color = Color(0.085, 0.055, 0.155)
	var sky_bot: Color = Color(0.180, 0.110, 0.180)
	var slices: int = 14
	var ground_y: float = act_bot - 60.0
	for i in slices:
		var t: float = float(i) / float(slices - 1)
		var y: float = act_top + t * (ground_y - act_top)
		var c: Color = sky_top.lerp(sky_bot, t)
		draw_rect(Rect2(0, y, VW, ceil((ground_y - act_top) / float(slices)) + 1.0), c)

	# Moon
	draw_circle(Vector2(VW * 0.78, act_top + 38.0), 12.0, Color(0.96, 0.92, 0.80, 0.78))
	draw_arc(Vector2(VW * 0.78, act_top + 38.0), 24.0, 0.0, TAU, 28, Color(1.0, 0.94, 0.78, 0.10), 12.0)

	# Stars
	for i in 24:
		var sx: float = fposmod(i * 41.0 + sin(i * 0.4) * 9.0, VW)
		var sy: float = act_top + fposmod(i * 13.0, (ground_y - act_top) * 0.5)
		var alpha: float = 0.30 + 0.30 * sin(_ambient_t * 2.0 + i)
		draw_circle(Vector2(sx, sy), 1.0, Color(1, 1, 1, alpha))

	# Tower on the left (where she fell from)
	var tower_x: float = VW * 0.02
	var tower_w: float = 50.0
	var tower_h: float = ground_y - act_top - 20.0
	draw_rect(Rect2(tower_x, act_top + 20.0, tower_w, tower_h), Color(0.055, 0.038, 0.080))
	# Brick texture
	var bw: float = 12.0
	var bh: float = 8.0
	for row in range(int(tower_h / bh) + 1):
		var y: float = act_top + 20.0 + row * bh
		var off: float = bw * 0.5 if row % 2 == 0 else 0.0
		for col in range(int(tower_w / bw) + 2):
			var x: float = tower_x + col * bw + off
			if x + bw - 1 < tower_x + tower_w:
				draw_rect(Rect2(x + 1, y + 1, bw - 2, bh - 2), Color(0.085, 0.060, 0.115))
	# Tower roof (gothic cone)
	draw_polygon([
		Vector2(tower_x - 6, act_top + 20.0),
		Vector2(tower_x + tower_w * 0.5, act_top - 30.0),
		Vector2(tower_x + tower_w + 6, act_top + 20.0)
	], [Color(0.040, 0.025, 0.058)])
	# Broken window where Soph fell from
	var win_y: float = act_top + 40.0
	draw_rect(Rect2(tower_x + tower_w * 0.5 - 6, win_y, 12, 18), Color(0.10, 0.04, 0.06))
	# Glass cracks (jagged)
	draw_line(Vector2(tower_x + tower_w * 0.5 - 5, win_y + 3), Vector2(tower_x + tower_w * 0.5 + 6, win_y + 16),
			Color(0.05, 0.02, 0.03), 1.0)

	# Ground
	draw_rect(Rect2(0, ground_y, VW, act_bot - ground_y), Color(0.060, 0.045, 0.040))
	for i in 70:
		var gx: float = fposmod(i * 27.0 + sin(i) * 7.0, VW)
		var gy: float = ground_y + 4.0 + fposmod(i * 11.0, 52.0)
		draw_rect(Rect2(gx, gy, 2, 2), Color(0.130, 0.090, 0.070, 0.55))

	# Impact crater under Soph
	var crater_x: float = _soph.position.x
	draw_arc(Vector2(crater_x, ground_y + 4), 36.0, 0.0, PI, 24, Color(0.025, 0.018, 0.020), 8.0)
	draw_arc(Vector2(crater_x, ground_y + 4), 22.0, 0.0, PI, 18, Color(0.040, 0.025, 0.025), 6.0)

	# Distant tree silhouettes
	for i in 5:
		var tx: float = VW * 0.18 + i * 95.0
		var th: float = 24.0 + float((i * 13) % 14)
		draw_polygon([
			Vector2(tx, ground_y),
			Vector2(tx + 14, ground_y - th),
			Vector2(tx + 28, ground_y)
		], [Color(0.020, 0.012, 0.028)])

func _draw_heal_aura() -> void:
	var pos: Vector2 = _soph.position
	var f: float = _heal_flash
	draw_arc(pos, 56.0 * (1.0 - f * 0.4), 0.0, TAU, 28, Color(0.55, 1.0, 0.62, f * 0.7), 4.0)
	draw_arc(pos, 78.0 * (1.0 - f * 0.4), 0.0, TAU, 28, Color(0.85, 1.0, 0.78, f * 0.40), 6.0)
	for i in 6:
		var ang: float = i * TAU / 6.0 + _ambient_t * 1.5
		var r: float = 32.0 + sin(_ambient_t * 3.0 + i) * 8.0
		draw_circle(pos + Vector2(cos(ang), sin(ang)) * r, 2.5, Color(0.78, 1.0, 0.85, f))
