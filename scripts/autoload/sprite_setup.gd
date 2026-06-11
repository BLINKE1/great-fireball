extends Node

# Generates all game sprites at runtime as procedural fallbacks, then lets
# real art override them by filename. Access via SpriteSetup.get_texture("name").
#
# OVERRIDE SYSTEM
# After the procedural textures are built, _load_overrides() scans the asset
# folders for a PNG whose name matches a texture key (e.g. "player_body.png").
# If found, it replaces the procedural texture. This means dropping authored
# art (from third parties or the assets-creator) into assets/sprites/ etc.
# automatically swaps it into every scene — and if the file is missing, the
# procedural version keeps the demo running. Nothing ever breaks.
#
# Search order (first match wins): see _OVERRIDE_DIRS below.

const _OVERRIDE_DIRS: Array[String] = [
	"res://assets/sprites/",
	"res://assets/sprites/player/",
	"res://assets/sprites/enemies/",
	"res://assets/sprites/items/",
	"res://assets/tilesets/",
	"res://assets/ui/",
]

var _t: Dictionary = {}
var _overridden: PackedStringArray = []  # keys swapped to authored art (for logging)

func _ready() -> void:
	_gen_player_body()
	_gen_player_hair()
	_gen_goblin()
	_gen_golem()
	_gen_goblin_leader()
	_gen_missile()
	_gen_chest()
	_gen_checkpoint_off()
	_gen_checkpoint_on()
	_gen_bg_stone()
	_gen_cave_far()
	_gen_cave_mid()
	_gen_floor_tile()
	_gen_platform_tile()
	_gen_wall_tile()
	_gen_forest_far()
	_gen_forest_mid()
	_gen_grass_floor()
	_gen_grass_platform()
	_gen_moss_wall()
	_gen_forest_tree()
	_gen_light_tex()
	_gen_goblin_archer()
	_gen_goblin_arrow()
	_gen_mana_orb()
	_gen_forest_ogre()
	_gen_ogre_shockwave()
	_gen_goblin_mutant()
	_gen_goblin_mutant_noarm()
	_gen_staff()
	_gen_juju()
	_gen_will()
	_gen_will_shield()
	_gen_gus()
	_gen_gus_dagger()
	_gen_mutant_arm()
	_gen_di()
	_gen_di_arrow()
	_gen_gui()
	_gen_gui_wolf()
	_gen_gui_sword()
	_gen_rose()
	_gen_ze()
	_gen_ze_fireball()
	_gen_rose_aurora()
	_gen_nail_icons()
	_gen_magic_missile()
	_gen_sword_slash_sprite()
	_gen_missile_spread()
	_gen_missile_piercing()
	_gen_missile_giant()
	_gen_missile_curved()
	_gen_portal()
	_gen_fire_goblin_archer()
	_gen_fire_goblin_arrow()
	_load_overrides()

func get_texture(name: String) -> Texture2D:
	return _t.get(name)

# ── Authored-art overrides ──────────────────────────────────────────────────────

func _load_overrides() -> void:
	for key in _t.keys():
		for dir in _OVERRIDE_DIRS:
			var path: String = dir + key + ".png"
			var tex: Texture2D = _try_load_texture(path)
			if tex != null:
				_t[key] = tex
				_overridden.append(key)
				break
	if not _overridden.is_empty():
		print("[SpriteSetup] Authored art loaded for: ", ", ".join(_overridden))

func _try_load_texture(path: String) -> Texture2D:
	# Prefer the imported resource (handles compression / mipmaps set in editor).
	if ResourceLoader.exists(path):
		var res: Resource = ResourceLoader.load(path)
		if res is Texture2D:
			return res
	# Fallback: raw image load, for PNGs dropped in but not yet imported.
	if FileAccess.file_exists(path):
		var img: Image = Image.new()
		if img.load(path) == OK:
			return ImageTexture.create_from_image(img)
	return null

# ── Helpers ───────────────────────────────────────────────────────────────────

func _store(name: String, img: Image) -> void:
	_t[name] = ImageTexture.create_from_image(img)

