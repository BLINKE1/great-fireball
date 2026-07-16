extends Node
## Orquestra a Torre dos Magos (metroidvania). Progressao:
##   átrio -> SALÃO DOS GUARDIÕES (golens ambiente) -> POÇO (subida + segredo no
##   topo) -> CÂMARA DA STAFF (golens guardioes + o cajado) -> [porta selada
##   abre com a staff] -> ALA SELADA (golem-elite + tesouro) -> CUME (saida pra
##   floresta). A staff e' a "chave" que destranca a ala — loop metroidvania.

const GolemScene = preload("res://scenes/enemies/golem.tscn")

@onready var player          = get_tree().get_first_node_in_group("player")
@onready var dialogue_box    = $"../DialogueBox"
@onready var skill_popup     = $"../SkillPopup"
@onready var enemies         = $"../Enemies"
@onready var guard_trigger   = $"../Triggers/GuardTrigger"
@onready var chamber_trigger = $"../Triggers/ChamberTrigger"
@onready var wing_trigger    = $"../Triggers/WingTrigger"
@onready var pedestal        = $"../Environment/StaffPedestal"
@onready var sealed_door     = $"../Doors/SealedDoor"

var _staff: Node2D = null
var _got_staff := false

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
		"Foi aqui que perdi meu cajado. Sinto a mana dele pulsando lá no alto.",
		"Guardiões de pedra ainda rondam. Cuidado, Soph.",
	], ["Soph", "Soph", "Soph"])
	if guard_trigger:
		guard_trigger.body_entered.connect(_on_guard, CONNECT_ONE_SHOT)
	if chamber_trigger:
		chamber_trigger.body_entered.connect(_on_chamber, CONNECT_ONE_SHOT)

# ── Salão dos Guardiões: golens ambiente (nao trava a passagem) ──────────────

func _on_guard(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if guard_trigger:
		guard_trigger.monitoring = false
	await _say(["Guardiões! Pedra viva. A espada arranha; a magia dói mais."], ["Soph"])
	AudioManager.play("roar", 0.9)
	_spawn(GolemScene, Vector2(1180, 466))
	_spawn(GolemScene, Vector2(1360, 466))

# ── Câmara da Staff: os guardioes despertam; limpar libera o cajado ──────────

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
	var guardians := [
		_spawn(GolemScene, Vector2(2360, 466)),
		_spawn(GolemScene, Vector2(2620, 466)),
		_spawn(GolemScene, Vector2(2820, 466)),
	]
	await _wait_for(guardians)
	await _reclaim_staff()

# ── A maga recupera o cajado -> a porta selada abre (a staff e' a chave) ──────

func _reclaim_staff() -> void:
	if _got_staff:
		return
	_got_staff = true
	await _say(["Silêncio de novo. Agora... meu cajado."], ["Soph"])
	AudioManager.play("boss_appear")
	var to: Vector2 = (player.global_position + Vector2(0, -18)) if is_instance_valid(player) \
			else (pedestal.global_position + Vector2(0, -80))
	if is_instance_valid(_staff):
		VFX.ring(_staff.global_position, get_parent(), Color(0.6, 0.35, 1.0, 0.9), 40.0, 0.5)
		var tw := _staff.create_tween()
		tw.tween_property(_staff, "global_position", _staff.global_position + Vector2(0, -30), 0.4).set_trans(Tween.TRANS_SINE)
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
		"A porta selada... o cajado é a chave. O selo cede!",
	], ["Soph", "Soph"])
	if sealed_door and sealed_door.has_method("unlock"):
		sealed_door.unlock()
	if wing_trigger:
		wing_trigger.body_entered.connect(_on_wing, CONNECT_ONE_SHOT)

# ── Ala Selada: golem-elite guardando o caminho ao cume ──────────────────────

func _on_wing(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if wing_trigger:
		wing_trigger.monitoring = false
	await _say([
		"Um guardião maior... o coração de pedra da torre.",
		"Passo por ele e chego ao topo — e à saída pra floresta.",
	], ["Soph", "Soph"])
	AudioManager.play("roar", 0.7)
	var elite := _spawn(GolemScene, Vector2(3520, 458))
	elite.scale = Vector2(1.5, 1.5)          # elite: maior e mais imponente
	if "hp" in elite:
		elite.hp = 180.0                      # mais duro (barra escala pela vida)
	await _wait_for([elite])
	await _open_summit()

# ── Cume: saida pra floresta ─────────────────────────────────────────────────

func _open_summit() -> void:
	await _say([
		"O caminho está livre. O cume — e o mundo lá fora.",
		"Agora, com o cajado de volta: o Fireball me espera na floresta.",
	], ["Soph", "Soph"])
	var portal := Area2D.new()
	portal.position = Vector2(4050, 462)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(90, 96)
	shape.shape = rect
	portal.add_child(shape)
	var glow := Sprite2D.new()
	glow.texture = _soft_tex()
	glow.scale = Vector2(2.6, 3.2)
	glow.modulate = Color(0.55, 0.35, 1.0, 0.9)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = m
	portal.add_child(glow)
	get_parent().add_child(portal)
	var tw := glow.create_tween().set_loops()
	tw.tween_property(glow, "modulate:a", 0.5, 0.9).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(glow, "modulate:a", 0.95, 0.9).set_ease(Tween.EASE_IN_OUT)
	VFX.ring(portal.position, get_parent(), Color(0.6, 0.4, 1.0, 0.9), 55.0, 0.6)
	AudioManager.play("boss_appear")
	portal.body_entered.connect(_on_portal)

func _on_portal(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if body.has_method("set_cutscene"):
		body.set_cutscene(true)
	GameState.fade_out_then(func():
		get_tree().change_scene_to_file("res://scenes/world/dungeon_1.tscn"))

# ── O cajado no pedestal (sprite procedural: haste + orbe de mana) ───────────

func _place_staff() -> void:
	if pedestal == null:
		return
	_staff = Node2D.new()
	_staff.global_position = pedestal.global_position + Vector2(0, -40)
	get_parent().add_child(_staff)
	var shaft := Line2D.new()
	shaft.points = PackedVector2Array([Vector2(0, 24), Vector2(-2, -18)])
	shaft.width = 4.0
	shaft.default_color = Color(0.42, 0.30, 0.20)
	_staff.add_child(shaft)
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
	VFX.ring(pedestal.global_position + Vector2(0, -20), get_parent(), Color(0.55, 0.35, 1.0, 0.7), 30.0, 0.6)

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

## Espera SO' pelos inimigos deste encontro (golens mortos se auto-liberam ->
## is_instance_valid fica falso). Evita travar por golens de outra sala.
func _wait_for(nodes: Array) -> void:
	while true:
		var alive := false
		for n in nodes:
			if is_instance_valid(n):
				alive = true
				break
		if not alive:
			return
		await get_tree().create_timer(0.35).timeout

func _spawn(scene: PackedScene, pos: Vector2) -> Node:
	var node = scene.instantiate()
	node.position = pos
	enemies.add_child(node)
	VFX.burst(Vector2(pos.x, pos.y - 20), enemies, Color(0.45, 0.30, 0.75), 14, 85.0, -45.0)
	return node
