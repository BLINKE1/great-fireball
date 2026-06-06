extends Node2D
## Abertura anime do Cap. 1 (vibe BoF IV). Dirigida por código sobre placeholders
## (trocáveis pela arte autoral depois). Beats: céu/torre/lua -> revelação da Soph
## (light rays) -> a Grande Bola de Fogo carrega -> IMPACT (flash + speed lines)
## -> title card. Emite `finished` no fim (ou no skip).
##
## Toolkit de efeitos anime reutilizável: light rays, speed lines, impact flash,
## vignette, letterbox, embers, câmera pan/zoom.

signal finished

const T_END := 11.0
const VW := 640.0
const VH := 360.0

var t := 0.0
var _done := false
var world: Node2D
var cam: Camera2D
var sky: TextureRect
var soph_body: Sprite2D
var soph_hair: Sprite2D
var rays: Sprite2D
var fireball: Sprite2D
var fb_core: Sprite2D
var speed: Sprite2D
var flash: ColorRect
var end_fade: ColorRect
var vignette: TextureRect
var lb_top: ColorRect
var lb_bot: ColorRect
var title: Label
var subtitle: Label
var skip_lbl: Label
var _ex := PackedFloat32Array()
var _ey := PackedFloat32Array()
var _evy := PackedFloat32Array()
var _eph := PackedFloat32Array()
var embers

# ── easing ────────────────────────────────────────────────────────────────────
func _es(x: float) -> float:
	x = clampf(x, 0.0, 1.0); return x * x * (3.0 - 2.0 * x)

func _band(a: float, b: float) -> float:
	if t <= a: return 0.0
	if t >= b: return 1.0
	return _es((t - a) / (b - a))

func _pulse(a: float, b: float) -> float:
	if t < a or t > b: return 0.0
	return sin(((t - a) / (b - a)) * PI)

# ── geradores de textura ──────────────────────────────────────────────────────
func _radial(r: int, col: Color, soft := 0.9) -> ImageTexture:
	var img := Image.create(r * 2, r * 2, false, Image.FORMAT_RGBA8)
	for y in r * 2:
		for x in r * 2:
			var d := Vector2(x - r, y - r).length() / float(r)
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(col.r, col.g, col.b, a * a * soft))
	return ImageTexture.create_from_image(img)

func _ray_tex(sz: int, n: int, col: Color) -> ImageTexture:
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var c := sz / 2.0
	for y in sz:
		for x in sz:
			var dx := x - c; var dy := y - c
			var d := sqrt(dx * dx + dy * dy) / c
			if d > 1.0: continue
			var w := 0.5 + 0.5 * sin(atan2(dy, dx) * n)
			img.set_pixel(x, y, Color(col.r, col.g, col.b, pow(maxf(w, 0.0), 3.0) * (1.0 - d) * col.a))
	return ImageTexture.create_from_image(img)

func _speed_tex(sz: int, n: int, col: Color) -> ImageTexture:
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var c := sz / 2.0
	for y in sz:
		for x in sz:
			var dx := x - c; var dy := y - c
			var d := sqrt(dx * dx + dy * dy) / c
			if d < 0.32 or d > 1.0: continue
			if (0.5 + 0.5 * sin(atan2(dy, dx) * n)) < 0.82: continue
			img.set_pixel(x, y, Color(col.r, col.g, col.b, (d - 0.32) * col.a))
	return ImageTexture.create_from_image(img)

func _vignette_tex() -> ImageTexture:
	var img := Image.create(64, 36, false, Image.FORMAT_RGBA8)
	for y in 36:
		for x in 64:
			var dx := (x / 64.0 - 0.5) * 2.0; var dy := (y / 36.0 - 0.5) * 2.0
			img.set_pixel(x, y, Color(0, 0, 0, clampf((sqrt(dx * dx + dy * dy) - 0.62) / 0.7, 0.0, 1.0) * 0.92))
	return ImageTexture.create_from_image(img)

func _spr(tex: Texture2D, pos: Vector2, parent: Node, z := 0) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex; s.position = pos; s.z_index = z
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(s); return s

func _layer(lz: int) -> CanvasLayer:
	var cl := CanvasLayer.new(); cl.layer = lz; add_child(cl); return cl