func _fr(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	var W := img.get_width(); var H := img.get_height()
	for dy in range(h):
		for dx in range(w):
			var px := x + dx; var py := y + dy
			if px >= 0 and py >= 0 and px < W and py < H:
				img.set_pixel(px, py, c)

func _fc(img: Image, cx: int, cy: int, r: int, c: Color) -> void:
	var W := img.get_width(); var H := img.get_height()
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx * dx + dy * dy <= r * r:
				var px := cx + dx; var py := cy + dy
				if px >= 0 and py >= 0 and px < W and py < H:
					img.set_pixel(px, py, c)

func _glow_soft(img: Image, cx: int, cy: int, r: int, c: Color, strength: float) -> void:
	var W := img.get_width(); var H := img.get_height()
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var dist := sqrt(float(dx * dx + dy * dy))
			if dist <= float(r):
				var px := cx + dx; var py := cy + dy
				if px >= 0 and py >= 0 and px < W and py < H:
					var t := (1.0 - dist / float(r)) * strength
					var existing := img.get_pixel(px, py)
					img.set_pixel(px, py, existing.lerp(c, clampf(t, 0.0, 1.0)))

func _stalactite_shape(img: Image, cx: int, w: int, h: int, c: Color, shadow: Color) -> void:
	var W_img := img.get_width(); var H_img := img.get_height()
	for y in range(min(h, H_img)):
		var t := float(y) / float(max(h - 1, 1))
		var half_w := int((1.0 - t) * float(w) / 2.0)
		for x in range(cx - half_w, cx + half_w + 1):
			if x >= 0 and x < W_img:
				var col := shadow if x <= cx - half_w + 2 else c
				img.set_pixel(x, y, col)

func _stalagmite_shape(img: Image, cx: int, w: int, h: int, c: Color, shadow: Color) -> void:
	var W_img := img.get_width(); var H_img := img.get_height()
	for y in range(min(h, H_img)):
		var t := float(y) / float(max(h - 1, 1))
		var half_w := int(t * float(w) / 2.0)
		var actual_y := H_img - 1 - y
		if actual_y < 0: continue
		for x in range(cx - half_w, cx + half_w + 1):
			if x >= 0 and x < W_img:
				var col := shadow if x <= cx - half_w + 2 else c
				img.set_pixel(x, actual_y, col)

# ── Player Body (32x64) ───────────────────────────────────────────────────────

func _gen_player_body() -> void:
	const SK  := Color(0.93, 0.78, 0.64)
	const Sd  := Color(0.73, 0.58, 0.44)
	const PU  := Color(0.55, 0.22, 0.80)
	const DP  := Color(0.32, 0.10, 0.55)
	const GO  := Color(0.95, 0.75, 0.10)
	const DGO := Color(0.72, 0.55, 0.05)
	const BK  := Color(0.08, 0.08, 0.08)

	var img := Image.create(32, 64, false, Image.FORMAT_RGBA8)

	_fc(img, 16, 12, 9, SK)
	_fr(img, 11, 10, 3, 3, BK)
	_fr(img, 19, 10, 3, 3, BK)
	img.set_pixel(12, 11, SK)
	img.set_pixel(20, 11, SK)
	_fr(img, 13, 16, 6, 1, Sd)
	_fr(img, 14, 21, 4, 4, SK)

	_fr(img, 3, 22, 5, 22, DP)
	_fr(img, 24, 22, 5, 22, DP)
	_fc(img, 5, 45, 3, SK)
	_fc(img, 27, 45, 3, SK)

	_fr(img, 7, 25, 18, 3, PU)
	_fr(img, 8, 28, 16, 24, PU)
	_fr(img, 7, 31, 18, 4, GO)
	_fr(img, 8, 31, 1, 4, DGO)
	_fr(img, 24, 31, 1, 4, DGO)
	_fr(img, 15, 31, 2, 4, Color(1.0, 0.92, 0.30))
	_fr(img, 8, 35, 2, 15, DP)
	_fr(img, 22, 35, 2, 15, DP)
	_fr(img, 6, 50, 20, 3, DP)
	_fr(img, 4, 53, 24, 2, DP)

	_fr(img, 10, 54, 5, 8, DP)
	_fr(img, 17, 54, 5, 8, DP)

	_fr(img, 8, 60, 7, 4, BK)
	_fr(img, 17, 60, 7, 4, BK)
	_fr(img, 9, 60, 3, 1, Color(0.28, 0.28, 0.32))
	_fr(img, 18, 60, 3, 1, Color(0.28, 0.28, 0.32))

	_store("player_body", img)

# ── Player Hair (32x20) ───────────────────────────────────────────────────────

func _gen_player_hair() -> void:
	# Blue hair per lore
	const H  := Color(0.22, 0.58, 1.00)   # main blue
	const HL := Color(0.55, 0.82, 1.00)   # highlight
	const DK := Color(0.10, 0.32, 0.80)   # shadow

	var img := Image.create(32, 20, false, Image.FORMAT_RGBA8)

	_fr(img, 8,  0, 16, 2, H)
	_fr(img, 5,  2, 22, 3, H)
	_fr(img, 2,  5, 28, 3, H)
	_fr(img, 0,  8, 32, 5, H)
	_fr(img, 0, 13, 11, 7, H)
	_fr(img, 21, 13, 11, 7, H)
	img.set_pixel(0, 19, Color.TRANSPARENT)
	img.set_pixel(31, 19, Color.TRANSPARENT)

	# Highlights on top
	_fr(img, 10, 0, 8, 1, HL)
	_fr(img, 8,  1, 6, 1, HL)
	# Shadow on lower strands
	_fr(img, 0, 16, 6, 4, DK)
	_fr(img, 26, 16, 6, 4, DK)

	_store("player_hair", img)

# ── Goblin (24x40) ────────────────────────────────────────────────────────────

func _gen_goblin() -> void:
	const GR := Color(0.28, 0.72, 0.20)
	const DG := Color(0.16, 0.48, 0.10)
	const YE := Color(0.92, 0.88, 0.05)
	const BK := Color(0.08, 0.08, 0.08)
	const SK := Color(0.93, 0.78, 0.64)
	const BR := Color(0.52, 0.33, 0.10)

	var img := Image.create(24, 40, false, Image.FORMAT_RGBA8)

	_fc(img, 12, 11, 9, GR)

	_fr(img, 0, 8, 3, 5, GR)
	_fr(img, 21, 8, 3, 5, GR)
	img.set_pixel(1, 6, GR); img.set_pixel(23, 6, GR)
	img.set_pixel(2, 5, GR); img.set_pixel(21, 5, GR)

	_fr(img, 5, 8, 4, 4, YE)
	_fr(img, 15, 8, 4, 4, YE)
	_fr(img, 6, 9, 2, 2, BK)
	_fr(img, 16, 9, 2, 2, BK)

	img.set_pixel(5, 7, DG); img.set_pixel(6, 7, DG); img.set_pixel(7, 7, DG)
	img.set_pixel(15, 7, DG); img.set_pixel(16, 7, DG); img.set_pixel(17, 7, DG)

	_fr(img, 11, 13, 2, 2, DG)

	_fr(img, 7, 16, 10, 3, BK)
	_fr(img, 8, 16, 2, 3, SK)
	_fr(img, 11, 16, 2, 3, SK)
	_fr(img, 14, 16, 2, 3, SK)

	_fr(img, 7, 20, 10, 10, DG)
	_fc(img, 12, 26, 6, DG)

	_fr(img, 1, 20, 7, 4, DG)
	_fr(img, 16, 20, 7, 4, DG)
	_fc(img, 2, 25, 3, GR)
	_fc(img, 22, 25, 3, GR)

	_fr(img, 7, 26, 10, 6, BR)

	_fr(img, 7, 32, 4, 8, DG)
	_fr(img, 13, 32, 4, 8, DG)

	_fr(img, 5, 38, 6, 2, DG)
	_fr(img, 13, 38, 6, 2, DG)
	img.set_pixel(5, 39, BK); img.set_pixel(7, 39, BK); img.set_pixel(9, 39, BK)
	img.set_pixel(13, 39, BK); img.set_pixel(15, 39, BK); img.set_pixel(17, 39, BK)

	_store("goblin", img)

# ── Golem (40x60) ─────────────────────────────────────────────────────────────

func _gen_golem() -> void:
	const ST  := Color(0.52, 0.48, 0.44)
	const DST := Color(0.35, 0.32, 0.28)
	const LST := Color(0.68, 0.64, 0.60)
	const CR  := Color(0.22, 0.20, 0.18)
	const RE  := Color(0.85, 0.20, 0.05)
	const ORN := Color(1.00, 0.55, 0.10)

	var img := Image.create(40, 60, false, Image.FORMAT_RGBA8)

	_fr(img, 6, 22, 28, 30, ST)
	_fr(img, 6, 22, 4, 30, DST)
	_fr(img, 30, 22, 4, 30, DST)
	_fr(img, 10, 22, 4, 20, LST)

	_fr(img, 7, 4, 26, 20, ST)
	_fr(img, 7, 4, 3, 20, DST)
	_fr(img, 30, 4, 3, 20, DST)
	_fr(img, 7, 4, 26, 2, LST)

	_fr(img, 11, 9, 6, 6, RE)
	_fr(img, 23, 9, 6, 6, RE)
	_fr(img, 13, 11, 2, 2, ORN)
	_fr(img, 25, 11, 2, 2, ORN)

	_fr(img, 12, 19, 16, 2, CR)
	_fr(img, 13, 19, 14, 1, DST)

	img.set_pixel(18, 8, CR); img.set_pixel(19, 9, CR); img.set_pixel(20, 10, CR)
	img.set_pixel(15, 28, CR); img.set_pixel(16, 29, CR); img.set_pixel(17, 30, CR)
	img.set_pixel(28, 24, CR); img.set_pixel(27, 25, CR); img.set_pixel(26, 26, CR)

	_fr(img, 0, 22, 8, 16, DST)
	_fr(img, 32, 22, 8, 16, DST)
	_fr(img, 0, 22, 8, 2, ST)
	_fr(img, 32, 22, 8, 2, ST)

	_fr(img, 0, 34, 8, 20, ST)
	_fr(img, 32, 34, 8, 20, ST)

	_fr(img, 0, 50, 10, 10, DST)
	_fr(img, 30, 50, 10, 10, DST)

	_fr(img, 10, 50, 8, 10, DST)
	_fr(img, 22, 50, 8, 10, DST)
	_fr(img, 11, 50, 3, 10, ST)
	_fr(img, 23, 50, 3, 10, ST)

	_store("golem", img)

# ── Goblin Leader (36x54) ────────────────────────────────────────────────────

func _gen_goblin_leader() -> void:
	const RE  := Color(0.75, 0.08, 0.08)
	const DRE := Color(0.52, 0.03, 0.03)
	const YE  := Color(0.92, 0.88, 0.05)
	const GO  := Color(0.95, 0.75, 0.10)
	const DGO := Color(0.72, 0.55, 0.05)
	const BK  := Color(0.08, 0.08, 0.08)
	const SK  := Color(0.93, 0.78, 0.64)
	const GR  := Color(0.42, 0.42, 0.42)
	const DGR := Color(0.28, 0.28, 0.28)

	var img := Image.create(36, 54, false, Image.FORMAT_RGBA8)

	_fr(img, 10, 3, 16, 4, GO)
	img.set_pixel(11, 2, GO); img.set_pixel(12, 1, GO); img.set_pixel(13, 0, GO)
	img.set_pixel(17, 1, GO); img.set_pixel(18, 0, GO); img.set_pixel(19, 1, GO)
	img.set_pixel(23, 2, GO); img.set_pixel(24, 1, GO); img.set_pixel(25, 0, GO)
	_fr(img, 13, 3, 3, 3, Color(0.80, 0.10, 0.80))
	_fr(img, 20, 3, 3, 3, Color(0.10, 0.60, 1.00))

	_fc(img, 18, 16, 12, RE)

	_fr(img, 2, 10, 5, 8, RE)
	_fr(img, 29, 10, 5, 8, RE)
	img.set_pixel(3, 8, RE); img.set_pixel(4, 7, RE)
	img.set_pixel(31, 8, RE); img.set_pixel(30, 7, RE)

	_fr(img, 8, 11, 6, 6, YE)
	_fr(img, 22, 11, 6, 6, YE)
	_fr(img, 9, 12, 4, 4, Color(1.0, 0.95, 0.20))
	_fr(img, 23, 12, 4, 4, Color(1.0, 0.95, 0.20))
	_fr(img, 10, 13, 2, 2, BK)
	_fr(img, 24, 13, 2, 2, BK)

	img.set_pixel(16, 16, DRE); img.set_pixel(17, 17, DRE)
	img.set_pixel(18, 16, DRE); img.set_pixel(19, 17, DRE)

	_fr(img, 17, 19, 3, 2, DRE)
	_fr(img, 10, 23, 16, 3, BK)
	_fr(img, 11, 23, 3, 4, SK)
	_fr(img, 22, 23, 3, 4, SK)
	_fr(img, 14, 23, 8, 2, SK)

	_fr(img, 6, 27, 24, 5, GR)
	_fr(img, 5, 25, 3, 8, DGR)
	_fr(img, 28, 25, 3, 8, DGR)

	_fr(img, 3, 31, 9, 16, DGR)
	_fr(img, 24, 31, 9, 16, DGR)

	_fr(img, 10, 31, 16, 16, DRE)
	_fr(img, 12, 32, 12, 12, GR)
	_fr(img, 13, 33, 10, 6, DGR)

	_fr(img, 9, 41, 18, 4, GO)
	_fr(img, 9, 41, 2, 4, DGO)
	_fr(img, 17, 41, 3, 4, Color(1.0, 0.92, 0.30))

	_fc(img, 3, 49, 4, RE)
	_fc(img, 33, 49, 4, RE)
	img.set_pixel(0, 51, DRE); img.set_pixel(1, 52, DRE)
	img.set_pixel(35, 51, DRE); img.set_pixel(34, 52, DRE)

	_fr(img, 11, 47, 6, 7, DRE)
	_fr(img, 19, 47, 6, 7, DRE)
	_fr(img, 9, 51, 8, 3, DGR)
	_fr(img, 19, 51, 8, 3, DGR)
	_fr(img, 10, 51, 3, 1, GR)
	_fr(img, 20, 51, 3, 1, GR)

	_store("goblin_leader", img)

# ── Goblin Mutante — BOSS (80x112, ~2x a Soph) ────────────────────────────────
# Brutamonte mutante: um braço gigante deformado, espinhos ósseos, arreio de
# couro vermelho + bandoleira de bombas (vibe Siege-Gang Commander), olhos que
# brilham. Trocável por um PNG "goblin_mutant.png" se o Will quiser arte autoral.
func _gen_goblin_mutant() -> void:
	var img := Image.create(80, 112, false, Image.FORMAT_RGBA8)
	_paint_mutant(img, true)
	_store("goblin_mutant", img)

func _gen_goblin_mutant_noarm() -> void:
	# Igual ao mutante, mas SEM o braço gigante (o Gus arranca no Convoke).
	var img := Image.create(80, 112, false, Image.FORMAT_RGBA8)
	_paint_mutant(img, false)
	_paint_mutant_stump(img)
	_store("goblin_mutant_noarm", img)

func _paint_mutant(img: Image, with_arm: bool) -> void:
	const GB  := Color(0.28, 0.40, 0.15)   # verde base
	const GL  := Color(0.46, 0.60, 0.24)   # verde claro (luz/barriga)
	const GD  := Color(0.18, 0.26, 0.09)   # verde sombra
	const MUT := Color(0.44, 0.16, 0.46)   # mutação roxa
	const MVN := Color(0.68, 0.30, 0.64)   # veia mutante
	const HAR := Color(0.56, 0.10, 0.08)   # couro vermelho
	const HRD := Color(0.36, 0.05, 0.04)   # tira escura
	const MET := Color(0.60, 0.62, 0.68)   # metal
	const MTD := Color(0.30, 0.32, 0.37)   # metal escuro
	const BON := Color(0.90, 0.86, 0.70)   # osso/presa
	const BND := Color(0.68, 0.64, 0.48)   # osso sombra
	const EYE := Color(1.00, 0.88, 0.18)   # olho brilhando
	const EYR := Color(0.95, 0.22, 0.05)   # borda do olho (vermelho)
	const BK  := Color(0.06, 0.06, 0.07)
	const BMB := Color(0.10, 0.10, 0.13)   # bomba
	const FUS := Color(0.95, 0.60, 0.10)   # pavio

	# ── Pernas + pés garrudos ──
	_fr(img, 24, 86, 14, 26, GB); _fr(img, 24, 86, 4, 26, GD)
	_fr(img, 44, 86, 14, 26, GB); _fr(img, 54, 86, 4, 26, GD)
	_fr(img, 20, 106, 20, 6, GB); _fr(img, 42, 106, 20, 6, GB)   # pés
	for fx in [20, 26, 32, 44, 50, 56]:
		img.set_pixel(fx, 111, BON); img.set_pixel(fx, 110, BON)   # garras
	# Tanga de couro
	_fr(img, 30, 80, 22, 14, HRD); _fr(img, 38, 80, 4, 14, HAR)

	# ── Tronco hercúleo (curvado/largo) ──
	_fr(img, 16, 50, 48, 38, GB)
	_fr(img, 22, 56, 34, 28, GL)            # barriga clara
	_fr(img, 16, 50, 6, 38, GD)             # sombra lateral
	_fr(img, 18, 82, 44, 6, GD)             # sombra inferior

	# ── Ombros enormes com espinhos ósseos ──
	_fr(img, 8, 42, 64, 12, GB)
	_fr(img, 8, 42, 64, 3, GL)
	for sx in [12, 22, 33, 46, 58, 67]:
		_fr(img, sx, 36, 4, 8, BON); img.set_pixel(sx + 1, 34, BON)

	# ── Arreio vermelho cruzado (X) + estudos de metal ──
	for yy in range(50, 86):
		var xa := 20 + (yy - 50) * 32 / 36
		var xb := 60 - (yy - 50) * 32 / 36
		_fr(img, xa, yy, 4, 1, HAR); _fr(img, xb, yy, 4, 1, HAR)
	for my in [54, 62, 70, 78]:
		_fc(img, 40, my, 2, MET)
	# Bandoleira de bombas (cintura)
	_fr(img, 18, 84, 44, 4, HRD)
	for bx in [24, 34, 44, 54]:
		_fc(img, bx, 90, 3, BMB); img.set_pixel(bx, 86, FUS); img.set_pixel(bx, 85, FUS)

	# ── Cabeça baixa entre os ombros ──
	_fc(img, 40, 24, 16, GB)
	_fc(img, 34, 28, 11, GL)                # bochecha clara
	_fr(img, 26, 12, 28, 5, GD)             # testa franzida (sombra)
	# Orelhas pontudas (conectadas à cabeça)
	_fr(img, 12, 18, 16, 5, GB); img.set_pixel(10, 19, GB); img.set_pixel(8, 20, BON)
	_fr(img, 52, 18, 16, 5, GB); img.set_pixel(69, 19, GB); img.set_pixel(71, 20, BON)
	# Chifres no topo
	for hx in [30, 40, 50]:
		_fr(img, hx, 6, 3, 7, BON); img.set_pixel(hx + 1, 4, BON)
	# Olhos brilhando (raivosos)
	_fc(img, 33, 24, 4, EYR); _fc(img, 47, 24, 4, EYR)
	_fc(img, 33, 24, 2, EYE); _fc(img, 47, 24, 2, EYE)
	img.set_pixel(33, 24, BK); img.set_pixel(47, 24, BK)
	_glow_soft(img, 33, 24, 6, EYE, 0.5); _glow_soft(img, 47, 24, 6, EYE, 0.5)
	# Mandíbula com presas (subordida)
	_fr(img, 28, 32, 24, 8, BK)
	for tx in [30, 36, 43, 49]:
		_fr(img, tx, 30, 3, 5, BON)         # presas pra cima
	_fr(img, 31, 38, 3, 3, BON); _fr(img, 46, 38, 3, 3, BON)

	# ── Braço NORMAL (esquerda da tela) ──
	_fr(img, 2, 48, 14, 30, GB); _fr(img, 2, 48, 4, 30, GD)
	_fc(img, 8, 80, 7, GB)                  # mão
	for cx in [3, 8, 13]:
		img.set_pixel(cx, 86, BON)          # garras

	# ── Braço GIGANTE MUTANTE (direita da tela) ──
	if with_arm:
		_fr(img, 58, 44, 20, 18, GB)            # ombro/úmero massivo
		_fr(img, 60, 60, 20, 26, GB)            # antebraço
		_fr(img, 58, 44, 20, 4, GL)
		# Veias da mutação
		for vy in range(48, 84, 4):
			img.set_pixel(66, vy, MVN); img.set_pixel(72, vy + 2, MUT)
		_fc(img, 70, 56, 4, MUT)               # protuberância
		# PUNHO descomunal
		_fc(img, 68, 94, 13, GB)
		_fc(img, 64, 92, 8, GL)
		_fc(img, 68, 94, 13, GB)               # contorno
		for ky in [86, 92, 98]:                # espinhos ósseos nos nós
			_fr(img, 78, ky, 2, 4, BON)
		for ky2 in [88, 96]:
			img.set_pixel(56, ky2, BON)
		_glow_soft(img, 70, 94, 6, MVN, 0.35)  # brilho mutante no punho

func _paint_mutant_stump(img: Image) -> void:
	# Coto sangrento onde ficava o braço gigante (o Gus arrancou).
	const GB := Color(0.28, 0.40, 0.15)
	const GL := Color(0.46, 0.60, 0.24)
	const GORE := Color(0.66, 0.12, 0.12)
	const GORD := Color(0.42, 0.06, 0.06)
	const BON := Color(0.90, 0.86, 0.70)
	_fr(img, 58, 46, 9, 14, GB)             # ombro restante
	_fr(img, 58, 46, 9, 3, GL)
	_fr(img, 60, 50, 7, 8, GORE)            # carne exposta
	_fr(img, 60, 56, 7, 2, GORD)
	img.set_pixel(63, 52, BON); img.set_pixel(65, 54, BON); img.set_pixel(62, 57, BON)
	img.set_pixel(64, 61, GORE); img.set_pixel(66, 64, GORD)

# ── Cajado da Soph (16x64) — avulso, p/ a cena do pickup/flourish ─────────────
func _gen_staff() -> void:
	const WD  := Color(0.45, 0.30, 0.16)   # madeira
	const WDD := Color(0.30, 0.19, 0.09)   # madeira sombra
	const WDL := Color(0.60, 0.42, 0.22)   # madeira luz
	const GLD := Color(0.85, 0.70, 0.18)   # enrolado dourado
	const MET := Color(0.62, 0.64, 0.70)   # metal (garras/cap)
	const ORC := Color(0.92, 0.97, 1.00)   # núcleo do orbe
	const ORG := Color(0.30, 0.70, 1.00)   # orbe (azul mágico)
	const ORP := Color(0.55, 0.35, 0.95)   # tinta roxa do glow

	var img := Image.create(16, 64, false, Image.FORMAT_RGBA8)

	# Haste
	_fr(img, 7, 16, 4, 42, WD)
	_fr(img, 7, 16, 1, 42, WDD)
	_fr(img, 10, 16, 1, 42, WDL)
	# Enrolados dourados
	for wy in [24, 34, 44]:
		_fr(img, 6, wy, 6, 2, GLD)
	# Cap de metal embaixo
	_fr(img, 6, 58, 6, 5, MET)
	img.set_pixel(8, 63, MET); img.set_pixel(9, 63, MET)
	# Garras de metal segurando o orbe
	_fr(img, 5, 12, 2, 6, MET)
	_fr(img, 11, 12, 2, 6, MET)
	img.set_pixel(6, 11, MET); img.set_pixel(11, 11, MET)
	# Orbe brilhando
	_glow_soft(img, 8, 8, 8, ORP, 0.55)
	_fc(img, 8, 8, 6, ORG)
	_fc(img, 8, 8, 3, ORC)
	img.set_pixel(7, 6, Color(1, 1, 1, 1))   # brilho especular

	_store("staff", img)

# ── Juju, a fada aliada (Convoke) — 24x24 ─────────────────────────────────────
func _gen_juju() -> void:
	const SK   := Color(0.97, 0.82, 0.62)   # pele
	const HAIR := Color(0.98, 0.55, 0.78)   # cabelo rosa
	const HAIRD:= Color(0.80, 0.35, 0.60)
	const DRS  := Color(0.40, 0.85, 0.55)   # vestido verde-fada
	const DRSD := Color(0.25, 0.62, 0.38)
	const WING := Color(0.78, 0.93, 1.0, 0.50)
	const WINGE:= Color(0.92, 0.98, 1.0, 0.85)
	const GLOW := Color(0.75, 1.0, 0.65)
	const BK   := Color(0.10, 0.10, 0.16)
	var img := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	# Glow mágico
	_glow_soft(img, 12, 12, 11, GLOW, 0.40)
	# Asas (atrás): dois pares translúcidos
	_fc(img, 6, 8, 4, WING); _fc(img, 18, 8, 4, WING)
	_fc(img, 7, 14, 3, WING); _fc(img, 17, 14, 3, WING)
	img.set_pixel(4, 7, WINGE); img.set_pixel(20, 7, WINGE)
	img.set_pixel(5, 16, WINGE); img.set_pixel(19, 16, WINGE)
	# Cabelo (topo)
	_fr(img, 9, 3, 6, 3, HAIR); img.set_pixel(8, 4, HAIR); img.set_pixel(15, 4, HAIR)
	img.set_pixel(8, 5, HAIRD); img.set_pixel(15, 5, HAIRD)
	# Cabeça
	_fc(img, 12, 7, 3, SK)
	img.set_pixel(11, 7, BK); img.set_pixel(13, 7, BK)         # olhinhos
	img.set_pixel(12, 9, Color(0.85, 0.45, 0.45))             # boquinha
	# Corpo / vestido (sino)
	_fr(img, 10, 10, 5, 3, DRS)
	_fr(img, 9, 13, 7, 3, DRS); _fr(img, 8, 16, 9, 2, DRS)
	_fr(img, 8, 16, 9, 1, DRSD)
	# bracinhos
	img.set_pixel(9, 11, SK); img.set_pixel(15, 11, SK)
	# brilho/varinha-fagulha
	img.set_pixel(16, 11, Color(1, 1, 0.7)); img.set_pixel(17, 10, Color(1, 1, 0.85))
	_store("juju", img)

# ── Will (aliado defensivo do Convoke) — 28x28, agachado em guarda ────────────
func _gen_will() -> void:
	const SK   := Color(0.92, 0.74, 0.56)   # pele
	const SKD  := Color(0.76, 0.58, 0.42)
	const HAIR := Color(0.34, 0.22, 0.14)   # cabelo castanho
	const ARM  := Color(0.40, 0.46, 0.56)   # armadura aço
	const ARMD := Color(0.26, 0.31, 0.40)
	const ARML := Color(0.58, 0.64, 0.74)
	const CAPE := Color(0.55, 0.16, 0.18)   # manto vermelho
	const CAPED:= Color(0.38, 0.10, 0.12)
	const BK   := Color(0.10, 0.10, 0.14)
	var img := Image.create(28, 28, false, Image.FORMAT_RGBA8)
	# Manto atrás (costas)
	_fr(img, 7, 11, 7, 13, CAPE); _fr(img, 7, 20, 8, 4, CAPED)
	# Pernas agachadas (joelho no chão)
	_fr(img, 9, 22, 4, 5, ARMD); _fr(img, 14, 24, 6, 3, ARM)
	img.set_pixel(19, 26, ARMD); img.set_pixel(20, 26, ARMD)
	# Tronco em guarda (inclinado pra frente)
	_fr(img, 10, 13, 9, 9, ARM)
	_fr(img, 10, 13, 9, 2, ARML)        # brilho no ombro
	_fr(img, 10, 20, 9, 2, ARMD)
	# Cinto
	_fr(img, 10, 19, 9, 1, Color(0.30, 0.22, 0.12))
	# Braço da frente (segurando o escudo, estendido)
	_fr(img, 18, 15, 4, 3, ARM); _fr(img, 21, 15, 2, 4, SK)
	# Cabeça + elmo aberto
	_fc(img, 14, 9, 4, SK)
	_fr(img, 10, 5, 9, 3, ARM)          # testeira do elmo
	_fr(img, 10, 5, 9, 1, ARML)
	img.set_pixel(11, 8, HAIR); img.set_pixel(12, 8, HAIR)   # cabelo na nuca
	img.set_pixel(16, 9, BK); img.set_pixel(17, 9, BK)       # olhos determinados
	img.set_pixel(15, 7, HAIR); img.set_pixel(16, 7, HAIR)
	img.set_pixel(17, 11, SKD)          # queixo/sombra
	_store("will", img)

# ── Escudo gigante do Will — 18x34, torre de aço com emblema ──────────────────
func _gen_will_shield() -> void:
	const STL  := Color(0.52, 0.58, 0.68)   # aço
	const STLD := Color(0.32, 0.37, 0.46)
	const STLL := Color(0.72, 0.78, 0.88)
	const RIM  := Color(0.86, 0.70, 0.28)   # borda dourada
	const RIML := Color(1.00, 0.92, 0.55)
	const EMB  := Color(0.30, 0.62, 1.00)   # emblema azul (cor da Soph)
	const EMBL := Color(0.65, 0.85, 1.00)
	var img := Image.create(18, 34, false, Image.FORMAT_RGBA8)
	# Corpo do escudo (cantos arredondados via _fr empilhado)
	_fr(img, 3, 1, 12, 32, STL)
	_fr(img, 2, 4, 14, 26, STL)
	_fr(img, 1, 8, 16, 18, STL)
	# Sombreado interno (volume)
	_fr(img, 9, 4, 6, 26, STLD)
	_fr(img, 3, 2, 5, 4, STLL)              # reflexo no topo-esquerda
	# Borda dourada
	for y in range(1, 33):
		img.set_pixel(3, y, RIM); img.set_pixel(14, y, RIM)
	for x in range(3, 15):
		img.set_pixel(x, 1, RIM); img.set_pixel(x, 32, RIM)
	img.set_pixel(3, 2, RIML); img.set_pixel(4, 1, RIML)
	# Emblema central (losango azul)
	_fc(img, 9, 16, 4, EMB)
	_fr(img, 8, 12, 2, 9, EMBL)
	_fr(img, 5, 15, 9, 2, EMBL)
	img.set_pixel(9, 16, Color(1, 1, 1))
	_store("will_shield", img)

# ── Gus (aliado dagger/aventureiro do Convoke) — 28x28, pose ágil c/ 2 adagas ──
func _gen_gus() -> void:
	const SK   := Color(0.90, 0.70, 0.52)   # pele
	const SKD  := Color(0.72, 0.53, 0.38)
	const HAIR := Color(0.20, 0.13, 0.08)   # cabelo escuro curto
	const BAND := Color(0.82, 0.18, 0.16)   # faixa vermelha (atlético/jiu-jítsu)
	const BANDL:= Color(0.95, 0.35, 0.30)
	const TUN  := Color(0.20, 0.50, 0.42)   # túnica de aventureiro (verde-azulado)
	const TUND := Color(0.13, 0.34, 0.30)
	const TUNL := Color(0.30, 0.66, 0.56)
	const LTH  := Color(0.42, 0.28, 0.16)   # couro (cinto/correias)
	const STL  := Color(0.78, 0.82, 0.90)   # aço das adagas
	const STLD := Color(0.50, 0.54, 0.62)
	const BK   := Color(0.08, 0.08, 0.10)
	var img := Image.create(28, 28, false, Image.FORMAT_RGBA8)
	# Pernas (passada ágil)
	_fr(img, 10, 22, 4, 5, TUND); _fr(img, 15, 23, 4, 4, TUND)
	_fr(img, 9, 26, 5, 1, LTH); _fr(img, 15, 26, 5, 1, LTH)   # botas
	# Tronco (levemente torcido, dinâmico)
	_fr(img, 9, 13, 9, 10, TUN)
	_fr(img, 9, 13, 9, 2, TUNL)            # luz no peito
	_fr(img, 9, 21, 9, 2, TUND)
	# Correias em X no peito
	for i in range(0, 8):
		img.set_pixel(10 + i, 14 + i, LTH)
		img.set_pixel(17 - i, 14 + i, LTH)
	_fr(img, 9, 20, 9, 1, LTH)             # cinto
	# Cabeça
	_fc(img, 13, 9, 4, SK)
	img.set_pixel(15, 9, BK); img.set_pixel(16, 9, BK)        # olhos focados
	img.set_pixel(16, 11, SKD)
	# Cabelo + faixa vermelha
	_fr(img, 9, 4, 9, 3, HAIR)
	img.set_pixel(9, 7, HAIR); img.set_pixel(10, 8, HAIR)
	_fr(img, 9, 6, 9, 1, BAND); img.set_pixel(9, 6, BANDL)
	img.set_pixel(18, 7, BAND); img.set_pixel(19, 8, BAND)    # ponta da faixa esvoaçando
	# Braço/adaga TRASEIRO (pra cima, atrás)
	_fr(img, 6, 14, 3, 3, SK)
	img.set_pixel(5, 12, STLD); img.set_pixel(5, 11, STL)
	img.set_pixel(4, 10, STL);  img.set_pixel(4, 9, STL)
	img.set_pixel(6, 13, LTH)              # punho/cabo
	# Braço/adaga DIANTEIRO (estendido pra frente)
	_fr(img, 18, 16, 4, 3, SK)
	img.set_pixel(22, 17, LTH)             # cabo
	img.set_pixel(23, 16, STLD); img.set_pixel(24, 16, STL)
	img.set_pixel(25, 15, STL);  img.set_pixel(26, 15, STL)
	_store("gus", img)

# ── Adaga arremessada do Gus — 12x6, apontando pra direita ────────────────────
func _gen_gus_dagger() -> void:
	const STL  := Color(0.82, 0.86, 0.94)
	const STLL := Color(1.0, 1.0, 1.0)
	const STLD := Color(0.52, 0.56, 0.64)
	const LTH  := Color(0.42, 0.28, 0.16)
	const GRD  := Color(0.70, 0.58, 0.30)   # guarda dourada
	var img := Image.create(12, 6, false, Image.FORMAT_RGBA8)
	# Cabo
	_fr(img, 0, 2, 3, 2, LTH)
	# Guarda
	img.set_pixel(3, 1, GRD); img.set_pixel(3, 2, GRD); img.set_pixel(3, 3, GRD); img.set_pixel(3, 4, GRD)
	# Lâmina
	_fr(img, 4, 2, 5, 2, STL)
	img.set_pixel(4, 2, STLL); img.set_pixel(5, 2, STLL)   # brilho
	img.set_pixel(9, 2, STL); img.set_pixel(10, 3, STL)    # ponta
	img.set_pixel(8, 3, STLD); img.set_pixel(7, 3, STLD)
	_store("gus_dagger", img)

# ── Pedaço do braço mutante (Gus arranca) — 16x12 ─────────────────────────────
func _gen_mutant_arm() -> void:
	const GRN  := Color(0.36, 0.55, 0.24)   # carne goblin
	const GRND := Color(0.24, 0.38, 0.16)
	const GRNL := Color(0.48, 0.68, 0.32)
	const PUR  := Color(0.45, 0.20, 0.50)   # veias da mutação
	const GORE := Color(0.65, 0.14, 0.16)   # ponta arrancada
	const BON  := Color(0.85, 0.82, 0.70)   # osso exposto
	var img := Image.create(16, 12, false, Image.FORMAT_RGBA8)
	_fr(img, 2, 3, 11, 6, GRN)
	_fr(img, 2, 3, 11, 2, GRNL)            # luz por cima
	_fr(img, 2, 8, 11, 1, GRND)
	_fc(img, 12, 6, 3, GRN)                # punho/garra
	img.set_pixel(14, 4, GRND); img.set_pixel(15, 5, GRND)   # garras
	img.set_pixel(14, 8, GRND); img.set_pixel(15, 7, GRND)
	# Veias roxas da mutação
	img.set_pixel(5, 5, PUR); img.set_pixel(7, 6, PUR); img.set_pixel(9, 5, PUR); img.set_pixel(6, 7, PUR)
	# Ponta arrancada (sangue + osso)
	_fr(img, 1, 4, 2, 4, GORE)
	img.set_pixel(1, 5, BON); img.set_pixel(2, 6, BON)
	_store("mutant_arm", img)

# ── Di (elfa Sentinela, esposa do Gus) — 28x28, arqueira com arco ─────────────
func _gen_di() -> void:
	const SK   := Color(0.95, 0.80, 0.66)   # pele clara élfica
	const SKD  := Color(0.80, 0.62, 0.50)
	const HAIR := Color(0.95, 0.88, 0.55)   # loiro-mel longo
	const HAIRD:= Color(0.80, 0.68, 0.36)
	const TUN  := Color(0.24, 0.52, 0.34)   # verde-floresta (ranger)
	const TUND := Color(0.16, 0.36, 0.24)
	const TUNL := Color(0.36, 0.66, 0.44)
	const LTH  := Color(0.46, 0.31, 0.18)   # couro
	const BOW  := Color(0.60, 0.42, 0.22)   # arco de madeira
	const BOWL := Color(0.78, 0.58, 0.32)
	const STR  := Color(0.90, 0.95, 0.85, 0.8)   # corda
	const BK   := Color(0.08, 0.10, 0.10)
	var img := Image.create(28, 28, false, Image.FORMAT_RGBA8)
	# Cabelo de trás (massa no topo da cabeça)
	_fr(img, 9, 4, 9, 5, HAIRD)
	_fr(img, 9, 4, 9, 4, HAIR)
	# Mechas longas laterais (emolduram o rosto, sem cobrir o tronco)
	_fr(img, 8, 9, 2, 10, HAIR);  img.set_pixel(8, 9, HAIRD); img.set_pixel(8, 18, HAIRD)
	_fr(img, 17, 9, 2, 8, HAIR);  img.set_pixel(18, 9, HAIRD)
	# Pernas (leggings + botas)
	_fr(img, 10, 22, 3, 5, TUND); _fr(img, 14, 22, 3, 5, TUND)
	_fr(img, 9, 26, 4, 1, LTH); _fr(img, 14, 26, 4, 1, LTH)
	# Túnica curta de ranger (por cima do cabelo de trás)
	_fr(img, 10, 13, 7, 9, TUN)
	_fr(img, 10, 13, 7, 2, TUNL)
	_fr(img, 10, 20, 7, 2, TUND)
	_fr(img, 10, 19, 7, 1, LTH)              # cinto
	# Cabeça (por cima do cabelo)
	_fc(img, 13, 9, 3, SK)
	# Orelha pontuda (elfa!)
	img.set_pixel(9, 9, SK); img.set_pixel(8, 8, SK)
	# Franja
	_fr(img, 10, 5, 7, 2, HAIR)
	img.set_pixel(10, 7, HAIR); img.set_pixel(16, 7, HAIR)
	# Olhos
	img.set_pixel(13, 9, BK); img.set_pixel(15, 9, BK)
	img.set_pixel(14, 11, SKD)
	# Braço que segura o arco (frente, estendido)
	_fr(img, 16, 13, 4, 2, SK)
	# Braço que puxa a corda (recolhido)
	img.set_pixel(11, 14, SK)
	# ── Arco (à frente, arco vertical curvado pra direita) ──
	var bx := 22
	for y in range(3, 22):
		# curva: afasta no meio
		var bulge := int(round(2.5 * sin(float(y - 3) / 18.0 * PI)))
		img.set_pixel(bx + bulge, y, BOW)
		if y % 3 == 0:
			img.set_pixel(bx + bulge, y, BOWL)
	# pontas do arco
	img.set_pixel(bx, 3, BOWL); img.set_pixel(bx, 21, BOWL)
	# corda (reta, puxada até a mão)
	for y in range(3, 22):
		img.set_pixel(bx, y, STR)
	# flecha encaixada apontando pra frente
	img.set_pixel(20, 12, LTH); img.set_pixel(21, 12, Color(0.85,0.9,0.8))
	img.set_pixel(24, 12, Color(0.7, 1.0, 0.6)); img.set_pixel(25, 12, Color(0.85, 1.0, 0.7))
	_store("di", img)

# ── Flecha élfica da Di — 14x4, ponta brilhante verde-teal ────────────────────
func _gen_di_arrow() -> void:
	const SHF  := Color(0.55, 0.42, 0.26)   # haste de madeira
	const TIP  := Color(0.65, 1.0, 0.70)    # ponta de energia verde
	const TIPL := Color(0.92, 1.0, 0.88)
	const FLE  := Color(0.30, 0.78, 0.50)   # penas verdes
	var img := Image.create(14, 4, false, Image.FORMAT_RGBA8)
	# Penas (atrás)
	img.set_pixel(0, 0, FLE); img.set_pixel(1, 0, FLE)
	img.set_pixel(0, 3, FLE); img.set_pixel(1, 3, FLE)
	img.set_pixel(1, 1, FLE); img.set_pixel(1, 2, FLE)
	# Haste
	_fr(img, 2, 1, 8, 2, SHF)
	# Ponta de energia
	img.set_pixel(10, 1, TIP); img.set_pixel(10, 2, TIP)
	img.set_pixel(11, 1, TIP); img.set_pixel(11, 2, TIP)
	img.set_pixel(12, 1, TIPL); img.set_pixel(13, 2, TIPL)
	img.set_pixel(12, 2, TIP)
	_store("di_arrow", img)

# ── Gui Fenrir (forma humana) — 28x28, guerreiro de espadão c/ olhar de lobo ──
func _gen_gui() -> void:
	const SK   := Color(0.86, 0.66, 0.50)
	const SKD  := Color(0.66, 0.48, 0.34)
	const HAIR := Color(0.17, 0.13, 0.11)
	const FUR  := Color(0.62, 0.60, 0.56)   # gola de pele
	const FURD := Color(0.42, 0.40, 0.38)
	const ARM  := Color(0.28, 0.30, 0.38)
	const ARMD := Color(0.18, 0.20, 0.26)
	const ARML := Color(0.42, 0.45, 0.54)
	const STL  := Color(0.82, 0.86, 0.94)
	const STLD := Color(0.52, 0.56, 0.64)
	const GRD  := Color(0.58, 0.46, 0.24)
	const AMB  := Color(0.95, 0.72, 0.20)   # olhos âmbar (o lobo por dentro)
	var img := Image.create(28, 28, false, Image.FORMAT_RGBA8)
	# Pernas / botas
	_fr(img, 10, 22, 3, 5, ARMD); _fr(img, 15, 22, 3, 5, ARMD)
	_fr(img, 9, 26, 4, 1, Color(0.30, 0.22, 0.14)); _fr(img, 15, 26, 4, 1, Color(0.30, 0.22, 0.14))
	# Tronco (armadura escura)
	_fr(img, 9, 13, 9, 9, ARM)
	_fr(img, 9, 13, 9, 2, ARML)
	_fr(img, 9, 20, 9, 2, ARMD)
	_fr(img, 9, 19, 9, 1, Color(0.30, 0.22, 0.12))   # cinto
	# Gola de pele (ombros)
	_fr(img, 8, 11, 11, 2, FUR)
	img.set_pixel(8, 12, FURD); img.set_pixel(18, 12, FURD)
	# Cabeça
	_fc(img, 13, 8, 3, SK)
	# Cabelo selvagem (espetado)
	_fr(img, 9, 3, 9, 4, HAIR)
	img.set_pixel(9, 2, HAIR); img.set_pixel(12, 1, HAIR); img.set_pixel(15, 1, HAIR); img.set_pixel(17, 2, HAIR)
	img.set_pixel(9, 7, HAIR); img.set_pixel(17, 7, HAIR)   # costeletas
	# Olhos âmbar
	img.set_pixel(13, 8, AMB); img.set_pixel(15, 8, AMB)
	img.set_pixel(14, 10, SKD)
	# Braço dianteiro
	_fr(img, 17, 14, 3, 2, SK)
	# Espadão (apoiado, diagonal pra cima-direita)
	img.set_pixel(20, 15, GRD); img.set_pixel(20, 16, GRD)          # punho
	img.set_pixel(21, 14, GRD); img.set_pixel(21, 15, GRD); img.set_pixel(21, 16, GRD); img.set_pixel(21, 17, GRD)  # guarda
	for p in [[22, 14], [23, 13], [24, 11], [25, 10], [26, 8], [26, 9]]:
		img.set_pixel(p[0], p[1], STL)
	img.set_pixel(22, 15, STLD); img.set_pixel(23, 14, STLD)
	_store("gui", img)

# ── Gui Fenrir (lobisomem) — 32x32, fera maior e curvada ──────────────────────
func _gen_gui_wolf() -> void:
	const FUR   := Color(0.44, 0.40, 0.40)
	const FURD  := Color(0.29, 0.26, 0.26)
	const FURL  := Color(0.58, 0.54, 0.52)
	const NOSE  := Color(0.16, 0.14, 0.15)
	const CLAW  := Color(0.93, 0.93, 0.86)
	const EYE   := Color(0.97, 0.80, 0.15)
	const FANG  := Color(0.95, 0.95, 0.88)
	const PANTS := Color(0.32, 0.22, 0.14)
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	# Pernas digitígradas + garras
	_fr(img, 10, 24, 4, 6, FUR); _fr(img, 18, 24, 4, 6, FUR)
	for fx in [9, 11, 13]: img.set_pixel(fx, 30, CLAW)
	for fx in [18, 20, 22]: img.set_pixel(fx, 30, CLAW)
	# Calça rasgada (resto da forma humana)
	_fr(img, 9, 22, 14, 3, PANTS); _fr(img, 9, 24, 14, 1, FURD)
	# Tronco peludo grande
	_fr(img, 8, 12, 16, 11, FUR)
	_fr(img, 8, 12, 16, 2, FURL)
	_fr(img, 8, 20, 16, 2, FURD)
	_fr(img, 14, 14, 4, 7, FURL)            # peito (V claro)
	# Braços/ombros grandes
	_fr(img, 4, 13, 5, 8, FUR); _fr(img, 23, 13, 5, 8, FUR)
	_fr(img, 4, 13, 5, 2, FURL); _fr(img, 23, 13, 5, 2, FURL)
	for cy in [21, 22, 23]:
		img.set_pixel(4, cy, CLAW); img.set_pixel(27, cy, CLAW)
	img.set_pixel(3, 22, CLAW); img.set_pixel(28, 22, CLAW)
	# Cabeça de lobo (focinho pra direita)
	_fc(img, 16, 8, 5, FUR)
	_fr(img, 16, 7, 7, 3, FUR)
	img.set_pixel(22, 8, NOSE); img.set_pixel(23, 8, NOSE)   # nariz
	# Orelhas
	img.set_pixel(12, 2, FURL); img.set_pixel(12, 3, FUR); img.set_pixel(13, 3, FUR)
	img.set_pixel(19, 2, FURL); img.set_pixel(19, 3, FUR); img.set_pixel(18, 3, FUR)
	# Olhos âmbar brilhando
	img.set_pixel(15, 7, EYE); img.set_pixel(18, 7, EYE)
	img.set_pixel(15, 8, Color(1, 1, 0.6)); img.set_pixel(18, 8, Color(1, 1, 0.6))
	# Presas
	img.set_pixel(19, 11, FANG); img.set_pixel(20, 11, FANG); img.set_pixel(21, 11, FANG)
	_store("gui_wolf", img)

# ── Espadão do espetinho do Gui — 24x6 ────────────────────────────────────────
func _gen_gui_sword() -> void:
	const STL  := Color(0.82, 0.86, 0.94)
	const STLL := Color(1, 1, 1)
	const STLD := Color(0.52, 0.56, 0.64)
	const GRD  := Color(0.60, 0.48, 0.24)
	const LTH  := Color(0.40, 0.27, 0.16)
	var img := Image.create(24, 6, false, Image.FORMAT_RGBA8)
	_fr(img, 0, 2, 3, 2, LTH)               # cabo
	_fr(img, 3, 1, 1, 4, GRD)               # guarda
	_fr(img, 4, 2, 17, 2, STL)              # lâmina
	_fr(img, 4, 2, 17, 1, STLL)             # fio brilhante
	img.set_pixel(21, 2, STL); img.set_pixel(22, 2, STL); img.set_pixel(23, 3, STL)   # ponta
	img.set_pixel(20, 3, STLD)
	_store("gui_sword", img)

# ── Mãe Rose — maga graduada de GELO (28x28) ──────────────────────────────────
func _gen_rose() -> void:
	const SK   := Color(0.95, 0.80, 0.68)
	const SKD  := Color(0.78, 0.62, 0.52)
	const HAIR := Color(0.46, 0.30, 0.22)   # castanho
	const HAIRL:= Color(0.60, 0.42, 0.30)
	const ROBE := Color(0.62, 0.82, 0.95)   # azul-gelo claro
	const ROBED:= Color(0.40, 0.62, 0.82)
	const ROBEL:= Color(0.82, 0.94, 1.0)
	const TRIM := Color(0.85, 0.95, 1.0)    # debrum branco-gelo
	const STF  := Color(0.55, 0.40, 0.26)   # cajado
	const ICE  := Color(0.6, 0.95, 1.0)     # cristal de gelo
	const ICEL := Color(0.92, 1.0, 1.0)
	const BK   := Color(0.10, 0.12, 0.16)
	var img := Image.create(28, 28, false, Image.FORMAT_RGBA8)
	# Vestido longo (sino)
	_fr(img, 9, 14, 10, 9, ROBE)
	_fr(img, 8, 21, 12, 4, ROBE)
	_fr(img, 8, 24, 12, 1, ROBED)
	_fr(img, 9, 14, 10, 2, ROBEL)
	_fr(img, 13, 16, 2, 9, ROBEL)           # faixa central
	_fr(img, 8, 23, 12, 1, TRIM)            # debrum
	# Cabelo: massa no topo + mechas longas laterais (emoldura, sem virar bloco)
	_fr(img, 9, 4, 9, 5, HAIRL)
	_fr(img, 9, 4, 9, 4, HAIR)
	_fr(img, 8, 9, 2, 11, HAIR);  img.set_pixel(8, 9, HAIRL); img.set_pixel(8, 19, HAIRL)
	_fr(img, 17, 9, 2, 11, HAIR); img.set_pixel(18, 9, HAIRL)
	# Cabeça
	_fc(img, 13, 9, 3, SK)
	_fr(img, 10, 5, 7, 2, HAIR)             # franja
	img.set_pixel(13, 9, BK); img.set_pixel(15, 9, BK)   # olhos
	img.set_pixel(14, 11, SKD)
	# Tiara de gelo
	img.set_pixel(11, 5, ICEL); img.set_pixel(13, 4, ICE); img.set_pixel(15, 5, ICEL)
	# Braços
	_fr(img, 7, 15, 2, 5, ROBED); _fr(img, 19, 15, 2, 5, ROBED)
	# Cajado com cristal (direita)
	for y in range(8, 25):
		img.set_pixel(22, y, STF)
	_fc(img, 22, 6, 2, ICE)
	img.set_pixel(22, 5, ICEL); img.set_pixel(22, 6, ICEL)
	img.set_pixel(20, 6, ICE); img.set_pixel(24, 6, ICE)
	_store("rose", img)

# ── Pai Zé — mago de FOGO (28x28) ─────────────────────────────────────────────
func _gen_ze() -> void:
	const SK   := Color(0.90, 0.72, 0.56)
	const SKD  := Color(0.72, 0.54, 0.40)
	const HAIR := Color(0.20, 0.16, 0.14)   # cabelo/barba escuros
	const GREY := Color(0.55, 0.52, 0.50)   # grisalho
	const ROBE := Color(0.66, 0.22, 0.14)   # vermelho-fogo
	const ROBED:= Color(0.46, 0.14, 0.10)
	const ROBEL:= Color(0.85, 0.38, 0.18)
	const TRIM := Color(0.95, 0.72, 0.25)   # debrum dourado
	const STF  := Color(0.40, 0.27, 0.16)
	const FIRE := Color(1.0, 0.55, 0.12)
	const FIREL:= Color(1.0, 0.85, 0.35)
	const BK   := Color(0.10, 0.09, 0.10)
	var img := Image.create(28, 28, false, Image.FORMAT_RGBA8)
	# Túnica longa
	_fr(img, 9, 14, 10, 9, ROBE)
	_fr(img, 8, 21, 12, 4, ROBE)
	_fr(img, 8, 24, 12, 1, ROBED)
	_fr(img, 9, 14, 10, 2, ROBEL)
	_fr(img, 13, 16, 2, 9, ROBEL)
	_fr(img, 8, 23, 12, 1, TRIM)
	# Cabelo
	_fr(img, 9, 4, 9, 4, HAIR)
	img.set_pixel(9, 5, GREY); img.set_pixel(17, 5, GREY)   # têmporas grisalhas
	# Cabeça
	_fc(img, 13, 9, 3, SK)
	img.set_pixel(13, 9, BK); img.set_pixel(15, 9, BK)      # olhos
	# Barba (pai!)
	_fr(img, 11, 11, 5, 3, HAIR)
	img.set_pixel(12, 13, GREY); img.set_pixel(14, 13, GREY)
	img.set_pixel(11, 11, SKD)
	# Braços
	_fr(img, 7, 15, 2, 5, ROBED); _fr(img, 19, 15, 2, 5, ROBED)
	# Cajado com orbe de fogo (direita)
	for y in range(8, 25):
		img.set_pixel(22, y, STF)
	_fc(img, 22, 6, 2, FIRE)
	img.set_pixel(22, 6, FIREL); img.set_pixel(22, 5, FIREL)
	img.set_pixel(20, 6, FIRE); img.set_pixel(24, 6, FIRE)
	_store("ze", img)

# ── Grande Bola de Fogo do Zé — 20x20 ─────────────────────────────────────────
func _gen_ze_fireball() -> void:
	_t_fireball()

func _t_fireball() -> void:
	var img := Image.create(20, 20, false, Image.FORMAT_RGBA8)
	_fc(img, 10, 10, 9, Color(0.85, 0.18, 0.05, 0.55))
	_fc(img, 10, 10, 7, Color(1.0, 0.42, 0.10))
	_fc(img, 10, 10, 5, Color(1.0, 0.68, 0.20))
	_fc(img, 10, 10, 3, Color(1.0, 0.92, 0.65))
	# labaredas
	for p in [[10, 0], [3, 3], [17, 3], [1, 10], [19, 10], [4, 17], [16, 17], [10, 19]]:
		img.set_pixel(p[0], p[1], Color(1.0, 0.5, 0.1, 0.7))
	_store("ze_fireball", img)

# ── Cortina de aurora boreal (gelo) da Rose — 24x36 ───────────────────────────
func _gen_rose_aurora() -> void:
	var img := Image.create(24, 36, false, Image.FORMAT_RGBA8)
	for x in range(24):
		var t := float(x) / 24.0
		var c := Color(0.4, 0.9, 1.0).lerp(Color(0.5, 1.0, 0.7), t)
		for y in range(36):
			var a := 1.0 - absf(float(y) - 18.0) / 18.0
			a *= 0.5 + 0.5 * sin(float(x) * 0.9 + float(y) * 0.22)
			a = clampf(a * 0.7, 0.0, 0.8)
			img.set_pixel(x, y, Color(c.r, c.g, c.b, a))
	_store("rose_aurora", img)

# ── Ícones das Unhas Poderosas (16x16) — arte detalhada p/ UI e cross-promo ───
func _gen_nail_icons() -> void:
	var widths := [0, 1, 1, 2, 2, 3, 3, 3, 4, 4, 4, 3, 3, 2, 1, 0]
	for id in ["lava", "raios", "gelo", "aurora"]:
		var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		for y in range(16):
			var hw: int = widths[y]
			if hw == 0:
				continue
			for x in range(8 - hw, 8 + hw + 1):
				if x < 0 or x > 15:
					continue
				img.set_pixel(x, y, _nail_px(id, x, y))
		# Reflexo especular (gel)
		img.set_pixel(6, 3, Color(1, 1, 1, 0.85)); img.set_pixel(6, 4, Color(1, 1, 1, 0.5))
		# Cutícula / base
		img.set_pixel(7, 14, Color(0.95, 0.9, 0.88)); img.set_pixel(8, 14, Color(0.95, 0.9, 0.88))
		_store("nail_" + id, img)

func _nail_px(id: String, x: int, y: int) -> Color:
	var t := float(y) / 15.0
	match id:
		"lava":
			var crack := (int(x * 2 + y * 3) % 4 == 0) or (int(absi(x - y)) % 5 == 0)
			return Color(1.0, 0.55, 0.12) if crack else Color(0.14, 0.10, 0.12)
		"raios":
			var bolt := absi(x - 8) == (y % 3)
			return Color(0.82, 0.95, 1.0) if bolt else Color(0.10, 0.16, 0.32)
		"gelo":
			var frost := int(x + y) % 4 == 0
			return Color(0.92, 0.98, 1.0) if frost else Color(0.46, 0.74, 0.94)
		"aurora":
			return Color.from_hsv(fmod(t + x * 0.03, 1.0), 0.5, 1.0)
	return Color.WHITE

# ── Magic Missile (28x12) ────────────────────────────────────────────────────

func _gen_missile() -> void:
	const CY := Color(0.20, 0.90, 1.00)
	const BL := Color(0.10, 0.55, 1.00)
	const WH := Color(1.00, 1.00, 1.00)
	const DM := Color(0.05, 0.30, 0.80)

	var img := Image.create(28, 12, false, Image.FORMAT_RGBA8)

	for i in range(10):
		var a := float(i) / 10.0
		img.set_pixel(i, 4, Color(DM.r, DM.g, DM.b, a * 0.5))
		img.set_pixel(i, 5, Color(BL.r, BL.g, BL.b, a * 0.8))
		img.set_pixel(i, 6, Color(BL.r, BL.g, BL.b, a * 0.8))
		img.set_pixel(i, 7, Color(DM.r, DM.g, DM.b, a * 0.5))

	_fc(img, 18, 6, 5, BL)
	_fc(img, 18, 6, 3, CY)
	_fc(img, 18, 6, 1, WH)

	img.set_pixel(23, 5, CY); img.set_pixel(24, 6, CY)
	img.set_pixel(23, 6, WH); img.set_pixel(23, 7, CY)

	_store("missile", img)

# ── Chest (32x32) ─────────────────────────────────────────────────────────────

func _gen_chest() -> void:
	const BR  := Color(0.58, 0.37, 0.14)
	const DBR := Color(0.38, 0.22, 0.07)
	const LBR := Color(0.72, 0.50, 0.25)
	const GO  := Color(0.95, 0.75, 0.10)
	const DGO := Color(0.70, 0.52, 0.05)

	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)

	_fr(img, 2, 8, 28, 7, LBR)
	_fr(img, 3, 9, 26, 2, Color(0.82, 0.62, 0.32))

	_fr(img, 2, 14, 28, 16, BR)

	_fr(img, 2, 14, 28, 2, GO)
	_fr(img, 2, 8, 2, 22, DGO)
	_fr(img, 28, 8, 2, 22, DGO)
	_fr(img, 2, 28, 28, 2, DBR)

	_fr(img, 4, 17, 24, 1, DBR)
	_fr(img, 4, 21, 24, 1, DBR)
	_fr(img, 4, 25, 24, 1, DBR)

	_fc(img, 16, 20, 4, GO)
	_fc(img, 16, 20, 2, DGO)
	_fr(img, 15, 20, 2, 3, Color(0.08, 0.08, 0.08))
	img.set_pixel(16, 23, Color(0.08, 0.08, 0.08))

	_fr(img, 2, 8, 4, 4, DGO)
	_fr(img, 26, 8, 4, 4, DGO)
	_fr(img, 2, 26, 4, 4, DGO)
	_fr(img, 26, 26, 4, 4, DGO)

	_store("chest", img)

