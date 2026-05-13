extends CanvasLayer

@onready var hp_bar:            ProgressBar = $Margin/VBox/HPRow/HPBar
@onready var mana_bar:          ProgressBar = $Margin/VBox/ManaRow/ManaBar
@onready var time_stop_overlay: ColorRect   = $TimeStopOverlay

const SKILLS = [
	{"name": "sword",           "key": "Q",    "symbol": "⚔",  "color": Color(0.95, 0.72, 0.12)},
	{"name": "magic_missile",   "key": "Z",    "symbol": "✦",  "color": Color(0.22, 0.82, 1.00)},
	{"name": "missile_spread",  "key": "A",    "symbol": "❊",  "color": Color(0.80, 0.35, 1.00)},
	{"name": "missile_piercing","key": "S",    "symbol": "→",  "color": Color(0.10, 0.95, 0.60)},
	{"name": "missile_giant",   "key": "D",    "symbol": "◉",  "color": Color(0.40, 0.90, 1.00)},
	{"name": "missile_curved",  "key": "E",    "symbol": "↺",  "color": Color(0.62, 0.18, 1.00)},
	{"name": "time_stop",       "key": "X",    "symbol": "⏸",  "color": Color(0.55, 0.38, 1.00)},
	{"name": "heal",            "key": "C",    "symbol": "♥",  "color": Color(0.22, 0.90, 0.44)},
	{"name": "magic_dash",      "key": "Shft", "symbol": "»",  "color": Color(0.12, 0.88, 1.00)},
	{"name": "double_jump",     "key": "↑↑",   "symbol": "↑",  "color": Color(0.60, 0.85, 1.00)},
]

var _skill_panels:  Array[ColorRect] = []
var _skill_borders: Array[ColorRect] = []
var _skill_fills:   Array[ColorRect] = []
var _cd_overlays:   Array[ColorRect] = []
var _player: Node = null
var _mana_flash_timer: float = 0.0

func _ready() -> void:
	GameState.time_stop_started.connect(_on_time_stop_start)
	GameState.time_stop_ended.connect(func(): time_stop_overlay.visible = false)
	call_deferred("_setup_bars")
	call_deferred("_build_skill_bar")
	call_deferred("_connect_to_player")

func _connect_to_player() -> void:
	_player = get_tree().get_first_node_in_group("player")
	if not _player:
		return
	_player.hp.hp_changed.connect(_on_hp_changed)
	_player.mana.mana_changed.connect(_on_mana_changed)
	_player.mana.mana_depleted.connect(_on_mana_depleted)
	_on_hp_changed(_player.hp.get_ratio())
	_on_mana_changed(_player.mana.get_ratio())

# ── Bar styling ───────────────────────────────────────────────────────────────

func _setup_bars() -> void:
	# HP bar
	var hp_fill := StyleBoxFlat.new()
	hp_fill.bg_color = Color(0.88, 0.18, 0.12)
	hp_fill.corner_radius_top_left    = 3
	hp_fill.corner_radius_top_right   = 3
	hp_fill.corner_radius_bottom_left = 3
	hp_fill.corner_radius_bottom_right= 3
	hp_bar.add_theme_stylebox_override("fill", hp_fill)

	var hp_bg := StyleBoxFlat.new()
	hp_bg.bg_color = Color(0.14, 0.04, 0.04, 0.92)
	hp_bg.border_width_left   = 1
	hp_bg.border_width_right  = 1
	hp_bg.border_width_top    = 1
	hp_bg.border_width_bottom = 1
	hp_bg.border_color = Color(0.60, 0.12, 0.10, 0.85)
	hp_bg.corner_radius_top_left     = 3
	hp_bg.corner_radius_top_right    = 3
	hp_bg.corner_radius_bottom_left  = 3
	hp_bg.corner_radius_bottom_right = 3
	hp_bar.add_theme_stylebox_override("background", hp_bg)

	# Mana bar
	var mp_fill := StyleBoxFlat.new()
	mp_fill.bg_color = Color(0.15, 0.55, 0.95)
	mp_fill.corner_radius_top_left    = 3
	mp_fill.corner_radius_top_right   = 3
	mp_fill.corner_radius_bottom_left = 3
	mp_fill.corner_radius_bottom_right= 3
	mana_bar.add_theme_stylebox_override("fill", mp_fill)

	var mp_bg := StyleBoxFlat.new()
	mp_bg.bg_color = Color(0.04, 0.06, 0.18, 0.92)
	mp_bg.border_width_left   = 1
	mp_bg.border_width_right  = 1
	mp_bg.border_width_top    = 1
	mp_bg.border_width_bottom = 1
	mp_bg.border_color = Color(0.12, 0.30, 0.72, 0.85)
	mp_bg.corner_radius_top_left     = 3
	mp_bg.corner_radius_top_right    = 3
	mp_bg.corner_radius_bottom_left  = 3
	mp_bg.corner_radius_bottom_right = 3
	mana_bar.add_theme_stylebox_override("background", mp_bg)

