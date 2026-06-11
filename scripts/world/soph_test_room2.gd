extends Node2D
## Test Room 2 — uma ÚNICA plataforma extensa, SEM monstros pré-spawnados.
## Você invoca tudo pelos comandos já existentes (mesmos da test room 1):
##   1 goblin · 2 archer · 3 leader · 4 golem · 5 fire archer · 6 ogre · 7 MUTANTE
##   N goblin · K limpa tudo · 0 facho (bosses) · U cicla Unhas
##   Convoke: V Juju · B Will · G Gus · T Di · W Gui · M Rose · P Zé
## Debug de arte (como na room 1): H modo · [ ] escala · ; ' offset · R reset.
##
## Os inimigos aparecem PERTO da Soph (a plataforma é longa) e caem no chão.

@onready var player: CharacterBody2D = $Player

var _sprite: AnimatedSprite2D
var _label: Label
var _hd: bool = true
var _scale: float = 0.34
var _offset_y: float = 0.0

const SCALE_STEP := 0.01
const OFFSET_STEP := 1.0

const ENEMY_SCENES := {
	KEY_1: "res://scenes/enemies/goblin.tscn",
	KEY_2: "res://scenes/enemies/goblin_archer.tscn",
	KEY_3: "res://scenes/enemies/goblin_leader.tscn",
	KEY_4: "res://scenes/enemies/golem.tscn",
	KEY_5: "res://scenes/enemies/fire_goblin_archer.tscn",
	KEY_6: "res://scenes/enemies/forest_ogre.tscn",
	KEY_7: "res://scenes/enemies/goblin_mutant.tscn",
}

func _ready() -> void:
	# Loadout completo pra testar tudo (igual à room 1).
	SkillManager.unlock("double_jump")
	SkillManager.unlock("magic_dash")
	SkillManager.unlock("magic_missile")
	SkillManager.unlock("convoke")
	SkillManager.unlock("convoke_will")
	SkillManager.unlock("convoke_gus")
	SkillManager.unlock("convoke_di")
	SkillManager.unlock("convoke_gui")
	SkillManager.unlock("convoke_rose")
	SkillManager.unlock("convoke_ze")
	Nails.equip("lava")
	player.jumps_remaining = player._max_air_jumps()
	_sprite = player.get_node("Sprite2D") as AnimatedSprite2D
	_hd = player.USE_HD_SOPH
	_scale = player.HD_SCALE
	_offset_y = player.HD_OFFSET.y
	_build_overlay()
	_apply()

# ── Spawn (perto da Soph) ─────────────────────────────────────────────────────
func _spawn_enemy(scene: PackedScene) -> void:
	if scene == null:
		return
	var e := scene.instantiate()
	add_child(e)
	# aparece um pouco à frente/atrás da Soph e cai no chão
	e.global_position = player.global_position + Vector2(randf_range(-300, 300), -160)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_N:
			_spawn_enemy(load("res://scenes/enemies/goblin.tscn"))
		elif event.keycode == KEY_K:
			for e in get_tree().get_nodes_in_group("enemy"):
				e.queue_free()
		elif event.keycode == KEY_0:
			for b in get_tree().get_nodes_in_group("boss"):
				if is_instance_valid(b) and b.has_method("force_beam"):
					b.force_beam()
		elif event.keycode == KEY_U:
			Nails.cycle()
		elif ENEMY_SCENES.has(event.keycode):
			_spawn_enemy(load(ENEMY_SCENES[event.keycode]))

# ── Debug de arte / overlay (igual à room 1) ─────────────────────────────────
func _build_overlay() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 20
	add_child(cl)
	var panel := PanelContainer.new()
	panel.position = Vector2(8, 8)
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

func _apply() -> void:
	if not _sprite:
		return
	if _hd:
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		player._base_scale = Vector2(_scale, _scale)
		_sprite.position = Vector2(0, _offset_y)
	else:
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		player._base_scale = Vector2.ONE
		_sprite.position = Vector2.ZERO

func _rebuild_frames() -> void:
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
	_label.text = "TEST ROOM 2 — plataforma única, sem monstros (você spawna)\n" \
		+ "%s  %s  vx %4.0f  scale %.2f  off %.0f\n" % [
			"HD" if _hd else "PX", _sprite.animation, spd, _scale, _offset_y] \
		+ "Convoke: V Juju  B Will  G Gus  T Di  W Gui  M Rose  P Ze\n" \
		+ "U Unhas: " + Nails.display_name() + "   0 facho(bosses)   K limpa\n" \
		+ "Spawn: N goblin  1gob 2arch 3lead 4golem 5fire 6ogre 7MUTANTE"
