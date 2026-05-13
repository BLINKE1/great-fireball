extends Node

const GoblinScene          = preload("res://scenes/enemies/goblin.tscn")
const GoblinArcherScene    = preload("res://scenes/enemies/goblin_archer.tscn")
const GolemScene           = preload("res://scenes/enemies/golem.tscn")
const ForestOgreScene      = preload("res://scenes/enemies/forest_ogre.tscn")
const FireGoblinArcherScene = preload("res://scenes/enemies/fire_goblin_archer.tscn")

@onready var player       = get_tree().get_first_node_in_group("player")
@onready var dialogue_box = $"../DialogueBox"
@onready var skill_popup  = $"../SkillPopup"
@onready var boss_hp_bar  = $"../BossHPBar"
@onready var enemies      = $"../Enemies"
@onready var area1_trigger  = $"../Triggers/Area1Trigger"
@onready var area2_trigger  = $"../Triggers/Area2Trigger"
@onready var chest_trigger  = $"../Triggers/ChestTrigger"
@onready var boss_trigger   = $"../Triggers/BossTrigger"

var _area2_done: bool = false

func _ready() -> void:
	GameState.reset_state()
	GameState.fade_in()
	call_deferred("_start")

func _start() -> void:
	GameState.start_session()
	MusicManager.play("game")
	await _say([
		"Que lugar sombrio...",
		"Dizem que um mago antigo escondeu segredos sobre magia avançada nesta floresta.",
		"Preciso aprender tudo o que puder. O caminho até o Fireball é longo.",
		"Vou explorar com cuidado.",
	], ["Soph", "Soph", "Soph", "Soph"])
	area1_trigger.body_entered.connect(_on_area1, CONNECT_ONE_SHOT)

# ── Área 1: Entrada ───────────────────────────────────────────────────────────

func _on_area1(body: Node) -> void:
	if not body.is_in_group("player"): return
	area1_trigger.monitoring = false
	await _say(["Goblins! Eles protegem algo..."], ["Soph"])
	_spawn(GoblinScene,       Vector2(820,  488))
	_spawn(GoblinScene,       Vector2(980,  488))
	_spawn(GoblinArcherScene, Vector2(1150, 488))
	_spawn(GoblinArcherScene, Vector2(1380, 448))
	_spawn(GoblinScene,       Vector2(1260, 488))
	chest_trigger.body_entered.connect(_on_chest, CONNECT_ONE_SHOT)
	await _wait_clear()
	await _say(["Bom. O caminho está livre."], ["Soph"])
	area2_trigger.body_entered.connect(_on_area2, CONNECT_ONE_SHOT)

# ── Baú: Duplo Salto + Míssil Duplo ──────────────────────────────────────────

func _on_chest(body: Node) -> void:
	if not body.is_in_group("player"): return
	chest_trigger.monitoring = false
	AudioManager.play("chest")
	await _say([
		"Um baú escondido!",
		"Botas Encantadas! Elas permitem saltar no ar uma segunda vez.",
	], ["Soph", "Soph"])
	SkillManager.unlock("double_jump")
	await skill_popup.show_skill("double_jump")
	await _say([
		"E há uma inscrição mágica nas paredes...",
		"\"Divida sua intenção e dobre sua força —\nMíssil Duplo.\"",
		"Sinto a técnica fluindo pela minha mente!",
		"Agora posso disparar dois mísseis ao mesmo tempo — pressione A.",
	], ["Soph", "", "Soph", "Dica"])
	SkillManager.unlock("missile_spread")
	await skill_popup.show_skill("missile_spread")

# ── Área 2: Caverna Profunda ──────────────────────────────────────────────────

func _on_area2(body: Node) -> void:
	if not body.is_in_group("player") or _area2_done: return
	_area2_done = true
	area2_trigger.monitoring = false
	await _say([
		"Golens e arqueiros! Eles ficam mais fortes conforme entro mais fundo.",
		"E este lugar é mais fundo do que parece... melhor não cair.",
		"Alturas grandes machucam — e as alturas aqui podem ser letais.",
		"Lembro da dica: Duplo Salto durante a queda amortece o impacto.",
	], ["Soph", "Soph", "Dica", "Dica"])
	_spawn(GolemScene,             Vector2(2400, 488))
	_spawn(GolemScene,             Vector2(2700, 488))
	_spawn(GoblinArcherScene,      Vector2(2900, 448))
	_spawn(FireGoblinArcherScene,  Vector2(3100, 448))
	_spawn(FireGoblinArcherScene,  Vector2(3300, 448))
	_spawn(GoblinScene,            Vector2(2550, 488))
	_spawn(GoblinScene,            Vector2(2800, 488))
	_spawn(GoblinScene,            Vector2(3050, 488))
	await _wait_clear()
	await _say([
		"Consegui!",
		"Outro glifo mágico nas paredes...",
		"\"Concentração. Precisão. Foco singular — Míssil Perfurante.\"",
		"Um míssil que não para. Atravessa tudo em seu caminho — pressione S.",
		"Isto vai ser útil contra o que estiver à frente.",
	], ["Soph", "Soph", "", "Dica", "Soph"])
	SkillManager.unlock("missile_piercing")
	await skill_popup.show_skill("missile_piercing")
	await _say([
		"Há outro glifo mais adiante... Deixa eu ver.",
		"\"A linha reta é o caminho do aprendiz —\no arco, o caminho do mestre.\"",
		"Sinto a trajetória curva tomar forma na minha mente!",
		"Míssil Curvo — pressione E.\nEle sobrevoa obstáculos pelo alto.",
	], ["Soph", "", "Soph", "Dica"])
	SkillManager.unlock("missile_curved")
	await skill_popup.show_skill("missile_curved")
	await _say([
		"Aqueles arqueiros de fogo queimaram minha capa...",
		"Outro glifo — este parece uma barreira de energia.",
		"\"Reflexo é a armadura da mente sábia —\nEscudo Mágico.\"",
		"Escudo Mágico desbloqueado! Pressione F para criar uma barreira temporária.",
	], ["Soph", "Soph", "", "Dica"])
	SkillManager.unlock("magic_shield")
	await skill_popup.show_skill("magic_shield")
	boss_trigger.body_entered.connect(_on_boss_room, CONNECT_ONE_SHOT)

