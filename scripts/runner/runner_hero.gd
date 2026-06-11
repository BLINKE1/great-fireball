extends CharacterBody2D
## Herói do run-and-gun = a maga Soph. Mecânicas no espírito do gênero clássico:
## correr, pular (com coyote time / buffer / pulo variável), AGACHAR, atirar em
## várias direções, power-ups e MORTE EM 1 HIT. Ela LANÇA o míssil com o CAJADO.
## Original/homenagem — sem assets de terceiros.
##
## Controles: setas mover · ↓ agachar · ↑ mirar p/ cima · Espaço pular · Z atirar.

const SPEED       := 150.0
const SPEED_BOOST := 205.0
const GRAVITY     := 1150.0
const JUMP        := -450.0
const JUMP_CUT    := 0.45
const COYOTE      := 0.10
const BUFFER      := 0.10
const SHOT_SPEED  := 400.0
const FIRE_CD     := 0.26
const FIRE_CD_RAPID := 0.14
const MAX_SHOTS   := 4

const Shot := preload("res://scripts/runner/runner_shot.gd")

var facing: float = 1.0
var crouching: bool = false
var alive: bool = true
var invuln: float = 0.0

var _fire_t: float = 0.0
var _coyote: float = 0.0
var _buffer: float = 0.0
var _walk_t: float = 0.0
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
	_spr.position = Vector2(0, -30)
	add_child(_spr)
	_stand.size = Vector2(18, 40)
	_crouch.size = Vector2(18, 22)
	_col = CollisionShape2D.new()
	_col.shape = _stand
	_col.position = Vector2(0, -20)
	add_child(_col)
	var cam := Camera2D.new()
	cam.position = Vector2(70, -70)
	cam.limit_left = 0
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 7.0
	add_child(cam)
	cam.make_current()

func _physics_process(delta: float) -> void:
	if not alive:
		return
	invuln = maxf(invuln - delta, 0.0)
	_fire_t = maxf(_fire_t - delta, 0.0)
	_coyote = maxf(_coyote - delta, 0.0)
	_buffer = maxf(_buffer - delta, 0.0)

	if is_on_floor():
		_coyote = COYOTE
	else:
		velocity.y += GRAVITY * delta

	crouching = is_on_floor() and Input.is_action_pressed("ui_down")
	var ix := 0.0
	if not crouching:
		ix = Input.get_axis("ui_left", "ui_right")
	if ix != 0.0:
		facing = signf(ix)
		_spr.flip_h = facing < 0
	velocity.x = ix * (SPEED_BOOST if pw_speed else SPEED)

	# Pulo com buffer + coyote + corte (variável)
	if Input.is_action_just_pressed("ui_accept"):
		_buffer = BUFFER
	if _buffer > 0.0 and _coyote > 0.0 and not crouching:
		velocity.y = JUMP
		_buffer = 0.0
		_coyote = 0.0
	if Input.is_action_just_released("ui_accept") and velocity.y < 0.0:
		velocity.y *= JUMP_CUT

	# Hitbox/visual de agachado
	_col.shape = _crouch if crouching else _stand
	_col.position = Vector2(0, -11) if crouching else Vector2(0, -20)

	move_and_slide()

	# Bob de caminhada / pose
	if crouching:
		_spr.position = Vector2(0, -20)
		_spr.scale = Vector2(2, 1.5)
	else:
		_spr.scale = Vector2(2, 2)
		if abs(velocity.x) > 5.0 and is_on_floor():
			_walk_t += delta
			_spr.position = Vector2(0, -30 + sin(_walk_t * 18.0) * 1.5)
		else:
			_spr.position = Vector2(0, -30)

	if Input.is_action_pressed("spell_magic_missile") and _fire_t <= 0.0 \
			and get_tree().get_nodes_in_group("rhero_shot").size() < MAX_SHOTS:
		_fire()

	for p in get_tree().get_nodes_in_group("rpower"):
		if is_instance_valid(p) and global_position.distance_to(p.global_position) < 26.0:
			_apply_power(p.get_meta("kind", ""))
			p.queue_free()

	if global_position.y > 800.0:
		_die()
		return

	if invuln <= 0.0 and _touching_danger():
		_die()

	_spr.visible = true if invuln <= 0.0 else (fmod(invuln, 0.2) < 0.1)

