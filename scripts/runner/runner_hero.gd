extends CharacterBody2D
## Herói do run-and-gun = a maga Soph. Mecânicas no espírito do gênero clássico:
## correr, pular, AGACHAR, atirar em várias direções, power-ups e MORTE EM 1 HIT.
## Projétil = míssil mágico (em vez de "cuspe"), na mesma altura/origem do tiro.
## Tudo original/homenagem — sem assets de terceiros.
##
## Controles: setas mover, ↓ agachar, ↑ mirar pra cima, Espaço pular, Z atirar.

const SPEED       := 140.0
const SPEED_BOOST := 190.0
const GRAVITY     := 1100.0
const JUMP        := -420.0
const SHOT_SPEED  := 380.0
const FIRE_CD     := 0.30
const FIRE_CD_RAPID := 0.16
const MAX_SHOTS   := 3

const Shot := preload("res://scripts/runner/runner_shot.gd")

var facing: float = 1.0
var crouching: bool = false
var alive: bool = true
var invuln: float = 0.0
var _fire_t: float = 0.0
var pw_spread: bool = false
var pw_rapid: bool = false
var pw_speed: bool = false

var _spr: Sprite2D
var _col: CollisionShape2D
var _stand := RectangleShape2D.new()
var _crouch := RectangleShape2D.new()

func _ready() -> void:
	add_to_group("rhero")
	collision_layer = 0
	collision_mask = 1
	_spr = Sprite2D.new()
	_spr.texture = _make_tex()
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.scale = Vector2(2, 2)
	_spr.position = Vector2(0, -14)
	add_child(_spr)
	_stand.size = Vector2(16, 28)
	_crouch.size = Vector2(16, 16)
	_col = CollisionShape2D.new()
	_col.shape = _stand
	_col.position = Vector2(0, -14)
	add_child(_col)
	var cam := Camera2D.new()
	cam.position = Vector2(60, -60)
	cam.limit_left = 0
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 6.0
	add_child(cam)
	cam.make_current()

func _physics_process(delta: float) -> void:
	if not alive:
		return
	invuln = maxf(invuln - delta, 0.0)
	_fire_t = maxf(_fire_t - delta, 0.0)
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	crouching = is_on_floor() and Input.is_action_pressed("ui_down")
	var ix := 0.0
	if not crouching:
		ix = Input.get_axis("ui_left", "ui_right")
	if ix != 0.0:
		facing = signf(ix)
		_spr.flip_h = facing < 0
	velocity.x = ix * (SPEED_BOOST if pw_speed else SPEED)

	if Input.is_action_just_pressed("ui_accept") and is_on_floor() and not crouching:
		velocity.y = JUMP

	# Hitbox/visual de agachado
	_col.shape = _crouch if crouching else _stand
	_col.position = Vector2(0, -8) if crouching else Vector2(0, -14)
	_spr.scale = Vector2(2, 1.35) if crouching else Vector2(2, 2)
	_spr.position = Vector2(0, -9) if crouching else Vector2(0, -14)

	move_and_slide()

	if Input.is_action_pressed("spell_magic_missile") and _fire_t <= 0.0 \
			and get_tree().get_nodes_in_group("rhero_shot").size() < MAX_SHOTS:
		_fire()

	# Power-ups no chão
	for p in get_tree().get_nodes_in_group("rpower"):
		if is_instance_valid(p) and global_position.distance_to(p.global_position) < 24.0:
			_apply_power(p.get_meta("kind", ""))
			p.queue_free()

	# Queda no buraco = morte
	if global_position.y > 760.0:
		_die()
		return

	# Dano (1 hit) — só fora do i-frame de respawn
	if invuln <= 0.0 and _touching_danger():
		_die()

	# Blink de i-frame
	_spr.visible = true if invuln <= 0.0 else (fmod(invuln, 0.2) < 0.1)

