extends Node2D
## Sala de testes da Soph — foco no desenvolvimento do personagem (sem historia).
##
## Overlay de debug que permite, AO VIVO:
##   - alternar HD <-> pixel-art (tecla H)
##   - ajustar escala da arte HD (tecla [ e ])
##   - ajustar offset vertical da arte HD (tecla ; e ')
##   - resetar a posicao da Soph (tecla R)
##   - ler o estado de animacao atual + velocidade
##
## Os valores de escala/offset sao aplicados direto no AnimatedSprite2D do
## player, entao da pra achar o alinhamento ideal sem reiniciar o jogo. Quando
## gostar, copie os numeros mostrados para HD_SCALE/HD_OFFSET em player.gd.

@onready var player: CharacterBody2D = $Player

var _sprite: AnimatedSprite2D
var _label: Label
var _hd: bool = true
var _scale: float = 0.34
var _offset_y: float = 0.0

const SCALE_STEP := 0.01
const OFFSET_STEP := 1.0

# Goblins de treino — pra sentir o JUICE de combate aqui mesmo no test room.
# (adicionados por script: não tocam no .tscn, então não conflitam com as
#  plataformas que você edita na cena.)
const GoblinScene := preload("res://scenes/enemies/goblin.tscn")
const TRAINING_X := [480, 680, 880]

# Dojo de combate: spawna qualquer inimigo pra sentir o juice + os ataques
# telegrafados (todos avisam antes de bater). Teclas 1-6.
const ENEMY_SCENES := {
	KEY_1: "res://scenes/enemies/goblin.tscn",
	KEY_2: "res://scenes/enemies/goblin_archer.tscn",
	KEY_3: "res://scenes/enemies/goblin_leader.tscn",
	KEY_4: "res://scenes/enemies/golem.tscn",
	KEY_5: "res://scenes/enemies/fire_goblin_archer.tscn",
	KEY_6: "res://scenes/enemies/forest_ogre.tscn",
	KEY_7: "res://scenes/enemies/goblin_mutant.tscn",
}

# ── Torre de bhop/kreedz até a ARENA DO BOSS ──────────────────────────────────
# Coluna de plataformas alinhadas a partir do ponto mais alto atual (TopMid,
# ~580,30). Cada andar de cima funciona como "teto": pra subir você pula pra
# FORA da coluna e volta (double jump) — vai e volta ganhando um andar por pulo.
# No topo, uma plataforma GRANDE: ao pisar nela, o Goblin Mutante spawna.
const MutantScene  := preload("res://scenes/enemies/goblin_mutant.tscn")
const TOWER_X      := 580.0
const TOWER_BASE_Y := 30.0     # referência: TopMid (plataforma mais alta atual)
const TOWER_GAP    := 88.0     # vão vertical entre andares (tato: maior = + difícil)
const TOWER_COUNT  := 10
const TOWER_PLAT_W := 54.0
const TOWER_PLAT_H := 12.0
const ARENA_W      := 340.0
const ARENA_H      := 20.0
var _arena_boss_spawned := false

func _arena_center_y() -> float:
	return TOWER_BASE_Y - (TOWER_COUNT + 1) * TOWER_GAP

func _ready() -> void:
	# Endgame loadout: a sala existe pra sentir o movimento completo da Soph.
	SkillManager.unlock("double_jump")
	SkillManager.unlock("magic_dash")
	SkillManager.unlock("magic_missile")
	# player._ready ja rodou ANTES desse _ready (filho roda antes do pai), entao
	# jumps_remaining ja foi calculado com double_jump bloqueado. Recarrega.
	player.jumps_remaining = player._max_air_jumps()
	# Pega o sprite do player e o estado HD atual como ponto de partida.
	# (player.gd expoe USE_HD_SOPH/HD_SCALE/HD_OFFSET como consts.)
	_sprite = player.get_node("Sprite2D") as AnimatedSprite2D
	_hd = player.USE_HD_SOPH
	_scale = player.HD_SCALE
	_offset_y = player.HD_OFFSET.y
	_build_overlay()
	_apply()
	_spawn_training_goblins.call_deferred()
	_build_bhop_tower()

# ── Goblins de treino ────────────────────────────────────────────────────────
func _spawn_training_goblins() -> void:
	for x in TRAINING_X:
		_spawn_goblin(Vector2(x, 430))

func _spawn_goblin(pos: Vector2) -> void:
	_spawn_enemy(GoblinScene, pos)

func _spawn_enemy(scene: PackedScene, pos: Vector2) -> void:
	if scene == null:
		return
	var e := scene.instantiate()
	add_child(e)
	e.global_position = pos   # após add_child p/ valer global_position

