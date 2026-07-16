extends Node
## Orquestra o slice jogavel da Torre dos Magos: atrio -> corredor -> CAMARA DA
## STAFF. A Soph entra na camara, os golens guardioes despertam; ao limpar a
## sala, o cajado no pedestal se ergue e voa pra ela (a maga recupera sua arma).
## Uma porta arcana trancada na parede do fundo insinua a torre exploravel que
## vem depois (metroidvania — arquitetura pronta pra crescer em salas conectadas).

const GolemScene = preload("res://scenes/enemies/golem.tscn")

@onready var player          = get_tree().get_first_node_in_group("player")
@onready var dialogue_box    = $"../DialogueBox"
@onready var skill_popup     = $"../SkillPopup"
@onready var enemies         = $"../Enemies"
@onready var chamber_trigger = $"../Triggers/ChamberTrigger"
@onready var pedestal        = $"../Environment/StaffPedestal"
@onready var future_door     = $"../Doors/FutureDoor"

var _staff: Node2D = null
var _done := false

func _ready() -> void:
	GameState.reset_state()
	GameState.fade_in()
	call_deferred("_start")

func _start() -> void:
	GameState.start_session()
	if MusicManager.has_method("play"):
		MusicManager.play("tower")
	_place_staff()
	await _say([
		"A Torre dos Magos... abandonada há tanto tempo.",
		"Foi aqui que perdi meu cajado. Sinto a mana dele pulsando adiante.",
		"Guardiões de pedra ainda rondam os corredores. Cuidado, Soph.",
	], ["Soph", "Soph", "Soph"])
	if chamber_trigger:
		chamber_trigger.body_entered.connect(_on_chamber, CONNECT_ONE_SHOT)

# ── Câmara da staff: os golens guardiões despertam ───────────────────────────

func _on_chamber(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if chamber_trigger:
		chamber_trigger.monitoring = false
	await _say([
		"Ali! Meu cajado, no pedestal.",
		"E os guardiões despertaram. Vou ter que passar por eles.",
	], ["Soph", "Soph"])
	AudioManager.play("roar")
	_spawn(GolemScene, Vector2(1980, 466))
	_spawn(GolemScene, Vector2(2260, 466))
	_spawn(GolemScene, Vector2(2500, 466))
	await _wait_clear()
	await _reclaim_staff()

# ── A maga recupera o cajado (o pedestal se abre, a staff voa pra ela) ────────

func _reclaim_staff() -> void:
	if _done:
		return
	_done = true
	await _say(["Silêncio de novo. Agora... meu cajado."], ["Soph"])
	AudioManager.play("boss_appear")
	var to := player.global_position + Vector2(0, -18) if is_instance_valid(player) \
			else pedestal.global_position + Vector2(0, -80)
	if is_instance_valid(_staff):
		VFX.ring(_staff.global_position, get_parent(), Color(0.6, 0.35, 1.0, 0.9), 40.0, 0.5)
		var tw := _staff.create_tween()
		tw.tween_property(_staff, "global_position", _staff.global_position + Vector2(0, -30), 0.4)\
			.set_trans(Tween.TRANS_SINE)
		tw.tween_property(_staff, "global_position", to, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(_staff, "scale", Vector2(0.2, 0.2), 0.5)
		tw.tween_callback(_staff.queue_free)
		await tw.finished
	if is_instance_valid(player) and player.has_method("shake"):
		player.shake(6.0, 0.3)
	VFX.burst(to, get_parent(), Color(0.55, 0.30, 0.95), 26, 150.0, 40.0)
	SkillManager.unlock("magic_missile")
	if skill_popup and skill_popup.has_method("show_skill"):
		await skill_popup.show_skill("magic_missile")
	await _say([
		"De volta às minhas mãos. A mana flui outra vez.",
		"Aquela porta selada no fundo... a torre guarda muito mais.",
		"Mas primeiro: o Fireball. A floresta me espera lá fora.",
	], ["Soph", "Soph", "Soph"])
	# insinua a expansao: o selo da porta do fundo pulsa (fica trancada de proposito)
	if future_door and future_door.has_method("unlock"):
		pass   # future_door segue trancada — e' o gancho da area exploravel

# ── O cajado no pedestal (sprite procedural: haste + orbe de mana) ───────────

func _place_staff() -> void:
	if pedestal == null:
		return
	_staff = Node2D.new()
	_staff.global_position = pedestal.global_position + Vector2(0, -40)
	get_parent().add_child(_staff)
	# haste
	var shaft := Line2D.new()
	shaft.points = PackedVector2Array([Vector2(0, 24), Vector2(-2, -18)])
	shaft.width = 4.0
	shaft.default_color = Color(0.42, 0.30, 0.20)
	_staff.add_child(shaft)
	# orbe de mana no topo (glow aditivo pulsante)
	var orb := Sprite2D.new()
	orb.texture = _soft_tex()
	orb.scale = Vector2(0.5, 0.5)
	orb.position = Vector2(-2, -22)
	orb.modulate = Color(0.55, 0.35, 1.0, 0.95)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	orb.material = m
	_staff.add_child(orb)
	var tw := orb.create_tween().set_loops()
	tw.tween_property(orb, "scale", Vector2(0.62, 0.62), 0.9).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(orb, "scale", Vector2(0.5, 0.5), 0.9).set_ease(Tween.EASE_IN_OUT)
	# feixe de luz subindo do pedestal
	VFX.ring(pedestal.global_position + Vector2(0, -20), get_parent(),
			Color(0.55, 0.35, 1.0, 0.7), 30.0, 0.6)

func _soft_tex() -> Texture2D:
	var s := 32
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var c := (s - 1) * 0.5
	for y in range(s):
		for x in range(s):
			var d := Vector2(x - c, y - c).length() / c
			img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d, 0.0, 1.0) ** 2))
	return ImageTexture.create_from_image(img)

# ── Helpers (mesmo padrao do dungeon_manager) ────────────────────────────────

func _say(lines: Array, names: Array = []) -> void:
	GameState.dialogue_active = true
	dialogue_box.show_dialogue(lines, names)
	await dialogue_box.dialogue_finished
	GameState.dialogue_active = false

func _wait_clear() -> void:
	while get_tree().get_nodes_in_group("enemy").size() > 0:
		await get_tree().create_timer(0.4).timeout

func _spawn(scene: PackedScene, pos: Vector2) -> Node:
	var node = scene.instantiate()
	node.position = pos
	enemies.add_child(node)
	VFX.burst(Vector2(pos.x, pos.y - 20), enemies, Color(0.45, 0.30, 0.75), 14, 85.0, -45.0)
	return node