# ── Checkpoint Crystal OFF (16x24) ───────────────────────────────────────────

func _gen_checkpoint_off() -> void:
	const GY   := Color(0.50, 0.48, 0.52)
	const DGY  := Color(0.30, 0.28, 0.32)
	const LGY  := Color(0.70, 0.68, 0.72)
	const BASE := Color(0.28, 0.25, 0.30)

	var img := Image.create(16, 24, false, Image.FORMAT_RGBA8)

	_fr(img, 4, 20, 8, 4, BASE)
	_fr(img, 3, 22, 10, 2, BASE)

	img.set_pixel(8, 1, LGY)
	img.set_pixel(8, 2, LGY)
	_fr(img, 7, 3, 3, 1, LGY)
	_fr(img, 6, 4, 5, 1, GY)
	_fr(img, 5, 5, 7, 1, GY)

	_fr(img, 5, 6, 7, 13, GY)
	_fr(img, 5, 6, 2, 13, LGY)
	_fr(img, 10, 6, 2, 13, DGY)

	_fr(img, 5, 18, 7, 2, GY)
	img.set_pixel(7, 20, DGY); img.set_pixel(8, 20, DGY); img.set_pixel(9, 20, DGY)

	_store("checkpoint_off", img)

# ── Checkpoint Crystal ON (16x24) ────────────────────────────────────────────

