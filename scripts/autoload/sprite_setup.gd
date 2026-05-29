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
	_gen_light_tex()
	_gen_goblin_archer()
	_gen_goblin_arrow()
	_gen_mana_orb()
	_gen_forest_ogre()
	_gen_ogre_shockwave()
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
	var cx := S / 2; var cy := S / 2; var r := float(S / 2)
	for y in range(S):
		for x in range(S):
			var dist := sqrt(float((x - cx) * (x - cx) + (y - cy) * (y - cy)))
			var t := clampf(1.0 - dist / r, 0.0, 1.0)
			var b := t * t * t
			img.set_pixel(x, y, Color(b, b, b, b))
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
