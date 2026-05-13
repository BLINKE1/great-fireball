extends CanvasLayer

@onready var hp_bar:          ProgressBar = $Margin/VBox/HPBar
@onready var mana_bar:        ProgressBar = $Margin/VBox/ManaBar
@onready var time_stop_overlay: ColorRect = $TimeStopOverlay

# Skills shown in the bar (order matters)
const SKILLS = [
	{"name": "sword",         "key": "Q",   "color": Color(0.95, 0.72, 0.12)},
	{"name": "magic_missile", "key": "Z",   "color": Color(0.22, 0.82, 1.00)},
	{"name": "time_stop",     "key": "X",   "color": Color(0.55, 0.38, 1.00)},
	{"name": "heal",          "key": "C",   "color": Color(0.22, 0.90, 0.44)},
	{"name": "magic_dash",    "key": "Shft","color": Color(0.12, 0.88, 1.00)},
	{"name": "double_jump",   "key": "↑↑",  "color": Color(0.60, 0.85, 1.00)},
]

var _skill_fills:   Array[ColorRect] = []
var _cd_overlays:   Array[ColorRect] = []
var _player: Node = null
var _mana_flash_timer: float = 0.0

func _ready() -> void:
	GameState.time_stop_started.connect(_on_time_stop_start)
	GameState.time_stop_ended.connect(func(): time_stop_overlay.visible = false)
	call_deferred("_connect_to_player")
	_build_skill_bar()

func _connect_to_player() -> void:
	_player = get_tree().get_first_node_in_group("player")
	if not _player:
		return
	_player.hp.hp_changed.connect(_on_hp_changed)
	_player.mana.mana_changed.connect(_on_mana_changed)
	_player.mana.mana_depleted.connect(_on_mana_depleted)
	_on_hp_changed(_player.hp.get_ratio())
	_on_mana_changed(_player.mana.get_ratio())

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

# ── Skill bar ─────────────────────────────────────────────────────────────────

func _build_skill_bar() -> void:
	var row := HBoxContainer.new()
	row.position = Vector2(10, 80)
	row.add_theme_constant_override("separation", 3)
	add_child(row)

	for s in SKILLS:
		# Outer background box
		var bg := ColorRect.new()
		bg.custom_minimum_size = Vector2(32, 32)
		bg.color = Color(0.06, 0.06, 0.10, 0.88)
		row.add_child(bg)

		# Colored fill (skill color, shown when unlocked)
		var fill := ColorRect.new()
		fill.size = Vector2(32, 32)
		fill.color = s["color"]
		fill.color.a = 0.0
		bg.add_child(fill)
		_skill_fills.append(fill)

		# Key label (top-left corner)
		var key := Label.new()
		key.text = s["key"]
		key.position = Vector2(2, 1)
		key.add_theme_font_size_override("font_size", 8)
		key.modulate = Color(1, 1, 1, 0.80)
		bg.add_child(key)

		# Cooldown/locked darkening overlay (top-down drain)
		var cd := ColorRect.new()
		cd.size = Vector2(32, 0)
		cd.position = Vector2(0, 0)
		cd.color = Color(0, 0, 0, 0.72)
		bg.add_child(cd)
		_cd_overlays.append(cd)

func _process(delta: float) -> void:
	if not _player or not is_instance_valid(_player):
		return

	# Low HP pulse: red flash below 25%
	if hp_bar.value < 25.0:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.0085)
		hp_bar.modulate = Color(1.0, 0.42 + pulse * 0.30, 0.42 + pulse * 0.30)
	else:
		hp_bar.modulate = Color.WHITE

	# Mana bar flash when depleted
	if _mana_flash_timer > 0.0:
		_mana_flash_timer = maxf(_mana_flash_timer - delta, 0.0)
		var f := _mana_flash_timer / 0.42
		mana_bar.modulate = Color(1.0 + f * 0.6, 0.5 - f * 0.4, 0.5 - f * 0.4)
	else:
		mana_bar.modulate = Color.WHITE

	for i in SKILLS.size():
		var sname: String = SKILLS[i]["name"]
		var unlocked: bool = SkillManager.has(sname)

		# Toggle color fill visibility
		_skill_fills[i].color.a = 0.82 if unlocked else 0.0

		if unlocked and _player.has_method("get_skill_cooldown"):
			var cd_ratio: float = clampf(_player.get_skill_cooldown(sname), 0.0, 1.0)
			_cd_overlays[i].size.y = 32.0 * cd_ratio
		else:
			# Locked skill: full dark overlay
			_cd_overlays[i].size.y = 32.0 if not unlocked else 0.0
