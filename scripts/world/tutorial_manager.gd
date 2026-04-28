extends Node

const GolemScene   = preload("res://scenes/enemies/golem.tscn")
const GoblinScene  = preload("res://scenes/enemies/goblin.tscn")
const LeaderScene  = preload("res://scenes/enemies/goblin_leader.tscn")

@onready var player         = get_tree().get_first_node_in_group("player")
@onready var dialogue_box   = $"../DialogueBox"
@onready var skill_popup    = $"../SkillPopup"
@onready var enemies        = $"../Enemies"
@onready var tower_door     = $"../Environment/TowerDoor"
@onready var blockade       = $"../Environment/Blockade"
@onready var chest_trigger  = $"../Triggers/ChestTrigger"
@onready var flee_trigger   = $"../Triggers/FleeTrigger"
@onready var horde_trigger  = $"../Triggers/HordeTrigger"
@onready var chest_visual   = $"../Environment/Chest"

var _heal_shown: bool = false

func _ready() -> void:
	call_deferred("_start")

func _start() -> void:
	await _say([
		"Um cajado mágico... ele está me chamando.",
		"Vou pegá-lo.",
	], ["Maga", "Maga"])
	chest_trigger.body_entered.connect(_on_chest, CONNECT_ONE_SHOT)

# ── Golens ───────────────────────────────────────────────────────────────────

func _on_chest(body: Node) -> void:
	if not body.is_in_group("player"): return
	chest_trigger.monitoring = false
	if is_instance_valid(chest_visual):
		chest_visual.queue_free()
	AudioManager.play("chest")
	await _say([
		"As defesas mágicas da torre foram ativadas!",
		"Golens de Pedra!",
	], ["", ""])
	_spawn(GolemScene, Vector2(520, 464))
	_spawn(GolemScene, Vector2(610, 464))
	SkillManager.unlock("time_stop")
	await _say(["Parar o Tempo deve funcionar! Pressione X."], ["Dica"])
	await skill_popup.show_skill("time_stop")
	await _wait_clear()
	await _say(["Preciso fugir desta torre!"], ["Maga"])
	if is_instance_valid(tower_door):
		tower_door.queue_free()
	flee_trigger.body_entered.connect(_on_fled, CONNECT_ONE_SHOT)

# ── Fuga / Goblins ───────────────────────────────────────────────────────────

func _on_fled(body: Node) -> void:
	if not body.is_in_group("player"): return
	_spawn(GoblinScene, Vector2(950, 464))
	_spawn(GoblinScene, Vector2(1050, 464))
	_spawn(GoblinScene, Vector2(1150, 464))
	player.hp.hp_changed.connect(_on_player_hurt)
	_fled_fallback()

func _fled_fallback() -> void:
	await _wait_clear()
	if not _heal_shown:
		_heal_shown = true
		if player.hp.hp_changed.is_connected(_on_player_hurt):
			player.hp.hp_changed.disconnect(_on_player_hurt)
		_teach_heal()

func _on_player_hurt(ratio: float) -> void:
	if ratio < 0.85 and not _heal_shown:
		_heal_shown = true
		player.hp.hp_changed.disconnect(_on_player_hurt)
		_teach_heal()

func _teach_heal() -> void:
	SkillManager.unlock("heal")
	await _say(["Estou ferida! Use Cura para recuperar HP — Pressione C."], ["Dica"])
	await skill_popup.show_skill("heal")
	await _wait_clear()
	await _say(["Quem está bloqueando o caminho?"], ["Maga"])
	_begin_leader()

# ── Goblin Líder ─────────────────────────────────────────────────────────────

func _begin_leader() -> void:
	SkillManager.unlock("magic_missile")
	await _say([
		"Um Goblin Líder! Ele não vai passar assim.",
		"Use Míssil Mágico para derrotá-lo — Pressione Z.",
	], ["", "Dica"])
	await skill_popup.show_skill("magic_missile")
	var leader = _spawn(LeaderScene, Vector2(1640, 455))
	leader.tree_exiting.connect(_on_leader_dead, CONNECT_ONE_SHOT)

func _on_leader_dead() -> void:
	if is_instance_valid(blockade):
		blockade.queue_free()
	await _say(["O caminho está livre! Mas... o que é isso?"], ["Maga"])
	horde_trigger.body_entered.connect(_on_horde, CONNECT_ONE_SHOT)

# ── Horda + Cutscene ─────────────────────────────────────────────────────────

func _on_horde(body: Node) -> void:
	if not body.is_in_group("player"): return
	horde_trigger.monitoring = false
	for i in 7:
		_spawn(GoblinScene, Vector2(2150 + i * 85, 464))
	await get_tree().create_timer(1.6).timeout
	_fireball_cutscene()

func _fireball_cutscene() -> void:
	player.set_cutscene(true)
	AudioManager.play("fireball")

	var flash = ColorRect.new()
	flash.anchor_right = 1.0
	flash.anchor_bottom = 1.0
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = Color(1.0, 0.45, 0.0, 0.0)
	flash.z_index = 100
	get_tree().root.add_child(flash)

	var tw = create_tween()
	tw.tween_property(flash, "color:a", 0.85, 0.25)
	tw.tween_property(flash, "color:a", 0.0,  0.60)
	tw.tween_callback(flash.queue_free)

	await get_tree().create_timer(0.4).timeout
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(enemy):
			enemy.queue_free()

	await get_tree().create_timer(1.0).timeout
	player.set_cutscene(false)

	await _say([
		"...",
		"Não importa qual é o problema —",
		"Bola de Fogo sempre é a melhor solução.",
		"Você tem potencial, aprendiz.",
		"Vá — aprenda Fireball.",
	], ["", "Mago Graduado", "Mago Graduado", "Mago Graduado", "Mago Graduado"])

	SkillManager.unlock("magic_dash")
	await _say(["Dash Mágico desbloqueado! Pressione Shift para deslizar."], ["Dica"])
	await skill_popup.show_skill("magic_dash")

	await _say([
		"A grande aventura começa agora...",
		"(Use Z X C Shift Q para testar suas habilidades)",
	], ["", ""])

# ── Helpers ───────────────────────────────────────────────────────────────────

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
	return node