func _gen_checkpoint_on() -> void:
	const BL   := Color(0.25, 0.65, 1.00)
	const DBL  := Color(0.10, 0.40, 0.90)
	const LBL  := Color(0.65, 0.88, 1.00)
	const WH   := Color(1.00, 1.00, 1.00)
	const BASE := Color(0.28, 0.25, 0.30)

	var img := Image.create(16, 24, false, Image.FORMAT_RGBA8)

	_fr(img, 4, 20, 8, 4, BASE)
	_fr(img, 3, 22, 10, 2, BASE)

	img.set_pixel(8, 1, LBL)
	img.set_pixel(8, 2, LBL)
	_fr(img, 7, 3, 3, 1, LBL)
	_fr(img, 6, 4, 5, 1, BL)
	_fr(img, 5, 5, 7, 1, BL)

	_fr(img, 5, 6, 7, 13, BL)
	_fr(img, 5, 6, 2, 13, LBL)
	_fr(img, 10, 6, 2, 13, DBL)

	_fr(img, 7, 8, 3, 9, WH)
	img.set_pixel(7, 8, LBL); img.set_pixel(9, 8, LBL)
	img.set_pixel(7, 16, LBL); img.set_pixel(9, 16, LBL)

	_fr(img, 5, 18, 7, 2, BL)
	img.set_pixel(7, 20, DBL); img.set_pixel(8, 20, DBL); img.set_pixel(9, 20, DBL)

	_store("checkpoint_on", img)

