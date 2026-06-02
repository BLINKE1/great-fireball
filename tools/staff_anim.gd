extends SceneTree
## Protótipo: o cajado levita pra mão VAZIA da Soph (snap reverse-edit) + flourish
## (giros + toss-and-catch, estilo DMC). Soph desenhada SEM cajado aqui (a arte
## autoral do jogo já segura um). Captura frames -> GIF.
##   xvfb-run -a godot --rendering-driver opengl3 -s tools/staff_anim.gd

const DT := 1.0 / 30.0
const T_END := 3.7
const SCALE := 3.2

var t := 0.0
var frame := 0
var world: Node2D
var staff: Sprite2D
var glow: Sprite2D
var flash: ColorRect
var cam: Camera2D
var ghosts: Array = []
var _hist: Array = []
var _shake := 0.0

var SOPH := Vector2(430, 430)
var HAND: Vector2
var HOLD: Vector2
var GROUND: Vector2
var PRE: Vector2

# ── helpers de desenho (replicam o SpriteSetup, mas SEM cajado) ───────────────
func _fr(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for dy in range(h):
		for dx in range(w):
			var px := x + dx; var py := y + dy
			if px >= 0 and py >= 0 and px < img.get_width() and py < img.get_height():
				img.set_pixel(px, py, c)

func _fc(img: Image, cx: int, cy: int, r: int, c: Color) -> void:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx * dx + dy * dy <= r * r:
				var px := cx + dx; var py := cy + dy
				if px >= 0 and py >= 0 and px < img.get_width() and py < img.get_height():
					img.set_pixel(px, py, c)

func _glow_soft(img: Image, cx: int, cy: int, r: int, c: Color, s: float) -> void:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var dist := sqrt(float(dx * dx + dy * dy))
			if dist <= float(r):
				var px := cx + dx; var py := cy + dy
				if px >= 0 and py >= 0 and px < img.get_width() and py < img.get_height():
					var tt := (1.0 - dist / float(r)) * s
					img.set_pixel(px, py, img.get_pixel(px, py).lerp(c, clampf(tt, 0.0, 1.0)))

func _soph_body() -> ImageTexture:
	var SK := Color(0.93, 0.78, 0.64); var Sd := Color(0.73, 0.58, 0.44)
	var PU := Color(0.55, 0.22, 0.80);  var DP := Color(0.32, 0.10, 0.55)
	var GO := Color(0.95, 0.75, 0.10);  var DGO := Color(0.72, 0.55, 0.05)
	var BK := Color(0.08, 0.08, 0.08)
	var img := Image.create(32, 64, false, Image.FORMAT_RGBA8)
	_fc(img, 16, 12, 9, SK)
	_fr(img, 11, 10, 3, 3, BK); _fr(img, 19, 10, 3, 3, BK)
	img.set_pixel(12, 11, SK); img.set_pixel(20, 11, SK)
	_fr(img, 13, 16, 6, 1, Sd); _fr(img, 14, 21, 4, 4, SK)
	_fr(img, 3, 22, 5, 22, DP); _fr(img, 24, 22, 5, 22, DP)
	_fc(img, 5, 45, 3, SK); _fc(img, 27, 45, 3, SK)
	_fr(img, 7, 25, 18, 3, PU); _fr(img, 8, 28, 16, 24, PU)
	_fr(img, 7, 31, 18, 4, GO); _fr(img, 8, 31, 1, 4, DGO); _fr(img, 24, 31, 1, 4, DGO)
	_fr(img, 15, 31, 2, 4, Color(1.0, 0.92, 0.30))
	_fr(img, 8, 35, 2, 15, DP); _fr(img, 22, 35, 2, 15, DP)
	_fr(img, 6, 50, 20, 3, DP); _fr(img, 4, 53, 24, 2, DP)
	_fr(img, 10, 54, 5, 8, DP); _fr(img, 17, 54, 5, 8, DP)
	_fr(img, 8, 60, 7, 4, BK); _fr(img, 17, 60, 7, 4, BK)
	return ImageTexture.create_from_image(img)

func _soph_hair() -> ImageTexture:
	var H := Color(0.22, 0.58, 1.0); var HL := Color(0.55, 0.82, 1.0); var DK := Color(0.10, 0.32, 0.80)
	var img := Image.create(32, 20, false, Image.FORMAT_RGBA8)
	_fr(img, 8, 0, 16, 2, H); _fr(img, 5, 2, 22, 3, H); _fr(img, 2, 5, 28, 3, H)
	_fr(img, 0, 8, 32, 5, H); _fr(img, 0, 13, 11, 7, H); _fr(img, 21, 13, 11, 7, H)
	_fr(img, 10, 0, 8, 1, HL); _fr(img, 8, 1, 6, 1, HL)
	_fr(img, 0, 16, 6, 4, DK); _fr(img, 26, 16, 6, 4, DK)
	return ImageTexture.create_from_image(img)

func _staff_tex() -> ImageTexture:
	var WD := Color(0.45, 0.30, 0.16); var WDD := Color(0.30, 0.19, 0.09); var WDL := Color(0.60, 0.42, 0.22)
	var GLD := Color(0.85, 0.70, 0.18); var MET := Color(0.62, 0.64, 0.70)
	var ORC := Color(0.92, 0.97, 1.0); var ORG := Color(0.30, 0.70, 1.0); var ORP := Color(0.55, 0.35, 0.95)
	var img := Image.create(16, 64, false, Image.FORMAT_RGBA8)
	_fr(img, 7, 16, 4, 42, WD); _fr(img, 7, 16, 1, 42, WDD); _fr(img, 10, 16, 1, 42, WDL)
	for wy in [24, 34, 44]: _fr(img, 6, wy, 6, 2, GLD)
	_fr(img, 6, 58, 6, 5, MET)
	_fr(img, 5, 12, 2, 6, MET); _fr(img, 11, 12, 2, 6, MET)
	_glow_soft(img, 8, 8, 8, ORP, 0.55); _fc(img, 8, 8, 6, ORG); _fc(img, 8, 8, 3, ORC)
	img.set_pixel(7, 6, Color(1, 1, 1, 1))
	return ImageTexture.create_from_image(img)

func _radial(r: int, col: Color) -> ImageTexture:
	var img := Image.create(r * 2, r * 2, false, Image.FORMAT_RGBA8)
	for y in r * 2:
		for x in r * 2:
			var d := Vector2(x - r, y - r).length() / float(r)
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(col.r, col.g, col.b, a * a * 0.9))
	return ImageTexture.create_from_image(img)

