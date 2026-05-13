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
	SkillManager.reset()
	GameState.fade_in()
	call_deferred("_start")

func _start() -> void:
	GameState.start_session()
	MusicManager.play("game")
	await _say([
		"Este cajado...",
		"Sinto uma energia enorme nele. Preciso levá-lo.",
		"Toda aprendiz de magia sonha com o Fireball.",
		"Mas primeiro — preciso sair desta torre.",
	], ["Soph", "Soph", "Soph", "Soph"])
	chest_trigger.body_entered.connect(_on_chest, CONNECT_ONE_SHOT)

# ── Golens ───────────────────────────────────────────────────────────────────

func _on_chest(body: Node) -> void:
	if not body.is_in_group("player"): return
	chest_trigger.monitoring = false
	if is_instance_valid(chest_visual):
		chest_visual.queue_free()
	AudioManager.play("chest")
	await _say([
		"Este cajado pode golpear diretamente — pressione Q para atacar.",
		"As defesas mágicas da torre foram ativadas!",
		"Golens de Pedra!",
	], ["Dica", "", ""])
	_spawn(GolemScene, Vector2(520, 464))
	_spawn(GolemScene, Vector2(610, 464))
	SkillManager.unlock("time_stop")
	await _say(["Parar o Tempo deve funcionar! Pressione X."], ["Dica"])
	await skill_popup.show_skill("time_stop")
	await _wait_clear()
	await _say(["Preciso fugir desta torre!"], ["Soph"])
	if is_instance_valid(tower_door):
		tower_door.queue_free()
	flee_trigger.body_entered.connect(_on_fled, CONNECT_ONE_SHOT)

# ── Fuga / Goblins ───────────────────────────────────────────────────────────

func _on_fled(body: Node) -> void:
	if not body.is_in_group("player"): return
	_spawn(GoblinScene, Vector2(1200, 464))
	_spawn(GoblinScene, Vector2(1300, 464))
	_spawn(GoblinScene, Vector2(1400, 464))
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
	await _say(["Quem está bloqueando o caminho?"], ["Soph"])
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
	await _say(["O caminho está livre! Mas... o que é isso?"], ["Soph"])
	horde_trigger.body_entered.connect(_on_horde, CONNECT_ONE_SHOT)

# ── Horda + Cutscene ─────────────────────────────────────────────────────────

func _on_horde(body: Node) -> void:
	if not body.is_in_group("player"): return
	horde_trigger.monitoring = false
	for i in 8:
		_spawn(GoblinScene, Vector2(2150 + i * 85, 464))
	await get_tree().create_timer(1.6).timeout
	_fireball_cutscene()

func _fireball_cutscene() -> void:
	player.set_cutscene(true)
	AudioManager.play("fireball")

	var cl := CanvasLayer.new()
	cl.layer = 45
	get_tree().root.add_child(cl)
	var flash := ColorRect.new()
	flash.anchor_right = 1.0
	flash.anchor_bottom = 1.0
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = Color(1.0, 0.45, 0.0, 0.0)
	cl.add_child(flash)

	var tw = create_tween()
	tw.tween_property(flash, "color:a", 0.90, 0.20)
	tw.tween_property(flash, "color:a", 0.0,  0.70)
	tw.tween_callback(cl.queue_free)

	# Screen shake
	if is_instance_valid(player) and player.has_method("shake"):
		player.shake(14.0, 0.60)

	await get_tree().create_timer(0.35).timeout
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(enemy):
			VFX.burst(enemy.global_position, enemy.get_parent(), Color(1.0, 0.50, 0.05), 8, 55.0, -20.0)
			enemy.queue_free()

	await get_tree().create_timer(1.1).timeout
	player.set_cutscene(false)

	await _say([
		"...",
		"O que foi isso?!",
	], ["", "Soph"])

	# Add dramatic pause before mage speaks from the tower
	await get_tree().create_timer(0.5).timeout

	await _say([
		"Não importa o tamanho do problema —",
		"Bola de Fogo é sempre a melhor solução.",
	], ["Mago Graduado", "Mago Graduado"])

	# Second screen pulse — mage disappears
	var cl2 := CanvasLayer.new()
	cl2.layer = 44
	get_tree().root.add_child(cl2)
	var flash2 := ColorRect.new()
	flash2.anchor_right = 1.0
	flash2.anchor_bottom = 1.0
	flash2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash2.color = Color(1.0, 0.65, 0.0, 0.0)
	cl2.add_child(flash2)
	var tw2 = create_tween()
	tw2.tween_property(flash2, "color:a", 0.35, 0.15)
	tw2.tween_property(flash2, "color:a", 0.0,  0.50)
	tw2.tween_callback(cl2.queue_free)

	await _say([
		"...",
		"Ele foi embora.",
		"Que poder...",
		"Não importa o que aconteça — vou aprender tudo sobre magia.",
		"E um dia... vou chegar lá.",
	], ["", "Soph", "Soph", "Soph", "Soph"])

	SkillManager.unlock("magic_dash")
	await _say(["Dash Mágico desbloqueado! Pressione Shift para deslizar."], ["Dica"])
	await skill_popup.show_skill("magic_dash")

	await _say([
		"A floresta encantada me chama.",
		"Mas cuidado — a queda de lugares altos machuca.",
		"Quanto maior a altura, maior o dano — quedas muito altas são letais.",
		"O Duplo Salto pode amortecer a queda: use-o na descida para dividir o dano em dois segmentos.",
		"No timing perfeito, você dobra a altura que pode cair sem se machucar.",
		"Vá para a direita — um portal abrirá o caminho.",
	], ["Soph", "Soph", "Dica", "Dica", "Dica", ""])
	_spawn_exit_portal()

func _spawn_exit_portal() -> void:
	var area = Area2D.new()
	area.position = Vector2(3550, 460)
	area.monitoring = true
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(90, 90)
	shape.shape = rect
	area.add_child(shape)

	var spr = Sprite2D.new()
	var portal_tex = SpriteSetup.get_texture("portal")
	if portal_tex:
		spr.texture = portal_tex
	else:
		spr.texture = SpriteSetup.get_texture("checkpoint_on")
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.scale = Vector2(2.0, 2.0)
	area.add_child(spr)
	get_parent().add_child(area)

	var tw := spr.create_tween().set_loops()
	tw.tween_property(spr, "modulate", Color(0.65, 1.0, 1.0), 0.85).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(spr, "modulate", Color.WHITE, 0.85).set_ease(Tween.EASE_IN_OUT)

	VFX.burst(Vector2(3550, 440), get_parent(), Color(0.35, 0.75, 1.0), 28, 120.0, 55.0)
	VFX.ring(Vector2(3550, 460), get_parent(), Color(0.40, 0.80, 1.0, 0.90), 50.0, 0.55)
	area.body_entered.connect(_on_portal_entered)

func _on_portal_entered(body: Node) -> void:
	if not body.is_in_group("player"): return
	body.set_cutscene(true)
	GameState.fade_out_then(func():
		get_tree().change_scene_to_file("res://scenes/world/dungeon_1.tscn")
	)

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
	VFX.burst(Vector2(pos.x, pos.y - 20), enemies, Color(0.55, 0.08, 0.04), 12, 78.0, -40.0)
	return node
