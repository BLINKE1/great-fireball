extends Node

# Generates all game sprites at runtime as ImageTexture objects.
# Access via SpriteSetup.get_texture("name").

var _t: Dictionary = {}

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

func get_texture(name: String) -> ImageTexture:
	return _t.get(name)

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

# ── Player Body (32x64) ───────────────────────────────────────────────────────

func _gen_player_body() -> void:
	const SK  := Color(0.93, 0.78, 0.64)   # skin
	const Sd  := Color(0.73, 0.58, 0.44)   # dark skin
	const PU  := Color(0.55, 0.22, 0.80)   # purple robe
	const DP  := Color(0.32, 0.10, 0.55)   # dark purple
	const GO  := Color(0.95, 0.75, 0.10)   # gold belt
	const DGO := Color(0.72, 0.55, 0.05)   # dark gold
	const BK  := Color(0.08, 0.08, 0.08)   # black

	var img := Image.create(32, 64, false, Image.FORMAT_RGBA8)

	# Head
	_fc(img, 16, 12, 9, SK)
	# Eyes (dark surround + skin shine)
	_fr(img, 11, 10, 3, 3, BK)
	_fr(img, 19, 10, 3, 3, BK)
	img.set_pixel(12, 11, SK)
	img.set_pixel(20, 11, SK)
	# Mouth
	_fr(img, 13, 16, 6, 1, Sd)
	# Neck
	_fr(img, 14, 21, 4, 4, SK)

	# Arms
	_fr(img, 3, 22, 5, 22, DP)
	_fr(img, 24, 22, 5, 22, DP)
	_fc(img, 5, 45, 3, SK)
	_fc(img, 27, 45, 3, SK)

	# Robe body
	_fr(img, 7, 25, 18, 3, PU)     # shoulders
	_fr(img, 8, 28, 16, 24, PU)    # body
	_fr(img, 7, 31, 18, 4, GO)     # belt
	_fr(img, 8, 31, 1, 4, DGO)
	_fr(img, 24, 31, 1, 4, DGO)
	_fr(img, 15, 31, 2, 4, Color(1.0, 0.92, 0.30))  # buckle
	# Robe shading stripes
	_fr(img, 8, 35, 2, 15, DP)
	_fr(img, 22, 35, 2, 15, DP)
	# Lower flare
	_fr(img, 6, 50, 20, 3, DP)
	_fr(img, 4, 53, 24, 2, DP)

	# Legs
	_fr(img, 10, 54, 5, 8, DP)
	_fr(img, 17, 54, 5, 8, DP)

	# Boots
	_fr(img, 8, 60, 7, 4, BK)
	_fr(img, 17, 60, 7, 4, BK)
	_fr(img, 9, 60, 3, 1, Color(0.28, 0.28, 0.32))
	_fr(img, 18, 60, 3, 1, Color(0.28, 0.28, 0.32))

	_store("player_body", img)

# ── Player Hair (32x20) ───────────────────────────────────────────────────────
# Hair is white — the hair.gdshader handles the blue-to-black gradient.

func _gen_player_hair() -> void:
	const H := Color.WHITE

	var img := Image.create(32, 20, false, Image.FORMAT_RGBA8)

	_fr(img, 8, 0, 16, 2, H)      # crown
	_fr(img, 5, 2, 22, 3, H)
	_fr(img, 2, 5, 28, 3, H)
	_fr(img, 0, 8, 32, 5, H)      # widest band
	_fr(img, 0, 13, 11, 7, H)     # left drape
	_fr(img, 21, 13, 11, 7, H)    # right drape
	# Taper bottom edges
	img.set_pixel(0, 19, Color.TRANSPARENT)
	img.set_pixel(31, 19, Color.TRANSPARENT)

	_store("player_hair", img)

# ── Goblin (24x40) ────────────────────────────────────────────────────────────