func _mk(tex: ImageTexture, pos: Vector2, z := 0) -> Sprite2D:
	var s := Sprite2D.new(); s.texture = tex; s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.scale = Vector2(SCALE, SCALE); s.position = pos; s.z_index = z; world.add_child(s); return s

func _es(x: float) -> float:
	x = clampf(x, 0.0, 1.0); return x * x * (3.0 - 2.0 * x)

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/staff_frames")
	# fundo
	var bglayer := CanvasLayer.new(); bglayer.layer = -10; get_root().add_child.call_deferred(bglayer)
	var bg := ColorRect.new(); bg.color = Color(0.05, 0.05, 0.08)
	bg.anchor_right = 1.0; bg.anchor_bottom = 1.0; bglayer.add_child(bg)

	world = Node2D.new(); get_root().add_child.call_deferred(world)

	HAND   = SOPH + Vector2(11, 13) * SCALE
	HOLD   = HAND + Vector2(4, -46)
	GROUND = Vector2(770, 560)
	PRE    = HOLD + Vector2(96, 86)

	glow = _mk(_radial(48, Color(0.35, 0.7, 1.0)), GROUND, -2)
	for i in 6:
		var g := _mk(_staff_tex(), GROUND, -1); g.modulate = Color(0.6, 0.85, 1.0, 0.0); ghosts.append(g)
	_mk(_soph_body(), SOPH, 0)
	_mk(_soph_hair(), SOPH + Vector2(0, -30) * SCALE, 1)
	staff = _mk(_staff_tex(), GROUND, 2)

	var fl := CanvasLayer.new(); fl.layer = 50; get_root().add_child.call_deferred(fl)
	flash = ColorRect.new(); flash.color = Color(1, 1, 1, 0.0)
	flash.anchor_right = 1.0; flash.anchor_bottom = 1.0
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE; fl.add_child(flash)

	cam = Camera2D.new(); cam.position = Vector2(560, 420); cam.zoom = Vector2(1.3, 1.3)
	get_root().add_child.call_deferred(cam)