# ── Background stone tile (32x32) ────────────────────────────────────────────

func _gen_bg_stone() -> void:
	const WL  := Color(0.18, 0.15, 0.12)
	const DWL := Color(0.10, 0.08, 0.06)
	const LWL := Color(0.26, 0.22, 0.17)

	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(WL)

	_fr(img, 1, 1, 13, 9, LWL)
	_fr(img, 16, 1, 15, 9, LWL)
	_fr(img, 8, 12, 16, 9, LWL)
	_fr(img, 0, 12, 7, 9, LWL)
	_fr(img, 25, 12, 7, 9, LWL)
	_fr(img, 1, 22, 13, 9, LWL)
	_fr(img, 16, 22, 15, 9, LWL)

	_fr(img, 0, 11, 32, 2, DWL)
	_fr(img, 0, 22, 32, 1, DWL)
	for i in range(9):
		img.set_pixel(15, i, DWL)
	for i in range(7):
		img.set_pixel(8, 13 + i, DWL)
		img.set_pixel(24, 13 + i, DWL)
	for i in range(9):
		img.set_pixel(15, 23 + i, DWL)

	_store("bg_stone", img)

# ── Cave Far Background (512x500) ─────────────────────────────────────────────
# Tileable horizontally — stalactites from ceiling, stalagmites from floor.

