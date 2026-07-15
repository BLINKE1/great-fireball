extends Node

const GoblinScene          = preload("res://scenes/enemies/goblin.tscn")
const GoblinArcherScene    = preload("res://scenes/enemies/goblin_archer.tscn")
const GoblinLeaderScene    = preload("res://scenes/enemies/goblin_leader.tscn")
const GolemScene           = preload("res://scenes/enemies/golem.tscn")
const ForestOgreScene      = preload("res://scenes/enemies/forest_ogre.tscn")
const GoblinMutantScene    = preload("res://scenes/enemies/goblin_mutant.tscn")
const FireGoblinArcherScene = preload("res://scenes/enemies/fire_goblin_archer.tscn")

@onready var player       = get_tree().get_first_node_in_group("player")
@onready var dialogue_box = $"../DialogueBox"
@onready var skill_popup  = $"../SkillPopup"
@onready var boss_hp_bar  = $"../BossHPBar"
@onready var enemies      = $"../Enemies"
@onready var area1_trigger  = $"../Triggers/Area1Trigger"
@onready var lancer_trigger = $"../Triggers/LancerTrigger"
@onready var area2_trigger  = $"../Triggers/Area2Trigger"
@onready var chest_trigger  = $"../Triggers/ChestTrigger"
@onready var boss_trigger   = $"../Triggers/BossTrigger"

var _area2_done: bool = false
var _boss_gate: Node = null   # parede de pedras que tranca a arena do boss

# ── Loop de retry do boss (HK): morrer -> CONTINUE -> renasce DIRETO na arena ──
var _boss: Node = null
var _boss_fight_active := false
var _attempts := 1
var _awaiting_continue := false
var _continue_layer: CanvasLayer = null

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

# ── Ato 1: o primeiro goblin (aprende o MELEE) ────────────────────────────────

func _on_area1(body: Node) -> void:
	if not body.is_in_group("player"): return
	area1_trigger.monitoring = false
	await _say([
		"Um goblin de guarda! Ele ainda não me viu.",
		"A espada resolve isso: chegue perto e pressione Q.",
	], ["Soph", "Dica"])
	_spawn(GoblinScene, Vector2(820, 488))
	await _wait_clear()
	await _say(["Uma boa lâmina resolve. Mas sinto cheiro de mais goblins..."], ["Soph"])
	lancer_trigger.body_entered.connect(_on_lancer, CONNECT_ONE_SHOT)

# ── Ato 2: o lanceiro (aprende o PARRY — corta a lança no ar) ─────────────────

func _on_lancer(body: Node) -> void:
	if not body.is_in_group("player"): return
	lancer_trigger.monitoring = false
	await _say([
		"Um lanceiro! Ele arremessa a lança de longe.",
		"O golpe da espada (Q) CORTA a lança no ar — no tempo certo.",
		"Aparar um projétil é a marca de uma maga completa.",
	], ["Soph", "Dica", "Soph"])
	_spawn(GoblinArcherScene, Vector2(1600, 488))
	await _wait_clear()
	await _say(["Lanceiros não são nada quando se conhece o tempo do aço."], ["Soph"])
	_spawn(GoblinArcherScene, Vector2(1700, 488))
	_spawn(GoblinScene,       Vector2(1550, 488))
	await _wait_clear()
	await _say(["O caminho está livre — por enquanto."], ["Soph"])
	area2_trigger.body_entered.connect(_on_area2, CONNECT_ONE_SHOT)
	chest_trigger.body_entered.connect(_on_chest, CONNECT_ONE_SHOT)

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

# ── Ato 3: o LÍDER do bando (aprende o HEADSHOT — míssil na jaca) ─────────────