func _gen_goblin() -> void:
	const GR := Color(0.28, 0.72, 0.20)
	const DG := Color(0.16, 0.48, 0.10)
	const YE := Color(0.92, 0.88, 0.05)
	const BK := Color(0.08, 0.08, 0.08)
	const SK := Color(0.93, 0.78, 0.64)   # teeth
	const BR := Color(0.52, 0.33, 0.10)   # shorts

	var img := Image.create(24, 40, false, Image.FORMAT_RGBA8)

	# Big round head
	_fc(img, 12, 11, 9, GR)

	# Pointy ears
	_fr(img, 0, 8, 3, 5, GR)
	_fr(img, 21, 8, 3, 5, GR)
	img.set_pixel(1, 6, GR); img.set_pixel(23, 6, GR)
	img.set_pixel(2, 5, GR); img.set_pixel(21, 5, GR)

	# Big yellow eyes with pupils
	_fr(img, 5, 8, 4, 4, YE)
	_fr(img, 15, 8, 4, 4, YE)
	_fr(img, 6, 9, 2, 2, BK)
	_fr(img, 16, 9, 2, 2, BK)

	# Angry brow
	img.set_pixel(5, 7, DG); img.set_pixel(6, 7, DG); img.set_pixel(7, 7, DG)
	img.set_pixel(15, 7, DG); img.set_pixel(16, 7, DG); img.set_pixel(17, 7, DG)

	# Nose
	_fr(img, 11, 13, 2, 2, DG)

	# Mouth with teeth
	_fr(img, 7, 16, 10, 3, BK)
	_fr(img, 8, 16, 2, 3, SK)
	_fr(img, 11, 16, 2, 3, SK)
	_fr(img, 14, 16, 2, 3, SK)

	# Hunched body
	_fr(img, 7, 20, 10, 10, DG)
	_fc(img, 12, 26, 6, DG)

	# Arms
	_fr(img, 1, 20, 7, 4, DG)
	_fr(img, 16, 20, 7, 4, DG)
	_fc(img, 2, 25, 3, GR)
	_fc(img, 22, 25, 3, GR)

	# Shorts
	_fr(img, 7, 26, 10, 6, BR)

	# Legs
	_fr(img, 7, 32, 4, 8, DG)
	_fr(img, 13, 32, 4, 8, DG)

	# Big feet
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
	const CR  := Color(0.22, 0.20, 0.18)   # cracks
	const RE  := Color(0.85, 0.20, 0.05)   # eye glow
	const ORN := Color(1.00, 0.55, 0.10)   # bright eye center

	var img := Image.create(40, 60, false, Image.FORMAT_RGBA8)

	# Body
	_fr(img, 6, 22, 28, 30, ST)
	_fr(img, 6, 22, 4, 30, DST)    # left shadow
	_fr(img, 30, 22, 4, 30, DST)   # right shadow
	_fr(img, 10, 22, 4, 20, LST)   # highlight stripe

	# Head (large block)
	_fr(img, 7, 4, 26, 20, ST)
	_fr(img, 7, 4, 3, 20, DST)
	_fr(img, 30, 4, 3, 20, DST)
	_fr(img, 7, 4, 26, 2, LST)     # top highlight

	# Glowing red eyes
	_fr(img, 11, 9, 6, 6, RE)
	_fr(img, 23, 9, 6, 6, RE)
	_fr(img, 13, 11, 2, 2, ORN)
	_fr(img, 25, 11, 2, 2, ORN)

	# Grim mouth
	_fr(img, 12, 19, 16, 2, CR)
	_fr(img, 13, 19, 14, 1, DST)

	# Cracks
	img.set_pixel(18, 8, CR); img.set_pixel(19, 9, CR); img.set_pixel(20, 10, CR)
	img.set_pixel(15, 28, CR); img.set_pixel(16, 29, CR); img.set_pixel(17, 30, CR)
	img.set_pixel(28, 24, CR); img.set_pixel(27, 25, CR); img.set_pixel(26, 26, CR)

	# Wide shoulders
	_fr(img, 0, 22, 8, 16, DST)
	_fr(img, 32, 22, 8, 16, DST)
	_fr(img, 0, 22, 8, 2, ST)
	_fr(img, 32, 22, 8, 2, ST)

	# Arms (thick slabs)
	_fr(img, 0, 34, 8, 20, ST)
	_fr(img, 32, 34, 8, 20, ST)

	# Fists
	_fr(img, 0, 50, 10, 10, DST)
	_fr(img, 30, 50, 10, 10, DST)

	# Legs (stubby)
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
	const SK  := Color(0.93, 0.78, 0.64)   # teeth
	const GR  := Color(0.42, 0.42, 0.42)   # metal armor
	const DGR := Color(0.28, 0.28, 0.28)

	var img := Image.create(36, 54, false, Image.FORMAT_RGBA8)

	# Crown base + spikes
	_fr(img, 10, 3, 16, 4, GO)
	img.set_pixel(11, 2, GO); img.set_pixel(12, 1, GO); img.set_pixel(13, 0, GO)
	img.set_pixel(17, 1, GO); img.set_pixel(18, 0, GO); img.set_pixel(19, 1, GO)
	img.set_pixel(23, 2, GO); img.set_pixel(24, 1, GO); img.set_pixel(25, 0, GO)
	# Crown gems
	_fr(img, 13, 3, 3, 3, Color(0.80, 0.10, 0.80))
	_fr(img, 20, 3, 3, 3, Color(0.10, 0.60, 1.00))

	# Big head
	_fc(img, 18, 16, 12, RE)

	# Pointy ears
	_fr(img, 2, 10, 5, 8, RE)
	_fr(img, 29, 10, 5, 8, RE)
	img.set_pixel(3, 8, RE); img.set_pixel(4, 7, RE)
	img.set_pixel(31, 8, RE); img.set_pixel(30, 7, RE)

	# Large glowing eyes
	_fr(img, 8, 11, 6, 6, YE)
	_fr(img, 22, 11, 6, 6, YE)
	_fr(img, 9, 12, 4, 4, Color(1.0, 0.95, 0.20))
	_fr(img, 23, 12, 4, 4, Color(1.0, 0.95, 0.20))
	_fr(img, 10, 13, 2, 2, BK)
	_fr(img, 24, 13, 2, 2, BK)

	# War scar
	img.set_pixel(16, 16, DRE); img.set_pixel(17, 17, DRE)
	img.set_pixel(18, 16, DRE); img.set_pixel(19, 17, DRE)

	# Nose + fang mouth
	_fr(img, 17, 19, 3, 2, DRE)
	_fr(img, 10, 23, 16, 3, BK)
	_fr(img, 11, 23, 3, 4, SK)    # left fang
	_fr(img, 22, 23, 3, 4, SK)    # right fang
	_fr(img, 14, 23, 8, 2, SK)    # teeth row

	# Shoulder armor
	_fr(img, 6, 27, 24, 5, GR)
	_fr(img, 5, 25, 3, 8, DGR)    # left spike
	_fr(img, 28, 25, 3, 8, DGR)   # right spike

	# Arms
	_fr(img, 3, 31, 9, 16, DGR)
	_fr(img, 24, 31, 9, 16, DGR)

	# Body + chest plate
	_fr(img, 10, 31, 16, 16, DRE)
	_fr(img, 12, 32, 12, 12, GR)
	_fr(img, 13, 33, 10, 6, DGR)

	# Belt
	_fr(img, 9, 41, 18, 4, GO)
	_fr(img, 9, 41, 2, 4, DGO)
	_fr(img, 17, 41, 3, 4, Color(1.0, 0.92, 0.30))

	# Hands/claws
	_fc(img, 3, 49, 4, RE)
	_fc(img, 33, 49, 4, RE)
	img.set_pixel(0, 51, DRE); img.set_pixel(1, 52, DRE)
	img.set_pixel(35, 51, DRE); img.set_pixel(34, 52, DRE)

	# Legs + armored boots
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

	# Fading tail
	for i in range(10):
		var a := float(i) / 10.0
		img.set_pixel(i, 4, Color(DM.r, DM.g, DM.b, a * 0.5))
		img.set_pixel(i, 5, Color(BL.r, BL.g, BL.b, a * 0.8))
		img.set_pixel(i, 6, Color(BL.r, BL.g, BL.b, a * 0.8))
		img.set_pixel(i, 7, Color(DM.r, DM.g, DM.b, a * 0.5))

	# Orb core
	_fc(img, 18, 6, 5, BL)
	_fc(img, 18, 6, 3, CY)
	_fc(img, 18, 6, 1, WH)

	# Front tip glow
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

	# Lid
	_fr(img, 2, 8, 28, 7, LBR)
	_fr(img, 3, 9, 26, 2, Color(0.82, 0.62, 0.32))

	# Body
	_fr(img, 2, 14, 28, 16, BR)

	# Gold trim bands
	_fr(img, 2, 14, 28, 2, GO)
	_fr(img, 2, 8, 2, 22, DGO)
	_fr(img, 28, 8, 2, 22, DGO)
	_fr(img, 2, 28, 28, 2, DBR)

	# Wood grain
	_fr(img, 4, 17, 24, 1, DBR)
	_fr(img, 4, 21, 24, 1, DBR)
	_fr(img, 4, 25, 24, 1, DBR)

	# Lock
	_fc(img, 16, 20, 4, GO)
	_fc(img, 16, 20, 2, DGO)
	_fr(img, 15, 20, 2, 3, Color(0.08, 0.08, 0.08))
	img.set_pixel(16, 23, Color(0.08, 0.08, 0.08))

	# Corner plates
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

	# Pedestal
	_fr(img, 4, 20, 8, 4, BASE)
	_fr(img, 3, 22, 10, 2, BASE)

	# Crystal diamond top
	img.set_pixel(8, 1, LGY)
	img.set_pixel(8, 2, LGY)
	_fr(img, 7, 3, 3, 1, LGY)
	_fr(img, 6, 4, 5, 1, GY)
	_fr(img, 5, 5, 7, 1, GY)

	# Crystal body
	_fr(img, 5, 6, 7, 13, GY)
	# Left bright facet
	_fr(img, 5, 6, 2, 13, LGY)
	# Right dark facet
	_fr(img, 10, 6, 2, 13, DGY)

	# Crystal bottom point
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

	# Pedestal
	_fr(img, 4, 20, 8, 4, BASE)
	_fr(img, 3, 22, 10, 2, BASE)

	# Crystal top
	img.set_pixel(8, 1, LBL)
	img.set_pixel(8, 2, LBL)
	_fr(img, 7, 3, 3, 1, LBL)
	_fr(img, 6, 4, 5, 1, BL)
	_fr(img, 5, 5, 7, 1, BL)

	# Crystal body
	_fr(img, 5, 6, 7, 13, BL)
	_fr(img, 5, 6, 2, 13, LBL)    # left bright
	_fr(img, 10, 6, 2, 13, DBL)   # right dark

	# Glowing white inner core
	_fr(img, 7, 8, 3, 9, WH)
	img.set_pixel(7, 8, LBL); img.set_pixel(9, 8, LBL)
	img.set_pixel(7, 16, LBL); img.set_pixel(9, 16, LBL)

	# Bottom
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

	# Brick rows
	_fr(img, 1, 1, 13, 9, LWL)
	_fr(img, 16, 1, 15, 9, LWL)
	_fr(img, 8, 12, 16, 9, LWL)
	_fr(img, 0, 12, 7, 9, LWL)
	_fr(img, 25, 12, 7, 9, LWL)
	_fr(img, 1, 22, 13, 9, LWL)
	_fr(img, 16, 22, 15, 9, LWL)

	# Mortar lines
	_fr(img, 0, 11, 32, 2, DWL)
	_fr(img, 0, 22, 32, 1, DWL)
	img.set_pixel(15, 0, DWL); img.set_pixel(15, 1, DWL); img.set_pixel(15, 2, DWL)
	img.set_pixel(15, 3, DWL); img.set_pixel(15, 4, DWL); img.set_pixel(15, 5, DWL)
	img.set_pixel(15, 6, DWL); img.set_pixel(15, 7, DWL); img.set_pixel(15, 8, DWL)
	img.set_pixel(8, 13, DWL); img.set_pixel(8, 14, DWL); img.set_pixel(8, 15, DWL)
	img.set_pixel(8, 16, DWL); img.set_pixel(8, 17, DWL); img.set_pixel(8, 18, DWL)
	img.set_pixel(24, 13, DWL); img.set_pixel(24, 14, DWL); img.set_pixel(24, 15, DWL)
	img.set_pixel(24, 16, DWL); img.set_pixel(24, 17, DWL); img.set_pixel(24, 18, DWL)
	img.set_pixel(15, 23, DWL); img.set_pixel(15, 24, DWL); img.set_pixel(15, 25, DWL)
	img.set_pixel(15, 26, DWL); img.set_pixel(15, 27, DWL); img.set_pixel(15, 28, DWL)

	_store("bg_stone", img)