func _fire() -> void:
	_fire_t = FIRE_CD_RAPID if pw_rapid else FIRE_CD
	var up := Input.is_action_pressed("ui_up")
	var down := Input.is_action_pressed("ui_down")
	var moving := Input.is_action_pressed("ui_left") or Input.is_action_pressed("ui_right")
	var dir: Vector2
	var hy := -26.0
	if crouching:
		dir = Vector2(facing, 0.0); hy = -10.0                     # agachada: tiro baixo
	elif up and moving:
		dir = Vector2(facing, -1.0).normalized()                  # diagonal p/ cima
	elif up:
		dir = Vector2(0.0, -1.0)                                   # reto p/ cima
	elif down and not is_on_floor():
		dir = Vector2(facing, 1.0).normalized()                   # diagonal p/ baixo (no ar)
	else:
		dir = Vector2(facing, 0.0)                                 # reto à frente
	var origin := global_position + Vector2(facing * 12.0, hy)
	var dirs := [dir]
	if pw_spread:
		dirs = [dir.rotated(-0.20), dir, dir.rotated(0.20)]
	AudioManager.play("missile", randf_range(0.95, 1.1))
	VFX.sparkle(origin, get_parent(), Color(0.6, 0.95, 1.0), 5)    # brilho do cajado
	for d in dirs:
		var s := Shot.new()
		s.vel = d * SHOT_SPEED
		get_parent().add_child(s)
		s.global_position = origin

func _touching_danger() -> bool:
	var chest := global_position + Vector2(0.0, -20.0)
	for e in get_tree().get_nodes_in_group("renemy"):
		if is_instance_valid(e) and chest.distance_to(e.global_position) < (e.hit_r + 8.0):
			return true
	for s in get_tree().get_nodes_in_group("renemy_shot"):
		if is_instance_valid(s) and chest.distance_to(s.global_position) < 14.0:
			return true
	var b := get_tree().get_first_node_in_group("rboss")
	if b and is_instance_valid(b) and chest.distance_to(b.global_position) < (b.hit_r + 8.0):
		return true
	return false

func _die() -> void:
	if not alive:
		return
	alive = false
	VFX.burst(global_position + Vector2(0, -20), get_parent(), Color(0.4, 0.7, 1.0), 26, 160.0, 60.0)
	VFX.ring(global_position + Vector2(0, -20), get_parent(), Color(0.6, 0.8, 1.0, 0.8), 44.0, 0.4)
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
	VFX.sparkle(global_position + Vector2(0, -24), get_parent(), Color(1, 1, 0.6), 12)

func _make_tex() -> ImageTexture:
	# Soph maga (original): chapéu roxo, cabelo, óculos, manto azul, cajado c/ gema.
	var img := Image.create(18, 30, false, Image.FORMAT_RGBA8)
	var ROBE := Color(0.20, 0.45, 0.85)
	var ROBE2 := Color(0.30, 0.58, 0.95)
	var SK := Color(0.97, 0.83, 0.67)
	var HAIR := Color(0.45, 0.30, 0.20)
	var HAT := Color(0.54, 0.27, 0.84)
	var HATD := Color(0.40, 0.18, 0.66)
	var BAND := Color(0.92, 0.78, 0.30)
	# manto
	for y in range(19, 30):
		for x in range(3, 15):
			img.set_pixel(x, y, ROBE if (x + y) % 2 == 0 else ROBE2)
	for y in range(19, 22):
		for x in range(3, 15):
			img.set_pixel(x, y, ROBE2)            # ombros mais claros
	# cabelo (laterais)
	for y in range(12, 22):
		img.set_pixel(4, y, HAIR); img.set_pixel(5, y, HAIR)
		img.set_pixel(12, y, HAIR); img.set_pixel(13, y, HAIR)
	# rosto
	for y in range(12, 19):
		for x in range(5, 13):
			img.set_pixel(x, y, SK)
	# óculos + olhos
	img.set_pixel(7, 15, Color(0.1, 0.1, 0.15)); img.set_pixel(10, 15, Color(0.1, 0.1, 0.15))
	img.set_pixel(6, 15, HATD); img.set_pixel(9, 15, HATD); img.set_pixel(11, 15, HATD)
	# chapéu pontudo
	for y in range(0, 12):
		var hw := int((12 - y) * 0.62) + 1
		for x in range(9 - hw, 9 + hw):
			if x >= 0 and x < 18:
				img.set_pixel(x, y, HAT if x > 9 - hw else HATD)
	for x in range(1, 17):
		img.set_pixel(x, 11, HATD)                # aba
	for x in range(4, 14):
		img.set_pixel(x, 10, BAND)                # faixa dourada
	# cajado (frente) + gema
	for y in range(13, 28):
		img.set_pixel(15, y, Color(0.55, 0.40, 0.24))
	img.set_pixel(15, 12, Color(0.6, 1.0, 0.95)); img.set_pixel(15, 11, Color(0.85, 1.0, 1.0))
	img.set_pixel(14, 12, Color(0.6, 1.0, 0.95, 0.6)); img.set_pixel(16, 12, Color(0.6, 1.0, 0.95, 0.6))
	return ImageTexture.create_from_image(img)