func _on_area2(body: Node) -> void:
	if not body.is_in_group("player") or _area2_done: return
	_area2_done = true
	area2_trigger.monitoring = false
	await _say([
		"O líder do bando! Couraça de metal... a espada mal arranha.",
		"A cabeça é o ponto fraco: mire o Míssil Mágico (Z) na CABEÇA dele.",
		"Um acerto na cabeça causa dano CRÍTICO.",
	], ["Soph", "Dica", "Dica"])
	_spawn(GoblinLeaderScene, Vector2(2450, 488))
	_spawn(GoblinScene,       Vector2(2340, 488))
	await _wait_clear()
	await _say([
		"Eca... sangue verde por toda parte.",
		"Se o líder estava aqui... o que exatamente ele guardava?",
	], ["Soph", "Soph"])
	# reforços na descida (usa tudo que aprendeu: melee + parry + headshot)
	await _say([
		"Mais deles! E golens desta vez — cuidado com as quedas à frente.",
	], ["Soph"])
	_spawn(GolemScene,             Vector2(2900, 488))
	_spawn(GoblinArcherScene,      Vector2(3100, 448))
	_spawn(FireGoblinArcherScene,  Vector2(3300, 448))
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

# ── Boss Room: o Goblin Mutante sai DO MEIO DAS ÁRVORES ──────────────────────

func _on_boss_room(body: Node) -> void:
	if not body.is_in_group("player"): return
	boss_trigger.monitoring = false
	if is_instance_valid(player) and player.has_node("Camera2D"):
		var cam: Camera2D = player.get_node("Camera2D")
		cam.create_tween().tween_property(cam, "zoom", Vector2(1.18, 1.18), 1.4).set_ease(Tween.EASE_IN_OUT)
	MusicManager.play("boss")
	# Tranca a arena: uma avalanche de pedras desaba atrás da Soph (estilo Megaman).
	_boss_gate = _drop_rockwall(4020.0)
	await _say([
		"As pedras desabaram atrás de mim! Não há volta.",
		"O chão está tremendo...",
		"As árvores... TEM ALGUMA COISA NO MEIO DAS ÁRVORES!",
	], ["Soph", "Soph", "Soph"])
	# Retry HK: o respawn passa a ser a PORTA DA ARENA — morrer volta no boss.
	if is_instance_valid(player):
		player.spawn_position = Vector2(4080.0, 458.0)
		if not player.hp.died.is_connected(_on_player_died_in_boss):
			player.hp.died.connect(_on_player_died_in_boss)
	var boss = await _boss_entrance()
	await _say([
		"Um goblin... GIGANTE. Deformado, coberto de bombas e sucata...",
		"O mutante que lidera todos eles. Não há como evitar — vou lutar!",
	], ["Soph", "Soph"])
	_arm_boss(boss)

func _arm_boss(boss: Node) -> void:
	_boss = boss
	_boss_fight_active = true
	boss_hp_bar.show_boss("Goblin Mutante", boss)
	boss.boss_died.connect(_on_ogre_died, CONNECT_ONE_SHOT)

# ── Morte no boss: limpa a arena e oferece o CONTINUE ─────────────────────────

func _on_player_died_in_boss() -> void:
	if not _boss_fight_active:
		return   # morte fora da luta -> fluxo normal de checkpoint
	_boss_fight_active = false
	# some com o boss e capangas (a arena reseta pro proximo round)
	if is_instance_valid(_boss):
		_boss.set_physics_process(false)
		var btw := _boss.create_tween()
		btw.tween_property(_boss, "modulate:a", 0.0, 0.5)
		btw.tween_callback(_boss.queue_free)
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and e != _boss:
			e.queue_free()
	for pr in get_tree().get_nodes_in_group("enemy_projectile"):
		if is_instance_valid(pr):
			pr.queue_free()
	# espera o fade de morte do player terminar (ele renasce na porta da arena)
	await get_tree().create_timer(2.3).timeout
	_show_continue_screen()