# ── Boss Room: Ogro da Floresta ───────────────────────────────────────────────

func _on_boss_room(body: Node) -> void:
	if not body.is_in_group("player"): return
	boss_trigger.monitoring = false
	await _say([
		"O que é isso?!",
		"Um Ogro enorme... Ele guarda alguma coisa importante.",
		"Não há como evitar. Vou ter que lutar!",
	], ["Soph", "Soph", "Soph"])
	if is_instance_valid(player) and player.has_node("Camera2D"):
		var cam: Camera2D = player.get_node("Camera2D")
		cam.create_tween().tween_property(cam, "zoom", Vector2(1.18, 1.18), 1.4).set_ease(Tween.EASE_IN_OUT)
	MusicManager.play("boss")
	var ogre = _spawn(ForestOgreScene, Vector2(4350, 455))
	boss_hp_bar.show_boss("Ogro da Floresta", ogre)
	ogre.boss_died.connect(_on_ogre_died, CONNECT_ONE_SHOT)

func _on_ogre_died() -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and e.has_method("take_damage"):
			e.take_damage(9999.0, e.global_position)
	MusicManager.play("game")
	AudioManager.play("victory")
	# White flash
	var cl := CanvasLayer.new()
	cl.layer = 45
	get_tree().root.add_child(cl)
	var flash := ColorRect.new()
	flash.anchor_right = 1.0; flash.anchor_bottom = 1.0
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = Color(1.0, 0.92, 0.70, 0.0)
	cl.add_child(flash)
	var ftw := flash.create_tween()
	ftw.tween_property(flash, "color:a", 0.55, 0.12)
	ftw.tween_property(flash, "color:a", 0.0,  0.65)
	ftw.tween_callback(cl.queue_free)
	# Camera zoom restore
	if is_instance_valid(player) and player.has_node("Camera2D"):
		var cam: Camera2D = player.get_node("Camera2D")
		cam.create_tween().tween_property(cam, "zoom", Vector2(1.0, 1.0), 1.8).set_ease(Tween.EASE_IN_OUT)
	await get_tree().create_timer(1.6).timeout
	await _say([
		"Consegui!",
		"... Há um livro antigo nas ruínas atrás dele.",
		"\"O míssil mágico não tem limite de tamanho —",
		"apenas de vontade e de mana.\"",
		"Sinto um poder imenso se concentrando nas minhas mãos...",
		"O Míssil Gigante! Pressione D.",
		"Não é o Fireball... mas é o máximo que posso fazer agora.",
		"\"A chama eterna repousa no coração da Montanha de Cinzas.\"",
		"Minha jornada continua — à Montanha de Cinzas!",
	], ["Soph", "Soph", "", "", "Soph", "Dica", "Soph", "", "Soph"])
	SkillManager.unlock("missile_giant")
	await skill_popup.show_skill("missile_giant")
	_spawn_exit_portal()

func _spawn_exit_portal() -> void:
	var area = Area2D.new()
	area.position = Vector2(5050, 462)
	area.monitoring = true
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(90, 90)
	shape.shape = rect
	area.add_child(shape)
	# Use new portal sprite
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
	tw.tween_property(spr, "modulate", Color(1.0, 0.68, 0.20), 0.9).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(spr, "modulate", Color.WHITE, 0.9).set_ease(Tween.EASE_IN_OUT)
	VFX.burst(Vector2(5050, 440), get_parent(), Color(1.0, 0.60, 0.15), 26, 115.0, 55.0)
	VFX.ring(Vector2(5050, 462), get_parent(), Color(1.0, 0.65, 0.20, 0.90), 55.0, 0.60)
	AudioManager.play("boss_appear")
	await _say([
		"Um portal de saída... A Montanha de Cinzas aguarda.",
	], [""])
	area.body_entered.connect(_on_portal_entered)

func _on_portal_entered(body: Node) -> void:
	if not body.is_in_group("player"): return
	body.set_cutscene(true)
	GameState.fade_out_then(func():
		get_tree().change_scene_to_file("res://scenes/ui/win_screen.tscn")
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
	VFX.burst(Vector2(pos.x, pos.y - 20), enemies, Color(0.60, 0.10, 0.05), 14, 85.0, -45.0)
	return node