func _fire() -> void:
	_fire_t = FIRE_CD_RAPID if pw_rapid else FIRE_CD
	var up := Input.is_action_pressed("ui_up")
	var moving := Input.is_action_pressed("ui_left") or Input.is_action_pressed("ui_right")
	var dir: Vector2
	var hy := -18.0
	if crouching:
		dir = Vector2(facing, 0.0); hy = -7.0          # tiro baixo agachado
	elif up and moving:
		dir = Vector2(facing, -1.0).normalized()        # diagonal pra cima
	elif up:
		dir = Vector2(0.0, -1.0)                          # reto pra cima
	else:
		dir = Vector2(facing, 0.0)                        # reto à frente
	var origin := global_position + Vector2(facing * 9.0, hy)
	var dirs := [dir]
	if pw_spread:
		dirs = [dir.rotated(-0.20), dir, dir.rotated(0.20)]
	AudioManager.play("missile", randf_range(0.95, 1.1))
	for d in dirs:
		var s := Shot.new()
		s.vel = d * SHOT_SPEED
		get_parent().add_child(s)
		s.global_position = origin

func _touching_danger() -> bool:
	var chest := global_position + Vector2(0.0, -14.0)
	for e in get_tree().get_nodes_in_group("renemy"):
		if is_instance_valid(e) and chest.distance_to(e.global_position) < (e.hit_r + 7.0):
			return true
	for s in get_tree().get_nodes_in_group("renemy_shot"):
		if is_instance_valid(s) and chest.distance_to(s.global_position) < 13.0:
			return true
	var b := get_tree().get_first_node_in_group("rboss")
	if b and is_instance_valid(b) and chest.distance_to(b.global_position) < (b.hit_r + 8.0):
		return true
	return false

func _die() -> void:
	if not alive:
		return
	alive = false
	VFX.burst(global_position + Vector2(0, -14), get_parent(), Color(0.4, 0.7, 1.0), 24, 150.0, 60.0)
	VFX.ring(global_position + Vector2(0, -14), get_parent(), Color(0.6, 0.8, 1.0, 0.8), 40.0, 0.4)
	AudioManager.play("hit_player")
	var mgr := get_parent()
	if mgr and mgr.has_method("hero_died"):
		mgr.hero_died()

func respawn(pos: Vector2) -> void:
	global_position = pos
	velocity = Vector2.ZERO
	alive = true
	invuln = 1.8
	pw_spread = false
	pw_rapid = false
	pw_speed = false
	_spr.visible = true

func _apply_power(kind: String) -> void:
	match kind:
		"spread": pw_spread = true
		"rapid":  pw_rapid = true
		"speed":  pw_speed = true
	AudioManager.play("orb_pickup", randf_range(1.05, 1.2))
	VFX.sparkle(global_position + Vector2(0, -16), get_parent(), Color(1, 1, 0.6), 10)

func _make_tex() -> ImageTexture:
	# Soph mini (maga): chapéu roxo pontudo, rosto, manto azul. Procedural.
	var img := Image.create(16, 28, false, Image.FORMAT_RGBA8)
	var ROBE := Color(0.20, 0.45, 0.85)
	var SK := Color(0.96, 0.82, 0.66)
	var HAT := Color(0.52, 0.26, 0.82)
	var HATD := Color(0.40, 0.18, 0.66)
	for y in range(16, 28):
		for x in range(3, 13):
			img.set_pixel(x, y, ROBE)
	for y in range(10, 16):
		for x in range(4, 12):
			img.set_pixel(x, y, SK)
	img.set_pixel(6, 13, Color(0.1, 0.1, 0.15)); img.set_pixel(9, 13, Color(0.1, 0.1, 0.15))
	# óculos (toque da Soph)
	img.set_pixel(5, 13, HATD); img.set_pixel(10, 13, HATD)
	# chapéu pontudo
	for y in range(0, 10):
		var hw := int((10 - y) * 0.72) + 1
		for x in range(8 - hw, 8 + hw):
			if x >= 0 and x < 16:
				img.set_pixel(x, y, HAT)
	for x in range(1, 15):
		img.set_pixel(x, 9, HATD)   # aba
	return ImageTexture.create_from_image(img)