func _ready() -> void:
	# Céu (gradiente)
	var skcl := _layer(-100)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.45, 0.72, 1.0])
	grad.colors = PackedColorArray([
		Color(0.03, 0.04, 0.10), Color(0.10, 0.07, 0.18),
		Color(0.30, 0.13, 0.18), Color(0.08, 0.06, 0.12)])
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad; gtex.fill_from = Vector2(0, 0); gtex.fill_to = Vector2(0, 1)
	gtex.width = 32; gtex.height = 128
	sky = TextureRect.new(); sky.texture = gtex; sky.stretch_mode = TextureRect.STRETCH_SCALE
	sky.size = Vector2(VW, VH); sky.modulate.a = 0.0
	skcl.add_child(sky)

	world = Node2D.new(); add_child(world)
	cam = Camera2D.new(); cam.position = Vector2(VW * 0.5, VH * 0.5); add_child(cam); cam.make_current()

	for i in 60:
		var st := _spr(_radial(1, Color(0.9, 0.92, 1.0)), Vector2(randf() * VW, randf() * VH * 0.5), world, -40)
		st.modulate.a = randf_range(0.3, 0.8)
	_spr(_radial(34, Color(0.85, 0.88, 0.95), 0.7), Vector2(VW * 0.74, 78), world, -38)
	_spr(_radial(13, Color(0.95, 0.96, 0.9)), Vector2(VW * 0.74, 78), world, -37)

	var tower := Node2D.new(); world.add_child(tower); tower.z_index = -20
	var tw_body := ColorRect.new()
	tw_body.color = Color(0.07, 0.06, 0.10); tw_body.size = Vector2(110, 460); tw_body.position = Vector2(VW * 0.5 - 55, 150)
	tower.add_child(tw_body)
	for mx in range(0, 110, 20):
		var m := ColorRect.new(); m.color = Color(0.10, 0.08, 0.13); m.size = Vector2(12, 15); m.position = Vector2(VW * 0.5 - 55 + mx, 140)
		tower.add_child(m)
	for wy in [190, 230, 270, 310]:
		_spr(_radial(6, Color(1.0, 0.7, 0.3)), Vector2(VW * 0.5, wy), tower, -19).modulate.a = 0.7

	rays = _spr(_ray_tex(320, 16, Color(1.0, 0.85, 0.5, 0.55)), Vector2(VW * 0.5, VH * 0.46), world, -10)
	rays.modulate.a = 0.0

	var sc := 2.4
	soph_body = _spr(SpriteSetup.get_texture("player_body"), Vector2(VW * 0.5, VH * 0.64), world, 0)
	soph_hair = _spr(SpriteSetup.get_texture("player_hair"), Vector2(VW * 0.5, VH * 0.64 - 30 * sc), world, 1)
	soph_body.scale = Vector2(sc, sc); soph_hair.scale = Vector2(sc, sc)
	soph_body.modulate = Color(0.1, 0.1, 0.15, 0.0); soph_hair.modulate = Color(0.1, 0.1, 0.15, 0.0)

	fireball = _spr(_radial(130, Color(1.0, 0.55, 0.15), 0.85), Vector2(VW * 0.5, VH * 0.42), world, 5)
	fireball.modulate.a = 0.0
	fb_core = _spr(_radial(46, Color(1.0, 0.92, 0.6)), Vector2(VW * 0.5, VH * 0.42), world, 6)
	fb_core.modulate.a = 0.0

	embers = _EmberScript.new(); embers.host = self; embers.z_index = 8; world.add_child(embers)
	for i in 60:
		_ex.append(randf() * VW); _ey.append(randf() * VH)
		_evy.append(randf_range(-26, -8)); _eph.append(randf() * TAU)

	var fxcl := _layer(40)
	speed = Sprite2D.new(); speed.texture = _speed_tex(480, 120, Color(1, 1, 1, 0.9))
	speed.position = Vector2(VW * 0.5, VH * 0.5); speed.modulate.a = 0.0
	speed.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fxcl.add_child(speed)

	var vcl := _layer(30)
	vignette = TextureRect.new(); vignette.texture = _vignette_tex(); vignette.size = Vector2(VW, VH); vignette.modulate.a = 0.0
	vcl.add_child(vignette)

	var flcl := _layer(50)
	flash = ColorRect.new(); flash.color = Color(1, 1, 1, 0.0); flash.size = Vector2(VW, VH); flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flcl.add_child(flash)
	end_fade = ColorRect.new(); end_fade.color = Color(0, 0, 0, 0.0); end_fade.size = Vector2(VW, VH); end_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flcl.add_child(end_fade)

	var lbcl := _layer(45)
	lb_top = ColorRect.new(); lb_top.color = Color(0, 0, 0); lb_top.size = Vector2(VW, 46); lb_top.position = Vector2(0, -46)
	lb_bot = ColorRect.new(); lb_bot.color = Color(0, 0, 0); lb_bot.size = Vector2(VW, 46); lb_bot.position = Vector2(0, VH)
	lbcl.add_child(lb_top); lbcl.add_child(lb_bot)

	var tcl := _layer(46)
	title = Label.new(); title.text = "A GRANDE BOLA DE FOGO"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.7))
	title.add_theme_color_override("font_shadow_color", Color(0.6, 0.2, 0.05))
	title.add_theme_constant_override("shadow_offset_x", 2); title.add_theme_constant_override("shadow_offset_y", 2)
	title.size = Vector2(VW, 40); title.position = Vector2(0, VH * 0.40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.pivot_offset = Vector2(VW * 0.5, 20); title.modulate.a = 0.0
	subtitle = Label.new(); subtitle.text = "— a chama eterna aguarda —"
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(0.8, 0.82, 0.95))
	subtitle.size = Vector2(VW, 24); subtitle.position = Vector2(0, VH * 0.40 + 38)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; subtitle.modulate.a = 0.0
	tcl.add_child(title); tcl.add_child(subtitle)
	# dica de skip
	skip_lbl = Label.new(); skip_lbl.text = "[Espaço] pular"
	skip_lbl.add_theme_font_size_override("font_size", 11)
	skip_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85, 0.6))
	skip_lbl.size = Vector2(VW - 12, 20); skip_lbl.position = Vector2(0, VH - 64)
	skip_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tcl.add_child(skip_lbl)

	MusicManager.play("boss")   # trilha tensa/épica (placeholder até música própria)