func _show_continue_screen() -> void:
	_attempts += 1
	if is_instance_valid(player):
		player.set_cutscene(true)
	_continue_layer = CanvasLayer.new()
	_continue_layer.layer = 55
	get_tree().root.add_child(_continue_layer)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.01, 0.04, 0.82)
	bg.anchor_right = 1.0; bg.anchor_bottom = 1.0
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_continue_layer.add_child(bg)
	var title := Label.new()
	title.text = "CONTINUE?"
	title.anchor_left = 0.0; title.anchor_right = 1.0
	title.anchor_top = 0.34; title.anchor_bottom = 0.50
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(0.95, 0.25, 0.18))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 3)
	_continue_layer.add_child(title)
	var sub := Label.new()
	sub.text = "Tentativa %d — o mutante espera na arena" % _attempts
	sub.anchor_left = 0.0; sub.anchor_right = 1.0
	sub.anchor_top = 0.50; sub.anchor_bottom = 0.58
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color(0.72, 0.62, 0.78))
	_continue_layer.add_child(sub)
	var prompt := Label.new()
	prompt.text = "[Espaço] Lutar de novo"
	prompt.anchor_left = 0.0; prompt.anchor_right = 1.0
	prompt.anchor_top = 0.62; prompt.anchor_bottom = 0.70
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 18)
	prompt.add_theme_color_override("font_color", Color(0.90, 0.85, 0.60))
	_continue_layer.add_child(prompt)
	var ptw := prompt.create_tween().set_loops()
	ptw.tween_property(prompt, "modulate:a", 0.35, 0.65).set_ease(Tween.EASE_IN_OUT)
	ptw.tween_property(prompt, "modulate:a", 1.0, 0.65).set_ease(Tween.EASE_IN_OUT)
	_awaiting_continue = true

func _unhandled_input(event: InputEvent) -> void:
	if not _awaiting_continue:
		return
	if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and event.keycode == KEY_SPACE):
		_awaiting_continue = false
		_do_continue()