func _gen_cave_far() -> void:
	var W := 512; var H := 500
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)

	# Gradient: deep black-purple top → slightly lighter purple bottom
	for y in range(H):
		var t := float(y) / float(H - 1)
		var c := Color(lerp(0.010, 0.028, t), lerp(0.004, 0.012, t), lerp(0.026, 0.062, t))
		for x in range(W):
			img.set_pixel(x, y, c)

	# Atmospheric glow pockets
	_glow_soft(img, 130, 200, 80, Color(0.08, 0.03, 0.22), 0.38)
	_glow_soft(img, 385, 160, 65, Color(0.06, 0.02, 0.18), 0.30)
	_glow_soft(img, 268, 320, 90, Color(0.05, 0.02, 0.16), 0.24)
	_glow_soft(img, 60,  350, 50, Color(0.07, 0.03, 0.20), 0.22)
	_glow_soft(img, 460, 280, 55, Color(0.06, 0.02, 0.17), 0.20)

	# Stalactites hanging from ceiling
	var sc := Color(0.048, 0.024, 0.092)
	var sd := Color(0.028, 0.014, 0.056)
	_stalactite_shape(img,  45, 30,  100, sc, sd)
	_stalactite_shape(img, 118, 20,  140, sc, sd)
	_stalactite_shape(img, 195, 36,   85, sc, sd)
	_stalactite_shape(img, 268, 24,  120, sc, sd)
	_stalactite_shape(img, 342, 32,   95, sc, sd)
	_stalactite_shape(img, 418, 26,  110, sc, sd)
	_stalactite_shape(img, 480, 18,   78, sc, sd)
	# Partial stalactites at edges for seamless tiling
	_stalactite_shape(img,   6, 16,   68, sc, sd)
	_stalactite_shape(img, 506, 14,   62, sc, sd)

	# Stalagmites rising from floor
	var sm := Color(0.038, 0.018, 0.074)
	var smd := Color(0.022, 0.010, 0.044)
	_stalagmite_shape(img,  82, 22,   65, sm, smd)
	_stalagmite_shape(img, 205, 28,   82, sm, smd)
	_stalagmite_shape(img, 315, 17,   55, sm, smd)
	_stalagmite_shape(img, 440, 24,   72, sm, smd)
	_stalagmite_shape(img, 504, 14,   46, sm, smd)

	_store("cave_far", img)

# ── Cave Mid Background (256x500) ─────────────────────────────────────────────
# Closer layer — larger forms, slightly lighter.

func _gen_cave_mid() -> void:
	var W := 256; var H := 500
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)

	for y in range(H):
		var t := float(y) / float(H - 1)
		var c := Color(lerp(0.022, 0.046, t), lerp(0.010, 0.022, t), lerp(0.052, 0.098, t))
		for x in range(W):
			img.set_pixel(x, y, c)

	# Stronger glow pockets
	_glow_soft(img, 128, 220, 100, Color(0.12, 0.04, 0.30), 0.32)
	_glow_soft(img,  30, 180,  48, Color(0.08, 0.03, 0.22), 0.24)
	_glow_soft(img, 228, 280,  60, Color(0.10, 0.04, 0.26), 0.26)

	# Large stalactites
	var sc := Color(0.070, 0.035, 0.132)
	var sd := Color(0.044, 0.022, 0.090)
	_stalactite_shape(img,  32, 44, 115, sc, sd)
	_stalactite_shape(img, 128, 34, 150, sc, sd)
	_stalactite_shape(img, 222, 40, 106, sc, sd)
	# Tiling edges
	_stalactite_shape(img,   0, 28,  90, sc, sd)
	_stalactite_shape(img, 256, 30,  98, sc, sd)

	# Large stalagmites
	var sm := Color(0.058, 0.030, 0.112)
	var smd := Color(0.036, 0.018, 0.072)
	_stalagmite_shape(img,  72, 32,   78, sm, smd)
	_stalagmite_shape(img, 190, 26,   68, sm, smd)
	_stalagmite_shape(img,   0, 20,   54, sm, smd)

	# Dark stone column for depth variation
	_fr(img, 234, 0, 22, H, sd)
	_fr(img, 236, 0,  8, H, sc)

	_store("cave_mid", img)

# ── Floor Tile (32x32) ─────────────────────────────────────────────────────────

# ── Floresta procedural: parallax de árvores + tiles de grama/musgo ───────────
func _tree(img: Image, cx: int, base_y: int, h: int, r: int,
		trunk_c: Color, canopy_c: Color, hi_c: Color) -> void:
	var trunk_h := maxi(4, int(h * 0.32))
	_fr(img, cx - 2, base_y - trunk_h, 4, trunk_h, trunk_c)
	var top := base_y - h
	# copa: blobs sobrepostos (árvore folhosa estilizada)
	_fc(img, cx, top + r, r, canopy_c)
	_fc(img, cx - int(r * 0.6), top + int(r * 1.4), int(r * 0.8), canopy_c)
	_fc(img, cx + int(r * 0.6), top + int(r * 1.4), int(r * 0.8), canopy_c)
	_fc(img, cx, base_y - trunk_h - int(r * 0.5), int(r * 0.9), canopy_c)
	_fc(img, cx - int(r * 0.35), top + r - 1, maxi(2, int(r * 0.35)), hi_c)  # luz da borda

func _gen_forest_far() -> void:
	var W := 512; var H := 500
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	seed(7731)
	# Céu de entardecer: índigo no topo → violeta → névoa verde no horizonte
	for y in range(H):
		var t := float(y) / float(H - 1)
		var c: Color
		if t < 0.60:
			var tt := t / 0.60
			c = Color(lerp(0.090, 0.250, tt), lerp(0.100, 0.155, tt), lerp(0.225, 0.180, tt))
		else:
			var tt := (t - 0.60) / 0.40
			c = Color(lerp(0.250, 0.100, tt), lerp(0.155, 0.175, tt), lerp(0.180, 0.120, tt))
		for x in range(W): img.set_pixel(x, y, c)
	# Lua + brilho
	_glow_soft(img, 398, 108, 78, Color(0.62, 0.68, 0.82), 0.42)
	_fc(img, 398, 108, 20, Color(0.86, 0.89, 0.94))
	_fc(img, 409, 101, 16, Color(0.055, 0.060, 0.165))  # recorte da crescente (cor do céu)
	for i in range(40):  # estrelas
		img.set_pixel(randi() % W, randi() % int(H * 0.5), Color(0.8, 0.85, 0.95, 0.6))
	# Linha de árvores distantes (azul-esverdeado, baixo contraste = neblina)
	var fc := Color(0.115, 0.165, 0.150); var ft := Color(0.085, 0.115, 0.110); var fh := Color(0.175, 0.245, 0.205)
	var x := 6
	while x < W:
		_tree(img, x, 452, randi_range(64, 116), randi_range(14, 26), ft, fc, fh)
		x += randi_range(32, 56)
	_store("forest_far", img)

func _gen_forest_mid() -> void:
	var W := 256; var H := 500
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)  # topo transparente (vê o far)
	seed(4422)
	var mc := Color(0.085, 0.205, 0.120); var mt := Color(0.105, 0.072, 0.048); var mh := Color(0.150, 0.310, 0.180)
	var x := 4
	while x < W:
		_tree(img, x, 484, randi_range(160, 250), randi_range(28, 42), mt, mc, mh)
		x += randi_range(38, 66)
	# Solo de neblina embaixo (funde com o chão)
	for y in range(440, H):
		var a := (float(y) - 440.0) / 60.0
		for px_x in range(W):
			var ex := img.get_pixel(px_x, y)
			img.set_pixel(px_x, y, ex.lerp(Color(0.05, 0.11, 0.07), clampf(a, 0.0, 0.7)))
	_store("forest_mid", img)

func _gen_grass_floor() -> void:
	const GR := Color(0.255, 0.500, 0.165); const GRD := Color(0.160, 0.345, 0.110)
	const GRL := Color(0.380, 0.660, 0.240); const DIRT := Color(0.300, 0.205, 0.130)
	const DIRT_D := Color(0.195, 0.130, 0.078); const DIRT_L := Color(0.385, 0.270, 0.165)
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(DIRT)
	seed(99)
	for i in range(40):  # textura de terra (pedrinhas/raízes)
		var px_x := randi() % 32; var py := randi_range(8, 31)
		img.set_pixel(px_x, py, DIRT_D if randf() < 0.6 else DIRT_L)
	# Faixa de grama no topo
	_fr(img, 0, 0, 32, 5, GR)
	_fr(img, 0, 0, 32, 2, GRL)
	# Lâminas pendendo (borda irregular grama→terra)
	for bx in [1, 4, 7, 11, 14, 18, 21, 25, 28, 31]:
		var bh := randi_range(2, 5)
		_fr(img, bx, 5, 1, bh, GR if randf() < 0.5 else GRD)
	_fr(img, 0, 4, 32, 1, GRD)  # sombra sob a grama
	_store("grass_floor", img)

func _gen_grass_platform() -> void:
	const GR := Color(0.270, 0.520, 0.175); const GRL := Color(0.400, 0.680, 0.255)
	const GRD := Color(0.165, 0.355, 0.115); const DIRT := Color(0.315, 0.215, 0.135)
	const DIRT_D := Color(0.205, 0.135, 0.082)
	var img := Image.create(32, 16, false, Image.FORMAT_RGBA8)
	img.fill(DIRT)
	seed(55)
	for i in range(14):
		img.set_pixel(randi() % 32, randi_range(5, 15), DIRT_D)
	_fr(img, 0, 0, 32, 4, GR)
	_fr(img, 0, 0, 32, 2, GRL)
	_fr(img, 0, 4, 32, 1, GRD)
	for bx in [2, 6, 10, 15, 19, 24, 29]:
		_fr(img, bx, 4, 1, randi_range(1, 3), GRD)
	_store("grass_platform", img)

func _gen_moss_wall() -> void:
	const RK := Color(0.205, 0.180, 0.150); const RKD := Color(0.120, 0.105, 0.088)
	const RKL := Color(0.275, 0.245, 0.205); const MOSS := Color(0.190, 0.330, 0.130)
	const MOSS_D := Color(0.130, 0.240, 0.090)
	var img := Image.create(16, 32, false, Image.FORMAT_RGBA8)
	img.fill(RK)
	_fr(img, 0, 0, 2, 32, RKD); _fr(img, 14, 0, 2, 32, RKD)
	_fr(img, 0, 10, 16, 2, RKD); _fr(img, 0, 22, 16, 2, RKD)
	_fr(img, 2, 1, 10, 4, RKL)
	seed(33)
	for i in range(18):  # manchas de musgo
		var px_x := randi_range(2, 13); var py := randi() % 32
		img.set_pixel(px_x, py, MOSS if randf() < 0.6 else MOSS_D)
	_store("moss_wall", img)

func _gen_forest_tree() -> void:
	# Árvore decorativa (64x128) p/ povoar a floresta no mundo (atrás do gameplay).
	const TR := Color(0.34, 0.23, 0.13); const TRD := Color(0.22, 0.15, 0.08); const TRL := Color(0.46, 0.32, 0.18)
	const CA := Color(0.17, 0.40, 0.16); const CAD := Color(0.105, 0.275, 0.105); const CAH := Color(0.31, 0.58, 0.27)
	var img := Image.create(64, 128, false, Image.FORMAT_RGBA8)
	# Tronco
	_fr(img, 28, 66, 9, 62, TR)
	_fr(img, 28, 66, 2, 62, TRD); _fr(img, 35, 66, 2, 62, TRL)
	for ly in [78, 92, 106]: _fr(img, 29, ly, 7, 1, TRD)   # textura de casca
	_fr(img, 24, 122, 17, 6, TR); _fr(img, 24, 122, 17, 2, TRD)  # base/raízes
	# Copa (cacho de blobs)
	_fc(img, 32, 42, 30, CA)
	_fc(img, 17, 50, 19, CA); _fc(img, 47, 50, 19, CA)
	_fc(img, 32, 22, 21, CA); _fc(img, 24, 62, 16, CA); _fc(img, 42, 62, 16, CA)
	# Clumps escuros (volume) + luz de cima-esquerda
	_fc(img, 42, 40, 11, CAD); _fc(img, 22, 36, 8, CAD); _fc(img, 38, 60, 9, CAD)
	_fc(img, 25, 28, 9, CAH); _fc(img, 44, 46, 7, CAH); _fc(img, 30, 50, 8, CAH)
	_glow_soft(img, 26, 26, 12, CAH, 0.4)
	_store("forest_tree", img)