# ── Skill bar ─────────────────────────────────────────────────────────────────

func _build_skill_bar() -> void:
	var row := HBoxContainer.new()
	row.position = Vector2(8, 82)
	row.add_theme_constant_override("separation", 3)
	add_child(row)

	for s in SKILLS:
		var col: Color = s["color"]

		# Outer border frame
		var border := ColorRect.new()
		border.custom_minimum_size = Vector2(36, 36)
		border.color = Color(col.r * 0.45, col.g * 0.45, col.b * 0.45, 0.55)
		row.add_child(border)
		_skill_borders.append(border)

		# Inner dark background
		var bg := ColorRect.new()
		bg.color = Color(0.05, 0.04, 0.10, 0.92)
		bg.position = Vector2(1, 1)
		bg.size = Vector2(34, 34)
		border.add_child(bg)
		_skill_panels.append(bg)

		# Colored fill (shown when unlocked & active)
		var fill := ColorRect.new()
		fill.color = Color(col.r, col.g, col.b, 0.0)
		fill.size = Vector2(34, 34)
		bg.add_child(fill)
		_skill_fills.append(fill)

		# Symbol label (centered)
		var sym := Label.new()
		sym.text = s["symbol"]
		sym.set_anchors_preset(Control.PRESET_CENTER)
		sym.position = Vector2(6, 5)
		sym.add_theme_font_size_override("font_size", 14)
		sym.modulate = Color(col.r, col.g, col.b, 0.85)
		bg.add_child(sym)

		# Key label (bottom-right)
		var key := Label.new()
		key.text = s["key"]
		key.position = Vector2(2, 23)
		key.add_theme_font_size_override("font_size", 8)
		key.modulate = Color(0.78, 0.78, 0.78, 0.75)
		bg.add_child(key)

		# Cooldown/locked dark overlay (top-down drain)
		var cd := ColorRect.new()
		cd.size = Vector2(34, 0)
		cd.position = Vector2(0, 0)
		cd.color = Color(0, 0, 0, 0.78)
		bg.add_child(cd)
		_cd_overlays.append(cd)

func _on_hp_changed(ratio: float) -> void:
	hp_bar.value = ratio * 100.0

func _on_mana_changed(ratio: float) -> void:
	mana_bar.value = ratio * 100.0

func _on_time_stop_start() -> void:
	time_stop_overlay.visible = true
	var tw := time_stop_overlay.create_tween()
	tw.tween_property(time_stop_overlay, "modulate:a", 2.2, 0.07)
	tw.tween_property(time_stop_overlay, "modulate:a", 1.0, 0.28)

func _on_mana_depleted() -> void:
	AudioManager.play("no_mana")
	_mana_flash_timer = 0.42

func _process(delta: float) -> void:
	if not _player or not is_instance_valid(_player):
		return

	# Low HP pulse
	if hp_bar.value < 25.0:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.0085)
		hp_bar.modulate = Color(1.0, 0.42 + pulse * 0.30, 0.42 + pulse * 0.30)
	else:
		hp_bar.modulate = Color.WHITE

	if _mana_flash_timer > 0.0:
		_mana_flash_timer = maxf(_mana_flash_timer - delta, 0.0)
		var f := _mana_flash_timer / 0.42
		mana_bar.modulate = Color(1.0 + f * 0.6, 0.5 - f * 0.4, 0.5 - f * 0.4)
	else:
		mana_bar.modulate = Color.WHITE

	for i in SKILLS.size():
		var sname: String = SKILLS[i]["name"]
		var col: Color    = SKILLS[i]["color"]
		var unlocked: bool = SkillManager.has(sname)

		# Border brightens when unlocked
		_skill_borders[i].color = Color(
			col.r * (0.7 if unlocked else 0.3),
			col.g * (0.7 if unlocked else 0.3),
			col.b * (0.7 if unlocked else 0.3),
			0.80 if unlocked else 0.40
		)

		_skill_fills[i].color.a = 0.18 if unlocked else 0.0

		if unlocked and _player.has_method("get_skill_cooldown"):
			var cd_ratio: float = clampf(_player.get_skill_cooldown(sname), 0.0, 1.0)
			_cd_overlays[i].size.y = 34.0 * cd_ratio
		else:
			_cd_overlays[i].size.y = 34.0 if not unlocked else 0.0