func _do_continue() -> void:
	if is_instance_valid(_continue_layer):
		var l := _continue_layer
		var tw := l.create_tween()
		for c in l.get_children():
			tw.parallel().tween_property(c, "modulate:a", 0.0, 0.3)
		tw.tween_callback(l.queue_free)
	_continue_layer = null
	if is_instance_valid(player):
		player.set_cutscene(false)
	# re-entrada CURTA (sem cinematica longa — retry rapido e' o segredo do HK)
	AudioManager.play("stomp")
	_shake_trees(4400.0, 340.0, 0.10)
	if is_instance_valid(player) and player.has_method("shake"):
		player.shake(6.0, 0.3)
	await get_tree().create_timer(0.5).timeout
	var boss = GoblinMutantScene.instantiate()
	boss.position = Vector2(4480.0, 432.0)
	boss.modulate.a = 0.0
	enemies.add_child(boss)
	VFX.burst(Vector2(4480.0, 380.0), enemies, Color(0.16, 0.42, 0.18), 20, 120.0, 60.0)
	AudioManager.play("roar")
	var tw2 := boss.create_tween()
	tw2.set_parallel(true)
	tw2.tween_property(boss, "modulate:a", 1.0, 0.35)
	tw2.tween_property(boss, "position:x", 4350.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw2.finished
	_arm_boss(boss)

# ── Cinemática: passos que balançam as árvores → o mutante emerge ─────────────

func _boss_entrance() -> Node:
	const SPAWN_X := 4520.0
	const ARENA_X := 4350.0
	# 3 passos, cada um mais perto: chão treme, árvores balançam, folhas caem
	for i in 3:
		AudioManager.play("stomp", 0.75 + i * 0.12)
		if is_instance_valid(player) and player.has_method("shake"):
			player.shake(3.0 + i * 2.5, 0.30)
		_shake_trees(4400.0, 340.0, 0.05 + i * 0.035)
		await get_tree().create_timer(0.55).timeout
	# emerge de tras das arvores: fade-in + passo pra arena
	var boss = GoblinMutantScene.instantiate()
	boss.position = Vector2(SPAWN_X, 432)
	boss.modulate.a = 0.0
	enemies.add_child(boss)
	_shake_trees(SPAWN_X, 220.0, 0.15)
	VFX.burst(Vector2(SPAWN_X, 360), enemies, Color(0.16, 0.42, 0.18), 26, 135.0, 65.0)   # folhas explodem
	VFX.burst(Vector2(SPAWN_X, 420), enemies, Color(0.10, 0.30, 0.12), 14, 90.0, 40.0)
	VFX.ground_burst(Vector2(SPAWN_X, 506.0), enemies, Color(0.30, 0.24, 0.16), 18)
	AudioManager.play("roar")
	if is_instance_valid(player) and player.has_method("shake"):
		player.shake(8.0, 0.4)
	var tw := boss.create_tween()
	tw.set_parallel(true)
	tw.tween_property(boss, "modulate:a", 1.0, 0.45)
	tw.tween_property(boss, "position:x", ARENA_X, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw.finished
	return boss

func _shake_trees(cx: float, radius: float, intensity: float) -> void:
	for t in get_tree().get_nodes_in_group("forest_tree"):
		if not is_instance_valid(t) or absf(t.global_position.x - cx) > radius:
			continue
		var a: float = intensity * randf_range(0.7, 1.3)
		var tw := t.create_tween()
		tw.tween_property(t, "rotation", a, 0.08)
		tw.tween_property(t, "rotation", -a * 0.8, 0.12)
		tw.tween_property(t, "rotation", a * 0.5, 0.10)
		tw.tween_property(t, "rotation", 0.0, 0.12)
		# folhas se soltando da copa (offset pela altura real da textura)
		var ch: float = (t.texture.get_size().y * 0.35 if t.texture else 40.0) * t.scale.y
		VFX.burst(t.global_position + Vector2(randf_range(-18, 18), -ch),
				get_parent(), Color(0.16, 0.40, 0.18), 5, 40.0, 85.0)

# ── Avalanche de pedras que tranca/destranca a arena ──────────────────────────
func _drop_rockwall(x: float) -> Node:
	const FLOOR_Y := 506.0
	const W := 46.0
	const H := 170.0
	var body := StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(W, H)
	cs.shape = rect
	body.add_child(cs)
	var spr := Sprite2D.new()
	var tex := SpriteSetup.get_texture("moss_wall")
	if tex:
		spr.texture = tex
		spr.region_enabled = true
		spr.region_rect = Rect2(0, 0, W, H)
		spr.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.modulate = Color(0.62, 0.58, 0.52)   # tom de rocha (mais escuro que musgo)
	body.add_child(spr)
	var final_y := FLOOR_Y - H * 0.5
	body.position = Vector2(x, final_y - 280.0)   # começa no alto e despenca
	get_parent().add_child(body)
	AudioManager.play("roar", 0.7)
	var tw := body.create_tween()
	tw.tween_property(body, "position:y", final_y, 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		AudioManager.play("stomp")
		if is_instance_valid(player) and player.has_method("shake"):
			player.shake(9.0, 0.35)
		VFX.ground_burst(Vector2(x, FLOOR_Y), get_parent(), Color(0.50, 0.45, 0.38), 26)
		VFX.burst(Vector2(x, FLOOR_Y - 20), get_parent(), Color(0.40, 0.36, 0.30), 16, 120.0, 60.0))
	return body

func _clear_rockwall(node: Node) -> void:
	if not is_instance_valid(node):
		return
	VFX.burst(node.position, get_parent(), Color(0.50, 0.45, 0.38), 28, 150.0, 40.0)
	VFX.ground_burst(Vector2(node.position.x, 506.0), get_parent(), Color(0.45, 0.40, 0.34), 20)
	AudioManager.play("stomp", 0.8)
	if is_instance_valid(player) and player.has_method("shake"):
		player.shake(7.0, 0.3)
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector2(1.0, 0.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(node, "modulate:a", 0.0, 0.35)
	tw.tween_callback(node.queue_free)

func _on_ogre_died() -> void:
	_boss_fight_active = false   # vitoria: morrer daqui pra frente nao reabre o boss
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and e.has_method("take_damage"):
			e.take_damage(9999.0, e.global_position)
	_clear_rockwall(_boss_gate)   # a barreira desmorona — caminho livre
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
	# Clímax do capítulo: o portal leva à Grande Bola de Fogo (anime_fireball).
	GameState.fade_out_then(func():
		get_tree().change_scene_to_file("res://scenes/intro/anime_fireball.tscn")
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