# ── Torre de bhop + arena do Boss ─────────────────────────────────────────────
func _build_bhop_tower() -> void:
	# 10 andares alinhados (coluna), cada um "teto" do de baixo → out-and-back.
	for i in range(1, TOWER_COUNT + 1):
		var y := TOWER_BASE_Y - i * TOWER_GAP
		_make_platform(Vector2(TOWER_X, y), TOWER_PLAT_W, TOWER_PLAT_H,
				Color(0.32, 0.42, 0.58))
	# Plataforma GRANDE da arena no topo.
	var ay := _arena_center_y()
	_make_platform(Vector2(TOWER_X, ay), ARENA_W, ARENA_H, Color(0.48, 0.20, 0.20))
	# Gatilho: pisar na arena spawna o Boss (uma vez).
	var trig := Area2D.new()
	trig.position = Vector2(TOWER_X, ay - 30.0)
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(ARENA_W - 20.0, 44.0)
	cs.shape = rs
	trig.add_child(cs)
	add_child(trig)
	trig.body_entered.connect(_on_arena_entered)

func _make_platform(pos: Vector2, w: float, h: float, col: Color) -> void:
	var body := StaticBody2D.new()
	body.position = pos
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(w, h)
	cs.shape = rs
	body.add_child(cs)
	var spr := Sprite2D.new()
	var ph := PlaceholderTexture2D.new()
	ph.size = Vector2(w, h)
	spr.texture = ph
	spr.modulate = col
	body.add_child(spr)
	add_child(body)

func _on_arena_entered(b: Node) -> void:
	if _arena_boss_spawned:
		return
	if not (b is Node and b.is_in_group("player")):
		return
	_arena_boss_spawned = true
	var ay := _arena_center_y()
	var boss := MutantScene.instantiate()
	add_child(boss)
	boss.global_position = Vector2(TOWER_X, ay - 60.0)   # cai na plataforma

func _build_overlay() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 20
	add_child(cl)
	var panel := PanelContainer.new()
	panel.position = Vector2(8, 8)
	# Quase invisivel: nao polui a tela mas continua legivel se voce procurar.
	panel.modulate = Color(1, 1, 1, 0.22)
	cl.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 10)
	margin.add_child(_label)

func _process(_delta: float) -> void:
	_handle_keys()
	_update_label()

func _handle_keys() -> void:
	if Input.is_action_just_pressed("ui_test_toggle_hd"):
		_hd = not _hd
		_rebuild_frames()
	if Input.is_action_just_pressed("ui_test_scale_up"):
		_scale += SCALE_STEP; _apply()
	if Input.is_action_just_pressed("ui_test_scale_down"):
		_scale = maxf(0.05, _scale - SCALE_STEP); _apply()
	if Input.is_action_just_pressed("ui_test_offset_up"):
		_offset_y -= OFFSET_STEP; _apply()
	if Input.is_action_just_pressed("ui_test_offset_down"):
		_offset_y += OFFSET_STEP; _apply()
	if Input.is_action_just_pressed("ui_test_reset"):
		player.global_position = Vector2(200, 300)
		player.velocity = Vector2.ZERO

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_G:                       # spawna mais um goblin
			_spawn_goblin(Vector2(randf_range(440, 920), 410))
		elif event.keycode == KEY_K:                     # limpa todos os inimigos
			for e in get_tree().get_nodes_in_group("enemy"):
				e.queue_free()
		elif ENEMY_SCENES.has(event.keycode):            # 1-6: spawna por tipo
			_spawn_enemy(load(ENEMY_SCENES[event.keycode]), Vector2(randf_range(460, 900), 400))

func _apply() -> void:
	if not _sprite:
		return
	# player._update_visuals reescreve sprite.scale todo frame como
	# _base_scale * squash. Pra que o ajuste persista, mudamos a _base_scale
	# do player (e não sprite.scale direto).
	if _hd:
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		player._base_scale = Vector2(_scale, _scale)
		_sprite.position = Vector2(0, _offset_y)
	else:
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		player._base_scale = Vector2.ONE
		_sprite.position = Vector2.ZERO

func _rebuild_frames() -> void:
	# Reconstroi o SpriteFrames no modo escolhido, se o player expoe os helpers.
	var anim := _sprite.animation
	var frame := _sprite.frame
	if _hd and player.has_method("_build_soph_frames_hd"):
		_sprite.sprite_frames = player._build_soph_frames_hd()
	elif not _hd and player.has_method("_build_soph_frames_pixel"):
		_sprite.sprite_frames = player._build_soph_frames_pixel()
	_apply()
	if _sprite.sprite_frames and _sprite.sprite_frames.has_animation(anim):
		_sprite.play(anim)
		_sprite.frame = frame

func _update_label() -> void:
	if not _label or not _sprite:
		return
	var spd := absf(player.velocity.x)
	_label.text = "%s  %s  vx %4.0f  scale %.2f  off %.0f\n" % [
			"HD" if _hd else "PX", _sprite.animation, spd, _scale, _offset_y] \
		+ "H mode  [ ] scale  ; ' off  R reset  Q sword  Z miss  Shift dash\n" \
		+ "G goblin  K clear  1gob 2arch 3lead 4golem 5fire 6ogre 7MUTANTE"