func _gen_floor_tile() -> void:
	const ST  := Color(0.265, 0.225, 0.182)
	const DST := Color(0.118, 0.098, 0.078)
	const LST := Color(0.388, 0.336, 0.270)
	const MS  := Color(0.195, 0.288, 0.115)

	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(ST)

	# Lit top edge
	_fr(img, 0, 0, 32, 2, LST)

	# Brick rows — horizontal mortar
	_fr(img, 0, 11, 32, 2, DST)
	_fr(img, 0, 22, 32, 2, DST)

	# Vertical mortar alternating per row
	for y in range(0, 11):   img.set_pixel(15, y, DST)
	for y in range(13, 22):
		img.set_pixel(7,  y, DST)
		img.set_pixel(23, y, DST)
	for y in range(24, 32):  img.set_pixel(15, y, DST)

	# Bottom shadow
	_fr(img, 0, 30, 32, 2, DST)

	# Moss
	img.set_pixel(3, 1, MS);  img.set_pixel(4, 2, MS)
	img.set_pixel(22, 0, MS); img.set_pixel(23, 1, MS); img.set_pixel(24, 2, MS)
	img.set_pixel(9, 14, MS); img.set_pixel(10, 15, MS)
	img.set_pixel(27, 25, MS); img.set_pixel(28, 26, MS)

	# Surface cracks
	img.set_pixel(7, 0, DST);  img.set_pixel(8, 1, DST)
	img.set_pixel(28, 1, DST)

	_store("floor_tile", img)

# ── Platform Tile (32x16) ──────────────────────────────────────────────────────

func _gen_platform_tile() -> void:
	const ST  := Color(0.308, 0.262, 0.212)
	const DST := Color(0.138, 0.114, 0.090)
	const LST := Color(0.448, 0.388, 0.310)
	const MS  := Color(0.222, 0.308, 0.132)

	var img := Image.create(32, 16, false, Image.FORMAT_RGBA8)
	img.fill(ST)

	# Lit top surface
	_fr(img, 0, 0, 32, 2, LST)
	img.set_pixel(0,  0, Color(0.55, 0.48, 0.38))
	img.set_pixel(31, 0, Color(0.55, 0.48, 0.38))

	# Single mortar line
	_fr(img, 0, 9, 32, 1, DST)

	# Vertical mortar
	for y in range(0, 9):   img.set_pixel(16, y, DST)
	for y in range(10, 16):
		img.set_pixel(8,  y, DST)
		img.set_pixel(24, y, DST)

	# Bottom shadow
	_fr(img, 0, 14, 32, 2, DST)
	_fr(img, 1, 13, 30, 1, DST)

	# Moss
	img.set_pixel(5, 1, MS)
	img.set_pixel(21, 0, MS); img.set_pixel(22, 1, MS)

	_store("platform_tile", img)

# ── Wall Tile (16x32) ──────────────────────────────────────────────────────────

func _gen_wall_tile() -> void:
	const ST  := Color(0.178, 0.148, 0.118)
	const DST := Color(0.085, 0.070, 0.055)
	const LST := Color(0.258, 0.218, 0.172)

	var img := Image.create(16, 32, false, Image.FORMAT_RGBA8)
	img.fill(ST)

	# Edge shadows
	_fr(img, 0,  0, 2, 32, DST)
	_fr(img, 14, 0, 2, 32, DST)

	# Horizontal mortar
	_fr(img, 0, 10, 16, 2, DST)
	_fr(img, 0, 22, 16, 2, DST)

	# Vertical mortar alternating
	for y in range(0, 10):  img.set_pixel(8, y, DST)
	for y in range(12, 22):
		img.set_pixel(4,  y, DST)
		img.set_pixel(12, y, DST)
	for y in range(24, 32): img.set_pixel(8, y, DST)

	# Highlights
	_fr(img, 2, 0,  3, 10, LST)
	_fr(img, 6, 12, 3, 10, LST)
	_fr(img, 2, 24, 3,  8, LST)

	_store("wall_tile", img)

# ── Soft Light Gradient (128x128) ─────────────────────────────────────────────
# Used as PointLight2D texture for atmospheric torch/magic lights.

func _gen_light_tex() -> void:
	var S := 128
	var img := Image.create(S, S, true, Image.FORMAT_RGBA8)
	var cx: int = S / 2; var cy: int = S / 2; var r: float = float(S / 2)
	for y in range(S):
		for x in range(S):
			var dist := sqrt(float((x - cx) * (x - cx) + (y - cy) * (y - cy)))
			var t := clampf(1.0 - dist / r, 0.0, 1.0)
			var bv: float = t * t * t
			img.set_pixel(x, y, Color(bv, bv, bv, bv))
	_store("light_tex", img)

# ── Goblin Archer (28x40) ─────────────────────────────────────────────────────
# Orange-tinted goblin with bow on back and red headband.

func _gen_goblin_archer() -> void:
	const GR  := Color(0.25, 0.65, 0.14)
	const DG  := Color(0.14, 0.40, 0.08)
	const OR  := Color(0.85, 0.48, 0.08)
	const YE  := Color(0.92, 0.85, 0.08)
	const BK  := Color(0.08, 0.08, 0.08)
	const RE  := Color(0.80, 0.12, 0.08)
	const LBR := Color(0.68, 0.50, 0.22)
	const DBR := Color(0.38, 0.25, 0.07)
	const SK  := Color(0.93, 0.78, 0.64)

	var img := Image.create(28, 40, false, Image.FORMAT_RGBA8)

	# Head
	_fc(img, 14, 11, 9, GR)
	# Ears
	_fr(img, 0, 8, 3, 5, GR)
	_fr(img, 25, 8, 3, 5, GR)
	# Headband (red)
	_fr(img, 5, 6, 18, 2, RE)
	# Eyes (orange-yellow)
	_fr(img, 6, 9, 4, 4, YE)
	_fr(img, 18, 9, 4, 4, YE)
	_fr(img, 7, 10, 2, 2, BK)
	_fr(img, 19, 10, 2, 2, BK)
	# Nose
	_fr(img, 12, 14, 4, 2, DG)
	# Teeth
	_fr(img, 11, 17, 6, 2, SK)
	_fr(img, 12, 17, 2, 2, BK)
	_fr(img, 14, 17, 2, 2, BK)
	# Body (orange tunic)
	_fr(img, 7, 20, 14, 10, OR)
	_fr(img, 6, 20, 16, 2, DG)
	# Arms
	_fr(img, 1, 20, 7, 4, DG)
	_fr(img, 20, 20, 7, 4, DG)
	# Quiver on back (left side)
	_fr(img, 1, 14, 3, 10, DBR)
	_fr(img, 2, 13, 2, 2, YE)
	img.set_pixel(2, 15, YE)
	# Bow stave (right side, vertical)
	_fr(img, 25, 10, 2, 20, LBR)
	_fr(img, 25, 10, 1, 20, DBR)
	# Bowstring dots
	img.set_pixel(26, 10, BK); img.set_pixel(26, 18, BK); img.set_pixel(26, 28, BK)
	# Legs
	_fr(img, 8, 30, 4, 10, DG)
	_fr(img, 16, 30, 4, 10, DG)
	# Feet
	_fr(img, 6, 38, 6, 2, DG)
	_fr(img, 14, 38, 6, 2, DG)
	img.set_pixel(6, 39, BK); img.set_pixel(8, 39, BK); img.set_pixel(10, 39, BK)
	img.set_pixel(14, 39, BK); img.set_pixel(16, 39, BK); img.set_pixel(18, 39, BK)

	_store("goblin_archer", img)

# ── Goblin Arrow (20x6) ───────────────────────────────────────────────────────

func _gen_goblin_arrow() -> void:
	const BR  := Color(0.55, 0.38, 0.15)
	const GR  := Color(0.45, 0.42, 0.38)
	const YE  := Color(0.85, 0.75, 0.30)

	var img := Image.create(20, 6, false, Image.FORMAT_RGBA8)
	# Shaft
	_fr(img, 3, 2, 13, 2, BR)
	# Metal tip
	_fr(img, 16, 1, 3, 4, GR)
	img.set_pixel(19, 2, GR)
	img.set_pixel(19, 3, GR)
	# Feather fletching
	_fr(img, 0, 0, 4, 2, YE)
	_fr(img, 0, 4, 4, 2, YE)

	_store("goblin_arrow", img)

# ── Mana Orb (12x12) ─────────────────────────────────────────────────────────

func _gen_mana_orb() -> void:
	var img := Image.create(12, 12, true, Image.FORMAT_RGBA8)
	_glow_soft(img, 6, 6, 5, Color(0.20, 0.55, 1.0), 0.85)
	_fc(img, 6, 6, 3, Color(0.42, 0.74, 1.0))
	_fc(img, 6, 6, 1, Color.WHITE)
	_store("mana_orb", img)

# ── Forest Ogre (52x64) ───────────────────────────────────────────────────────
# Big, angry cave ogre with tusks. Boss of Dungeon 1.

func _gen_forest_ogre() -> void:
	const GN  := Color(0.28, 0.48, 0.15)
	const DGN := Color(0.16, 0.30, 0.08)
	const LGN := Color(0.44, 0.66, 0.26)
	const BR  := Color(0.52, 0.35, 0.12)
	const TN  := Color(0.90, 0.80, 0.62)
	const RE  := Color(0.78, 0.12, 0.04)
	const BK  := Color(0.06, 0.06, 0.06)

	var img := Image.create(52, 64, false, Image.FORMAT_RGBA8)

	# Ears (big and floppy, drawn first so head overlaps them)
	_fr(img, 2, 8, 8, 14, GN)
	_fr(img, 42, 8, 8, 14, GN)
	_fr(img, 3, 9, 4, 10, LGN)
	_fr(img, 43, 9, 4, 10, LGN)

	# Head
	_fc(img, 26, 15, 14, GN)
	# Brow ridge (dark, heavy)
	_fr(img, 12, 6, 28, 5, DGN)
	# Eyes (red, menacing)
	_fr(img, 14, 10, 6, 6, RE)
	_fr(img, 32, 10, 6, 6, RE)
	_fr(img, 15, 11, 4, 4, Color(0.55, 0.05, 0.02))
	_fr(img, 33, 11, 4, 4, Color(0.55, 0.05, 0.02))
	_fr(img, 16, 12, 2, 2, BK)
	_fr(img, 34, 12, 2, 2, BK)
	# Nose (wide, flat)
	_fr(img, 22, 18, 8, 4, DGN)
	_fr(img, 24, 19, 2, 3, BK)
	_fr(img, 26, 19, 2, 3, BK)
	# Mouth (grimace)
	_fr(img, 18, 23, 16, 3, BK)
	_fr(img, 19, 24, 14, 1, DGN)
	# Tusks
	_fr(img, 16, 26, 4, 10, TN)
	_fr(img, 32, 26, 4, 10, TN)
	img.set_pixel(16, 35, DGN); img.set_pixel(35, 35, DGN)

	# Neck
	_fr(img, 20, 28, 12, 6, GN)

	# Body (barrel chest)
	_fr(img, 8, 32, 36, 22, GN)
	_fr(img, 8, 32, 5, 22, DGN)    # left shadow
	_fr(img, 39, 32, 5, 22, DGN)   # right shadow
	_fr(img, 14, 32, 7, 12, LGN)   # chest highlight

	# Loincloth
	_fr(img, 14, 50, 24, 8, BR)
	_fr(img, 12, 52, 28, 5, BR)
	_fr(img, 18, 54, 16, 4, Color(BR.r * 0.75, BR.g * 0.75, BR.b * 0.75))

	# Arms (thick)
	_fr(img, 0, 32, 10, 22, GN)
	_fr(img, 42, 32, 10, 22, GN)
	_fr(img, 0, 32, 3, 22, DGN)
	_fr(img, 49, 32, 3, 22, DGN)
	# Fists
	_fc(img, 5, 55, 5, DGN)
	_fc(img, 47, 55, 5, DGN)

	# Legs (wide)
	_fr(img, 11, 54, 11, 10, DGN)
	_fr(img, 30, 54, 11, 10, DGN)
	# Feet
	_fr(img, 8, 62, 15, 2, DGN)
	_fr(img, 29, 62, 15, 2, DGN)

	_store("forest_ogre", img)

# ── Ogre Shockwave (28x12) ────────────────────────────────────────────────────
# Ground energy wave emitted by the Ogre's stomp in Phase 2+.

func _gen_ogre_shockwave() -> void:
	const OR  := Color(1.00, 0.48, 0.06)
	const YE  := Color(0.95, 0.78, 0.12)
	const WH  := Color(1.00, 0.96, 0.80)

	var img := Image.create(28, 12, false, Image.FORMAT_RGBA8)
	# Trailing fade
	for i in range(10):
		var a := float(i) / 10.0
		_fr(img, i * 2, 4, 2, 4, Color(OR.r, OR.g, OR.b, a * 0.75))
	# Leading orb
	_fc(img, 22, 6, 5, OR)
	_fc(img, 22, 6, 3, YE)
	_fc(img, 22, 6, 1, WH)
	# Tip sparks
	img.set_pixel(27, 5, YE); img.set_pixel(27, 7, YE)

	_store("ogre_shockwave", img)