class _EmberScript extends Node2D:
	var host
	func _draw():
		if host == null: return
		for i in host._ex.size():
			var a: float = 0.4 + 0.6 * (0.5 + 0.5 * sin(host.t * 3.0 + host._eph[i]))
			draw_circle(Vector2(host._ex[i], host._ey[i]), 1.5, Color(1.0, 0.6, 0.2, a * 0.55))

func _unhandled_input(event: InputEvent) -> void:
	if _done: return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		_finish()

func _finish() -> void:
	if _done: return
	_done = true
	finished.emit()

func _process(delta: float) -> void:
	if _done or cam == null:
		return
	t += delta

	for i in _ex.size():
		_ey[i] += _evy[i] * delta
		_ex[i] += sin(t * 1.2 + _eph[i]) * 6.0 * delta
		if _ey[i] < -6: _ey[i] = VH + 6; _ex[i] = randf() * VW
	if embers: embers.queue_redraw()

	sky.modulate.a = _band(0.2, 1.4)
	lb_top.position.y = lerpf(-46, 0, _band(0.0, 0.8))
	lb_bot.position.y = lerpf(VH, VH - 46, _band(0.0, 0.8))
	vignette.modulate.a = _band(0.3, 1.6) * 0.85

	var cam_y := lerpf(VH * 0.62, VH * 0.50, _band(1.4, 3.6))
	var cam_zoom := lerpf(1.10, 1.40, _band(3.4, 5.6))
	if t > 7.6:
		cam_zoom = lerpf(1.40, 1.02, _band(7.6, 9.2))
		cam_y = lerpf(VH * 0.50, VH * 0.55, _band(7.6, 9.2))
	cam.position = Vector2(VW * 0.5, cam_y)
	cam.zoom = Vector2(cam_zoom, cam_zoom)
	cam.offset = Vector2(randf_range(-6, 6), randf_range(-6, 6)) if (t >= 7.5 and t < 8.1) else Vector2.ZERO

	var rev := _band(3.4, 5.0)
	var col := Color(0.1, 0.1, 0.15).lerp(Color(1, 1, 1), rev)
	soph_body.modulate = Color(col.r, col.g, col.b, _band(3.2, 4.4))
	soph_hair.modulate = Color(col.r, col.g, col.b, _band(3.2, 4.4))
	soph_hair.skew = 0.04 * sin(t * 1.6)

	rays.modulate.a = _band(4.0, 5.6) * 0.5 + _pulse(6.0, 8.0) * 0.5
	rays.rotation = t * 0.15

	var charge := _band(5.6, 7.5)
	fireball.modulate.a = charge * 0.9
	fb_core.modulate.a = charge
	var fb_s := lerpf(0.3, 1.5, charge) + _pulse(7.4, 8.2) * 1.1
	fireball.scale = Vector2(fb_s, fb_s)
	fb_core.scale = Vector2(fb_s * 0.8, fb_s * 0.8)

	flash.color.a = _pulse(7.5, 8.0) * 0.95
	speed.modulate.a = _pulse(7.55, 8.4)
	speed.scale = Vector2(1, 1) * lerpf(0.6, 2.0, _band(7.55, 8.4))
	speed.rotation = t * 0.6

	title.modulate.a = _band(8.4, 9.4)
	subtitle.modulate.a = _band(9.0, 10.0)
	title.scale = Vector2(1, 1) * lerpf(1.1, 1.0, _band(8.4, 9.0))
	skip_lbl.modulate.a = clampf(1.0 - _band(8.0, 8.6), 0.0, 0.6)

	# cues de áudio (uma vez cada)
	if t >= 7.55 and not has_meta("snd_impact"):
		set_meta("snd_impact", true); AudioManager.play("fireball"); AudioManager.play("boss_appear", 0.7)
	if t >= 8.5 and not has_meta("snd_title"):
		set_meta("snd_title", true); AudioManager.play("victory", 0.9)

	# fade-out + fim
	end_fade.color.a = _band(T_END - 0.9, T_END)
	if t >= T_END:
		_finish()