func _process(_d: float) -> bool:
	if staff == null or cam == null: return false
	cam.make_current()
	t += DT

	var pos := GROUND
	var rot := PI / 2.0
	var fast := false

	if t < 0.5:
		pos = GROUND; rot = PI / 2.0
	elif t < 1.5:
		var u := _es((t - 0.5) / 1.0)
		pos = GROUND.lerp(PRE, u)
		rot = lerpf(PI / 2.0, 0.0, u) + sin(t * 9.0) * 0.18 * (1.0 - u)
	elif t < 1.74:
		var u := (t - 1.5) / 0.24
		pos = PRE.lerp(HOLD, u * u)
		rot = lerpf(0.0, TAU * 2.0, u)
		fast = true
	elif t < 1.9:
		pos = HOLD; rot = 0.0
	elif t < 2.75:
		var u := (t - 1.9) / 0.85
		rot = TAU * 3.0 * _es(u)
		pos = HOLD + Vector2(sin(u * TAU) * 26.0, -150.0 * sin(u * PI))
		fast = true
	else:
		var u := (t - 2.75)
		pos = HOLD + Vector2(0, sin(u * 3.0) * 3.0)
		rot = sin(u * 2.0) * 0.04

	staff.position = pos
	staff.rotation = rot
	glow.position = pos + Vector2(0, -24 * SCALE).rotated(rot)

	var gs := 0.6 + 0.5 * _es(clampf((t - 0.5) / 1.2, 0.0, 1.0))
	if t >= 1.74 and t < 1.95: gs += (1.95 - t) / 0.21 * 1.6
	if t >= 2.62 and t < 2.8:  gs += (2.8 - t) / 0.18 * 1.1
	glow.scale = Vector2(gs, gs)
	glow.modulate.a = clampf(0.4 + gs * 0.25, 0.0, 1.0)

	var fa := 0.0
	if t >= 1.72 and t < 1.92: fa = (1.92 - t) / 0.2 * 0.5
	if t >= 2.66 and t < 2.82: fa = maxf(fa, (2.82 - t) / 0.16 * 0.35)
	flash.color.a = fa

	if t >= 1.72 and t < 1.9: _shake = 8.0
	_shake = maxf(_shake - DT * 45.0, 0.0)
	cam.offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))

	_hist.push_front([pos, rot])
	if _hist.size() > 24: _hist.pop_back()
	for i in ghosts.size():
		var gi: Sprite2D = ghosts[i]
		var idx := (i + 1) * 3
		if fast and idx < _hist.size():
			gi.position = _hist[idx][0]; gi.rotation = _hist[idx][1]
			gi.modulate.a = 0.30 * (1.0 - float(i) / ghosts.size())
		else:
			gi.modulate.a = 0.0

	_capture()
	if t >= T_END:
		print("frames: ", frame); quit(0); return true
	return false

func _capture() -> void:
	var img := get_root().get_texture().get_image()
	if img:
		img.save_png("/tmp/staff_frames/frame_%03d.png" % frame)
		frame += 1