# ── Magic Missile Sprite (28x12) ──────────────────────────────────────────────

func _gen_magic_missile() -> void:
	var img := Image.create(28, 12, false, Image.FORMAT_RGBA8)
	for y in 12:
		for x in 28:
			var cy: float = absf(float(y) - 5.5) / 5.5
			var prog: float = float(x) / 27.0
			var bright: float = (1.0 - cy * cy) * (0.3 + prog * 0.7)
			if bright > 0.02:
				var r: float = bright * 0.10
				var g: float = bright * 0.72
				var b: float = bright * 1.00
				var a: float = minf(bright * 1.4, 1.0)
				img.set_pixel(x, y, Color(r, g, b, a))
	# Bright tip highlight
	img.set_pixel(26, 5, Color(0.8, 1.0, 1.0, 1.0))
	img.set_pixel(27, 5, Color(1.0, 1.0, 1.0, 1.0))
	img.set_pixel(27, 6, Color(0.8, 1.0, 1.0, 1.0))
	_store("magic_missile", img)

# ── Sword Slash Arc Sprite (52x8) ────────────────────────────────────────────

func _gen_sword_slash_sprite() -> void:
	var img := Image.create(52, 8, false, Image.FORMAT_RGBA8)
	for x in 52:
		for y in 8:
			var cx: float = absf(float(x) - 25.5) / 25.5
			var cy: float = absf(float(y) - 3.5) / 3.5
			var bright: float = (1.0 - cx * cx) * (1.0 - cy * cy * 0.6)
			if bright > 0.04:
				var r: float = minf(0.98 + bright * 0.30, 1.0)
				var g: float = minf(0.82 + bright * 0.20, 1.0)
				var b: float = 0.20 + bright * 0.30
				var a: float = minf(bright * 1.2, 0.92)
				img.set_pixel(x, y, Color(r, g, b, a))
	_store("sword_slash_arc", img)

# ── Missile Spread (Míssil Duplo) — 28x12, violet-purple tones ───────────────

func _gen_missile_spread() -> void:
	var img := Image.create(28, 12, false, Image.FORMAT_RGBA8)
	for y in 12:
		for x in 28:
			var cy: float = absf(float(y) - 5.5) / 5.5
			var prog: float = float(x) / 27.0
			var bright: float = (1.0 - cy * cy) * (0.25 + prog * 0.75)
			if bright > 0.02:
				var r: float = bright * 0.75
				var g: float = bright * 0.18
				var b: float = bright * 1.00
				var a: float = minf(bright * 1.5, 1.0)
				img.set_pixel(x, y, Color(r, g, b, a))
	# Bright tip
	img.set_pixel(26, 5, Color(0.95, 0.70, 1.0, 1.0))
	img.set_pixel(27, 5, Color(1.00, 1.00, 1.0, 1.0))
	img.set_pixel(27, 6, Color(0.95, 0.70, 1.0, 1.0))
	_store("missile_spread", img)

# ── Missile Piercing (Míssil Perfurante) — 36x10, teal-green ─────────────────

func _gen_missile_piercing() -> void:
	var img := Image.create(36, 10, false, Image.FORMAT_RGBA8)
	for y in 10:
		for x in 36:
			var cy: float = absf(float(y) - 4.5) / 4.5
			var prog: float = float(x) / 35.0
			var bright: float = (1.0 - cy * cy * 1.2) * (0.2 + prog * 0.8)
			if bright > 0.02:
				var r: float = bright * 0.05
				var g: float = bright * 0.95
				var b: float = bright * 0.65
				var a: float = minf(bright * 1.6, 1.0)
				img.set_pixel(x, y, Color(r, g, b, a))
	# Sharp tip — elongated
	img.set_pixel(34, 4, Color(0.60, 1.0, 0.85, 1.0))
	img.set_pixel(35, 4, Color(1.00, 1.0, 1.00, 1.0))
	img.set_pixel(35, 5, Color(0.60, 1.0, 0.85, 1.0))
	_store("missile_piercing", img)

# ── Missile Giant (Míssil Gigante) — 56x24, radiant blue-white orb ───────────

func _gen_missile_giant() -> void:
	var img := Image.create(56, 24, false, Image.FORMAT_RGBA8)
	# Glowing orb core
	_glow_soft(img, 44, 12, 11, Color(0.35, 0.80, 1.0), 0.95)
	_glow_soft(img, 44, 12,  7, Color(0.65, 0.92, 1.0), 0.98)
	_fc(img, 44, 12, 4, Color(0.85, 0.97, 1.0))
	_fc(img, 44, 12, 2, Color(1.00, 1.00, 1.0))
	# Energy trail
	for x in 36:
		var t := float(x) / 35.0
		var a  := t * 0.75
		var half := int(3.0 + t * 5.0)
		for y in range(12 - half, 12 + half + 1):
			if y >= 0 and y < 24:
				var existing := img.get_pixel(x, y)
				if existing.a < a:
					img.set_pixel(x, y, Color(0.20, 0.65, 1.0, a))
	# Tip sparks
	img.set_pixel(54, 10, Color(0.9, 1.0, 1.0, 0.9))
	img.set_pixel(55, 12, Color(1.0, 1.0, 1.0, 1.0))
	img.set_pixel(54, 14, Color(0.9, 1.0, 1.0, 0.9))
	_store("missile_giant", img)

# ── Missile Curved (Míssil Curvo) — 24x14, indigo-violet teardrop orb ────────
# Oriented tip-right for sprite rotation to match velocity direction.

func _gen_missile_curved() -> void:
	var img := Image.create(24, 14, true, Image.FORMAT_RGBA8)
	# Trailing energy fade (left side)
	for x in 16:
		var prog := float(x) / 15.0
		var half := int(1.5 + prog * 4.5)
		var a := prog * 0.80
		for y in range(7 - half, 7 + half + 1):
			if y >= 0 and y < 14:
				var existing := img.get_pixel(x, y)
				if existing.a < a:
					img.set_pixel(x, y, Color(0.35, 0.05, 0.90, a))
	# Orb core glow
	_glow_soft(img, 18, 7, 6, Color(0.60, 0.20, 1.00), 0.95)
	_glow_soft(img, 18, 7, 4, Color(0.78, 0.45, 1.00), 0.98)
	_fc(img, 18, 7, 2, Color(0.92, 0.72, 1.00))
	_fc(img, 18, 7, 1, Color(1.00, 0.95, 1.00))
	# Tip spark
	img.set_pixel(22, 6, Color(0.95, 0.80, 1.0, 0.90))
	img.set_pixel(23, 7, Color(1.00, 1.00, 1.0, 1.00))
	img.set_pixel(22, 8, Color(0.95, 0.80, 1.0, 0.90))
	# Helical shimmer stripe along trail
	for x in range(2, 15, 3):
		img.set_pixel(x, 5, Color(0.70, 0.30, 1.0, 0.55))
		img.set_pixel(x + 1, 9, Color(0.70, 0.30, 1.0, 0.55))
	_store("missile_curved", img)

# ── Portal (animated exit) — 32x48, glowing crystal portal ───────────────────

func _gen_portal() -> void:
	const BL  := Color(0.30, 0.72, 1.00)
	const LBL := Color(0.65, 0.90, 1.00)
	const WH  := Color(1.00, 1.00, 1.00)
	const DBL := Color(0.10, 0.38, 0.85)
	const GL  := Color(0.55, 0.88, 1.00)

	var img := Image.create(32, 48, false, Image.FORMAT_RGBA8)

	# Base pedestal
	_fr(img, 8,  42, 16, 6, Color(0.28, 0.24, 0.38))
	_fr(img, 6,  44, 20, 4, Color(0.22, 0.18, 0.32))

	# Crystal body
	_fr(img, 12,  6, 8, 2, LBL)
	_fr(img, 10,  8, 12, 3, BL)
	_fr(img, 8,  11, 16, 26, BL)
	_fr(img, 8,  11, 3, 26, LBL)  # left highlight
	_fr(img, 21, 11, 3, 26, DBL)  # right shadow
	_fr(img, 10, 36, 12, 4, BL)
	_fr(img, 12, 39, 8, 3, DBL)

	# Inner glow streak
	_fr(img, 14, 10, 4, 28, WH)
	img.set_pixel(14, 10, LBL); img.set_pixel(17, 10, LBL)
	img.set_pixel(14, 37, LBL); img.set_pixel(17, 37, LBL)

	# Crystal tip (top point)
	img.set_pixel(16,  2, LBL)
	img.set_pixel(16,  3, LBL)
	_fr(img, 15,  4, 3, 2, BL)

	# Ambient outer glow
	_glow_soft(img, 16, 22, 14, GL, 0.30)

	_store("portal", img)

# ── Fire Goblin Archer (28x40) ────────────────────────────────────────────────
# Darker, more menacing variant with fire-orange palette and burn-glow eyes.

func _gen_fire_goblin_archer() -> void:
	const GR  := Color(0.18, 0.42, 0.08)
	const DG  := Color(0.10, 0.25, 0.04)
	const OR  := Color(0.95, 0.38, 0.04)
	const DOR := Color(0.65, 0.22, 0.02)
	const YE  := Color(1.00, 0.82, 0.10)
	const BK  := Color(0.06, 0.06, 0.06)
	const RE  := Color(0.85, 0.08, 0.04)
	const LBR := Color(0.55, 0.35, 0.10)
	const DBR := Color(0.28, 0.15, 0.03)
	const SK  := Color(0.90, 0.72, 0.58)

	var img := Image.create(28, 40, false, Image.FORMAT_RGBA8)

	_fc(img, 14, 11, 9, GR)
	_fr(img, 0, 8, 3, 5, GR)
	_fr(img, 25, 8, 3, 5, GR)
	# Flame-orange headband
	_fr(img, 5, 6, 18, 2, OR)
	# Burning eyes (orange-red glow)
	_fr(img, 6, 9, 4, 4, OR)
	_fr(img, 18, 9, 4, 4, OR)
	_fr(img, 7, 10, 2, 2, Color(1.0, 0.55, 0.0))
	_fr(img, 19, 10, 2, 2, Color(1.0, 0.55, 0.0))
	# Fire glow dots in eyes
	img.set_pixel(7, 10, RE); img.set_pixel(8, 10, RE)
	img.set_pixel(19, 10, RE); img.set_pixel(20, 10, RE)
	# Nose
	_fr(img, 12, 14, 4, 2, DG)
	# Teeth
	_fr(img, 11, 17, 6, 2, SK)
	_fr(img, 12, 17, 2, 2, BK)
	_fr(img, 14, 17, 2, 2, BK)
	# Body (dark fire tunic)
	_fr(img, 7, 20, 14, 10, DOR)
	_fr(img, 6, 20, 16, 2, DG)
	# Fire trim on tunic
	for tx in range(7, 21):
		if tx % 2 == 0:
			img.set_pixel(tx, 28, OR)
			img.set_pixel(tx, 29, YE)
	# Arms
	_fr(img, 1, 20, 7, 4, DG)
	_fr(img, 20, 20, 7, 4, DG)
	# Quiver (fire-colored arrows inside)
	_fr(img, 1, 14, 3, 10, DBR)
	_fr(img, 2, 13, 2, 2, OR)
	img.set_pixel(2, 15, YE)
	img.set_pixel(2, 17, OR)
	# Bow stave (darker wood)
	_fr(img, 25, 10, 2, 20, LBR)
	_fr(img, 25, 10, 1, 20, DBR)
	img.set_pixel(26, 10, BK); img.set_pixel(26, 18, BK); img.set_pixel(26, 28, BK)
	# Legs
	_fr(img, 8, 30, 4, 10, DG)
	_fr(img, 16, 30, 4, 10, DG)
	# Feet
	_fr(img, 6, 38, 6, 2, DG)
	_fr(img, 14, 38, 6, 2, DG)
	img.set_pixel(6, 39, BK); img.set_pixel(8, 39, BK); img.set_pixel(10, 39, BK)
	img.set_pixel(14, 39, BK); img.set_pixel(16, 39, BK); img.set_pixel(18, 39, BK)

	_store("fire_goblin_archer", img)

# ── Fire Goblin Arrow (22x6) ──────────────────────────────────────────────────
# Flaming arrow — darker shaft with orange-red fire tip.

func _gen_fire_goblin_arrow() -> void:
	const DBR := Color(0.32, 0.18, 0.04)
	const OR  := Color(1.00, 0.45, 0.06)
	const YE  := Color(1.00, 0.82, 0.10)
	const RE  := Color(0.90, 0.12, 0.04)

	var img := Image.create(22, 6, false, Image.FORMAT_RGBA8)
	# Shaft (dark wood)
	_fr(img, 3, 2, 13, 2, DBR)
	# Burning tip
	_fr(img, 16, 1, 4, 4, OR)
	img.set_pixel(19, 2, RE)
	img.set_pixel(20, 2, RE)
	img.set_pixel(21, 2, YE)
	# Fire fletching
	_fr(img, 0, 0, 4, 2, OR)
	_fr(img, 0, 4, 4, 2, OR)
	img.set_pixel(0, 0, YE); img.set_pixel(1, 1, YE)
	img.set_pixel(0, 5, YE); img.set_pixel(1, 4, YE)

	_store("fire_goblin_arrow", img)
